-- 奔雷矛 · 黄宝石改造
--
-- 与绿宝石（greengem.lua）同一套交互与生命周期，只是效果不同：
--   手持黄宝石对「古铸的充能奔雷矛」使用 → 改造成功
--   效果（只在冲刺那一下生效，不改任何常驻数值面板）：
--     1. 冲刺伤害 ×2
--     2. 冲刺命中的电击僵直 0.8 秒 → 2.4 秒
--   持续一天（TUNING.TOTAL_DAY_TIME = 480 秒），到期自动失效，
--   失效后可以再用一颗黄宝石。
--
-- 交互完全复用本体的 useabletargeteditem（componentactions.lua 的
-- USEITEM -> useabletargeteditem），与绿宝石完全一致，两块宝石互不影响，
-- 同一把矛可以同时带绿宝石和黄宝石的改造。
--
-- 约定的标签：
--     yellowgem_targetable  加在奔雷矛上 → 可被黄宝石改造
--     yellowgem_attuned     加在奔雷矛上 → 已被改造（每把武器只允许一颗）
-- 客户端读不到服务端标签，所以额外挂 net_bool / net_int 做镜像。
--
-- 使用门槛：只有「古铸的充能奔雷矛」可以用黄宝石，
-- 即 prefab == spear_wathgrithr_lightning_charged 且带古铸状态
-- （服务端看 ancient 标签，客户端看 ancientcast 模块同步的 net 标记）。

local G = require("shared/genv")
local Shared = require("shared/weapon")
local SpearName = require("shared/spearname")
local AncientConfig = require("ancient_cast/config")

local AddPrefabPostInit = G.Get("AddPrefabPostInit")
local net_bool = G.Get("net_bool")
local net_int = G.Get("net_int")
local TUNING = G.Get("TUNING")
local FRAMES = G.Get("FRAMES")
local TheWorld = G.Lazy("TheWorld")
local GetTime = G.Lazy("GetTime")

local YellowGem = {}

YellowGem.TAG_TARGETABLE = "yellowgem_targetable"
YellowGem.TAG_ATTUNED = "yellowgem_attuned"

-- 冲刺命中那一下的伤害倍率（普通攻击不受影响）
YellowGem.LUNGE_DMG_MULT = 2

-- 冲刺命中后的电击僵直时长（秒）。原版走 TUNING.ELECTROCUTE_DEFAULT_DURATION
-- = 0.8 秒。
YellowGem.STUN = 2.4

-- 效果持续一天，与绿宝石一致
YellowGem.DURATION = TUNING.TOTAL_DAY_TIME

--------------------------------------------------------------------------
-- 改造状态的客户端镜像
--------------------------------------------------------------------------
local function EnsureAttunedNet(inst)
	if inst._yellowgem_net == nil then
		inst._yellowgem_net = net_bool(inst.GUID, "spear.yellowgem", "yellowgemdirty")
	end
	return inst._yellowgem_net
end

-- 剩余秒数同步给客户端，供物品名显示
--
-- 同步的是「发送那一刻的剩余秒数」，不是绝对时间戳：
-- 客户端和服务器是两个进程，GetTime() 不同源，同步时间戳会算出离谱的值。
-- 客户端收到后记下本地基准时间，再自己倒数。
local function EnsureExpireNet(inst)
	if inst._yellowgem_expire_net == nil then
		inst._yellowgem_expire_net =
			net_int(inst.GUID, "spear.yellowgemexpire", "yellowgemexpiredirty")
		inst:ListenForEvent("yellowgemexpiredirty", function(i)
			i._yellowgem_net_base = GetTime()
		end)
	end
	return inst._yellowgem_expire_net
end

-- 前向声明：改造生效时补挂冲刺钩子（实现见文件后面的 HookLunge）。
-- prefab post-init 阶段组件有可能还没加全，所以改造真正生效时再挂一次（幂等）。
local HookLunge

