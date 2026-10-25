-- 月台仪式 · 远古伪科学站「古铸」交互
--
-- 交互方式：
--   玩家装备着奔雷矛 -> 左键点击远古伪科学站 -> 动作菜单里选「古铸」
--   -> 消耗 5 个铥矿，武器永久获得「古铸」效果并改名。
--
-- 为什么用 EQUIPPED 类型的组件动作：
--   奔雷矛是双手武器（one_slot），捡起来会自动进装备槽，
--   放不进"手持格"，所以拿不到 USEITEM / INVENTORY 类型的动作。
--   而装备状态下点击场景实体时，本体只会收集 EQUIPPED 动作
--   （见 playeractionpicker.lua 的 GetEquippedItemActions），
--   所以这里把动作挂在武器自带的 equippable 组件上。
--
--   组件动作的收集器由服务端注册（AddComponent -> RegisterComponentActions），
--   再通过 actionreplica 同步到客户端，因此两端都能看到并使用这个动作。
--
-- 注意：本文件是 require 进来的普通模块，默认 _G 带 strict，
-- 引擎接口必须显式从 GLOBAL 取（见 genv.lua）。

local G = require("shared/genv")
local Config = require("ancient_cast/config")
local Util = require("ancient_cast/util")
local Ancientcast = require("ancient_cast/ancientcast")

local AddAction, AddComponentAction, AddStategraphActionHandler, ActionHandler =
	G.Many("AddAction", "AddComponentAction", "AddStategraphActionHandler", "ActionHandler")

local ACTIONS = G.Get("ACTIONS")
local STRINGS = G.Get("STRINGS")
local SpawnElectricHitSparks = G.Get("SpawnElectricHitSparks")
local TheWorld = G.Lazy("TheWorld")

local AltarActions = {}

local ACTION_ID = "WIGFRIDARMOR_ANCIENTCAST"

-- 供月台的 SCENE 动作收集器复用（见 moonbase_actions.lua）
AltarActions.ACTION_ID = ACTION_ID

-- 诊断用：每个通道只打印一次
AltarActions._diag = {}

--------------------------------------------------------------------------
-- 找到要古铸的武器
--
-- 两种来源：
--   1. EQUIPPED 动作：invobject 就是当前装备的奔雷矛
--   2. SCENE 动作：invobject 为空，改为在背包里找
--------------------------------------------------------------------------
local function FindSpear(doer, invobject)
	if invobject ~= nil and Util.IsSpearPrefab(invobject.prefab) then
		return invobject
	end

	local inv = doer ~= nil and doer.components.inventory or nil
	if inv == nil then
		return nil
	end

	return inv:FindItem(function(o)
		return o ~= nil and Util.IsSpearPrefab(o.prefab)
	end)
end

-- 导出给月台的 SCENE 收集器用
AltarActions.FindSpear = FindSpear

--------------------------------------------------------------------------
-- 客户端：数一数玩家身上有几个铥矿
--
-- 统计背包格、手持格，以及装备的背包（溢出容器）里的。
-- 少统计一处就会出现"明明够却看不到按钮"的情况。
--------------------------------------------------------------------------
local function CountThulecite(doer)
	local inv = doer ~= nil and doer.replica ~= nil and doer.replica.inventory or nil
	if inv == nil then
		return 0
	end

	local n = 0
	for i = 1, inv:GetNumSlots() do
		local it = inv:GetItemInSlot(i)
		if it ~= nil and it.prefab == Config.ANCIENT_MATERIAL then
			n = n + 1
		end
	end

	local active = inv:GetActiveItem()
	if active ~= nil and active.prefab == Config.ANCIENT_MATERIAL then
		n = n + 1
	end

	-- 装备的背包（溢出容器）里的也要算
	local overflow = inv:GetOverflowContainer()
	if overflow ~= nil then
		for _, it in pairs(overflow:GetItems() or {}) do
			if it ~= nil and it.prefab == Config.ANCIENT_MATERIAL then
				n = n + 1
			end
		end
	end

	return n
end

