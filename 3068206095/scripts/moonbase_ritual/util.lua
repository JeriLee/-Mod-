-- 月台仪式 · 公共判断函数
-- 这些函数被多个模块复用，统一放这里避免循环依赖。
--
-- 注意：本文件是 require 进来的普通模块，默认 _G 带 strict，
-- 引擎接口必须显式从 GLOBAL 取（见 genv.lua）。

local G = require("moonbase_ritual/genv")
local Config = require("moonbase_ritual/config")

local TUNING = G.Get("TUNING")

local Util = {}

-- 是否为奔雷矛（普通形态或充能形态）
function Util.IsSpear(item)
	return item ~= nil and (item.prefab == Config.SPEAR or item.prefab == Config.SPEAR_CHARGED)
end

-- 月台是否完好（未被砸坏到无法使用）
function Util.MoonIsFixed(inst)
	local w = inst.components.workable
	return w ~= nil and (w.workleft or 0) > TUNING.MOONBASE_DAMAGED_WORK
end

-- 月台上是否插着矛
function Util.MoonHasSpear(inst)
	return inst._thunderspear ~= nil
end

--------------------------------------------------------------------------
-- 把皮肤名转换成与 prefab 相匹配的皮肤名
--
-- 充能奔雷矛的皮肤 prefab 是 "spear_wathgrithr_lightning_charged_xxx"，
-- 它的 init_fn（prefabskin.lua 的 spear_wathgrithr_lightning_charged_init_fn）
-- 会调用 inst:SetFxOwner()，而这个方法只有充能形态的 prefab 才有。
--
-- 如果拿普通形态的 prefab 去套充能形态的皮肤，初始化时会直接崩：
--   attempt to call method 'SetFxOwner' (a nil value)
--
-- 所以 prefab 一旦变成普通形态，皮肤名必须同步去掉 "_charged"，
-- 换成对应的普通皮肤。这与原版升级时用 GetSkinBuild() 的做法一致
-- （原版 GetBuildForItem 对充能皮肤返回的也是普通皮肤的 build 名）。
--------------------------------------------------------------------------
function Util.MatchSkin(prefab, skinname)
	if skinname == nil or skinname == "" then
		return nil
	end
	if prefab == Config.SPEAR and string.find(skinname, "_charged", 1, true) ~= nil then
		return (string.gsub(skinname, "_charged", ""))
	end
	return skinname
end

-- 根据月台 workable.workleft 推算外观状态
function Util.GetMoonState(inst)
	local wl = inst.components.workable ~= nil and inst.components.workable.workleft or 0
	if wl > TUNING.MOONBASE_DAMAGED_WORK then
		return "full"
	elseif wl * 2 > TUNING.MOONBASE_DAMAGED_WORK then
		return "med"
	elseif wl > 0 then
		return "medlow"
	end
	return "low"
end

return Util