local function MarkAttuned(inst)
	if not TheWorld.ismastersim then
		return
	end
	inst:AddTag(YellowGem.TAG_ATTUNED)
	EnsureAttunedNet(inst):set(true)

	if HookLunge ~= nil then
		HookLunge(inst)
	end
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

-- 黄宝石只对「古铸的充能奔雷矛」生效
local function IsEligibleTarget(ent)
	if ent == nil or ent.HasTag == nil or not IsChargedSpearPrefab(ent.prefab) then
		return false
	end
	return ent:HasTag(YellowGem.TAG_TARGETABLE) and IsAncient(ent)
end

local function IsAttuned(ent)
	if ent == nil or ent.HasTag == nil then
		return false
	end
	if ent:HasTag(YellowGem.TAG_ATTUNED) then
		return true
	end
	local net = ent._yellowgem_net
	return net ~= nil and net:value()
end

local function IsUsableTarget(ent)
	return IsEligibleTarget(ent) and not IsAttuned(ent)
end

--------------------------------------------------------------------------
-- 到期处理
--
-- 两种效果都是「冲刺时现算」的，没有落在属性上的数字，所以撤掉时
-- 只需要清标签 / net / 计时器，不用回滚任何面板数值。
--------------------------------------------------------------------------
local function ClearAttunement(inst)
	if not TheWorld.ismastersim then
		return
	end

	if inst._yellowgem_task ~= nil then
		inst._yellowgem_task:Cancel()
		inst._yellowgem_task = nil
	end

	inst._yellowgem_count = nil
	inst._yellowgem_expire = nil

	inst:RemoveTag(YellowGem.TAG_ATTUNED)
	EnsureAttunedNet(inst):set(false)
	EnsureExpireNet(inst):set(0)
end

-- 排定到期任务
--
-- 运行时用 _yellowgem_expire（本进程内的绝对时间）做判定，
-- 但存档只存剩余秒数：GetTime() 从游戏进程启动算起，跨存档不连续，
-- 存绝对时间戳会让「读档后剩余时间被重置成满值」（本体组件也都存 remainingtime）。
local function StartExpireTimer(inst, duration)
	if not TheWorld.ismastersim then
		return
	end

	if inst._yellowgem_task ~= nil then
		inst._yellowgem_task:Cancel()
		inst._yellowgem_task = nil
	end

	inst._yellowgem_expire = GetTime() + duration
	inst._yellowgem_net_base = GetTime()
	EnsureExpireNet(inst):set(math.ceil(duration))
	inst._yellowgem_task = inst:DoTaskInTime(duration, function(i)
		i._yellowgem_task = nil
		ClearAttunement(i)
	end)
end

--------------------------------------------------------------------------
-- 名字兜底：把剩余时间拼进物品名
--
-- 服务端/客户端都能算（到期时间戳走 net_int），与绿宝石的写法一致。
--------------------------------------------------------------------------
local function FormatClock(seconds)
	seconds = math.floor(seconds + 0.5)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

local function SetupFallbackName(inst)
	if inst._yellowgem_fallbackname then
		return
	end
	inst._yellowgem_fallbackname = true

	local old = inst.displaynamefn
	inst.displaynamefn = function(i)
		local base = old ~= nil and old(i) or nil
		if base == nil then
			base = SpearName.GetBaseName(i.prefab)
		end
		if base == nil then
			return nil
		end

		local remaining = YellowGem.GetRemaining(i)
		if remaining <= 0 then
			return base
		end

		return string.format("%s（黄宝石 %s/%s）",
			base, FormatClock(remaining), FormatClock(YellowGem.DURATION))
	end
end

