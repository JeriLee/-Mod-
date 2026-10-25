-- 月台仪式 · 引擎接口桥接
--
-- 背景（为什么需要这一层）：
--   modmain.lua 运行在 DST 的 mod 环境 env 里，它带有两层能力：
--     1. env 上的 mod API   -> AddAction / AddComponentAction /
--                              AddPrefabPostInit / AddStategraphActionHandler /
--                              GetModConfigData（由 scripts/modutil.lua 挂上）
--     2. env 的 __index 元表 -> 回退到 GLOBAL(_G)，能取到 TheWorld / TUNING /
--                              SpawnPrefab / ACTIONS / STRINGS ...
--
--   但 require 加载的普通模块运行在默认 _G 上，而 DST 的 _G 开启 strict：
--   访问任何未声明的变量都会报 "variable 'xxx' is not declared"，
--   连 env / GLOBAL 这两个名字本身也不例外。
--
-- 接口分两类，处理方式不同：
--   A. 加载期接口（mod API + 静态全局）——modmain 加载时即可用，
--      由 modmain 一次性抓取后塞进来，模块用 G.Get / G.Many 取。
--   B. 运行时全局（TheWorld / SpawnPrefab 等）——只有进入世界、
--      世界实体创建之后才被赋值。modmain 加载时它们还是 nil，
--      所以不能预抓取，必须每次用 G.Global() 实时从 GLOBAL 里取。
--
-- 用法：
--   -- modmain.lua（顺序不能改）
--   require("shared/genv").Init(GLOBAL, {
--       AddAction                  = AddAction,
--       AddComponentAction         = AddComponentAction,
--       AddStategraphActionHandler = AddStategraphActionHandler,
--       AddPrefabPostInit          = AddPrefabPostInit,
--       GetModConfigData           = GetModConfigData,
--       ActionHandler              = ActionHandler,
--       TUNING                     = TUNING,
--       net_bool                   = net_bool,
--       ACTIONS                    = ACTIONS,
--       STRINGS                    = STRINGS,
--       FindEntity                 = FindEntity,
--   })
--   require("moonbase_ritual/init").Setup()
--
--   -- 任意模块
--   local G = require("shared/genv")
--   local TUNING = G.Get("TUNING")                 -- 加载期接口
--   local TheWorld = G.Global("TheWorld")          -- 运行时全局（实时取）

local G = {}

-- 已抓取的加载期接口表，由 modmain 注入
local api = nil

-- 引擎 _G 表，由 modmain 注入，用于实时取运行时全局
local global = nil

function G.Init(global_table, api_table)
	global = global_table
	api = api_table or {}
end

local function EnsureAPI()
	if api == nil then
		error("shared/genv: Init 未调用，请检查 modmain.lua 的加载顺序")
	end
	return api
end

local function EnsureGlobal()
	if global == nil then
		error("shared/genv: Init 未注入 GLOBAL，请检查 modmain.lua 的加载顺序")
	end
	return global
end

-- 取单个加载期接口（从预抓取的 api 表里拿）
function G.Get(name)
	return EnsureAPI()[name]
end

-- 批量取出加载期接口（最多支持 4 个）
function G.Many(...)
	local t = EnsureAPI()
	local names = { ... }
	local n = #names

	if n == 0 then
		return
	elseif n == 1 then
		return t[names[1]]
	elseif n == 2 then
		return t[names[1]], t[names[2]]
	elseif n == 3 then
		return t[names[1]], t[names[2]], t[names[3]]
	else
		return t[names[1]], t[names[2]], t[names[3]], t[names[4]]
	end
end

-- 实时从 GLOBAL 取一个运行时全局（TheWorld / SpawnPrefab 等）
-- 每次调用都会重新索引，保证拿到进入世界后的最新值。
function G.Global(name)
	return EnsureGlobal()[name]
end

-- 懒解析代理：返回一个表，任何索引/调用都会实时从 GLOBAL 重新取值。
-- 适用于 TheWorld / SpawnPrefab 这类"进入世界后才存在"的运行时全局：
--   local TheWorld    = G.Lazy("TheWorld")
--   local SpawnPrefab = G.Lazy("SpawnPrefab")
--   if TheWorld.ismastersim then ... end   -- 实时取 GLOBAL.TheWorld.ismastersim
--   SpawnPrefab("x")                        -- 实时取 GLOBAL.SpawnPrefab 并调用
local function resolve(name)
	return EnsureGlobal()[name]
end

function G.Lazy(name)
	return setmetatable({}, {
		__index = function(_, key)
			local v = resolve(name)
			if type(v) == "table" then
				return v[key]
			end
			return nil
		end,
		__call = function(_, ...)
			local v = resolve(name)
			if type(v) == "function" then
				return v(...)
			end
			error("shared/genv: GLOBAL." .. tostring(name) .. " 不可调用", 2)
		end,
	})
end

return G
