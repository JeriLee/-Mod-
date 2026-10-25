-- 月台仪式 · 武器的插入 / 取出 / 弹出
--
-- 数据模型：
--   月台用一组成员字段记录"插着什么矛"：
--     _thunderspear          prefab 名
--     _thunderspear_uses     耐久百分比
--     _thunderspear_skin     皮肤名
--     _thunderspear_skinid   皮肤 id
--     _thunderspear_ismoon   是否已月淬
--     _thunderspear_isancient 是否已古铸
--     _thunderspear_charges  已完成的充能次数
--     _thunderspear_charging 是否正在充能
--   同时 _staffinst 持有一个真实武器实体（AddChild + RemoveFromScene），
--   用于显示插在月台上的外观。
--
-- 注意：本文件是 require 进来的普通模块，引擎接口从 GLOBAL 取。

local G = require("shared/genv")
local Config = require("moonbase_ritual/config")
local Util = require("moonbase_ritual/util")
local FxStar = require("moonbase_ritual/fx_star")
local FxSymbol = require("moonbase_ritual/fx_symbol")
local FxCharge = require("moonbase_ritual/fx_charge")
local Moonforged = require("moonbase_ritual/moonforged")
local Ancientcast = require("ancient_cast/ancientcast")
local AncientConfig = require("ancient_cast/config")
local MoonRepair = require("moonbase_ritual/moonbase_repair")

local SpawnPrefab = G.Lazy("SpawnPrefab")

local MoonIO = {}

--------------------------------------------------------------------------
-- 内部：停止充能与相关特效
--------------------------------------------------------------------------
local function StopCharge(inst)
	inst._thunderspear_charging = nil
	if inst.components.moonbeastspawner ~= nil then
		inst.components.moonbeastspawner:Stop()
	end
	FxCharge.Stop(inst, false)
	FxStar.Hide(inst)
end

--------------------------------------------------------------------------
-- 内部：把月台上的代理实体取下来（返回真实武器实体）
--------------------------------------------------------------------------
local function DetachProxy(inst, uses, was_moon, was_ancient)
	if inst._staffinst ~= nil and inst._staffinst:IsValid() then
		inst:RemoveChild(inst._staffinst)
		inst._staffinst:ReturnToScene()
		if inst._staffinst.components.finiteuses ~= nil then
			inst._staffinst.components.finiteuses:SetPercent(uses)
		end
		local result = inst._staffinst
		inst._staffinst = nil

		-- 取回时再确认一次月淬 / 古铸状态（幂等，可重复调用）
		if was_moon then
			Moonforged.Apply(result)
		end
		if was_ancient then
			Ancientcast.Apply(result)
		end
		return result
	end

	-- 兜底：没有代理实体时按记录重建一把
	-- 皮肤名要跟 prefab 保持一致，否则（充能皮肤套普通 prefab）初始化会崩
	local result = SpawnPrefab(inst._thunderspear,
		Util.MatchSkin(inst._thunderspear, inst._thunderspear_skin),
		inst._thunderspear_skinid)
	if result ~= nil then
		if result.components.finiteuses ~= nil then
			result.components.finiteuses:SetPercent(uses)
		end
		if was_moon then
			Moonforged.Apply(result)
		end
		if was_ancient then
			Ancientcast.Apply(result)
		end
	end
	return result
end

--------------------------------------------------------------------------
-- 内部：清空"插着矛"的全部状态
--------------------------------------------------------------------------
local function ClearState(inst)
	inst._thunderspear = nil
	inst._thunderspear_uses = nil
	inst._thunderspear_skin = nil
	inst._thunderspear_skinid = nil
	inst._thunderspear_ismoon = nil
	inst._thunderspear_isancient = nil
	inst._thunderspear_charges = 0
	inst._staffuse = nil
end

--------------------------------------------------------------------------
-- 内部：同步"插着矛"状态给客户端
--------------------------------------------------------------------------
local function SyncNet(inst, has_spear)
	if inst._thunderspear_net ~= nil then
		inst._thunderspear_net:set(has_spear)
	end
end

