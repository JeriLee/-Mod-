-- 月台仪式 · 月圆充能流程与月台存档
--
-- 两阶段流程（对齐原版唤星者法杖 OnStaffGiven -> ToggleMoonCharge）：
--   阶段1 预充能：播放 recharging_full 蓄力动画，
--                 时长 = 月台 fullmoonstartdelay（最少 MIN_CHARGE_START_DELAY）
--   阶段2 爆发：  挂 mooncharge 计时器 + 刷月兽 + 光柱特效
--   计时结束：    充能次数 +1，达到 CHARGES 则完成月淬
--
-- 注意：本文件是 require 进来的普通模块，引擎接口从 GLOBAL 取。

local G = require("shared/genv")
local Config = require("moonbase_ritual/config")
local Util = require("moonbase_ritual/util")
local FxStar = require("moonbase_ritual/fx_star")
local FxSymbol = require("moonbase_ritual/fx_symbol")
local FxCharge = require("moonbase_ritual/fx_charge")
local Moonforged = require("moonbase_ritual/moonforged")

local TheWorld = G.Lazy("TheWorld")
local SpawnPrefab = G.Lazy("SpawnPrefab")

local MoonCharge = {}

--------------------------------------------------------------------------
-- 尝试启动充能
-- 触发时机：月圆开始 / 月圆夜中途插入武器 / 读档恢复
--------------------------------------------------------------------------
function MoonCharge.TryStart(i)
	if not TheWorld.ismastersim then
		return
	end

	if not i:IsValid() or not Util.MoonHasSpear(i) or not Util.MoonIsFixed(i) then
		return
	end

	if not TheWorld.state.isfullmoon or i._thunderspear_charging then
		return
	end

	-- 已经是月淬形态则无需再充能
	if i._thunderspear_ismoon then
		return
	end

	i._thunderspear_charging = true

	-- 阶段1：预充能
	-- 仅仅播放月台蓄力动画，并清理可能残留的旧计时器/特效
	FxCharge.Stop(i, false)
	if not i.AnimState:IsCurrentAnimation("recharging_full") then
		i.AnimState:PlayAnimation("recharging_full", true)
	end

	if i.components.timer ~= nil then
		local left = i.components.timer:GetTimeLeft("fullmoonstartdelay")
		local predelay = math.max(Config.MIN_CHARGE_START_DELAY,
			left or Config.MIN_CHARGE_START_DELAY)
		i.components.timer:StopTimer("spearcharge_pre")
		i.components.timer:StartTimer("spearcharge_pre", predelay)
	end
end

--------------------------------------------------------------------------
-- 内部：完成月淬（把月台上的矛换成带 moon 标签的普通奔雷矛）
--------------------------------------------------------------------------
local function FinishMoonforge(i)
	local uses = i._thunderspear_uses or 1

	i._thunderspear_charges = 0
	-- 保留插入时的形态：普通矛进来还是普通矛，充能矛进来还是充能矛。
	-- （早期版本在这里强制换成普通奔雷矛，会把玩家的充能矛静默降级：
	--   耐久 200->150、冲刺冷却 3s->1.5s、移速 x1.2->x1.0，还失去冲刺回耐久）
	-- 皮肤名必须与 prefab 配套：充能形态的皮肤会调用只有充能形态才有的
	-- SetFxOwner，用普通形态的 prefab 套上去会在初始化时直接崩溃。
	i._thunderspear_skin = Util.MatchSkin(i._thunderspear, i._thunderspear_skin)
	i._thunderspear_ismoon = true

	-- 记下旧矛的充能能量，避免仪式完成后能量被清零
	local chargepercent = nil
	if i._staffinst ~= nil and i._staffinst:IsValid()
		and i._staffinst.components.rechargeable ~= nil then
		chargepercent = i._staffinst.components.rechargeable:GetPercent()
	end

	if i._staffinst ~= nil and i._staffinst:IsValid() then
		i:RemoveChild(i._staffinst)
		i._staffinst:Remove()
	end

	local proxy = SpawnPrefab(i._thunderspear, i._thunderspear_skin, i._thunderspear_skinid)
	if proxy ~= nil then
		if proxy.components.finiteuses ~= nil then
			proxy.components.finiteuses:SetPercent(uses)
		end
		if chargepercent ~= nil and proxy.components.rechargeable ~= nil then
			proxy.components.rechargeable:SetPercent(chargepercent)
		end
		-- 先挂到月台上并移出场景，再施加月淬效果
		i:AddChild(proxy)
		proxy.Transform:SetPosition(0, 0, 0)
		proxy:RemoveFromScene()
		i._staffinst = proxy
		i._staffuse = nil

		-- 打上月淬标签，增伤 / 夜修都以此为开关
		proxy:AddTag(Config.MOON_TAG)
		Moonforged.Apply(proxy)
	end

	-- 更新月台上显示的贴图
	FxSymbol.Apply(i)

	if i.components.moonbeastspawner ~= nil then
		i.components.moonbeastspawner:ForcePetrify()
		i.components.moonbeastspawner:Stop()
	end

	-- 仪式完成：收尾光柱并显示升级完成光球
	FxCharge.Stop(i, true)
	FxStar.Show(i)
