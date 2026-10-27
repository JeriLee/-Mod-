-- 古铸 · 「古铸」状态效果
--
-- 古铸与「月淬」「月台仪式」互不相干，是一条独立的路线：
--   在远古伪科学站花 5 个铥矿，给奔雷矛做一次"古铸"，
--   武器因此获得两个新功能：
--     1. 对巨人 boss（epic 标签）增伤
--     2. 携带它的玩家免疫蜂后减速
--
-- 古铸不是在矛上做 prefab 替换，而是在矛上打 "ancient" 标签来标记
-- （见 Config.ANCIENT_TAG）。本模块负责给带标签的矛挂上应有的效果：
--   1. 对巨人 boss 增伤（见 Apply 里的 damagetypebonus:AddBonus("epic", ...)）
--   2. 免疫蜂后减速（见 SetupBeequeenImmune）
--   3. 改名（普通形态「古铸奔雷矛」/ 充能形态「古铸充能奔雷矛」）
--
-- 所有函数都是幂等的，可以安全地在施加 / 读档等多种时机重复调用。
--
-- 注意：本文件是 require 进来的普通模块，默认 _G 带 strict，
-- 引擎接口必须显式从 GLOBAL 取（见 genv.lua）。

local G = require("shared/genv")
local Config = require("ancient_cast/config")
local SpearName = require("shared/spearname")

local TheWorld = G.Lazy("TheWorld")
local net_bool = G.Get("net_bool")

local Ancientcast = {}

--------------------------------------------------------------------------
-- 免疫蜂后减速
--
-- 本体蜂后的减速来自它喷出的蜂蜜拖尾 honey_trail：玩家踩上去时，
-- honey_trail 会检查玩家是否带 "vigorbuff" 标签（HONEYTRAILSLOWDOWN_CANT_TAGS），
-- 带了就跳过减速。所以古铸矛的做法是：
--   装备古铸奔雷矛时 -> 给玩家临时挂上 "vigorbuff" 标签
--   卸下时            -> 移除该标签
--
-- 这样完全复用本体逻辑，玩家携带古铸矛时踩蜂蜜不会被减速。
--
-- 注意：vigorbuff 在本体还有"抵消慢速装备的移速惩罚"的副作用
-- （equippable.lua / inventoryitem_replica.lua 里 speed < 1 时 +0.25），
-- 如果玩家同时携带了其它慢速装备，会被顺带抵消一部分惩罚；
-- 这是本体的既有行为，可接受。
--------------------------------------------------------------------------

-- 装备古铸矛：给玩家挂 vigorbuff
local function OnEquipAncient(inst, owner)
	if owner == nil or not owner:IsValid() then
		return
	end
	if not owner:HasTag(Config.BEEQUEEN_IMMUNE_TAG) then
		owner:AddTag(Config.BEEQUEEN_IMMUNE_TAG)
		-- 让本体重新计算地面速度倍率（locomotor 的 groundspeedmultiplier）
		-- 否则只加标签，已处于减速状态的地面倍率不会立刻刷新。
		if owner.components.locomotor ~= nil then
			owner.components.locomotor:EnableGroundSpeedMultiplier(false)
			owner.components.locomotor:EnableGroundSpeedMultiplier(true)
		end
	end
end

-- 卸下古铸矛：移除玩家身上的 vigorbuff
local function OnUnequipAncient(inst, owner)
	if owner == nil or not owner:IsValid() then
		return
	end
	if owner:HasTag(Config.BEEQUEEN_IMMUNE_TAG) then
		owner:RemoveTag(Config.BEEQUEEN_IMMUNE_TAG)
		if owner.components.locomotor ~= nil then
			owner.components.locomotor:EnableGroundSpeedMultiplier(false)
			owner.components.locomotor:EnableGroundSpeedMultiplier(true)
		end
	end
end

