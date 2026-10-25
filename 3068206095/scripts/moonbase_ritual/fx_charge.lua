-- 月台仪式 · 月圆充能视觉特效
-- 复刻原版 moonbase 的光柱 / 脉冲 / 泛光 / 充能动画。
--
-- 时间线：
--   阶段1（预充能）播放 recharging_full 蓄力动画，时长 = 月台 fullmoonstartdelay
--   阶段2（爆发）   刷光柱 + 脉冲 + 强光，并按时推进脉冲等级
--
-- 注意：光柱染色不在这里做，因为 SetMultColour 在服务端对客户端无效，
-- 改为在 beam_tint.lua 里通过 AddPrefabPostInit 在两端各自染色。
--
-- 注意：本文件是 require 进来的普通模块，引擎接口从 GLOBAL 取。

local G = require("moonbase_ritual/genv")

local SpawnPrefab = G.Lazy("SpawnPrefab")
local TUNING = G.Get("TUNING")

local FxCharge = {}

--------------------------------------------------------------------------
-- 内部：取消脉冲等级推进任务
--------------------------------------------------------------------------
local function CancelLevelTasks(i)
	if i._spearfx_lvtask2 ~= nil then
		i._spearfx_lvtask2:Cancel()
		i._spearfx_lvtask2 = nil
	end
	if i._spearfx_lvtask3 ~= nil then
		i._spearfx_lvtask3:Cancel()
		i._spearfx_lvtask3 = nil
	end
end

--------------------------------------------------------------------------
-- 停止全部充能特效
-- finished = true 时脉冲播放收尾动画（仪式成功），否则直接移除
--------------------------------------------------------------------------
function FxCharge.Stop(i, finished)
	CancelLevelTasks(i)

	-- 停掉两个阶段计时器
	if i.components.timer ~= nil then
		i.components.timer:StopTimer("spearcharge_pre")
		i.components.timer:StopTimer("mooncharge")
	end

	if i._spearfx_pulse ~= nil then
		if i._spearfx_pulse:IsValid() then
			if finished then
				i._spearfx_pulse:FinishFX()
			else
				i._spearfx_pulse:Remove()
			end
		end
		i._spearfx_pulse = nil
	end

	if i._spearfx_front ~= nil then
		if i._spearfx_front:IsValid() then
			i._spearfx_front:KillFX()
		end
		i._spearfx_front = nil
	end

	if i._spearfx_back ~= nil then
		if i._spearfx_back:IsValid() then
			i._spearfx_back:KillFX()
		end
		i._spearfx_back = nil
	end

	i.Light:Enable(false)
	i.AnimState:ClearBloomEffectHandle()
	i:RemoveTag("intense")
	if i.AnimState:IsCurrentAnimation("recharging_full") then
		i.AnimState:PlayAnimation("full")
	end
end

--------------------------------------------------------------------------
-- 阶段2：爆发（光柱 + 脉冲 + 强光 + 脉冲等级推进）
--------------------------------------------------------------------------
function FxCharge.StartBeams(i)
	local x, y, z = i.Transform:GetWorldPosition()

	if i._spearfx_front == nil or not i._spearfx_front:IsValid() then
		i._spearfx_back = SpawnPrefab("positronbeam_back")
		i._spearfx_back.Transform:SetPosition(x, y, z)
		i._spearfx_front = SpawnPrefab("positronbeam_front")
		i._spearfx_front.Transform:SetPosition(x, y, z)
		i._spearfx_pulse = SpawnPrefab("positronpulse")
		i._spearfx_pulse.Transform:SetPosition(x, y, z)
	end

	-- 光 + 泛光
	i.Light:Enable(true)
	i.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

	-- 充能动画（月台完整时状态为 full；阶段1 通常已经在播放）
	if not i.AnimState:IsCurrentAnimation("recharging_full") then
		i.AnimState:PlayAnimation("recharging_full", true)
	end

	-- 脉冲强度分级：第1阶段 -> 等级2(intense)，第2阶段 -> 等级3
	CancelLevelTasks(i)
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

--------------------------------------------------------------------------
-- 阶段2 正式开始：挂 mooncharge 计时器 + 刷月兽 + 爆发特效
--------------------------------------------------------------------------
function FxCharge.EnterPhase2(i)
	if i.components.timer ~= nil then
		-- 计时器必须命名为 mooncharge：月兽 brain（moonbeastbrain.lua）硬编码
		-- 用"月台上是否存在该计时器"来判断仪式是否进行中，否则会立即石化
		i.components.timer:StopTimer("mooncharge")
		i.components.timer:StartTimer("mooncharge", TUNING.MOONBASE_CHARGE_DURATION)
	end

	if i.components.moonbeastspawner ~= nil then
		i.components.moonbeastspawner:Start()
	end

	FxCharge.StartBeams(i)
end

return FxCharge