end

--------------------------------------------------------------------------
-- 处理充能计时结束
--------------------------------------------------------------------------
local function OnTimerDone(i, data)
	if data == nil then
		return
	end

	-- 阶段1 结束 -> 进入阶段2
	if data.name == "spearcharge_pre" then
		if not Util.MoonHasSpear(i) or not i._thunderspear_charging then
			return
		end
		if not TheWorld.state.isfullmoon or not Util.MoonIsFixed(i) then
			return
		end
		FxCharge.EnterPhase2(i)
		return
	end

	if data.name ~= "mooncharge" then
		return
	end

	if not Util.MoonHasSpear(i) or not i._thunderspear_charging then
		return
	end

	i._thunderspear_charging = nil
	i._thunderspear_charges = (i._thunderspear_charges or 0) + 1

	if i._thunderspear_charges < Config.CHARGES then
		-- 还没攒够次数，停掉本轮特效等待下个月圆
		if i.components.moonbeastspawner ~= nil then
			i.components.moonbeastspawner:Stop()
		end
		FxCharge.Stop(i, false)
		return
	end

	FinishMoonforge(i)
end

--------------------------------------------------------------------------
-- 存档 / 读档
--------------------------------------------------------------------------
local function SetupSaveLoad(inst)
	local oldOnSave = inst.OnSave
	inst.OnSave = function(i, data)
		if oldOnSave ~= nil then
			oldOnSave(i, data)
		end
		if Util.MoonHasSpear(i) then
			data.thunderspear = i._thunderspear
			data.thunderspear_uses = i._thunderspear_uses
			data.thunderspear_skin = i._thunderspear_skin
			data.thunderspear_skinid = i._thunderspear_skinid
			data.thunderspear_ismoon = i._thunderspear_ismoon
			data.thunderspear_charges = i._thunderspear_charges
		end
	end

	local oldOnLoad = inst.OnLoad
	inst.OnLoad = function(i, data)
		if oldOnLoad ~= nil then
			oldOnLoad(i, data)
		end
		if data == nil or data.thunderspear == nil then
			return
		end

		i._thunderspear = data.thunderspear
		i._thunderspear_uses = data.thunderspear_uses or 1
		-- 旧存档可能存过"普通 prefab + 充能皮肤"这种不匹配的组合，
		-- 读档时必须把皮肤纠正回与 prefab 匹配的那个，否则会崩
		i._thunderspear_skin = Util.MatchSkin(i._thunderspear, data.thunderspear_skin)
		i._thunderspear_skinid = data.thunderspear_skinid
		i._thunderspear_ismoon = data.thunderspear_ismoon
		i._thunderspear_charges = data.thunderspear_charges or 0

		i:DoTaskInTime(0, function(ii)
			if not ii:IsValid() or not Util.MoonHasSpear(ii) then
				return
			end

			local proxy = SpawnPrefab(ii._thunderspear, ii._thunderspear_skin,
				ii._thunderspear_skinid)
			if proxy ~= nil then
				if proxy.components.finiteuses ~= nil then
					proxy.components.finiteuses:SetPercent(ii._thunderspear_uses or 1)
				end
				if ii._thunderspear_ismoon then
					proxy:AddTag(Config.MOON_TAG)
					Moonforged.Apply(proxy)
				end
				ii:AddChild(proxy)
				proxy.Transform:SetPosition(0, 0, 0)
				proxy:RemoveFromScene()
				ii._staffinst = proxy
				ii._staffuse = nil
			end

			-- 读档后恢复贴图
			FxSymbol.Apply(ii)

			if ii._thunderspear_net ~= nil then
				ii._thunderspear_net:set(true)
			end

			-- 已是月淬形态，恢复升级完成光球
			if ii._thunderspear_ismoon then
				FxStar.Show(ii)
			end

			-- 若读档时正是月圆，恢复充能与特效
			MoonCharge.TryStart(ii)
		end)
	end
end

--------------------------------------------------------------------------
-- 在月台上装配充能相关的事件监听
--------------------------------------------------------------------------
function MoonCharge.Setup(inst)
	-- 月台被移除/摧毁时清理光球
	inst:ListenForEvent("onremove", function(i)
		FxStar.Hide(i)
	end)

	-- 月圆状态切换
	inst:WatchWorldState("isfullmoon", function(i, isfullmoon)
		if isfullmoon then
			i:DoTaskInTime(0, function(ii)
				MoonCharge.TryStart(ii)
			end)
		else
			-- 月圆结束，一并停掉两个计时器与特效
			i._thunderspear_charging = nil
			if i.components.moonbeastspawner ~= nil then
				i.components.moonbeastspawner:Stop()
			end
			FxCharge.Stop(i, false)
		end
	end)

	-- 充能计时结束
	inst:ListenForEvent("timerdone", OnTimerDone)

	-- 插入武器后主动尝试开始充能（月圆夜中途插入时世界状态不会切换）
	inst:ListenForEvent("moonbase_spear_inserted", function(i)
		MoonCharge.TryStart(i)
	end)

	SetupSaveLoad(inst)
end

return MoonCharge