--------------------------------------------------------------------------
-- 客户端：在玩家的背包里找一把奔雷矛
--
-- 背包格 + 装备的背包（溢出容器）都找。
--------------------------------------------------------------------------
function AltarActions.FindSpearInInventory(doer)
	local inv = doer ~= nil and doer.replica ~= nil and doer.replica.inventory or nil
	if inv == nil then
		return nil
	end

	for i = 1, inv:GetNumSlots() do
		local it = inv:GetItemInSlot(i)
		if it ~= nil and Util.IsSpearPrefab(it.prefab) then
			return it
		end
	end

	local overflow = inv:GetOverflowContainer()
	if overflow ~= nil then
		for _, it in pairs(overflow:GetItems() or {}) do
			if it ~= nil and Util.IsSpearPrefab(it.prefab) then
				return it
			end
		end
	end

	return nil
end

--------------------------------------------------------------------------
-- 客户端：能不能显示「古铸」动作
--
-- 1. 这把矛已经古铸过了 -> 不显示
-- 2. 铥矿不够 -> 不显示（免得玩家点了没反应）
--------------------------------------------------------------------------
function AltarActions.CanCast(doer, spear)
	if spear == nil then
		return false
	end
	if spear._ancientcast_net ~= nil and spear._ancientcast_net:value() then
		return false
	end
	if CountThulecite(doer) < Config.ANCIENT_COST then
		return false
	end
	return true
end

--------------------------------------------------------------------------
-- 组件动作收集器（EQUIPPED 与 USEITEM 共用）
--
-- 签名两种通道一致：(inst, doer, target, actions, right)
--   EQUIPPED: inst = 装备槽里的武器
--   USEITEM : inst = 手持格里的武器
--------------------------------------------------------------------------
local function CollectCastAction(channel, inst, doer, target, actions, right)
	-- 只在右键时提供（与"右键避雷针给奔雷矛充能"保持一致）
	if not right then
		return
	end
	if doer == nil or target == nil then
		return
	end

	-- 诊断：每个通道只打印一次，方便定位"按钮不出现"卡在哪一步
	local diag = AltarActions._diag
	if diag[channel] == nil then
		diag[channel] = true
		print("[古铸] 诊断 " .. channel
			.. " 触发：手持物=" .. tostring(inst.prefab)
			.. " 目标=" .. tostring(target.prefab)
			.. " 铥矿=" .. tostring(CountThulecite(doer)))
	end

	-- 只认奔雷矛
	if not Util.IsSpearPrefab(inst.prefab) then
		return
	end
	-- 只认远古伪科学站
	if target.prefab ~= Config.ALTAR and not target:HasTag("ancient_station") then
		return
	end
	-- 已经古铸过就不再显示
	if inst._ancientcast_net ~= nil and inst._ancientcast_net:value() then
		return
	end
	-- 注意：这里不检查"铥矿够不够"。
	-- 客户端数不到背包/箱子里的铥矿时会把按钮整个藏掉，
	-- 玩家根本不知道有这条路；所以按钮一律显示，
	-- 铥矿数量交给服务端判定，不够时给出提示。
	table.insert(actions, ACTIONS[ACTION_ID])
end

--------------------------------------------------------------------------
-- 古铸成功时的表现
--------------------------------------------------------------------------
local function PlayCastFx(altar, spear)
	if altar ~= nil and altar.SoundEmitter ~= nil then
		altar.SoundEmitter:PlaySound("dontstarve/common/ancienttable_craft")
		altar.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_ding")
	end

	if spear ~= nil and SpawnElectricHitSparks ~= nil then
		-- 第二个参数是要对齐（火花出现）的目标：这里是被铸造的矛
		SpawnElectricHitSparks(altar, spear, true)
	end
end