--------------------------------------------------------------------------
-- 挂载"装备/卸下"监听，实现免疫蜂后减速
--
-- 必须在 prefab 初始化时调用一次（客户端服务端都执行，但这里只在
-- 服务端生效，因为标签是服务端数据）。通过 equippable 的 equipped /
-- unequipped 事件，在装备/卸下时按"自己是否已古铸"来决定给玩家加/减标签。
--------------------------------------------------------------------------
function Ancientcast.SetupBeequeenImmune(inst)
	if not TheWorld.ismastersim or inst == nil or not inst:IsValid() then
		return
	end
	if inst._ancientcast_beequeenimmune then
		return
	end
	inst._ancientcast_beequeenimmune = true

	inst:ListenForEvent("equipped", function(i, data)
		if i:HasTag(Config.ANCIENT_TAG) then
			OnEquipAncient(i, data ~= nil and data.owner or nil)
		end
	end)

	inst:ListenForEvent("unequipped", function(i, data)
		if i:HasTag(Config.ANCIENT_TAG) then
			OnUnequipAncient(i, data ~= nil and data.owner or nil)
		end
	end)
end

--------------------------------------------------------------------------
-- 古铸后改名
--
-- 名称由共享的通用命名函数（shared/spearname.lua）动态生成：
-- 它会同时读取"月萃"和"古铸"两个标记，按「月萃 → 古铸 → 基础名」
-- 的顺序拼接，因此两种效果任意组合都能正确显示。
--
-- 本函数只负责：
--   1. 创建"是否已古铸"的 net 变量（客户端可见标记）
--   2. 调用通用函数挂载 displaynamefn（幂等，与月淬共用同一个）
--
-- 注意："ancient" 标签既不会同步到客户端，也不会随存档保存，
-- 所以这里单独用一个 net_bool 作为客户端可见的标记。
--------------------------------------------------------------------------
function Ancientcast.SetupName(inst)
	-- net 变量必须在客户端和服务端都创建，且名字一致
	if inst._ancientcast_net == nil then
		inst._ancientcast_net = net_bool(inst.GUID, "spear.ancientcast",
			"thunderspearancientcastdirty")
	end

	-- 统一挂载 displaynamefn（幂等），同时读取月萃 + 古铸两个标记
	SpearName.SetupDisplayName(inst,
		function(i)
			return i._moonforged_net ~= nil and i._moonforged_net:value()
		end,
		function(i)
			return i._ancientcast_net ~= nil and i._ancientcast_net:value()
		end)
end

--------------------------------------------------------------------------
-- 施加全部古铸效果（幂等）
--------------------------------------------------------------------------
function Ancientcast.Apply(inst)
	if not TheWorld.ismastersim or inst == nil or not inst:IsValid() then
		return
	end

	-- 保证标签存在
	if not inst:HasTag(Config.ANCIENT_TAG) then
		inst:AddTag(Config.ANCIENT_TAG)
	end

	-- 同步到客户端，让改名在两端都生效
	if inst._ancientcast_net == nil then
		Ancientcast.SetupName(inst)
	end
	if inst._ancientcast_net ~= nil then
		inst._ancientcast_net:set(true)
	end

	-- 免疫蜂后减速（装备/卸下时给玩家加/减 vigorbuff 标签）
	Ancientcast.SetupBeequeenImmune(inst)

	-- 对巨人 boss（epic 标签）增伤
	-- AddBonus 同 src + 同 key 会覆盖，重复调用是安全的。
	local damagetypebonus = inst.components.damagetypebonus
		or inst:AddComponent("damagetypebonus")
	damagetypebonus:AddBonus("epic", inst, Config.ANCIENT_GIANT_DAMAGE_BONUS)

	-- 若此刻已经装备着（古铸在装备状态下进行），立即给持有者补上标签
	local equippable = inst.components.equippable
	if equippable ~= nil and equippable:IsEquipped() then
		local owner = inst.components.inventoryitem ~= nil
			and inst.components.inventoryitem:GetGrandOwner() or nil
		if owner ~= nil and owner:IsValid() then
			OnEquipAncient(inst, owner)
		end
	end
end