--------------------------------------------------------------------------
-- 插入奔雷矛
-- 返回 true 表示成功（调用方负责 item:Remove()）
--------------------------------------------------------------------------
function MoonIO.Insert(inst, item)
	if item == nil or not Util.IsSpear(item) or Util.MoonHasSpear(inst) then
		return false
	end
	if not Util.MoonIsFixed(inst) then
		return false
	end

	local uses = item.components.finiteuses ~= nil
		and item.components.finiteuses:GetPercent() or 1
	local skinname = item.skinname
	local skinid = item.skin_id

	inst._thunderspear = item.prefab
	inst._thunderspear_uses = uses
	inst._thunderspear_skin = skinname
	inst._thunderspear_skinid = skinid
	inst._thunderspear_ismoon = item:HasTag(Config.MOON_TAG)
	inst._thunderspear_isancient = item:HasTag(AncientConfig.ANCIENT_TAG)
	inst._thunderspear_charges = 0
	inst._thunderspear_charging = nil

	-- 确保 repairable 组件就绪：插着矛期间月台受损时，月岩也能修理。
	-- 月台"完好"时 workrepairable 标签为 false，不会误显示"修理"；
	-- 受损后 workrepairable 自动变 true，月岩右键即可出现"修理"按钮。
	MoonRepair.EnsureRepairable(inst)

	-- 禁用 trader：插矛后不能再"给予"，否则玩家手持月岩点月台时会
	-- 走 GIVE（给予）动作而非 REPAIR（修理），角色会说"惹怒诸神"。
	-- 与本体 OnStaffGiven 里 trader:Disable() 的做法一致。
	if inst.components.trader ~= nil then
		inst.components.trader:Disable()
	end

	-- 生成一个真实武器实体挂到月台上（复用 _staffinst 字段）
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

	-- 显示矛的贴图
	FxSymbol.Apply(inst)

	inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/moonstaff_place")

	SyncNet(inst, true)

	-- 若此刻正是月圆之夜，则立即开始充能
	-- （月圆开始时的世界状态切换会触发，但中途插入不会，需主动通知）
	inst:PushEvent("moonbase_spear_inserted")

	return true
end

--------------------------------------------------------------------------
-- 玩家取下武器
-- 返回真实武器实体，由调用方负责放进玩家背包
-- （doer 参数保留是为了接口一致性，本函数不需要它）
--------------------------------------------------------------------------
function MoonIO.TakeOut(inst)
	if not Util.MoonHasSpear(inst) then
		return nil
	end

	local uses = inst._thunderspear_uses or 1
	local was_moon = inst._thunderspear_ismoon
	local was_ancient = inst._thunderspear_isancient

	StopCharge(inst)

	local result = DetachProxy(inst, uses, was_moon, was_ancient)

	ClearState(inst)
	FxSymbol.Clear(inst)
	inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/moonstaff_place")
	SyncNet(inst, false)

	-- 摘矛后：若月台已受损，确保 repairable 组件就绪，月岩右键能出现"修理"
	if not Util.MoonIsFixed(inst) then
		MoonRepair.EnsureRepairable(inst)
	end

	-- 重新启用 trader（月台完好时才能再插矛），与本体 OnStaffTaken 一致
	if Util.MoonIsFixed(inst) and inst.components.trader ~= nil then
		inst.components.trader:Enable()
	end

	return result
end

--------------------------------------------------------------------------
-- 月台被砸碎，武器弹出掉地上
--------------------------------------------------------------------------
function MoonIO.Expel(inst)
	if not Util.MoonHasSpear(inst) then
		return
	end

	local uses = inst._thunderspear_uses or 1
	local was_moon = inst._thunderspear_ismoon
	local was_ancient = inst._thunderspear_isancient

	StopCharge(inst)

	local result = DetachProxy(inst, uses, was_moon, was_ancient)

	ClearState(inst)
	FxSymbol.Clear(inst)
	SyncNet(inst, false)

	-- 弹出后：若月台已受损，确保 repairable 组件就绪
	if not Util.MoonIsFixed(inst) then
		MoonRepair.EnsureRepairable(inst)
	end

	-- 重新启用 trader（月台完好时才能再插矛）
	if Util.MoonIsFixed(inst) and inst.components.trader ~= nil then
		inst.components.trader:Enable()
	end

	if result ~= nil then
		if inst.components.lootdropper == nil then
			inst:AddComponent("lootdropper")
		end
		inst.components.lootdropper:FlingItem(result)
	end
end

return MoonIO