function AltarActions.Register()
	local ACT = AddAction(ACTION_ID, "古铸", function(act)
		if act == nil then
			return false
		end

		local doer = act.doer
		local target = act.target

		if doer == nil or target == nil or not target:IsValid() then
			return false
		end

		-- 客户端只做预测，真实逻辑在服务端
		if not TheWorld.ismastersim then
			return true
		end

		-- 目标必须是远古伪科学站
		if target.prefab ~= Config.ALTAR and not target:HasTag("ancient_station") then
			return false
		end

		-- 武器 = 玩家装备的 / 背包里的奔雷矛
		-- EQUIPPED / USEITEM 动作的 invobject 就是那把武器
		-- （见 playeractionpicker.lua 的 SortActionList）
		local spear = FindSpear(doer, act.invobject)

		-- 调试信息：只在玩家真的点了的时候打印，方便定位问题
		-- （服务端用服务端自己的库存统计，客户端那份 replica 读不到）
		local inv = doer.components.inventory
		local _, thulen = inv:Has(Config.ANCIENT_MATERIAL, Config.ANCIENT_COST)
		print("[古铸] 目标=" .. tostring(target.prefab)
			.. " 武器=" .. tostring(spear ~= nil and spear.prefab or "无")
			.. " 铥矿=" .. tostring(thulen)
			.. " 已古铸=" .. tostring(spear ~= nil and spear:HasTag(Config.ANCIENT_TAG) or false))

		if spear == nil then
			return false
		end
		if spear:HasTag(Config.ANCIENT_TAG) then
			return false
		end

		-- 扣铥矿：数量不够就整个失败，不扣任何东西
		if not Ancientcast.Consume(doer, Config.ANCIENT_COST) then
			print("[古铸] 铥矿不足，失败")
			-- 提示玩家（reason 会被本体念出来）
			return false, "NEEDTHULECITE"
		end

		-- 施加古铸
		Ancientcast.Apply(spear)

		PlayCastFx(target, spear)

		print("[古铸] 成功")

		return true
	end)

	ACT.mount_valid = true
	ACT.distance = 2
	ACT.priority = 1
	-- 只允许右键触发
	-- （EntityScript:IsActionValid 会检查 action.rmb ~= right）
	ACT.rmb = true

	STRINGS.ACTIONS[ACTION_ID] = "古铸"
	STRINGS.ACTIONS[ACTION_ID .. "_GENERIC"] = "古铸"

	-- 诊断：确认动作与组件动作都已注册
	print("[古铸] 动作已注册 id=" .. ACTION_ID
		.. " 组件动作通道：EQUIPPED / USEITEM / SCENE(workable)")

	-- EQUIPPED：装备着奔雷矛时右键点击远古伪科学站
	AddComponentAction("EQUIPPED", "batteryuser", function(inst, doer, target, actions, right)
		CollectCastAction("EQUIPPED", inst, doer, target, actions, right)
	end)

	-- USEITEM：手持奔雷矛时右键点击远古伪科学站
	--
	-- 必须同时注册这一条：本体"手持物右键避雷针充能"走的就是 USEITEM
	-- 通道（componentactions.lua 里 USEITEM.batteryuser 收集器），
	-- 说明玩家平时是把奔雷矛拿在手上（active slot）而不是装在装备槽，
	-- 只注册 EQUIPPED 的话按钮根本不会出现。
	--
	-- 组件名用 "batteryuser"：
	--   这是模组已经给奔雷矛挂上的组件（见 lightning_spear/lightningrod.lua），
	--   客户端服务端都有真实组件，两端都会注册组件动作，
	--   右键动作在客户端才能正常显示。
	AddComponentAction("USEITEM", "batteryuser", function(inst, doer, target, actions, right)
		CollectCastAction("USEITEM", inst, doer, target, actions, right)
	end)

	-- SCENE：玩家没拿着矛、装备槽也空着时（矛在背包里）右键远古伪科学站
	--
	-- 组件名用 "workable" 而不是 "inspectable"：
	--   "inspectable" 已经被月台仪式占用（同一个模组里同名同类型的组件动作
	--   只能有一个收集器，后注册的会覆盖前面的），
	--   而远古伪科学站本身就有 workable 组件，用它互不干扰。
	AddComponentAction("SCENE", "workable", function(inst, doer, actions, right)
		if not right then
			return
		end
		if doer == nil or doer.replica == nil or doer.replica.inventory == nil then
			return
		end
		-- 诊断
		if AltarActions._diag["SCENE"] == nil then
			AltarActions._diag["SCENE"] = true
			print("[古铸] 诊断 SCENE 触发：目标=" .. tostring(inst.prefab)
				.. " 铥矿=" .. tostring(CountThulecite(doer)))
		end
		-- 只认远古伪科学站
		if inst.prefab ~= Config.ALTAR and not inst:HasTag("ancient_station") then
			return
		end
		local spear = AltarActions.FindSpearInInventory(doer)
		if spear ~= nil and not (spear._ancientcast_net ~= nil and spear._ancientcast_net:value()) then
			table.insert(actions, ACTIONS[ACTION_ID])
		end
	end)

	AddStategraphActionHandler("wilson", ActionHandler(ACTIONS[ACTION_ID], "dolongaction"))
	AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS[ACTION_ID], "dolongaction"))
end

return AltarActions
