-- 月台仪式 · 月台修理（repairable 组件维护 + 修理后动画更新）
--
-- 背景：本体月台的被攻击（UpdateWorkState）和修理（OnRepaired）内部都会
-- 调用 ToggleMoonCharge，而 ToggleMoonCharge 会无条件 StopTimer("mooncharge")
-- （停充能），这与模组奔雷矛的充能流程冲突。因此模组在"插着奔雷矛"时
-- 用 MoonAnim.PlayHit 绕过 UpdateWorkState，但这也绕过了它内部的
-- MakeRepairable（维护 repairable 组件），导致月岩右键不显示"修理"按钮。
--
-- 本模块补上被绕过的那部分：
--   EnsureRepairable(inst)  确保 repairable 组件存在且配置正确（幂等）
--   OnMoonRepaired(inst)    复刻本体 OnRepaired：修理后更新月台贴图/动画
--
-- 注意：本文件是 require 进来的普通模块，引擎接口从 GLOBAL 取。

local G = require("shared/genv")
local Util = require("moonbase_ritual/util")

local MATERIALS = G.Get("MATERIALS")

local MoonRepair = {}

--------------------------------------------------------------------------
-- 复刻本体的 IsInAnimState（moonbase.lua）：判断当前是否已处于某状态动画
--------------------------------------------------------------------------
local function IsInAnimState(inst, state)
	return inst.AnimState:IsCurrentAnimation(state)
		or inst.AnimState:IsCurrentAnimation("recharging_" .. state)
		or inst.AnimState:IsCurrentAnimation("hit_" .. state)
		or inst.AnimState:IsCurrentAnimation("fix_" .. state)
end

--------------------------------------------------------------------------
-- 复刻本体的 OnRepaired（moonbase.lua）：修理后更新月台贴图/动画
--
-- 与本体差异：不调用 ToggleMoonCharge（它会停掉模组充能），只做贴图/动画更新。
--------------------------------------------------------------------------
function MoonRepair.OnMoonRepaired(inst)
	local state = Util.GetMoonState(inst)

	if state == "full" then
		-- 修满了：移除 repairable，避免修理与给予动作优先级冲突
		inst:RemoveComponent("repairable")
		if inst.components.workable ~= nil then
			inst.components.workable:SetWorkLeft(inst.components.workable.maxwork)
		end
	end

	if not IsInAnimState(inst, state) then
		if state ~= "low" then
			inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/repair")
			inst.AnimState:PlayAnimation("fix_" .. state)
			if inst.components.timer ~= nil
				and inst.components.timer:TimerExists("mooncharge") then
				inst.AnimState:PushAnimation("recharging_" .. state, true)
			else
				inst.AnimState:PushAnimation(state, false)
			end
		else
			inst.AnimState:PlayAnimation("low")
		end
	end
end

--------------------------------------------------------------------------
-- 确保月台有 repairable 组件（月岩修理的入口），并挂上 onrepaired 回调
--
-- 复刻本体的 MakeRepairable（moonbase.lua）：
--   repairable 组件 + repairmaterial = "moonrock" + onrepaired 回调。
--
-- 幂等、安全：无论 repairable 组件是否存在，都会确保 repairmaterial、
-- onrepaired、noannounce 正确设置。
--------------------------------------------------------------------------
function MoonRepair.EnsureRepairable(inst)
	local r = inst.components.repairable
	if r == nil then
		inst:AddComponent("repairable")
		r = inst.components.repairable
	end
	if r ~= nil then
		r.repairmaterial = MATERIALS.MOONROCK
		r.onrepaired = MoonRepair.OnMoonRepaired
		r.noannounce = true
	end
end

return MoonRepair
