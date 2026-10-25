GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})  --GLOBAL相关照抄


PrefabFiles = {
}

Assets = {
}

-- 月淬状态用 "moon" 标签标记，不再单独做一个 prefab
-- 名字见 scripts/moonbase_ritual/config.lua 的 Config.MOONFORGED_NAME
STRINGS.NAMES.SPEAR_MOONFORGED = "月萃奔雷矛"
STRINGS.RECIPE_DESC.SPEAR_MOONFORGED = "被月光淬炼过的奔雷矛，对暗影生物有额外伤害，夜里会缓慢恢复耐久"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.SPEAR_MOONFORGED = "月光淬炼的战矛。"

STRINGS.NAMES.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_MOONFORGED = "月萃充能奔雷矛"
STRINGS.RECIPE_DESC.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_MOONFORGED = "被月光淬炼过的充能奔雷矛，对暗影生物有额外伤害，夜里会缓慢恢复耐久"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_MOONFORGED = "月光淬炼的充能战矛。"


--------------------------------------------------------------------------
-- 奔雷矛 · 月台充能
-- 具体实现按职责拆分在 scripts/moonbase_ritual/ 目录下，见该目录 init.lua
--
-- 注意：require 进来的模块默认 _G 带 strict，无法直接访问 env / GLOBAL。
-- 所以这里在 modmain 自己的作用域里（AddAction / TheWorld / GLOBAL 都是
-- 确定可用的）把模块需要的接口一次性抓取出来，交给 genv 桥接表。
-- 模块里只从 genv 取值，绝不二次解析，避免 require 缓存/元表顺序等坑。
--
-- 顺序不能改：Init 必须早于任何 require("moonbase_ritual/...")。
--------------------------------------------------------------------------
require("moonbase_ritual/genv").Init(GLOBAL, {
	AddAction                  = AddAction,
	AddComponentAction         = AddComponentAction,
	AddStategraphActionHandler = AddStategraphActionHandler,
	AddPrefabPostInit          = AddPrefabPostInit,
	GetModConfigData           = GetModConfigData,
	ActionHandler              = ActionHandler,
	TUNING                     = TUNING,
	net_bool                   = net_bool,
	net_shortint               = net_shortint,
	ACTIONS                    = ACTIONS,
	STRINGS                    = STRINGS,
	FindEntity                 = FindEntity,
	SpawnElectricHitSparks     = SpawnElectricHitSparks,
	Class                      = Class,
	EQUIPSLOTS                 = EQUIPSLOTS,
	GetInventoryItemAtlas      = GetInventoryItemAtlas,
	AddPlayerPostInit          = AddPlayerPostInit,
	AddSimPostInit             = AddSimPostInit,
})
require("moonbase_ritual/init").Setup()

--------------------------------------------------------------------------
-- 奔雷矛 · 避雷针充能
-- 手持普通奔雷矛右键带电避雷针，参考机器人（WX-78）的充能流程：
-- 同样的动作与动画，但不给玩家个人属性提升，改为强化武器本身
-- （耐久 +30%、伤害 +20%，持续一天）。
-- 实现见 scripts/lightning_spear/lightningrod.lua
--------------------------------------------------------------------------
require("lightning_spear/lightningrod").Setup()

--------------------------------------------------------------------------
-- 雷萃状态的 HUD 指示器（图标 + 倒计时）
--
-- 客户端进入世界时 HUD / ThePlayer 可能都还没就绪，
-- 所以 hud 模块内部注册了多个入口（玩家实体 / 世界开始 / 立即尝试）
-- 并带定时重试，只要有一个能跑起来就会挂上。
--------------------------------------------------------------------------
require("lightning_spear/hud").Start()