--------------------------------------------------------------------------
-- 冲刺命中：伤害翻倍 + 电击僵直 2.4 秒
--
-- 伤害：冲刺那一下走的是 AoEWeapon_Base:OnHit → Combat:DoAttack，
--       伤害由 weapon:GetDamage 给出，所以在 prehit 里临时包装 GetDamage，
--       命中回调里立刻还原（没命中/敲树走 onmiss 或兜底任务还原）。
--       GetDamage 返回 (基础伤害, 位面伤害表)，两个都翻倍 = 全伤害翻倍。
--
-- 僵直：电击时长来自 CalcEntityElectrocuteDuration（stategraphs/commonstates.lua），
--       它优先取 inst.electrocute_duration，其次才是 ELECTROCUTE_DEFAULT_DURATION，
--       而攻击事件里没有字段能把 duration 传进去。
--       所以冲刺命中前临时给目标设上 electrocute_duration，稍后还原，
--       这样电击状态时长和电击特效时长都会变成 2.4 秒，且不会永久改到目标。
--
--       注意时序：受击事件在服务端是「延迟处理」的（本体 Lightning_OnPreLunge
--       也是为此等了 2 帧才清标志），所以不能下一帧就还原，否则电击状态
--       onenter 读到的还是默认值 —— 这也是之前电击时长没变的原因。
--
--       玩家走的是 SGwilson 自己的 electrocute 状态（时长取动画长度，
--       不看 electrocute_duration），命中后等受击事件处理完再用 sg:SetTimeout 兜底。
--------------------------------------------------------------------------
local function EndDoubleDamage(inst)
	local weapon = inst.components ~= nil and inst.components.weapon or nil
	if weapon == nil or weapon._yellowgem_old_getdamage == nil then
		return
	end

	weapon.GetDamage = weapon._yellowgem_old_getdamage
	weapon._yellowgem_old_getdamage = nil

	if inst._yellowgem_dmg_task ~= nil then
		inst._yellowgem_dmg_task:Cancel()
		inst._yellowgem_dmg_task = nil
	end
end

-- 位面伤害是一张 { 类型 = 数值 } 的表（SpDamageUtil 的格式），
-- 不能直接乘；这里等价于 SpDamageUtil.ApplyMult(tbl, mult)，
-- 省得为了一个乘法去 require 本体模块。
local function ScaleSpDamage(tbl, mult)
	if tbl == nil then
		return nil
	end
	for k, v in pairs(tbl) do
		tbl[k] = v * mult
	end
	return tbl
end

local function BeginDoubleDamage(inst)
	local weapon = inst.components.weapon
	if weapon == nil or weapon._yellowgem_old_getdamage ~= nil then
		return
	end

	-- 临时包装实例方法：本体和其它模组对基础伤害的加成都会一起翻倍
	local oldget = weapon.GetDamage
	weapon._yellowgem_old_getdamage = oldget
	weapon.GetDamage = function(self, attacker, target)
		local dmg, spdmg = oldget(self, attacker, target)
		return dmg * YellowGem.LUNGE_DMG_MULT,
			ScaleSpDamage(spdmg, YellowGem.LUNGE_DMG_MULT)
	end

	-- 兜底：这一下没走到 onhit 也要还原，避免倍率泄漏到普通攻击
	inst._yellowgem_dmg_task = inst:DoTaskInTime(0, function(i)
		i._yellowgem_dmg_task = nil
		EndDoubleDamage(i)
	end)
end

