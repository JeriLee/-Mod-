-- 月台仪式 · 自定义交互动作
--
-- 空手点击插着矛的月台 -> 取下武器。
--
-- 月台自身的"修理"交给本体逻辑：本体月台用「月岩（moonrocknugget）」
-- 修理（repairable 组件 + repairer 组件 + ACTIONS.REPAIR），
-- 本模组不再介入修理，避免与本体月岩修理冲突。
--
-- 动作 ID 沿用历史上的 WIGFRIDARMOR_MOONREPAIR 命名，
-- 避免已经发布的版本在存档 / 客户端缓存中失效。
--
-- 注意：本文件是 require 进来的普通模块，默认 _G 带 strict，
-- 引擎接口必须显式从 GLOBAL 取（见 genv.lua）。

local G = require("shared/genv")
local Util = require("moonbase_ritual/util")
local MoonIO = require("moonbase_ritual/moonbase_io")

local AddAction, AddComponentAction, AddStategraphActionHandler, ActionHandler =
	G.Many("AddAction", "AddComponentAction", "AddStategraphActionHandler", "ActionHandler")

local ACTIONS = G.Get("ACTIONS")
local STRINGS = G.Get("STRINGS")
local TheWorld = G.Lazy("TheWorld")

local MoonActions = {}

local ACTION_ID = "WIGFRIDARMOR_MOONREPAIR"

function MoonActions.Register()
	local ACT = AddAction(ACTION_ID, "使用", function(act)
		local doer = act.doer
		local target = act.target

		if doer == nil or target == nil or not target:IsValid() then
			return false
		end

		-- 客户端只做预测，真实逻辑在服务端
		if not TheWorld.ismastersim then
			return true
		end

		-- 插着矛且空手 -> 取下
		if act.invobject == nil and Util.MoonHasSpear(target) then
			local item = MoonIO.TakeOut(target)
			if item ~= nil and doer.components.inventory ~= nil then
				doer.components.inventory:GiveItem(item, nil, target:GetPosition())
				return true
			end
		end
		return false
	end)

	ACT.mount_valid = true
	ACT.distance = 2
	ACT.priority = 1

	STRINGS.ACTIONS[ACTION_ID] = "使用"
	STRINGS.ACTIONS[ACTION_ID .. "_GENERIC"] = "使用"

	-- SCENE 类型：空手取下
	AddComponentAction("SCENE", "inspectable", function(inst, doer, actions, right)
		if right or doer == nil or doer.replica == nil or doer.replica.inventory == nil then
			return
		end
		if not inst:HasTag("moonbase") then
			return
		end

		-- 插着矛（客户端看 net 变量）-> 可取下
		local has_spear = inst._thunderspear_net ~= nil
			and inst._thunderspear_net:value() or false
		if has_spear then
			table.insert(actions, ACTIONS[ACTION_ID])
			return
		end
	end)

	AddStategraphActionHandler("wilson", ActionHandler(ACTIONS[ACTION_ID], "dolongaction"))
	AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS[ACTION_ID], "dolongaction"))
end

return MoonActions
