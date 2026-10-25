-- 古铸 · 全局配置与常量
--
-- 古铸与「月台仪式」是两条互不相干的路线：
--   月台仪式 = 插进月亮台 + 月圆之夜充能
--   古铸     = 在远古伪科学站花 5 个铥矿
--
-- 注意：本文件是 require 进来的普通模块，默认 _G 带 strict，
-- 引擎接口必须显式从 GLOBAL 取（见 shared/genv.lua）。

local G = require("shared/genv")

local GetModConfigData = G.Get("GetModConfigData")

local Config = {}

-- 远古伪科学站 = 原版 ancient_altar（英文名 Ancient Pseudoscience Station）
Config.ALTAR = "ancient_altar"

-- 铥矿（注意：不是铥矿碎片 thulecite_pieces）
Config.ANCIENT_MATERIAL = "thulecite"

-- 一次古铸需要几个铥矿
Config.ANCIENT_COST = 5

-- 古铸标记标签
Config.ANCIENT_TAG = "ancient"

-- 对巨人 boss（epic 标签）的增伤倍数：1.2 = +20%
--
-- 巨人 boss（鹿角鹅/熊大/龙蝇/蜂王/蚁后等）都打 "epic" 标签，
-- 通过 damagetypebonus 组件的 AddBonus 实现对它们的增伤。
Config.ANCIENT_GIANT_DAMAGE_BONUS = 1.2

-- 免疫蜂后减速用的标签
--
-- 本体蜂后（Bee Queen）的减速不是直接作用，而是靠它喷出的蜂蜜拖尾
-- honey_trail：玩家踩上去时，honey_trail 会检查玩家是否带 "vigorbuff"
-- 标签，带了就排除在减速判定之外（见 scripts/prefabs/honey_trail.lua 的
-- HONEYTRAILSLOWDOWN_CANT_TAGS）。
--
-- 所以只要在玩家携带古铸奔雷矛时给玩家临时挂上 "vigorbuff" 标签，
-- 就能复用本体这套免疫逻辑，玩家踩蜂蜜也不会被减速。
Config.BEEQUEEN_IMMUNE_TAG = "vigorbuff"

-- 古铸后的显示名称不再在这里定义，改由共享命名函数统一生成
-- （见 shared/spearname.lua：前缀「月萃 → 古铸 → 基础名」动态拼接）

-- 模组配置读取
-- 注意：为保证服务器与客户端读到的值一致，这里用 pcall 兜底，
-- 缺失时回落到默认值（与 modinfo.lua 中的 default 保持一致）。
local function GetCfg(key, default)
	if GetModConfigData == nil then
		return default
	end
	local ok, v = pcall(GetModConfigData, key)
	if ok and v ~= nil then
		return v
	end
	return default
end

Config.ENABLE = GetCfg("AncientCast_Enable", true)

return Config