function HookLunge(inst)
	if not TheWorld.ismastersim then
		return
	end

	local lunge = inst.components.aoeweapon_lunge
	if lunge == nil or lunge._yellowgem_hooked then
		return
	end
	lunge._yellowgem_hooked = true

	local oldprehit = lunge.onprehitfn
	lunge.onprehitfn = function(i, doer, target)
		if oldprehit ~= nil then
			oldprehit(i, doer, target)
		end
		if IsAttuned(i) then
			-- 必须在 DoAttack 之前生效
			BeginDoubleDamage(i)
		end
		if IsAttuned(i) and target ~= nil and target:IsValid() then
			-- 同一次冲刺会命中多个目标 / 可能连击同一个目标，
			-- 已经有未还原的任务时保留最初的值，避免把 2.4 当成"原值"存回去。
			if target._yellowgem_stun_task == nil then
				target._yellowgem_prev_stun = target.electrocute_duration
			end
			target.electrocute_duration = YellowGem.STUN

			-- 3 帧足够覆盖受击事件的延迟，又不会明显影响别的电击来源
			target._yellowgem_stun_task = target:DoTaskInTime(3 * FRAMES, function(t)
				t._yellowgem_stun_task = nil
				t.electrocute_duration = t._yellowgem_prev_stun
				t._yellowgem_prev_stun = nil
			end)
		end
	end

	local oldhit = lunge.onhitfn
	lunge.onhitfn = function(i, doer, target)
		-- 这一下的伤害已经结算完了，先还原倍率，避免影响后面的逻辑
		EndDoubleDamage(i)
		if oldhit ~= nil then
			oldhit(i, doer, target)
		end
		if IsAttuned(i) and target ~= nil and target:IsValid() then
			-- 等受击事件处理完（约 2 帧）再确认是否真的进了电击状态；
			-- sg.timeout 是「状态内绝对时间」，所以这里设置 2.4 仍然是
			-- 进入电击状态后总共 2.4 秒。
			target:DoTaskInTime(3 * FRAMES, function(t)
				if t:IsValid() and t.sg ~= nil and t.sg:HasStateTag("electrocute") then
					-- sg:SetTimeout 是相对当前状态时间算的
					local left = (t.sg.timeout or 0) - (t.sg.timeinstate or 0)
					if left < YellowGem.STUN then
						t.sg:SetTimeout(YellowGem.STUN)
						if not i._yellowgem_stun_diag then
							i._yellowgem_stun_diag = true
							print("[黄宝石] 冲刺电击僵直已生效：" .. YellowGem.STUN .. "s")
						end
					end
				end
			end)
		end
	end

	-- 没打中（敲树、目标刚好消失等）也要还原伤害倍率
	local oldmiss = lunge.onmissfn
	lunge.onmissfn = function(i, doer, target)
		EndDoubleDamage(i)
		if oldmiss ~= nil then
			oldmiss(i, doer, target)
		end
	end
end

--------------------------------------------------------------------------
-- 存档 / 读档
--
-- 与绿宝石一致：链式包装旧的 OnSave / OnLoad，并用幂等标记避免重复包装。
--------------------------------------------------------------------------
local function SetupPersist(inst)
	if not TheWorld.ismastersim then
		return
	end

	if inst._yellowgem_persist then
		return
	end
	inst._yellowgem_persist = true

	local oldOnSave = inst.OnSave
	inst.OnSave = function(i, data)
		-- EntityScript.OnSave 的返回值是 references（GUID 列表），不是数据表，
		-- 数据必须原地写进传进来的 data。
		data = data or {}
		local refs = oldOnSave ~= nil and oldOnSave(i, data) or nil
		if refs == data then
			refs = nil
		end
		if (i._yellowgem_count or 0) > 0 and i._yellowgem_expire ~= nil then
			local remaining = i._yellowgem_expire - GetTime()
			if remaining > 0 then
				data.yellowgem_count = i._yellowgem_count
				-- 存剩余秒数，不要存绝对时间戳（见 StartExpireTimer 的说明）
				data.yellowgem_remaining = remaining
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

		local remaining = data.yellowgem_remaining
		if remaining == nil then
			-- 更老的存档存的是绝对时间戳，跨进程不可信，按满时长恢复一次
			remaining = data.yellowgem_expire ~= nil and YellowGem.DURATION or nil
		end
		if remaining == nil or remaining <= 0 then
			return
		end
		remaining = math.min(remaining, YellowGem.DURATION)

		i._yellowgem_count = data.yellowgem_count or 1
		MarkAttuned(i)
		StartExpireTimer(i, remaining)
	end
