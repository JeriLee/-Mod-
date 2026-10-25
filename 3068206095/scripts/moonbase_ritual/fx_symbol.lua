-- 月台仪式 · 月台上插着的矛的贴图覆盖
-- 把月台 AnimState 的 swap_staffs 槽位覆盖成奔雷矛的贴图。
--   - 有皮肤：用 OverrideItemSkinSymbol（皮肤 build + 默认 build 兜底）
--   - 无皮肤：用 OverrideSymbol（默认 build）
-- 参考 scripts/prefabs/spear_wathgrithr.lua 的 OnEquip 写法。
--
-- 注意：本文件是 require 进来的普通模块，仅操作 AnimState，不需要引擎全局。

local Config = require("moonbase_ritual/config")

local FxSymbol = {}

function FxSymbol.Apply(inst)
	local proxy = inst._staffinst

	-- 注：月淬奔雷矛的自定义外观资源已归档到仓库根目录 Arts/，
	-- 不再随模组发布，这里统一复用基础奔雷矛的 build/symbol。
	local skin_build = nil
	if proxy ~= nil and proxy:IsValid() and proxy.GetSkinBuild ~= nil then
		skin_build = proxy:GetSkinBuild()
		if skin_build == "" then
			skin_build = nil
		end
	end

	if skin_build ~= nil then
		inst.AnimState:OverrideItemSkinSymbol("swap_staffs", skin_build,
			Config.SPEAR_SWAP_SYMBOL, proxy.GUID, Config.SPEAR_SWAP_BUILD)
	else
		inst.AnimState:OverrideSymbol("swap_staffs",
			Config.SPEAR_SWAP_BUILD, Config.SPEAR_SWAP_SYMBOL)
	end
end

-- 清除覆盖
function FxSymbol.Clear(inst)
	inst.AnimState:ClearOverrideSymbol("swap_staffs")
end

return FxSymbol
