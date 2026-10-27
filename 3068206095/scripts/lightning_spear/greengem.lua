-- 奔雷矛 · 绿宝石改造
--
-- 交互完全复用本体的标签式收集器（componentactions.lua 的
-- USEITEM -> useabletargeteditem）：
--     inst.UseableTargetedItem_ValidTarget(target, doer)
-- 只要手持物品带 useabletargeteditem 组件、目标带约定标签，
-- 客户端就会显示「使用」动作，服务端由 onusefn 执行。
--
-- 不新增 prefab、不新增 UPGRADETYPES，只约定两个标签：
--     greengem_targetable  加在奔雷矛上 → 可被绿宝石改造
--     greengem_attuned     加在奔雷矛上 → 已被改造（每把武器只允许一次）
-- 改造层数记在 inst._greengem_count，读档时按层数补回数值。
--
-- 使用门槛：只有「古铸的充能奔雷矛」可以使用绿宝石，
-- 即 prefab == spear_wathgrithr_lightning_charged 且带古铸状态
-- （服务端看 ancient 标签，客户端看 ancientcast 模块同步的 net 标记）。
--
-- 每次使用：位面伤害 +30，持续一天
-- （TUNING.TOTAL_DAY_TIME = 480 秒）。到期后自动撤销加成、
-- 清掉改造状态，之后可以再次使用绿宝石。
--
-- 改造状态需要让客户端也知道（客户端要隐藏「使用」动作），
-- 而标签不会同步到客户端，所以额外挂一个 net_bool 做镜像。
-- 到期时间用绝对时间戳写进存档，读档后按剩余时间重新排任务。

local G = require("shared/genv")
local Shared = require("shared/weapon")
local SpearName = require("shared/spearname")
local AncientConfig = require("ancient_cast/config")

local AddPrefabPostInit = G.Get("AddPrefabPostInit")
local net_bool = G.Get("net_bool")
local net_int = G.Get("net_int")
local TUNING = G.Get("TUNING")
local TheWorld = G.Lazy("TheWorld")
local GetTime = G.Lazy("GetTime")

local GreenGem = {}

GreenGem.TAG_TARGETABLE = "greengem_targetable"
GreenGem.TAG_ATTUNED = "greengem_attuned"

-- 每颗绿宝石提供/撤销的位面伤害
GreenGem.PLANAR_GAIN = 30

-- 效果持续一天（TUNING.TOTAL_DAY_TIME = 480 秒），到期自动失效
GreenGem.DURATION = TUNING.TOTAL_DAY_TIME

--------------------------------------------------------------------------
-- 改造状态的客户端镜像
--------------------------------------------------------------------------
local function EnsureAttunedNet(inst)
	if inst._greengem_net == nil then
		inst._greengem_net = net_bool(inst.GUID, "spear.greengem", "greengemdirty")
	end
	return inst._greengem_net
end

-- 剩余秒数同步给客户端，供物品名 / Insight 描述显示
--
-- 注意这里同步的是「发送那一刻的剩余秒数」，不是绝对时间戳：
-- 客户端和服务器是两个进程，GetTime() 不同源，同步时间戳会算出离谱的值。
-- 客户端收到后记下本地基准时间，再自己倒数。
local function EnsureExpireNet(inst)
	if inst._greengem_expire_net == nil then
		inst._greengem_expire_net =
			net_int(inst.GUID, "spear.greengemexpire", "greengemexpiredirty")
		inst:ListenForEvent("greengemexpiredirty", function(i)
			i._greengem_net_base = GetTime()
		end)
	end
	return inst._greengem_expire_net
end

local function MarkAttuned(inst)
	if not TheWorld.ismastersim then
		return
	end
	inst:AddTag(GreenGem.TAG_ATTUNED)
	EnsureAttunedNet(inst):set(true)
end

local function IsAncient(ent)
	if ent == nil or ent.HasTag == nil then
		return false
	end
	if ent:HasTag(AncientConfig.ANCIENT_TAG) then
		return true
	end
	-- 客户端读不到标签，只能读古铸模块同步过来的 net 标记
	local net = ent._ancientcast_net
	return net ~= nil and net:value()
