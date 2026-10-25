-- 月台仪式 · 「月淬」状态效果
--
-- 月淬不是一个独立的 prefab，而是在普通奔雷矛上打 "moon" 标签来标记。
-- 本模块负责给带标签的矛挂上应有的全部效果：
--   1. 对暗影阵营 +25% 伤害（参考 glasscutter.lua 的 damagetypebonus）
--   2. 夜晚缓慢恢复耐久
--   3. 解除装备限制（充能矛原有 restrictedtag）
--
-- 所有函数都是幂等的，可以安全地在插入 / 取出 / 读档等多种时机重复调用。
--
-- 注意：本文件是 require 进来的普通模块，默认 _G 带 strict，
-- 引擎接口必须显式从 GLOBAL 取（见 genv.lua）。

local G = require("moonbase_ritual/genv")
local Config = require("moonbase_ritual/config")

local TheWorld = G.Lazy("TheWorld")
local TUNING = G.Get("TUNING")

local Moonforged = {}

--------------------------------------------------------------------------
-- 解除奔雷矛的装备限制
--------------------------------------------------------------------------
function Moonforged.UnlockEquip(inst)
	if not TheWorld.ismastersim then
		return
	end
	if inst.components.equippable ~= nil then
		inst.components.equippable.restrictedtag = nil
	end
end

--------------------------------------------------------------------------
-- 夜晚缓慢恢复耐久
--
-- 恢复速度换算：
--   seconds_per_use = (NIGHT_HOURS * TUNING.SEG_TIME) / total
-- 即"用 NIGHT_HOURS 个夜晚回满一整条耐久"，每晚实际黑夜时长按 SEG_TIME 计。
-- 举例：NIGHT_HOURS=12、总耐久 150，则每 2.4 秒回 1 点。
--
-- 插在月台上（parent 带 moonbase 标签）时不恢复，
-- 拿在手上 / 背包里（parent 是玩家或容器）正常恢复。
--------------------------------------------------------------------------
function Moonforged.AddNightRepair(inst)
	if not TheWorld.ismastersim then
		return
	end
	if inst.components.finiteuses == nil or Config.NIGHT_HOURS <= 0 then
		return
	end

	local total = inst.components.finiteuses.total
	local seconds_per_use = (Config.NIGHT_HOURS * TUNING.SEG_TIME) / math.max(1, total)

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

--------------------------------------------------------------------------
-- 施加全部月淬效果（幂等）
--------------------------------------------------------------------------
function Moonforged.Apply(inst)
	if not TheWorld.ismastersim or inst == nil or not inst:IsValid() then
		return
	end

	-- 保证标签存在
	if not inst:HasTag(Config.MOON_TAG) then
		inst:AddTag(Config.MOON_TAG)
	end

	-- 对暗影阵营增伤
	-- AddBonus 同 src + 同 key 会覆盖，重复调用是安全的
	local damagetypebonus = inst.components.damagetypebonus
		or inst:AddComponent("damagetypebonus")
	damagetypebonus:AddBonus("shadowsubmissive", inst, Config.SHADOW_DAMAGE_BONUS)

	-- 解除装备限制
	Moonforged.UnlockEquip(inst)

	-- 夜晚回耐久：只挂一次周期性任务
	if not inst._moonforged_nightrepair then
		inst._moonforged_nightrepair = true
		Moonforged.AddNightRepair(inst)
	end
end

--------------------------------------------------------------------------
-- 充能矛（原版 spear_wathgrithr_lightning_charged）的初始化
-- 与月淬不同：只解锁装备 + 夜修，不加暗影增伤
--------------------------------------------------------------------------
function Moonforged.SetupChargedSpear(inst)
	Moonforged.UnlockEquip(inst)
	Moonforged.AddNightRepair(inst)
end

--------------------------------------------------------------------------
-- 让 "moon" 标签随存档保存/恢复
-- AddTag 添加的标签不会写入存档，所以额外把标记写进 SaveRecord。
-- 读档时组件状态也不会恢复，因此按标签重建月淬效果。
--------------------------------------------------------------------------
function Moonforged.SetupPersist(inst)
	if not TheWorld.ismastersim then
		return
	end

	local oldOnSave = inst.OnSave
	inst.OnSave = function(i, data)
		local ret = oldOnSave ~= nil and oldOnSave(i, data) or data
		if i:HasTag(Config.MOON_TAG) then
			ret = ret or {}
			ret.moonforged = true
		end
		return ret
	end

	local oldOnLoad = inst.OnLoad
	inst.OnLoad = function(i, data)
		if oldOnLoad ~= nil then
			oldOnLoad(i, data)
		end
		if data ~= nil and data.moonforged then
			i:AddTag(Config.MOON_TAG)
			Moonforged.Apply(i)
		end
	end
end

--------------------------------------------------------------------------
-- 给物品加 tradable，使其能拖到月台上
--------------------------------------------------------------------------
function Moonforged.MakeTradable(inst)
	if not TheWorld.ismastersim then
		return
	end
	if inst.components.tradable == nil then
		inst:AddComponent("tradable")
	end
end

return Moonforged
