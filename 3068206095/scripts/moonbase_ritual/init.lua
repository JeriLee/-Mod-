-- 月台仪式 · 统一装配入口
--
-- 目录结构：
--   genv.lua             引擎全局变量桥接（模块里访问 GLOBAL 用）
--   config.lua           常量与模组配置
--   util.lua             公共判断（IsSpear / MoonIsFixed / MoonHasSpear / GetMoonState）
--   fx_star.lua          升级完成光球特效
--   fx_symbol.lua        月台上插矛的贴图覆盖
--   fx_charge.lua        充能光柱 / 脉冲 / 泛光特效
--   beam_tint.lua        光柱染色（两端各自执行）
--   moonforged.lua       「月淬」状态效果（暗影增伤 / 夜修 / 解锁装备 / 存档持久化）
--   moonbase_io.lua      插入 / 取下 / 弹出 / 喂碎片
--   moonbase_anim.lua    插矛时月台受击动画
--   moonbase_charge.lua  月圆充能流程与月台存档
--   moonbase_actions.lua 自定义交互动作
--   moonbase_bind.lua    把逻辑挂到原版 moonbase 上（trader / workable / net）
--
-- 只在 modmain 里 require 本文件并调用 Setup() 即可。
--
-- 注意：本文件是 require 进来的普通模块，引擎接口从 GLOBAL 取。

local G = require("moonbase_ritual/genv")
local Config = require("moonbase_ritual/config")
local Moonforged = require("moonbase_ritual/moonforged")
local MoonBind = require("moonbase_ritual/moonbase_bind")
local MoonCharge = require("moonbase_ritual/moonbase_charge")
local MoonActions = require("moonbase_ritual/moonbase_actions")
local BeamTint = require("moonbase_ritual/beam_tint")

local AddPrefabPostInit = G.Get("AddPrefabPostInit")
local TheWorld = G.Lazy("TheWorld")

local MoonbaseRitual = {}

--------------------------------------------------------------------------
-- 给奔雷矛（含各皮肤）和充能矛挂上能力
--------------------------------------------------------------------------
local function SetupSpearPrefabs()
	-- 普通奔雷矛（含皮肤）：可拖到月台 + moon 标签持久化 + 月淬改名
	local function SetupNormalSpear(inst)
		-- 先挂 net 变量与改名逻辑（客户端服务端都要执行）
		Moonforged.SetupName(inst)
		Moonforged.MakeTradable(inst)
		Moonforged.SetupPersist(inst)
	end

	AddPrefabPostInit(Config.SPEAR, SetupNormalSpear)
	for _, skin in ipairs(Config.SPEAR_SKINS) do
		AddPrefabPostInit(Config.SPEAR .. "_" .. skin, SetupNormalSpear)
	end

	-- 充能矛（含皮肤）：可拖到月台 + 解锁装备 + 夜修 + moon 标签持久化 + 月淬改名
	local function SetupCharged(inst)
		-- 先挂 net 变量与改名逻辑（客户端服务端都要执行）
		Moonforged.SetupName(inst)
		Moonforged.MakeTradable(inst)
		Moonforged.SetupChargedSpear(inst)
		-- 必须也要持久化：否则读档后 moon 标签丢失，
		-- Apply 不会被调用，暗影增伤 / 夜修 / 改名 / 解锁 全部失效
		Moonforged.SetupPersist(inst)
	end

	AddPrefabPostInit(Config.SPEAR_CHARGED, SetupCharged)
	for _, skin in ipairs(Config.SPEAR_SKINS) do
		AddPrefabPostInit(Config.SPEAR_CHARGED .. "_" .. skin, SetupCharged)
	end
end

--------------------------------------------------------------------------
-- 装配全部内容
--------------------------------------------------------------------------
function MoonbaseRitual.Setup()
	if not Config.ENABLE then
		return
	end

	-- 1) 动作与输入
	MoonActions.Register()

	-- 2) 月台本体：net 变量 / trader / workable / 充能流程
	AddPrefabPostInit("moonbase", function(inst)
		MoonBind.Setup(inst)
		if TheWorld.ismastersim then
			MoonCharge.Setup(inst)
		end
	end)

	-- 3) 武器侧能力
	SetupSpearPrefabs()

	-- 4) 充能光柱染色
	BeamTint.Register()
end

return MoonbaseRitual
