-- 古铸 · 公共判断函数
--
-- 注意：本文件是 require 进来的普通模块，默认 _G 带 strict，
-- 引擎接口必须显式从 GLOBAL 取（见 shared/genv.lua）。

local Shared = require("shared/weapon")

local Util = {}

-- 按 prefab 名判断是否为奔雷矛（含皮肤、含充能形态）
function Util.IsSpearPrefab(prefab)
	if prefab == nil then
		return false
	end
	if prefab == Shared.SPEAR or prefab == Shared.SPEAR_CHARGED then
		return true
	end
	for _, skin in ipairs(Shared.SPEAR_SKINS) do
		if prefab == Shared.SPEAR .. "_" .. skin
			or prefab == Shared.SPEAR_CHARGED .. "_" .. skin then
			return true
		end
	end
	return false
end

return Util
