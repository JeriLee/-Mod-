GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})  --GLOBAL相关照抄


PrefabFiles = {
	"wigfridarmor",
	"moonforged_spear",
}

Assets = {
}

STRINGS.NAMES.WIGFRIDARMOR = "女武神战甲"
STRINGS.NAMES.MOONFORGED_SPEAR = "月淬奔雷矛"
STRINGS.RECIPE_DESC.MOONFORGED_SPEAR = "被月光淬炼过的奔雷矛，对暗影生物有额外伤害，夜里会缓慢恢复耐久"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.MOONFORGED_SPEAR = "月光淬炼的战矛。"
STRINGS.RECIPE_DESC.WIGFRIDARMOR = "女武神要有像样的战甲，我看石头和金子就很合适嘛"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.WIGFRIDARMOR = "他很适合女武神."

AddRecipe("wigfridarmor",
{Ingredient("goldnugget", 2),Ingredient("rocks", 2)},
RECIPETABS.WAR, TECH.NONE,
nil, nil, nil, nil, "valkyrie",
"images/inventoryimages/wigfridarmor.xml",
"wigfridarmor.tex")


--------------------------------------------------------------------------
-- 奔雷矛 · 月台充能
--------------------------------------------------------------------------

local SPEAR = "spear_wathgrithr_lightning"
local SPEAR_CHARGED = "spear_wathgrithr_lightning_charged"
local MOONFORGED_SPEAR = "moonforged_spear"
local REPAIR_MATERIAL = "thulecite_pieces"

-- 月淬奔雷矛固定使用的 lunar 皮肤 build（与 moonforged_spear.lua 中一致）
local MOONFORGED_SKIN = "spear_wathgrithr_lightning_lunar"

-- 奔雷矛在月台上显示用的 build 符号
-- （普通形态和充能形态公用一套build 和 swap 符号） 见 scripts/prefabs/spear_wathgrithr.lua
local SPEAR_SWAP_BUILD = "spear_wathgrithr_lightning"
local SPEAR_SWAP_SYMBOL = "swap_spear_wathgrithr_lightning"

-- 月圆充能光柱/脉冲颜色（RGBA，0~1）
-- 原版月台光柱是青白色；这里用乘法着色(SetMultColour)把它染成指定颜色。
-- 白底 × 本颜色 = 显示颜色，分量越小越暗。{1,1,1,1} 即原版白色。
-- 光柱由三层组成，可分别着色：
--   SPEAR_BEAM_COLOUR_PULSE = 中间脉冲(positronpulse)
--   SPEAR_BEAM_COLOUR_BACK  = 后层光柱(positronbeam_back)
--   SPEAR_BEAM_COLOUR_FRONT = 前层光柱(positronbeam_front)
local SPEAR_BEAM_COLOUR_PULSE = { 1,    0.2, 0.2, 1 }   -- 中间：红色
local SPEAR_BEAM_COLOUR_BACK  = { 0.3,  0.5, 1,   1 }   -- 一侧：蓝色
local SPEAR_BEAM_COLOUR_FRONT = { 1,    1,   1,   1 }   -- 另一侧：白色

local function GetCfg(key, default)
	local ok, v = pcall(GetModConfigData, key)
	if ok and v ~= nil then
		return v
	end
	return default
end

local ENABLE = GetCfg("ThunderSpear_Enable", true)
local CHARGES = GetCfg("ThunderSpear_Charges", 1)
local NIGHT_HOURS = GetCfg("ThunderSpear_NightHours", 12)
local REPAIR_HP = GetCfg("ThunderSpear_RepairHP", 2)


