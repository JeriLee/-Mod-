-- 月台仪式 · 把逻辑挂到原版 moonbase 上
-- 包括：net 变量、trader 接受/收取、workable 受击处理。
-- 充能流程与存档在 moonbase_charge.lua，这里只做"接线"。
--
-- 注意：本文件是 require 进来的普通模块，引擎接口从 GLOBAL 取。

local G = require("shared/genv")
local Util = require("moonbase_ritual/util")
local MoonIO = require("moonbase_ritual/moonbase_io")
local MoonAnim = require("moonbase_ritual/moonbase_anim")

local TheWorld = G.Lazy("TheWorld")
local net_bool = G.Get("net_bool")

local MoonBind = {}

--------------------------------------------------------------------------
-- 让月台接受奔雷矛（覆盖 trader 的接受/收取回调）
--------------------------------------------------------------------------
local function HookTrader(inst)
	if inst.components.trader == nil then
		return
	end

	local oldAbleToAccept = inst.components.trader.abletoaccepttest
	inst.components.trader.abletoaccepttest = function(target, item, giver, count)
		-- 已经插着矛就不能再插
		if Util.MoonHasSpear(target) then
			return false, "NOTSTAFF"
		end

		if Util.IsSpear(item) then
			if Util.MoonIsFixed(target) then
				return true
			end
			return false, "NOTSTAFF"
		end

		if oldAbleToAccept ~= nil then
			return oldAbleToAccept(target, item, giver, count)
		end
		return true
	end

	local oldOnAccept = inst.components.trader.onaccept
	inst.components.trader.onaccept = function(target, giver, item, count)
		if Util.IsSpear(item) then
			if MoonIO.Insert(target, item) then
				item:Remove()
			end
			return
		end

		if oldOnAccept ~= nil then
			oldOnAccept(target, giver, item, count)
		end
	end
end

--------------------------------------------------------------------------
-- 接管月台被攻击的处理
--------------------------------------------------------------------------
local function HookWorkable(inst)
	if inst.components.workable == nil then
		return
	end

	local oldOnWork = inst.components.workable.onwork

	inst.components.workable:SetOnWorkCallback(function(i, worker, workleft, numworks)
		-- 没插着矛：完全交还原版逻辑
		if not Util.MoonHasSpear(i) then
			if oldOnWork ~= nil then
				oldOnWork(i, worker, workleft, numworks)
			end
			return
		end

		if workleft <= 0 then
			-- 完全碎裂：先走原版（触发损毁），再把武器弹出
			if oldOnWork ~= nil then
				oldOnWork(i, worker, workleft, numworks)
			end
			MoonIO.Expel(i)
		else
			-- 未碎裂，播放对应损坏程度的碎裂动画
			MoonAnim.PlayHit(i)
		end
	end)
end

--------------------------------------------------------------------------
-- 主入口：在 moonbase 的 AddPrefabPostInit 中调用
--------------------------------------------------------------------------
function MoonBind.Setup(inst)
	-- 同步"插着矛"状态（net 变量，客户端与服务端都要建）
	if inst._thunderspear_net == nil then
		inst._thunderspear_net = net_bool(inst.GUID, "moonbase._thunderspear",
			"thunderspeardirty")
	end

	-- 以下是纯服务端逻辑
	if not TheWorld.ismastersim then
		return
	end

	HookTrader(inst)
	HookWorkable(inst)
end

return MoonBind