end

-- 前缀匹配，兼皮肤版 prefab（spear_wathgrithr_lightning_charged[_skin]）
local function IsChargedSpearPrefab(prefab)
	return prefab ~= nil
		and prefab:sub(1, #Shared.SPEAR_CHARGED) == Shared.SPEAR_CHARGED
end

-- 绿宝石只对「古铸的充能奔雷矛」生效
local function IsEligibleTarget(ent)
	if ent == nil or ent.HasTag == nil or not IsChargedSpearPrefab(ent.prefab) then
		return false
	end
	return ent:HasTag(GreenGem.TAG_TARGETABLE) and IsAncient(ent)
end

local function IsAttuned(ent)
	if ent == nil or ent.HasTag == nil then
		return false
	end
	if ent:HasTag(GreenGem.TAG_ATTUNED) then
		return true
	end
	local net = ent._greengem_net
	return net ~= nil and net:value()
end

local function IsUsableTarget(ent)
	return IsEligibleTarget(ent) and not IsAttuned(ent)
end

--------------------------------------------------------------------------
-- 数值：位面伤害用「增量」叠加，不要按 prefab 基准值重算
--
-- 原因：装备上可能还有别的加成（例如避雷针充能的 ×1.2，见 lightningrod.lua），
-- 按 TUNING 基准重算容易把别人的加成抹掉。增量方式天然兼容。
--------------------------------------------------------------------------
local function ApplyStacks(inst, count)
	if not TheWorld.ismastersim or count == nil or count <= 0 then
		return
	end

	if inst.components.weapon == nil then
		return
	end

	local planar = inst.components.planardamage
	if planar == nil then
		planar = inst:AddComponent("planardamage")
	end
	planar:SetBaseDamage(planar:GetBaseDamage() + GreenGem.PLANAR_GAIN * count)
end

-- 到期撤销：与 ApplyStacks 严格对称地减回去
local function RestoreStacks(inst, count)
	if not TheWorld.ismastersim or count == nil or count <= 0 then
		return
	end

	local planar = inst.components.planardamage
	if planar ~= nil then
		planar:SetBaseDamage(math.max(0, planar:GetBaseDamage() - GreenGem.PLANAR_GAIN * count))
	end
end

-- 撤掉强化状态（标签 + 客户端镜像 + 数值），之后可以再次使用绿宝石
local function ClearAttunement(inst)
	if not TheWorld.ismastersim then
		return
	end

	if inst._greengem_task ~= nil then
		inst._greengem_task:Cancel()
		inst._greengem_task = nil
	end

	local count = inst._greengem_count or 0
	inst._greengem_count = nil
	inst._greengem_expire = nil

	inst:RemoveTag(GreenGem.TAG_ATTUNED)
	EnsureAttunedNet(inst):set(false)
	EnsureExpireNet(inst):set(0)

	RestoreStacks(inst, count)
end

-- 排定到期任务
--
-- 运行时统一用 _greengem_expire（本进程内的绝对时间）做判定，
-- 但存档只存剩余秒数：GetTime() 从游戏进程启动算起，跨存档不连续，
-- 存绝对时间戳会让「读档后剩余时间被重置成满值」（本体组件也都存 remainingtime）。
local function StartExpireTimer(inst, duration)
	if not TheWorld.ismastersim then
		return
	end

	if inst._greengem_task ~= nil then
		inst._greengem_task:Cancel()
		inst._greengem_task = nil
	end

	inst._greengem_expire = GetTime() + duration
	inst._greengem_net_base = GetTime()
	EnsureExpireNet(inst):set(math.ceil(duration))
	inst._greengem_task = inst:DoTaskInTime(duration, function(i)
		i._greengem_task = nil
		ClearAttunement(i)
	end)
end

--------------------------------------------------------------------------
-- 名字兜底：没有 Insight 时把剩余时间拼进物品名
--
-- 本体没有物品属性面板，不装 Insight 时唯一能看到的地方就是悬浮物品名。
-- 所以这里在 displaynamefn 外层追加「（绿宝石 4:12/8:00）」。
-- 装了 Insight 时交给 insight_desc.lua 的悬浮行，这里原样返回避免重复。
--------------------------------------------------------------------------
local function FormatClock(seconds)
	seconds = math.floor(seconds + 0.5)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

local function SetupFallbackName(inst)
	if inst._greengem_fallbackname then
		return
	end
	inst._greengem_fallbackname = true

	local old = inst.displaynamefn
	inst.displaynamefn = function(i)
		local base = old ~= nil and old(i) or nil
		if base == nil then
			-- 没有月淬/古铸前缀时，回退到本体基础名
			base = SpearName.GetBaseName(i.prefab)
		end
		if base == nil then
			return nil
		end

		-- Insight 描述注册成功时由它的悬浮行负责显示，避免重复
		if GreenGem.InsightRegistered then
			return base
		end

		local remaining = GreenGem.GetRemaining(i)
		if remaining <= 0 then
			return base
		end

		return string.format("%s（绿宝石 %s/%s）",
			base, FormatClock(remaining), FormatClock(GreenGem.DURATION))
	end
end

--------------------------------------------------------------------------
-- 存档 / 读档
--
-- 本体奔雷矛没有 OnSave / OnLoad，这里沿用模组其他模块的写法：
-- 链式包装旧的 OnSave / OnLoad，并用幂等标记避免重复包装。
--------------------------------------------------------------------------
local function SetupPersist(inst)
	if not TheWorld.ismastersim then
		return
	end

	if inst._greengem_persist then
		return
	end
	inst._greengem_persist = true

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
		if (i._greengem_count or 0) > 0 and i._greengem_expire ~= nil then
			local remaining = i._greengem_expire - GetTime()
			if remaining > 0 then
				data.greengem_count = i._greengem_count
				-- 存剩余秒数，不要存绝对时间戳（见 StartExpireTimer 的说明）
				data.greengem_remaining = remaining
			end
		end
		return refs
	end

	local oldOnLoad = inst.OnLoad
	inst.OnLoad = function(i, data)
		if oldOnLoad ~= nil then
			oldOnLoad(i, data)
		end

		if data == nil then
			return
		end

		-- 只存了层数、没有剩余时间的老存档视为已过期，不再恢复
		local remaining = data.greengem_remaining
		if remaining == nil then
			-- 更老的存档存的是绝对时间戳，跨进程不可信，按满时长恢复一次
			remaining = data.greengem_expire ~= nil and GreenGem.DURATION or nil
		end
		if remaining == nil or remaining <= 0 then
			return
		end
		remaining = math.min(remaining, GreenGem.DURATION)

		i._greengem_count = data.greengem_count or 1
		MarkAttuned(i)
		-- 读档时 prefab 刚重建，weapon.damage 是默认值，按层数补扣
		ApplyStacks(i, i._greengem_count)
		StartExpireTimer(i, remaining)
	end
end

--------------------------------------------------------------------------
-- 升级成充能矛时继承改造状态
--
-- 本体 Lightning_OnUpgraded 会 SpawnPrefab 一把新矛再把旧矛 Remove，
-- 新矛不会带上旧矛的运行时字段，所以用一个模块级临时值接力。
-- SpawnPrefab 发生在 onupgradefn 内部，此时能把值写进新矛的 PostInit。
--------------------------------------------------------------------------
local pending = nil

local function SetupUpgradeInherit(inst)
	local upgradeable = inst.components.upgradeable
	if upgradeable == nil or upgradeable.onupgradefn == nil then
		return
	end

	if inst._greengem_upgrade_inherit then
		return
	end
	inst._greengem_upgrade_inherit = true

	local oldOnUpgrade = upgradeable.onupgradefn
	upgradeable.onupgradefn = function(i, upgrader, item)
		pending = (i._greengem_count ~= nil and i._greengem_expire ~= nil)
			and { count = i._greengem_count, expire = i._greengem_expire }
			or nil
		local a, b, c = oldOnUpgrade(i, upgrader, item)
		pending = nil
		return a, b, c
	end
end

--------------------------------------------------------------------------
-- 使用绿宝石
--------------------------------------------------------------------------
local function OnUseGreenGem(gem, target, doer)
	if target == nil or not target:IsValid() or not IsEligibleTarget(target) then
		return false
	end

	if target.components.weapon == nil then
		return false
	end

	-- 每把武器只允许吸收一颗
	if IsAttuned(target) then
		return false, "GREENGEM_ALREADY_USED"
	end

	target._greengem_count = 1
	MarkAttuned(target)
	ApplyStacks(target, 1)
	StartExpireTimer(target, GreenGem.DURATION)

	-- 消耗一颗（绿宝石可堆叠）
	if gem.components.stackable ~= nil then
		gem.components.stackable:Get(1):Remove()
	else
		gem:Remove()
	end

	return true
end

--------------------------------------------------------------------------
-- 装配
--------------------------------------------------------------------------
function GreenGem.Setup()
	local function SetupSpear(inst)
		-- 双端都要有标签（服务端判定），net 做客户端镜像
		inst:AddTag(GreenGem.TAG_TARGETABLE)
		EnsureAttunedNet(inst)
		EnsureExpireNet(inst)
		SetupFallbackName(inst)

		if not TheWorld.ismastersim then
			return
		end

		SetupPersist(inst)
		SetupUpgradeInherit(inst)

		-- 刚由普通矛升级而来的充能矛：接力改造状态与剩余时间
		if pending ~= nil then
			local remaining = pending.expire - GetTime()
			if remaining > 0 then
				inst._greengem_count = pending.count
				MarkAttuned(inst)
				ApplyStacks(inst, pending.count)
				StartExpireTimer(inst, remaining)
			end
		end
	end

	AddPrefabPostInit(Shared.SPEAR, SetupSpear)
	AddPrefabPostInit(Shared.SPEAR_CHARGED, SetupSpear)
	for _, skin in ipairs(Shared.SPEAR_SKINS) do
		AddPrefabPostInit(Shared.SPEAR .. "_" .. skin, SetupSpear)
		AddPrefabPostInit(Shared.SPEAR_CHARGED .. "_" .. skin, SetupSpear)
	end

	-- 绿宝石：挂 useabletargeteditem，纯标签判断有效目标
	AddPrefabPostInit("greengem", function(inst)
		if inst.components.useabletargeteditem == nil then
			inst:AddComponent("useabletargeteditem")
		end

		-- 注意：不要用 inst:AddTag(prefab.."_targeter") 那条通道。
		-- 那个标签是按 prefab 名固定的，没法按目标状态动态改，
		-- 结果就是武器改造完之后客户端仍然一直显示「使用」动作。
		-- 这里只走 ValidTarget，才能做到改造后客户端直接不再提示。

		-- componentactions 是点号调用（target, doer），
		-- componentutil 的 socket 包装是冒号调用（self, target, doer），
		-- 两个位置都查一遍，避免签名错位。
		inst.UseableTargetedItem_ValidTarget = function(a, b)
			return IsUsableTarget(a) or IsUsableTarget(b)
		end

		if not TheWorld.ismastersim then
			return
		end

		inst.components.useabletargeteditem:SetOnUseFn(OnUseGreenGem)
	end)
end

--------------------------------------------------------------------------
-- 供外部（Insight 描述等）查询剩余时间
--
-- net 里是「同步那一刻的剩余秒数」，用本地 GetTime() 相对基准倒数，
-- 服务端和客户端各自计时都不会串。
--------------------------------------------------------------------------
function GreenGem.GetRemaining(inst)
	if inst == nil then
		return 0
	end
	local net = inst._greengem_expire_net
	local secs = net ~= nil and net:value() or 0
	if secs == nil or secs <= 0 then
		return 0
	end

	local elapsed = GetTime() - (inst._greengem_net_base or GetTime())
	local remaining = secs - elapsed
	if remaining <= 0 then
		return 0
	end
	return math.min(remaining, GreenGem.DURATION)
end

return GreenGem
