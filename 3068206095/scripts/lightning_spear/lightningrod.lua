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
local AddPlayerPostInit = G.Get("AddPlayerPostInit")
local SpawnElectricHitSparks = G.Get("SpawnElectricHitSparks")
local net_shortint = G.Get("net_shortint")
local net_int = G.Get("net_int")
local TUNING = G.Get("TUNING")
local TheWorld = G.Lazy("TheWorld")

local LightningRod = {}

-- 加成持续时间：一天（= 一个完整昼夜循环）
local BUFF_DURATION = TUNING.TOTAL_DAY_TIME

--------------------------------------------------------------------------
-- 内部：创建客户端可见的"剩余时间"net 变量
--
-- net 变量不随存档保存，读档后需要重新写回当前剩余时间。
-- 客户端据此显示 HUD 上的图标与倒计时。
--------------------------------------------------------------------------
local function EnsureNetTime(inst)
	if inst._lightningrod_net == nil then
		inst._lightningrod_net = net_shortint(inst.GUID, "spear.lightningrod_time",
			"lightningrodtimedirty")
	end
	return inst._lightningrod_net
end

--------------------------------------------------------------------------
-- 内部：把剩余时间同步到"持有者"身上 —— HUD 的备用数据通道
--
-- 武器上的 net 变量只有拿到武器实体才能读到；
-- 而玩家分类对象（player_classified）上的 net 变量是本体 HUD 用的通道
-- （本体的 buff 图标 _buffsymbol 就是这么同步的），更可靠。
-- 两条通道都写，客户端优先读武器，读不到再读分类对象。
--------------------------------------------------------------------------
local function EnsureClassifiedNet(inst)
	if inst._mod_lightningrod_time == nil then
		inst._mod_lightningrod_time = net_shortint(inst.GUID,
			"mod.lightningrod_time", "modlightningrodtimedirty")

		-- HUD 图标的拖动位置（客户端写，服务端读取并存档）
		inst._mod_lightningrod_posx = net_int(inst.GUID,
			"mod.lightningrod_posx", "modlightningrodposxdirty")
		inst._mod_lightningrod_posy = net_int(inst.GUID,
			"mod.lightningrod_posy", "modlightningrodposydirty")
	end
	return inst._mod_lightningrod_time
end

local function SyncOwnerTime(inst)
	local owner = nil
	if inst.components.inventoryitem ~= nil then
		owner = inst.components.inventoryitem:GetGrandOwner()
	end

	if owner == nil then
		-- 已经没有持有者了，把之前的持有者那边清零
		local prev = inst._lightningrod_owner
		inst._lightningrod_owner = nil
		if prev ~= nil and prev.player_classified ~= nil then
			local netvar = EnsureClassifiedNet(prev.player_classified)
			if netvar ~= nil then
				netvar:set(0)
			end
		end
		return
	end

	inst._lightningrod_owner = owner
	local netvar = EnsureClassifiedNet(owner.player_classified)
	if netvar ~= nil then
		netvar:set(math.max(0, math.floor(inst._lightningrod_buff_time or 0)))
	end
end

local function SyncNetTime(inst)
	local netvar = EnsureNetTime(inst)
	if netvar ~= nil then
		netvar:set(math.max(0, math.floor(inst._lightningrod_buff_time or 0)))
	end
	SyncOwnerTime(inst)