if ENABLE then

	-- 预充能最短时长 （对齐原版 moonbase 的 MIN_CHARGE_START_DELAY = 1)
	local MIN_CHARGE_START_DELAY = 1

	local function IsSpear(item)
		return item ~= nil and (item.prefab == SPEAR or item.prefab == SPEAR_CHARGED)
	end

	local function MoonIsFixed(inst)
		local w = inst.components.workable
		return w ~= nil and (w.workleft or 0) > TUNING.MOONBASE_DAMAGED_WORK
	end

	local function MoonHasSpear(inst)
		return inst._thunderspear ~= nil
	end

	-- 升级完成后月台上的光球特效（对应原版 moonbase 的 ShowColdStar / HideColdStar）
	local function ShowSpearStar(i)
		if i._spearstar == nil then
			i._spearstar = SpawnPrefab("staffcoldlightfx")
			if i._spearstar ~= nil then
				i._spearstar.entity:SetParent(i.entity)
				if i.Light:IsEnabled() then
					i.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
				end
			end
		end
	end

	local function HideSpearStar(i)
		if i._spearstar ~= nil then
			i._spearstar:Remove()
			i._spearstar = nil
			if not i.Light:IsEnabled() then
				i.AnimState:ClearBloomEffectHandle()
			end
		end
	end

	-- 根据月台上代理实体(_staffinst)的皮肤,覆盖 swap_staffs 槽位的贴图
	--  - 有皮肤：用OverrideItemSkinSymbol (皮肤 build + BUILD，默认build兜底)
	--  - 无皮肤：用OverrideSymbol(默认 build)
	-- 参考 scripts/perfabs/spear_wathgrithr.lua 的 OnEquip 写法
	local function ApplySpearSymbol(inst)
		local proxy = inst._staffinst

		-- 月淬奔雷矛：固定 lunar 皮肤外观
		if proxy ~= nil and proxy:IsValid() and proxy.prefab == MOONFORGED_SPEAR then
			inst.AnimState:OverrideItemSkinSymbol("swap_staffs", MOONFORGED_SKIN, SPEAR_SWAP_SYMBOL, proxy.GUID, SPEAR_SWAP_BUILD)
			return
		end

		local skin_build = nil
		if proxy ~= nil and proxy:IsValid() and proxy.GetSkinBuild ~= nil then
			skin_build = proxy:GetSkinBuild()
			if skin_build == "" then
				skin_build = nil
			end
		end

		if skin_build ~= nil then
			inst.AnimState:OverrideItemSkinSymbol("swap_staffs", skin_build, SPEAR_SWAP_SYMBOL, proxy.GUID, SPEAR_SWAP_BUILD)
		else
			inst.AnimState:OverrideSymbol("swap_staffs", SPEAR_SWAP_BUILD, SPEAR_SWAP_SYMBOL)
		end
	end

	-- 月圆充能视觉特效
	-- 复刻原版moonbase 的光柱/脉冲/光效/充能动画
	local function SpearFX_CancelLevelTasks(i)
		if i._spearfx_lvtask2 ~= nil then i._spearfx_lvtask2:Cancel(); i._spearfx_lvtask2 = nil end
		if i._spearfx_lvtask3 ~= nil then i._spearfx_lvtask3:Cancel(); i._spearfx_lvtask3 = nil end
	end

	local function SpearFX_Stop(i, finished)
		SpearFX_CancelLevelTasks(i)

		-- 停掉两个阶段计时器
		if i.components.timer ~= nil then
			i.components.timer:StopTimer("spearcharge_pre")
			i.components.timer:StopTimer("mooncharge")
		end

		if i._spearfx_pulse ~= nil then
			if i._spearfx_pulse:IsValid() then
				if finished then i._spearfx_pulse:FinishFX() else i._spearfx_pulse:Remove() end
			end
			i._spearfx_pulse = nil
		end

		if i._spearfx_front ~= nil then
			if i._spearfx_front:IsValid() then i._spearfx_front:KillFX() end
			i._spearfx_front = nil
		end

		if i._spearfx_back ~= nil then
			if i._spearfx_back:IsValid() then i._spearfx_back:KillFX() end
			i._spearfx_back = nil
		end

		i.Light:Enable(false)
		i.AnimState:ClearBloomEffectHandle()
		i:RemoveTag("intense")
		if i.AnimState:IsCurrentAnimation("recharging_full") then
			i.AnimState:PlayAnimation("full")
		end
	end

	-- 阶段2：爆发 光柱+脉冲+强光+脉冲等级推进
	-- (recharging_full 动画在阶段1已经在播放)
	local function SpearFX_StartBeams(i)
		local x, y, z = i.Transform:GetWorldPosition()

		if i._spearfx_front == nil or not i._spearfx_front:IsValid() then
			i._spearfx_back = SpawnPrefab("positronbeam_back")
			i._spearfx_back.Transform:SetPosition(x, y, z)
			i._spearfx_front = SpawnPrefab("positronbeam_front")
			i._spearfx_front.Transform:SetPosition(x, y, z)
			i._spearfx_pulse = SpawnPrefab("positronpulse")
			i._spearfx_pulse.Transform:SetPosition(x, y, z)
			-- 染色不在这里做： SetMultColour 在服务端对客户端无效
			-- 改由三个 FX prefab的AddPrefabPostInit 在两端各自染色（见文件底部）
		end

		-- 光 + 泛光
		i.Light:Enable(true)
		i.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

		-- 充能动画（月台完整时状态为full；阶段1 通常已经在播放）
		if not i.AnimState:IsCurrentAnimation("recharging_full") then
			i.AnimState:PlayAnimation("recharging_full", true)
		end

		-- 脉冲强度分级： 第1阶段 -> 等级2(intense), 第2阶段 -> 等级3
		SpearFX_CancelLevelTasks(i)
		local t2 = math.min(TUNING.MOONBASE_CHARGE_DURATION1, TUNING.MOONBASE_CHARGE_DURATION)
		i._spearfx_lvtask2 = i:DoTaskInTime(t2, function(ii)
			ii._spearfx_lvtask2 = nil
			if ii._spearfx_pulse ~= nil and ii._spearfx_pulse:IsValid() then
				ii._spearfx_pulse:SetLevel(2)
			end
			ii:AddTag("intense")
		end)
		local t3 = math.min(TUNING.MOONBASE_CHARGE_DURATION1 * 2, TUNING.MOONBASE_CHARGE_DURATION)
		i._spearfx_lvtask3 = i:DoTaskInTime(t3, function(ii)
			ii._spearfx_lvtask3 = nil
			if ii._spearfx_pulse ~= nil and ii._spearfx_pulse:IsValid() then
				ii._spearfx_pulse:SetLevel(3)
			end
		end)
	end

	-- 阶段 2 正式开始： 挂mooncharge 计时器 + 刷月兽 + 爆发特效
	local function SpearCharge_EnterPhase2(i)
		if i.components.timer ~= nil then
			-- 计时器必须命名为 mooncharge ： 月兽brain (moonbeastbrain.lua)硬编码
			-- 判断月台上是否存在计时器来判断仪式是否在进行中，否则会立即石化
			i.components.timer:StopTimer("mooncharge")
			i.components.timer:StartTimer("mooncharge", TUNING.MOONBASE_CHARGE_DURATION)
		end

		if i.components.moonbeastspawner ~= nil then
			i.components.moonbeastspawner:Start()
		end
		SpearFX_StartBeams(i)
	end

	-- 尝试启动充能 （当前为月圆，月台完整，插着未能充能的矛时）
	-- 既用于月圆开始，也用于 月圆夜中途插入奔雷矛 - 后者 isfullmoon状态
	-- 不切换，WatchWorldState 回调不会触发，必须由插入动作主动调用
	-- 以对齐原版唤星者法杖 OnStaffGiven -> ToggleMoonCharge 的行为
	--
	-- 两阶段流程，对齐星杖：
	-- 阶段1 预充能：只播放 recharging_full 蓄力动画，时长 = 月台 fullmoonstartdelay
	-- 阶段2 爆发：todo 注释待补充

	local function TryStartSpearCharge(i)
		if not TheWorld.ismastersim then
			return
		end

		if not i:IsValid() or not MoonHasSpear(i) or not MoonIsFixed(i) then
			return
		end

		if not TheWorld.state.isfullmoon or i._thunderspear_charging then
			return
		end

		-- 已经是月淬形态则无需再充能
		if i._thunderspear == MOONFORGED_SPEAR then
			return
		end

		i._thunderspear_charging = true

		-- 阶段1：预充能：仅仅播放月台蓄力动画，并且清理可能残留的旧计时器/特效
		SpearFX_Stop(i, false)
		if not i.AnimState:IsCurrentAnimation("recharging_full") then
			i.AnimState:PlayAnimation("recharging_full", true)
		end

		if i.components.timer ~= nil then
			local left = i.components.timer:GetTimeLeft("fullmoonstartdelay")
			local predelay = math.max(MIN_CHARGE_START_DELAY, left or MIN_CHARGE_START_DELAY)
			i.components.timer:StopTimer("spearcharge_pre")
			i.components.timer:StartTimer("spearcharge_pre", predelay)
		end
	end

	------------------------------------------------------------------------
	-- 插入
	------------------------------------------------------------------------
	local function MoonInsert(inst, item)
		if item == nil or not IsSpear(item) or MoonHasSpear(inst) then
			return false
		end
		if not MoonIsFixed(inst) then
			return false
		end

		local uses = item.components.finiteuses ~= nil and item.components.finiteuses:GetPercent() or 1
		local skinname = item.skinname
		local skinid = item.skin_id

		inst._thunderspear = item.prefab
		inst._thunderspear_uses = uses
		inst._thunderspear_skin = skinname
		inst._thunderspear_skinid = skinid
		inst._thunderspear_charges = 0
		inst._thunderspear_charging = nil

		-- 生成一个真正的武器实体挂到月台上（复用 _staffinst 字段）
		local proxy = SpawnPrefab(item.prefab, skinname, skinid)
		if proxy ~= nil then
			if proxy.components.finiteuses ~= nil then
				proxy.components.finiteuses:SetPercent(uses)
			end
			inst:AddChild(proxy)
			proxy.Transform:SetPosition(0, 0, 0)
			proxy:RemoveFromScene()
			inst._staffinst = proxy
			inst._staffuse = nil
		end

		-- 显示矛符号
		ApplySpearSymbol(inst)

		inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/moonstaff_place")

		-- 同步"插着矛"状态给客户端
		if inst._thunderspear_net ~= nil then
			inst._thunderspear_net:set(true)
		end

		-- 若此刻正是月圆之夜，则立即开始充能
		TryStartSpearCharge(inst)

		return true
	end

	------------------------------------------------------------------------
	-- 取下
	------------------------------------------------------------------------
	local function MoonTakeOut(inst, doer)
		if not MoonHasSpear(inst) then
			return nil
		end

		local uses = inst._thunderspear_uses or 1

		-- 停掉充能
		inst._thunderspear_charging = nil
		if inst.components.moonbeastspawner ~= nil then
			inst.components.moonbeastspawner:Stop()
		end
		SpearFX_Stop(inst, false)
		HideSpearStar(inst)

		-- 取出代理实体
		local result = nil
		if inst._staffinst ~= nil and inst._staffinst:IsValid() then
			inst:RemoveChild(inst._staffinst)
			inst._staffinst:ReturnToScene()
			if inst._staffinst.components.finiteuses ~= nil then
				inst._staffinst.components.finiteuses:SetPercent(uses)
			end
			result = inst._staffinst
			inst._staffinst = nil
		else
			local spear = inst._thunderspear
			local skinname = inst._thunderspear_skin
			local skinid = inst._thunderspear_skinid
			-- 月淬矛固定 lunar 外观，不传皮肤参数
			if spear == MOONFORGED_SPEAR then
				skinname, skinid = nil, nil
			end
			result = SpawnPrefab(spear, skinname, skinid)
			if result ~= nil and result.components.finiteuses ~= nil then
				result.components.finiteuses:SetPercent(uses)
			end
		end

		-- 清空状态
		inst._thunderspear = nil
		inst._thunderspear_uses = nil
		inst._thunderspear_skin = nil
		inst._thunderspear_skinid = nil
		inst._thunderspear_charges = 0
		inst._staffuse = nil

		inst.AnimState:ClearOverrideSymbol("swap_staffs")
		inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/moonstaff_place")

		if inst._thunderspear_net ~= nil then
			inst._thunderspear_net:set(false)
		end

		return result
	end

	-- 月台碎裂，武器掉落，停止充能/光柱
	local function MoonExpelSpear(inst)
		if not MoonHasSpear(inst) then
			return
		end

		local uses = inst._thunderspear_uses or 1

		-- 停充能与特效
		inst._thunderspear_charging = nil
		if inst.components.moonbeastspawner ~= nil then
			inst.components.moonbeastspawner:Stop()
		end
		SpearFX_Stop(inst, false)
		HideSpearStar(inst)

		-- 取出代理实体
		local result = nil
		if inst._staffinst ~= nil and inst._staffinst:IsValid() then
			inst:RemoveChild(inst._staffinst)
			inst._staffinst:ReturnToScene()
			if inst._staffinst.components.finiteuses ~= nil then
				inst._staffinst.components.finiteuses:SetPercent(uses)
			end
			result = inst._staffinst
			inst._staffinst = nil
		else
			-- 月淬矛固定 lunar 外观，不传皮肤参数
			local skinname = inst._thunderspear_skin
			local skinid = inst._thunderspear_skinid
			if inst._thunderspear == MOONFORGED_SPEAR then
				skinname, skinid = nil, nil
			end
			result = SpawnPrefab(inst._thunderspear, skinname, skinid)
			if result ~= nil and result.components.finiteuses ~= nil then
				result.components.finiteuses:SetPercent(uses)
			end
		end

		-- 清空状态
		inst._thunderspear = nil
		inst._thunderspear_uses = nil
		inst._thunderspear_skin = nil
		inst._thunderspear_skinid = nil
		inst._thunderspear_charges = 0
		inst._staffuse = nil

		inst.AnimState:ClearOverrideSymbol("swap_staffs")
		if inst._thunderspear_net ~= nil then
			inst._thunderspear_net:set(false)
		end

		-- 弹落到地面
		if result ~= nil then
			if inst.components.lootdropper == nil then
				inst:AddComponent("lootdropper")
			end
			inst.components.lootdropper:FlingItem(result)
		end
	end

	-- 月台受击状态
	local function SpearMoonGetState(inst)
		local wl = inst.components.workable ~= nil and inst.components.workable.workleft or 0
		if wl > TUNING.MOONBASE_DAMAGED_WORK then
			return "full"
		elseif wl * 2 > TUNING.MOONBASE_DAMAGED_WORK then
			return "med"
		elseif wl > 0 then
			return "medlow"
		end
		return "low"
	end

	-- 播放被攻击的碎裂动画；充能中则回到 recharging 循环
	local function SpearMoonPlayHit(inst)
		local state = SpearMoonGetState(inst)
		if state ~= "low" then
			inst.AnimState:PlayAnimation("hit_"..state)
			if inst._thunderspear_charging and inst.components.timer ~= nil
				and inst.components.timer:TimerExists("mooncharge") then
				inst.AnimState:PushAnimation("recharging_"..state, true)
			else
				inst.AnimState:PushAnimation(state, false)
			end
		else
			inst.AnimState:PlayAnimation("low")
		end
	end

	------------------------------------------------------------------------
	-- 喂碎片
	------------------------------------------------------------------------
	local function MoonFeed(inst, doer)
		if not MoonHasSpear(inst) or MoonIsFixed(inst) then
			return false
		end
		if doer == nil or not doer:IsValid() or doer.components.inventory == nil then
			return false
		end

		local item = doer.components.inventory:FindItem(function(o)
			return o ~= nil and o.prefab == REPAIR_MATERIAL
		end)
		if item == nil then
			return false
		end

		if item.components.stackable ~= nil and item.components.stackable:IsStack() then
			item.components.stackable:Get(1):Remove()
		else
			item:Remove()
		end

		-- 补武器耐久 25%
		if inst._thunderspear_uses ~= nil then
			inst._thunderspear_uses = math.min(1, inst._thunderspear_uses + 0.25)
			if inst._staffinst ~= nil and inst._staffinst:IsValid()
				and inst._staffinst.components.finiteuses ~= nil then
				inst._staffinst.components.finiteuses:SetPercent(inst._thunderspear_uses)
			end
		end

		-- 补月台损坏值
		local w = inst.components.workable
		if w ~= nil then
			w:SetWorkLeft(math.min(w.maxwork or 0, (w.workleft or 0) + REPAIR_HP))
			if MoonIsFixed(inst) and inst.components.trader ~= nil then
				inst.components.trader:Enable()
			end
		end

		inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/repair")

		return true
	end

	------------------------------------------------------------------------
	-- 动作
	------------------------------------------------------------------------
	local ACT = AddAction("WIGFRIDARMOR_MOONREPAIR", "使用", function(act)
		local doer = act.doer
		local target = act.target
		if doer == nil or target == nil or not target:IsValid() then
			return false
		end

		if not TheWorld.ismastersim then
			return true
		end

		-- 插着矛且空手 -> 取下
		if act.invobject == nil and MoonHasSpear(target) then
			local item = MoonTakeOut(target, doer)
			if item ~= nil and doer.components.inventory ~= nil then
				doer.components.inventory:GiveItem(item, nil, target:GetPosition())
				return true
			end
			return false
		end

		-- 喂碎片
		return MoonFeed(target, doer)
	end)

	ACT.mount_valid = true
	ACT.distance = 2
	ACT.priority = 1

	STRINGS.ACTIONS.WIGFRIDARMOR_MOONREPAIR = "使用"
	STRINGS.ACTIONS.WIGFRIDARMOR_MOONREPAIR_GENERIC = "使用"

	-- SCENE 类型：空手取下 / 手拿碎片喂
	AddComponentAction("SCENE", "inspectable", function(inst, doer, actions, right)
		if right or doer == nil or doer.replica == nil or doer.replica.inventory == nil then
			return
		end
		if not inst:HasTag("moonbase") then
			return
		end

		-- 插着矛（客户端看 net 变量）且空手 -> 取下
		local has_spear = inst._thunderspear_net ~= nil and inst._thunderspear_net:value() or false
		if has_spear then
			table.insert(actions, ACTIONS.WIGFRIDARMOR_MOONREPAIR)
			return
		end

		-- 有碎片 -> 喂
		for i = 1, doer.replica.inventory:GetNumSlots() do
			local it = doer.replica.inventory:GetItemInSlot(i)
			if it ~= nil and it.prefab == REPAIR_MATERIAL then
				table.insert(actions, ACTIONS.WIGFRIDARMOR_MOONREPAIR)
				return
			end
		end
	end)

	AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.WIGFRIDARMOR_MOONREPAIR, "dolongaction"))
	AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.WIGFRIDARMOR_MOONREPAIR, "dolongaction"))

	------------------------------------------------------------------------
	-- 月台：同步变量 + 月圆充能 + 存档
	------------------------------------------------------------------------
	AddPrefabPostInit("moonbase", function(inst)

		-- 同步"插着矛"状态（net 变量，两边都要建）
		if inst._thunderspear_net == nil then
			inst._thunderspear_net = net_bool(inst.GUID, "moonbase._thunderspear", "thunderspeardirty")
		end

		if not TheWorld.ismastersim then
			return
		end

		-- 月台被移除/摧毁时清理光球
		inst:ListenForEvent("onremove", function(i)
			HideSpearStar(i)
		end)

		-- 让月台也接受奔雷矛
		if inst.components.trader ~= nil then
			local oldAbleToAccept = inst.components.trader.abletoaccepttest
			inst.components.trader.abletoaccepttest = function(target, item, giver, count)
				if MoonHasSpear(target) then
					return false, "NOTSTAFF"
				end
				if IsSpear(item) then
					if MoonIsFixed(target) then
						return true
					end
					return false, "NOTSTAFF"
				end
				if oldAbleToAccept ~= nil then
					return oldAbleToAccept(target, item, giver, count)
				end
				return true
			end

			local oldOnAccept = inst.components.trader.onaccept
			inst.components.trader.onaccept = function(target, giver, item, count)
				if IsSpear(item) then
					if MoonInsert(target, item) then
						item:Remove()
					end
					return
				end
				if oldOnAccept ~= nil then
					oldOnAccept(target, giver, item, count)
				end
			end
		end

		-- 接管月台被攻击处理
		if inst.components.workable ~= nil then
			local oldOnWork = inst.components.workable.onwork
			inst.components.workable:SetOnWorkCallback(function(i, worker, workleft, numworks)
				if not MoonHasSpear(i) then
					if oldOnWork ~= nil then
						oldOnWork(i, worker, workleft, numworks)
					end
					return
				end

				if workleft <= 0 then
					-- 完全碎裂
					if oldOnWork ~= nil then
						oldOnWork(i, worker, workleft, numworks)
					end
					MoonExpelSpear(i)
				else
					-- 未碎裂，播放碎裂动画
					SpearMoonPlayHit(i)
				end
			end)
		end

		-- 月圆状态
		inst:WatchWorldState("isfullmoon", function (i, isfullmoon)
			if isfullmoon then
				i:DoTaskInTime(0, function (ii)
					TryStartSpearCharge(ii)
				end)
			else
				-- 月圆结束，一并停掉两个计时器
				i._thunderspear_charging = nil
				if i.components.moonbeastspawner ~= nil then
					i.components.moonbeastspawner:Stop()
				end
				SpearFX_Stop(i, false)
			end
		end)

		-- 充能计时结束
		inst:ListenForEvent("timerdone", function(i, data)
			if data == nil then
				return
			end

			-- 阶段1
			if data.name == "spearcharge_pre" then
				if not MoonHasSpear(i) or not i._thunderspear_charging then
					return
				end
				if not TheWorld.state.isfullmoon or not MoonIsFixed(i) then
					return
				end
				SpearCharge_EnterPhase2(i)
				return
			end

			-- todo 检查是否正确
			if data.name ~= "mooncharge" then
				return
			end
			if not MoonHasSpear(i) or not i._thunderspear_charging then
				return
			end

			i._thunderspear_charging = nil
			i._thunderspear_charges = (i._thunderspear_charges or 0) + 1

			if i._thunderspear_charges < CHARGES then
				if i.components.moonbeastspawner ~= nil then
					i.components.moonbeastspawner:Stop()
				end
				SpearFX_Stop(i, false)
				return
			end

			-- 充满：换成月淬奔雷矛（固定 lunar 外观，不继承原皮肤）
			local uses = i._thunderspear_uses or 1

			i._thunderspear = MOONFORGED_SPEAR
			i._thunderspear_charges = 0

			if i._staffinst ~= nil and i._staffinst:IsValid() then
				i:RemoveChild(i._staffinst)
				i._staffinst:Remove()
			end
			local proxy = SpawnPrefab(MOONFORGED_SPEAR)
			if proxy ~= nil then
				if proxy.components.finiteuses ~= nil then
					proxy.components.finiteuses:SetPercent(uses)
				end
				i:AddChild(proxy)
				proxy.Transform:SetPosition(0, 0, 0)
				proxy:RemoveFromScene()
				i._staffinst = proxy
				i._staffuse = nil
			end

			-- 升级武器
			ApplySpearSymbol(i)

			if i.components.moonbeastspawner ~= nil then
				i.components.moonbeastspawner:ForcePetrify()
				i.components.moonbeastspawner:Stop()
			end

			-- 仪式完成：显示升级完成光球
			SpearFX_Stop(i, true)
			ShowSpearStar(i)
		end)

		-- 存档
		local oldOnSave = inst.OnSave
		inst.OnSave = function(i, data)
			if oldOnSave ~= nil then
				oldOnSave(i, data)
			end
			if MoonHasSpear(i) then
				data.thunderspear = i._thunderspear
				data.thunderspear_uses = i._thunderspear_uses
				data.thunderspear_skin = i._thunderspear_skin
				data.thunderspear_skinid = i._thunderspear_skinid
				data.thunderspear_charges = i._thunderspear_charges
			end
		end

		local oldOnLoad = inst.OnLoad
		inst.OnLoad = function(i, data)
			if oldOnLoad ~= nil then
				oldOnLoad(i, data)
			end
			if data ~= nil and data.thunderspear ~= nil then
				i._thunderspear = data.thunderspear
				i._thunderspear_uses = data.thunderspear_uses or 1
				i._thunderspear_skin = data.thunderspear_skin
				i._thunderspear_skinid = data.thunderspear_skinid
				i._thunderspear_charges = data.thunderspear_charges or 0

				i:DoTaskInTime(0, function(ii)
					if not ii:IsValid() or not MoonHasSpear(ii) then
						return
					end
					-- 月淬矛固定 lunar 外观，不传皮肤参数
					local skinname = ii._thunderspear_skin
					local skinid = ii._thunderspear_skinid
					if ii._thunderspear == MOONFORGED_SPEAR then
						skinname, skinid = nil, nil
					end
					local proxy = SpawnPrefab(ii._thunderspear, skinname, skinid)
					if proxy ~= nil then
						if proxy.components.finiteuses ~= nil then
							proxy.components.finiteuses:SetPercent(ii._thunderspear_uses or 1)
						end
						ii:AddChild(proxy)
						proxy.Transform:SetPosition(0, 0, 0)
						proxy:RemoveFromScene()
						ii._staffinst = proxy
						ii._staffuse = nil
					end
					-- 读档后恢复贴图
					ApplySpearSymbol(ii)
					if ii._thunderspear_net ~= nil then
						ii._thunderspear_net:set(true)
					end

					-- 读档：若已是月淬形态，恢复升级完成光球
					if ii._thunderspear == MOONFORGED_SPEAR then
						ShowSpearStar(ii)
					end

					-- 读档如果是月圆，则恢复充能和特效
					TryStartSpearCharge(ii)
				end)
			end
		end
	end)

	------------------------------------------------------------------------
	-- 奔雷矛：夜晚缓慢恢复耐久
	------------------------------------------------------------------------
	local function AddNightRepair(inst)
		if not TheWorld.ismastersim then
			return
		end
		if inst.components.finiteuses == nil or NIGHT_HOURS <= 0 then
			return
		end

		local total = inst.components.finiteuses.total
		local seconds_per_use = (NIGHT_HOURS * TUNING.SEG_TIME) / math.max(1, total)

		inst._nightrepair_acc = 0

		inst:DoPeriodicTask(1, function(i)
			local fu = i.components.finiteuses
			if fu == nil then
				return
			end
			local uses = fu:GetUses()
			if uses <= 0 or uses >= fu.total then
				i._nightrepair_acc = 0
				return
			end
			if TheWorld.state.isday then
				i._nightrepair_acc = 0
				return
			end
			-- 插在月台上（父实体是月台）不恢复；拿在手上/背包里 parent 是玩家，正常恢复
			if i.parent ~= nil and i.parent:HasTag("moonbase") then
				return
			end

			i._nightrepair_acc = i._nightrepair_acc + 1
			if i._nightrepair_acc >= seconds_per_use then
				local gain = math.floor(i._nightrepair_acc / seconds_per_use)
				i._nightrepair_acc = i._nightrepair_acc - gain * seconds_per_use
				fu:Repair(gain)
			end
		end)
	end

	-- 接触奔雷矛装备限制
	local function UnlockChargedSpear(inst)
		if not TheWorld.ismastersim then
			return
		end
		if inst.components.equippable ~= nil then
			inst.components.equippable.restrictedtag = nil
		end
	end

	-- 升级后 才获得可装备 + 缓慢恢复耐久
	local function SetupChargedSpear(inst)
		UnlockChargedSpear(inst)
		AddNightRepair(inst)
	end

	-- 给奔雷矛甲tradable 可以拖到月台
	local function AddSpearTradable(inst)
		if not TheWorld.ismastersim then
			return
		end
		if inst.components.tradable == nil then
			inst:AddComponent("tradable")
		end
	end

	local SPEAR_SKINS = { "lunar", "valkyrie", "wrestle", "northern" }

	-- 普通奔雷矛拖拽
	AddPrefabPostInit(SPEAR, AddSpearTradable)
	for _, skin in ipairs(SPEAR_SKINS) do
		AddPrefabPostInit(SPEAR.."_"..skin, AddSpearTradable)
	end

	-- 充能矛
	AddPrefabPostInit(SPEAR_CHARGED, function (inst)
		AddSpearTradable(inst)
		SetupChargedSpear(inst)
	end)
	for _, skin in ipairs(SPEAR_SKINS) do
		AddPrefabPostInit(SPEAR_CHARGED.."_"..skin, function (inst)
			AddSpearTradable(inst)
			SetupChargedSpear(inst)
		end)
	end

	-- 月淬奔雷矛：复用充能矛的装备解锁 + 夜晚恢复耐久
	AddPrefabPostInit(MOONFORGED_SPEAR, function (inst)
		UnlockChargedSpear(inst)
		AddNightRepair(inst)
	end)

	local BEAM_COLOURS = {
		positronbeam_back  = SPEAR_BEAM_COLOUR_BACK,
		positronbeam_front = SPEAR_BEAM_COLOUR_FRONT,
		positronpulse      = SPEAR_BEAM_COLOUR_PULSE,
	}
	local MOONBASE_TAG = { "moonbase" }
	local function TintBeamForSpear(inst)
		inst:DoTaskInTime(0, function(i)
			if not i:IsValid() then
				return
			end
			local c = BEAM_COLOURS[i.prefab]
			if c == nil then
				return
			end
			-- 查找脚下月台，判断是否插着武器
			local mb = FindEntity(i, 4, nil, MOONBASE_TAG)
			if mb ~= nil and mb._thunderspear_net ~= nil and mb._thunderspear_net:value() then
				i.AnimState:SetMultColour(c[1], c[2], c[3], c[4])
			end
		end)
	end

	AddPrefabPostInit("positronbeam_back", TintBeamForSpear)
	AddPrefabPostInit("positronbeam_front", TintBeamForSpear)
	AddPrefabPostInit("positronpulse", TintBeamForSpear)

end
