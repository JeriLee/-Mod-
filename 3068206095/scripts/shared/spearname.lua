-- 共享 · 奔雷矛通用命名生成
--
-- 月淬（moonbase_ritual）与古铸（ancient_cast）改的是同一把奔雷矛，
-- 两者都能给它打上一个独立的标记标签，因此名称需要按"标记组合"动态生成，
-- 而不是各自套一层 displaynamefn（那样会互相覆盖，丢失其中一个前缀）。
--
-- 命名规则（前缀顺序固定：月萃 → 古铸 → 基础名）：
--   无任何效果      -> 奔雷矛 / 充能奔雷矛
--   仅古铸          -> 古铸奔雷矛 / 古铸充能奔雷矛
--   仅月萃          -> 月萃奔雷矛 / 月萃充能奔雷矛
--   古铸 + 月萃     -> 月萃古铸奔雷矛 / 月萃古铸充能奔雷矛
--
-- 基础名（"奔雷矛" / "充能奔雷矛"）来自本体 STRINGS.NAMES：
--   SPEAR_WATHGRITHR_LIGHTNING          = 奔雷矛
--   SPEAR_WATHGRITHR_LIGHTNING_CHARGED  = 充能奔雷矛
-- 前缀词用中文常量（月萃 / 古铸），由各自模块的 config 传入。
--
-- 本模块只提供纯函数，不依赖引擎运行时全局，客户端服务端都可调用。

local G = require("shared/genv")

local STRINGS = G.Get("STRINGS")

local SpearName = {}

-- 前缀词（月萃在前，古铸在后）
SpearName.MOON_PREFIX = "月萃"
SpearName.ANCIENT_PREFIX = "古铸"

-- 判断 prefab 名是否属于"充能"形态
-- （皮肤 prefab 也会保留 "_charged" 片段，所以用片段匹配而非整串比较）
function SpearName.IsChargedPrefab(prefab)
	return prefab ~= nil and string.find(prefab, "_charged", 1, true) ~= nil
end

--------------------------------------------------------------------------
-- 取奔雷矛的基础显示名（不含任何前缀）
--
-- 优先读本体的 STRINGS.NAMES；若取不到（理论上不会）则回退到写死的中文名。
--------------------------------------------------------------------------
function SpearName.GetBaseName(prefab)
	if SpearName.IsChargedPrefab(prefab) then
		local n = STRINGS ~= nil and STRINGS.NAMES.SPEAR_WATHGRITHR_LIGHTNING_CHARGED or nil
		return (n ~= nil and n ~= "") and n or "充能奔雷矛"
	end
	local n = STRINGS ~= nil and STRINGS.NAMES.SPEAR_WATHGRITHR_LIGHTNING or nil
	return (n ~= nil and n ~= "") and n or "奔雷矛"
end

--------------------------------------------------------------------------
-- 通用命名生成
--
-- prefab        物品的 prefab 名（用于判断是否充能形态 + 取基础名）
-- is_moonforged 是否已月淬（打 moon 标签）
-- is_ancient    是否已古铸（打 ancient 标签）
--
-- 返回最终显示名。前缀顺序固定为：月萃 → 古铸 → 基础名。
--------------------------------------------------------------------------
function SpearName.GetName(prefab, is_moonforged, is_ancient)
	local parts = {}

	if is_moonforged then
		table.insert(parts, SpearName.MOON_PREFIX)
	end
	if is_ancient then
		table.insert(parts, SpearName.ANCIENT_PREFIX)
	end

	table.insert(parts, SpearName.GetBaseName(prefab))

	return table.concat(parts, "")
end

--------------------------------------------------------------------------
-- 统一的 displaynamefn 挂载
--
-- 由月淬 / 古铸模块各自调用（各自会先创建自己的 net 变量），
-- 这里只挂一个 displaynamefn，同时读取两个模块的 net 标记动态拼名。
--
-- inst           奔雷矛实体
-- isMoonFn       函数：传入 inst，返回"是否已月淬"（读 _moonforged_net）
-- isAncientFn    函数：传入 inst，返回"是否已古铸"（读 _ancientcast_net）
--
-- 说明：两个 net 变量由月淬（_moonforged_net）与古铸（_ancientcast_net）
-- 各自在 SetupName 里创建；只要两者都调用过本函数挂 displaynamefn，
-- 任意组合都能正确显示。由于本函数幂等（同一实体只挂一次），
-- 谁先调用、谁后调用都不影响结果。
--------------------------------------------------------------------------
function SpearName.SetupDisplayName(inst, isMoonFn, isAncientFn)
	if inst._spearname_displayfn ~= nil then
		return
	end
	inst._spearname_displayfn = true

	local oldfn = inst.displaynamefn
	inst.displaynamefn = function(i)
		local is_moon = isMoonFn ~= nil and isMoonFn(i) or false
		local is_ancient = isAncientFn ~= nil and isAncientFn(i) or false

		if is_moon or is_ancient then
			return SpearName.GetName(i.prefab, is_moon, is_ancient)
		end

		return oldfn ~= nil and oldfn(i) or nil
	end
end

return SpearName