--------------------------------------------------------------------------
-- 让 "ancient" 标签随存档保存/恢复
-- AddTag 添加的标签不会写入存档，所以额外把标记写进 SaveRecord。
-- 读档时 prefab 会重新初始化，因此按标签重建古铸效果。
--------------------------------------------------------------------------
function Ancientcast.SetupPersist(inst)
	if not TheWorld.ismastersim then
		return
	end

	-- 幂等：避免 OnSave / OnLoad 被重复包装
	if inst._ancientcast_persist then
		return
	end
	inst._ancientcast_persist = true

	local oldOnSave = inst.OnSave
	inst.OnSave = function(i, data)
		-- 注意：EntityScript.OnSave 的返回值约定是 references（GUID 列表），
		-- 不是数据表。数据必须原地写进传进来的 data。
		-- 老包装若返回 data 本身，这里直接丢弃，避免污染 references。
		data = data or {}
		local refs = oldOnSave ~= nil and oldOnSave(i, data) or nil
		if refs == data then
			refs = nil
		end
		if i:HasTag(Config.ANCIENT_TAG) then
			data.ancientcast = true
		end
		return refs
	end

	local oldOnLoad = inst.OnLoad
	inst.OnLoad = function(i, data)
		if oldOnLoad ~= nil then
			oldOnLoad(i, data)
		end
		if data ~= nil and data.ancientcast then
			i:AddTag(Config.ANCIENT_TAG)
			Ancientcast.Apply(i)
		end
	end
end

--------------------------------------------------------------------------
-- 消耗铥矿
--
-- 返回 true 表示已扣够并扣完；false 表示数量不足（不扣任何东西）。
--------------------------------------------------------------------------
function Ancientcast.Consume(doer, count)
	local inv = doer ~= nil and doer.components.inventory or nil
	if inv == nil or count == nil or count <= 0 then
		return false
	end

	local has, num = inv:Has(Config.ANCIENT_MATERIAL, count)
	if not has or num < count then
		return false
	end

	-- 先收集要扣的实体，再逐个扣除
	-- （Inventory 没有"按 prefab 扣 N 个"的接口，只有按实体扣）
	local targets = {}
	for _, item in pairs(inv.itemslots) do
		if item ~= nil and item.prefab == Config.ANCIENT_MATERIAL then
			table.insert(targets, item)
		end
	end
	local active = inv:GetActiveItem()
	if active ~= nil and active.prefab == Config.ANCIENT_MATERIAL then
		table.insert(targets, active)
	end
	-- 溢出容器（背包等）里的铥矿也要算上，
	-- 否则背包满了的时候会出现"明明够却扣不掉"的情况
	--
	-- 注意：服务端的 Inventory:GetOverflowContainer() 返回的是
	-- **容器组件**（item.components.container），不是实体；
	-- 容器的物品放在它的 .slots 里。
	local overflow = inv:GetOverflowContainer()
	if overflow ~= nil then
		for _, item in pairs(overflow.slots or {}) do
			if item ~= nil and item.prefab == Config.ANCIENT_MATERIAL then
				table.insert(targets, item)
			end
		end
	end

	local removed = 0
	for _, item in ipairs(targets) do
		if removed >= count then
			break
		end
		if not item:IsValid() then
			-- 已经被别处移走了，跳过
		else
			local stackable = item.components.stackable
			if stackable ~= nil then
				-- 可堆叠物品（铥矿就是）：一次只取 1 个
				--
				-- 注意 RemoveItem 的第二个参数：
				--   true  = 整堆扣掉（会把 20 个铥矿一次全扣光）
				--   false = 只取 1 个（本体消耗材料的标准做法）
				-- 这里必须用 false，并且按"个数"而不是按"实体"计数。
				while removed < count and item:IsValid() and stackable:StackSize() > 0 do
					local ret = inv:RemoveItem(item, false)
					if ret == nil then
						break
					end
					removed = removed + 1
					-- 取出来的那份要销毁，不能留在世界里
					ret:Remove()
				end
			else
				-- 不可堆叠：整个扣掉
				local ret = inv:RemoveItem(item, true)
				if ret ~= nil then
					removed = removed + 1
					ret:Remove()
				end
			end
		end
	end

	return removed >= count
end

return Ancientcast
