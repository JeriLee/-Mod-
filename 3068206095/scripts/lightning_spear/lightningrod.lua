-- 奔雷矛 · 避雷针充能
--
-- 参考本体里 WX-78（机器人）用避雷针充电的完整流程：
--   1. 避雷针带 battery 组件，充电者带 batteryuser 组件
--   2. 动作 ACTIONS.CHARGE_FROM：
--        手持物品时 strfn 返回 "ITEM"，状态图走 "catchonfire" 动画
--        （机器人本体是 "SELF" + "doshortaction"，并额外播 electrocute）
--   3. 充电成功后 battery:OnUsed 会消耗掉避雷针上储存的电荷
--
-- 与机器人的区别：
--   机器人是给自己充能（个人属性提升：回血、掉理智、模块充能），
--   奔雷矛则是给武器充能 —— 耐久 +30%、伤害 +20%，持续一天。
--   玩家本人不获得任何属性提升。
--
-- 注意：batteryuser 组件是通过 AddPrefabPostInit 挂上的，
-- 客户端服务端都会执行，所以右键避雷针时客户端能正常显示该动作。

local G = require("moonbase_ritual/genv")
local Config = require("moonbase_ritual/config")

local AddPrefabPostInit = G.Get("AddPrefabPostInit")
local SpawnElectricHitSparks = G.Get("SpawnElectricHitSparks")
local TUNING = G.Get("TUNING")
local TheWorld = G.Lazy("TheWorld")

local LightningRod = {}

-- 加成持续时间：一天（= 一个完整昼夜循环）
local BUFF_DURATION = TUNING.TOTAL_DAY_TIME

--------------------------------------------------------------------------
-- 内部：设置 / 清除武器的伤害加成
--
-- 用函数形式的 damage（本体 dumbbells 也是这么做的），
-- 这样加成到期时只要把倍数置空即可，不必还原原始伤害值。
--------------------------------------------------------------------------
local function SetDamageMult(inst, mult)
	local weapon = inst.components.weapon
	if weapon == nil then
		return
	end

	if inst._lightningrod_base_damage == nil then
		inst._lightningrod_base_damage = weapon.damage
		weapon:SetDamage(function(self, attacker, target)
			local base = inst._lightningrod_base_damage
			local dmg = type(base) == "function" and base(self, attacker, target) or base
			return dmg * (inst._lightningrod_damage_mult or 1)
		end)
	end

	inst._lightningrod_damage_mult = mult
end

--------------------------------------------------------------------------
-- 内部：启动加成倒计时
--------------------------------------------------------------------------
local function StartBuffTimer(inst, duration)
	if inst._lightningrod_buff_task ~= nil then
		inst._lightningrod_buff_task:Cancel()
		inst._lightningrod_buff_task = nil
	end

	inst._lightningrod_buff_time = duration

	inst._lightningrod_buff_task = inst:DoPeriodicTask(1, function(i)
		i._lightningrod_buff_time = (i._lightningrod_buff_time or 0) - 1
		if i._lightningrod_buff_time <= 0 then
			i._lightningrod_buff_task = nil
			-- 倍数置空即等于恢复原始伤害
			SetDamageMult(i, nil)
		end
	end)
end

--------------------------------------------------------------------------
-- 内部：施加武器加成
-- repair_durability 为 false 时只恢复伤害加成（读档用，耐久已存在存档里）
--------------------------------------------------------------------------
local function ApplyBuff(inst, duration, repair_durability)
	if repair_durability then
		local fu = inst.components.finiteuses
		if fu ~= nil then
			fu:Repair(fu.total * Config.LIGHTNINGROD_DURABILITY_RATIO)
		end
	end

	SetDamageMult(inst, Config.LIGHTNINGROD_DAMAGE_MULT)
	StartBuffTimer(inst, duration)
end

--------------------------------------------------------------------------
-- 充能成功回调（batteryuser 组件触发）
--
-- 注意：这里刻意不碰玩家本人 —— 机器人那套个人属性提升
-- （回血 / 掉理智 / 模块充能）对女武神不适用。
--------------------------------------------------------------------------
local function OnBatteryUsed(inst, battery)
	-- 只强化武器本身
	ApplyBuff(inst, BUFF_DURATION, true)

	-- 与本体夜之棒一样，充能成功时给点电火花
	SpawnElectricHitSparks(inst, battery, true)

	return true
end

--------------------------------------------------------------------------
-- 存档：保留充能加成的剩余时间
--------------------------------------------------------------------------
local function SetupPersist(inst)
	if not TheWorld.ismastersim then
		return
	end

	-- 幂等：避免 OnSave / OnLoad 被重复包装
	if inst._lightningrod_persist then
		return
	end
	inst._lightningrod_persist = true

	local oldOnSave = inst.OnSave
	inst.OnSave = function(i, data)
		local ret = oldOnSave ~= nil and oldOnSave(i, data) or data
		if ret ~= nil and i._lightningrod_buff_time ~= nil and i._lightningrod_buff_time > 0 then
			ret.lightningrod_buff = i._lightningrod_buff_time
		end
		return ret
	end

	local oldOnLoad = inst.OnLoad
	inst.OnLoad = function(i, data)
		if oldOnLoad ~= nil then
			oldOnLoad(i, data)
		end
		if data ~= nil and data.lightningrod_buff ~= nil and data.lightningrod_buff > 0 then
			-- 耐久已随 finiteuses 存档，这里只恢复伤害加成
			ApplyBuff(i, data.lightningrod_buff, false)
		end
	end
end

--------------------------------------------------------------------------
-- 主入口
--------------------------------------------------------------------------
function LightningRod.Setup()
	local function SetupSpear(inst)
		-- batteryuser：让奔雷矛可以作为"充能者"去接触避雷针
		if inst.components.batteryuser == nil then
			inst:AddComponent("batteryuser")
			inst.components.batteryuser:SetOnBatteryUsedFn(OnBatteryUsed)
		end

		-- 存档：保留充能加成
		SetupPersist(inst)
	end

	-- 只给"普通奔雷矛"加（充能形态是升级产物，不参与这条路线）
	AddPrefabPostInit(Config.SPEAR, SetupSpear)
	for _, skin in ipairs(Config.SPEAR_SKINS) do
		AddPrefabPostInit(Config.SPEAR .. "_" .. skin, SetupSpear)
	end
end

return LightningRod
