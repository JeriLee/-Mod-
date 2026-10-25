-- 古铸 · 统一装配入口
--
-- 目录结构（scripts/ancient_cast/）：
--   config.lua              常量与模组配置
--   util.lua                公共判断（按 prefab 名识别奔雷矛）
--   ancientcast.lua         「古铸」状态效果（免疫蜂后减速 / 改名 / 存档持久化）
--   ancient_altar_actions.lua  远古伪科学站「古铸」交互动作
--
-- 另外，承载组件动作的空组件放在 scripts/components/ancientcaster.lua
-- （引擎的 LoadComponent 只会去 components 目录找）。
--
-- 只在 modmain 里 require 本文件并调用 Setup() 即可。
--
-- 注意：本文件是 require 进来的普通模块，引擎接口从 GLOBAL 取。

local G = require("shared/genv")
local Config = require("ancient_cast/config")
local Shared = require("shared/weapon")
local Ancientcast = require("ancient_cast/ancientcast")
local AltarActions = require("ancient_cast/ancient_altar_actions")

local AddPrefabPostInit = G.Get("AddPrefabPostInit")

local AncientCast = {}

--------------------------------------------------------------------------
-- 给奔雷矛（含各皮肤）和充能矛挂上古铸能力
--
-- 说明：古铸与月台仪式是两条独立的路线，但改的是同一把矛，
-- 所以这里也会挂 displaynamefn。两边各套一层 displaynamefn 没问题：
-- 先套的在内层、后套的在外层，显示时先问外层，外层没有再问内层。
--------------------------------------------------------------------------
local function SetupSpearPrefabs()
	local function SetupSpear(inst)
		-- 改名 + 存档持久化 + 免疫蜂后减速监听（客户端服务端都要执行）
		Ancientcast.SetupName(inst)
		Ancientcast.SetupPersist(inst)
		Ancientcast.SetupBeequeenImmune(inst)
	end

	-- 充能矛：补一个 batteryuser 组件
	--
	-- 「古铸」的组件动作挂在 batteryuser 上（见 ancient_altar_actions.lua），
	-- 因为这是模组已经验证过"客户端服务端都注册成功"的组件
	-- （普通奔雷矛的 batteryuser 由 lightning_spear/lightningrod.lua 挂上）。
	--
	-- 充能矛本身不参与"避雷针充能"这条路线，所以挂上组件后
	-- 要把 "batteryuser" 标签去掉：
	--   本体的 USEITEM/EQUIPPED 收集器靠这个标签判断
	--   （inst:HasTag("batteryuser")），
	--   去掉标签后本体不会对充能矛显示"充能"动作，
	--   而模组的组件动作是按"组件"注册的，不受影响，照样能显示"古铸"。
	local function SetupChargedSpear(inst)
		if inst.components.batteryuser == nil then
			inst:AddComponent("batteryuser")
		end
		inst:RemoveTag("batteryuser")

		SetupSpear(inst)
	end

	AddPrefabPostInit(Shared.SPEAR, SetupSpear)
	for _, skin in ipairs(Shared.SPEAR_SKINS) do
		AddPrefabPostInit(Shared.SPEAR .. "_" .. skin, SetupSpear)
	end

	AddPrefabPostInit(Shared.SPEAR_CHARGED, SetupChargedSpear)
	for _, skin in ipairs(Shared.SPEAR_SKINS) do
		AddPrefabPostInit(Shared.SPEAR_CHARGED .. "_" .. skin, SetupChargedSpear)
	end
end

--------------------------------------------------------------------------
-- 装配全部内容
--------------------------------------------------------------------------
function AncientCast.Setup()
	if not Config.ENABLE then
		return
	end

	-- 1) 交互动作
	--
	-- 注意：AddComponentAction 的注册顺序在客户端与服务端必须完全一致，
	-- 因为模组的组件动作是靠"注册顺序"生成 id 再同步过去的。
	-- 本模块注册 "ancientcaster"（EQUIPPED / USEITEM）与 "workable"（SCENE），
	-- 与月台仪式的 "inspectable"（SCENE）互不冲突。
	AltarActions.Register()

	-- 2) 武器侧能力
	SetupSpearPrefabs()
end

return AncientCast