end

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
	SyncNetTime(inst)

	inst._lightningrod_buff_task = inst:DoPeriodicTask(1, function(i)
		i._lightningrod_buff_time = (i._lightningrod_buff_time or 0) - 1
		SyncNetTime(i)
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
--
-- 但"电击僵直"要补上：本体里 WX-78（机器人）是 SELF 充能，
-- 自己会被 electrocute 僵直一下；奔雷矛是 invobject 充能，
-- 充电的是武器、玩家本人不会自动被电。所以这里主动把持矛的
-- 玩家电一下，让"女武神触摸带电避雷针"和机器人表现一致。
--------------------------------------------------------------------------
local function OnBatteryUsed(inst, battery)
	-- 只强化武器本身
	ApplyBuff(inst, BUFF_DURATION, true)

	-- 与本体夜之棒一样，充能成功时给点电火花
	SpawnElectricHitSparks(inst, battery, true)

	-- 玩家手直接接触带电的避雷针 -> 被电击僵直（参考 WX-78）
	local owner = inst.components.inventoryitem ~= nil
		and inst.components.inventoryitem:GetGrandOwner() or nil
	if owner ~= nil and owner:IsValid() and owner:HasTag("player") then
		-- 延迟一点点再电：CHARGE_FROM 动作本身会播 catchonfire 动画，
		-- 若此刻立即推 electrocute 会被它盖掉而看不到僵直。
		-- 延后一帧（0.1s），让 electrocute 状态盖过 catchonfire，
		-- 玩家才会真正被电得僵直一下（与机器人被雷劈打断动作同理）。
		owner:DoTaskInTime(0.1, function(o)
			if o:IsValid() then
				-- noresist=true：与机器人一致，始终会被电（不豁免绝缘/潮湿）
				o:PushEventImmediate("electrocute",
					{ stimuli = "electric", noresist = true })
			end
		end)
	end

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
-- 存档：把 HUD 图标的位置存到玩家身上
--
-- 位置是客户端拖出来的，写在玩家分类对象（player_classified）的 net 变量上；
-- 服务端在存盘时把这个值抄进玩家存档，读档时再写回 net 变量，
-- 于是客户端重连 / 读档后图标会回到玩家上次摆放的位置。
--------------------------------------------------------------------------
local function SetupPlayerPersist(inst)
	if not TheWorld.ismastersim then
		return
	end

	-- 幂等
	if inst._mod_lightningrod_pos_persist then
		return
	end
	inst._mod_lightningrod_pos_persist = true

	local oldOnSave = inst.OnSave
	inst.OnSave = function(i, data)
		local ret = oldOnSave ~= nil and oldOnSave(i, data) or data
		local pc = i.player_classified
		if ret ~= nil and pc ~= nil and pc._mod_lightningrod_posx ~= nil then
			ret.modlightningrodpos = {
				x = pc._mod_lightningrod_posx:value(),
				y = pc._mod_lightningrod_posy:value(),
			}
		end
		return ret
	end

	local oldOnLoad = inst.OnLoad
	inst.OnLoad = function(i, data)
		if oldOnLoad ~= nil then
			oldOnLoad(i, data)
		end
		local p = data ~= nil and data.modlightningrodpos or nil
		local pc = i.player_classified
		if p ~= nil and pc ~= nil and pc._mod_lightningrod_posx ~= nil then
			pc._mod_lightningrod_posx:set(p.x or 0)
			pc._mod_lightningrod_posy:set(p.y or 0)
		end
	end
end

--------------------------------------------------------------------------
-- 主入口
--------------------------------------------------------------------------
function LightningRod.Setup()
	local function SetupSpear(inst)
		-- net 变量：客户端服务端都要创建，名字一致
		-- 客户端靠它显示 HUD 上的雷萃图标与倒计时
		EnsureNetTime(inst)

		-- batteryuser：让奔雷矛可以作为"充能者"去接触避雷针
		if inst.components.batteryuser == nil then
			inst:AddComponent("batteryuser")
			inst.components.batteryuser:SetOnBatteryUsedFn(OnBatteryUsed)
		end

		-- 存档：保留充能加成
		SetupPersist(inst)
	end

	-- 玩家分类对象上的 net 变量（HUD 的备用数据通道）
	-- 客户端服务端都要创建，名字一致
	local function SetupClassified(inst)
		EnsureClassifiedNet(inst)
	end

	-- 只给"普通奔雷矛"加（充能形态是升级产物，不参与这条路线）
	AddPrefabPostInit(Config.SPEAR, SetupSpear)
	for _, skin in ipairs(Config.SPEAR_SKINS) do
		AddPrefabPostInit(Config.SPEAR .. "_" .. skin, SetupSpear)
	end

	AddPrefabPostInit("player_classified", SetupClassified)

	-- 玩家存档：保存 HUD 图标位置
	if AddPlayerPostInit ~= nil then
		AddPlayerPostInit(SetupPlayerPersist)
	end
end

return LightningRod
