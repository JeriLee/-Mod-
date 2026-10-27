-- 奔雷矛 · Insight 描述扩展
--
-- 参考 Insight（workshop 2189004162）的写法：
--   scripts/prefab_descriptors/*.lua 里
--       return { Describe = function(inst, context) ... end }
--   对外注册入口是 Insight.API.V1.AddPrefabDescriptor(name, descriptor, { modname = "..." })
--   （见 A2189004162/modmain.lua:993-1032，_G.Insight 在 modmain 顶部就已导出）
--
-- 本文件只做一件事：当武器上还有绿宝石强化时，在 Insight 的悬浮信息里
-- 多加一行「绿宝石 剩余时间/总时长」。
--
-- 剩余时间来自 greengem.lua 用 net_int 同步的到期时间戳，
-- 两端都能算，客户端不需要额外数据。

local G = require("shared/genv")
local Shared = require("shared/weapon")
local GreenGem = require("lightning_spear/greengem")

local AddSimPostInit = G.Get("AddSimPostInit")
local AddPlayerPostInit = G.Get("AddPlayerPostInit")

local InsightDesc = {}

-- Insight 的 metadata.modname 只用于标识来源
local MODNAME = "3068206095"
local LINE_NAME = "greengem_attunement"

--------------------------------------------------------------------------
-- 时间格式化
--
-- 优先用 Insight 自己的 context.time:SimpleProcess（输出与游戏内一致的时间写法，
-- 例如 "4分12秒"）；拿不到就退回整秒。
--------------------------------------------------------------------------
local function FormatDuration(context, seconds)
	if context ~= nil and context.time ~= nil
		and type(context.time.SimpleProcess) == "function" then
		local ok, text = pcall(context.time.SimpleProcess, context.time, seconds)
		if ok and text ~= nil then
			return tostring(text)
		end
	end
	return string.format("%d", math.floor(seconds + 0.5))
end

--------------------------------------------------------------------------
-- 描述本体
--
-- 返回 nil 表示不显示这一行（没有绿宝石强化时）。
--------------------------------------------------------------------------
local function Describe(inst, context)
	local remaining = GreenGem.GetRemaining(inst)
	if remaining <= 0 then
		return
	end

	return {
		name = LINE_NAME,
		-- Insight 的 SortDescriptors 是 priority 越大越靠前
		priority = 20,
		description = string.format("绿宝石 %s/%s",
			FormatDuration(context, remaining),
			FormatDuration(context, GreenGem.DURATION)),
	}
end

--------------------------------------------------------------------------
-- 注册
--
-- 注意时机：本模组可能比 Insight 先加载，所以先同步试一次，
-- 失败再挂到 AddSimPostInit 上重试（此时所有 modmain 都已执行完）。
--------------------------------------------------------------------------
local registered = false

function InsightDesc.Register()
	if registered then
		return true
	end

	local Insight = G.Global("Insight")
	if Insight == nil or Insight.API == nil or Insight.API.V1 == nil then
		return false
	end

	local add = Insight.API.V1.AddPrefabDescriptor
	if type(add) ~= "function" then
		return false
	end

	-- 不要用 Insight.prefab_descriptors[name] 做存在性检查：
	-- 那张表带 __index 元表，读未知名字会去 import 并缓存一个占位描述。
	add(Shared.SPEAR_CHARGED, { Describe = Describe }, { modname = MODNAME })

	-- 告诉 greengem：悬浮行已接管，名字里不必再重复拼一遍
	GreenGem.InsightRegistered = true

	registered = true
	return true
end

function InsightDesc.Setup()
	if InsightDesc.Register() then
		return
	end

	-- Insight 后加载时兜底重试；两个钩子都挂上，覆盖客户端/服务端不同时机
	AddSimPostInit(function()
		InsightDesc.Register()
	end)
	AddPlayerPostInit(function()
		InsightDesc.Register()
	end)
end

return InsightDesc