end

--------------------------------------------------------------------------
-- 升级成充能矛时继承改造状态
--
-- 本体 Lightning_OnUpgraded 会 SpawnPrefab 一把新矛再把旧矛 Remove，
-- 新矛不会带上旧矛的运行时字段，所以用一个模块级临时值接力。
--------------------------------------------------------------------------
local pending = nil

local function SetupUpgradeInherit(inst)
	local upgradeable = inst.components.upgradeable
	if upgradeable == nil or upgradeable.onupgradefn == nil then
		return
	end

	if inst._yellowgem_upgrade_inherit then
		return
	end
	inst._yellowgem_upgrade_inherit = true

	local oldOnUpgrade = upgradeable.onupgradefn
	upgradeable.onupgradefn = function(i, upgrader, item)
		pending = (i._yellowgem_count ~= nil and i._yellowgem_expire ~= nil)
			and { count = i._yellowgem_count, expire = i._yellowgem_expire }
			or nil
		local a, b, c = oldOnUpgrade(i, upgrader, item)
		pending = nil
		return a, b, c
	end
end

--------------------------------------------------------------------------
-- 使用黄宝石
--------------------------------------------------------------------------
local function OnUseYellowGem(gem, target, doer)
	if target == nil or not target:IsValid() or not IsEligibleTarget(target) then
		return false
	end

	-- 每把武器只允许吸收一颗
	if IsAttuned(target) then
		return false, "YELLOWGEM_ALREADY_USED"
	end

	target._yellowgem_count = 1
	MarkAttuned(target)
	StartExpireTimer(target, YellowGem.DURATION)

	-- 消耗一颗（黄宝石可堆叠）
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
function YellowGem.Setup()
	local function SetupSpear(inst)
		-- 双端都要有标签（服务端判定），net 做客户端镜像
		inst:AddTag(YellowGem.TAG_TARGETABLE)
		EnsureAttunedNet(inst)
		EnsureExpireNet(inst)
		SetupFallbackName(inst)

		if not TheWorld.ismastersim then
			return
		end

		HookLunge(inst)
		SetupPersist(inst)
		SetupUpgradeInherit(inst)

		-- 刚由普通矛升级而来的充能矛：接力改造状态与剩余时间
		if pending ~= nil then
			local remaining = pending.expire - GetTime()
			if remaining > 0 then
				inst._yellowgem_count = pending.count
				MarkAttuned(inst)
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

	-- 黄宝石：挂 useabletargeteditem，纯标签判断有效目标
	AddPrefabPostInit("yellowgem", function(inst)
		if inst.components.useabletargeteditem == nil then
			inst:AddComponent("useabletargeteditem")
		end

		-- componentactions 是点号调用（target, doer），
		-- componentutil 的 socket 包装是冒号调用（self, target, doer），
		-- 两个位置都查一遍，避免签名错位。
		inst.UseableTargetedItem_ValidTarget = function(a, b)
			return IsUsableTarget(a) or IsUsableTarget(b)
		end

		if not TheWorld.ismastersim then
			return
		end

		inst.components.useabletargeteditem:SetOnUseFn(OnUseYellowGem)
	end)
end

--------------------------------------------------------------------------
-- 供外部查询剩余时间
--
-- net 里是「同步那一刻的剩余秒数」，用本地 GetTime() 相对基准倒数，
-- 服务端和客户端各自计时都不会串。
--------------------------------------------------------------------------
function YellowGem.GetRemaining(inst)
	if inst == nil then
		return 0
	end
	local net = inst._yellowgem_expire_net
	local secs = net ~= nil and net:value() or 0
	if secs == nil or secs <= 0 then
		return 0
	end
	local remaining = secs - (GetTime() - (inst._yellowgem_net_base or GetTime()))
	if remaining <= 0 then
		return 0
	end
	return math.min(remaining, YellowGem.DURATION)
end

return YellowGem
