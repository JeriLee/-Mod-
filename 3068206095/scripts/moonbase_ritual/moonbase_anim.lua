-- 月台仪式 · 插着矛时月台的受击动画
-- 按剩余损坏程度播放对应阶段的碎裂动画；
-- 若正在充能，攻击后回到 recharging 循环而不是普通待机。
--
-- 注意：本文件是 require 进来的普通模块，仅做纯逻辑，不需要引擎全局。

local Util = require("moonbase_ritual/util")

local MoonAnim = {}

function MoonAnim.PlayHit(inst)
	local state = Util.GetMoonState(inst)

	if state == "low" then
		-- 已经完全损坏，没有可播的碎裂动画
		inst.AnimState:PlayAnimation("low")
		return
	end

	inst.AnimState:PlayAnimation("hit_" .. state)

	local charging = inst._thunderspear_charging
		and inst.components.timer ~= nil
		and inst.components.timer:TimerExists("mooncharge")

	if charging then
		inst.AnimState:PushAnimation("recharging_" .. state, true)
	else
		inst.AnimState:PushAnimation(state, false)
	end
end

return MoonAnim
