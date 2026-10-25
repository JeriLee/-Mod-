-- 月台仪式 · 全局配置与常量
-- 所有需要跨文件共享的字面量/配置项集中在这里，其余文件只读不写。
--
-- 注意：本文件是 require 进来的普通模块，默认 _G 带 strict，
-- 引擎接口必须显式从 GLOBAL 取（见 genv.lua）。

local G = require("shared/genv")
local Shared = require("shared/weapon")

local GetModConfigData = G.Get("GetModConfigData")

local Config = {}

--------------------------------------------------------------------------
-- 基础 prefab 名
--
-- 奔雷矛的 prefab 名放在 shared/weapon.lua：
-- 月台仪式与古铸改的是同一把矛，两边共用一份，避免对不上。
--------------------------------------------------------------------------
Config.SPEAR = Shared.SPEAR
Config.SPEAR_CHARGED = Shared.SPEAR_CHARGED
Config.SPEAR_SKINS = Shared.SPEAR_SKINS

-- 月淬标记标签：带此标签的奔雷矛 = 已被月光淬炼过
Config.MOON_TAG = "moon"

-- 月淬后对暗影阵营的增伤倍数（玻璃刀为 1.25，即 +25%）
Config.SHADOW_DAMAGE_BONUS = 1.25

-- 月淬后的显示名称不再在这里定义，改由共享命名函数统一生成
-- （见 shared/spearname.lua：前缀「月萃 → 古铸 → 基础名」动态拼接）

--------------------------------------------------------------------------
-- 避雷针给奔雷矛的加成（见 scripts/lightning_spear/lightningrod.lua）
--------------------------------------------------------------------------
-- 耐久加成比例：+30%
Config.LIGHTNINGROD_DURABILITY_RATIO = 0.3

-- 伤害加成倍数：+20%
Config.LIGHTNINGROD_DAMAGE_MULT = 1.2

--------------------------------------------------------------------------
-- 月台插矛显示用的 build / symbol
-- 普通形态和充能形态公用一套 build 和 swap 符号
-- 见 scripts/prefabs/spear_wathgrithr.lua
--------------------------------------------------------------------------
Config.SPEAR_SWAP_BUILD = "spear_wathgrithr_lightning"
Config.SPEAR_SWAP_SYMBOL = "swap_spear_wathgrithr_lightning"

--------------------------------------------------------------------------
-- 月圆充能光柱/脉冲颜色（RGBA，0~1）
-- 原版月台光柱是青白色，这里用乘法着色（SetMultColour）把它染成指定颜色。
-- 白底 × 本颜色 = 显示颜色，分量越小越暗。{1,1,1,1} 即原版白色。
-- 光柱由三层组成，可分别着色：
--   PULSE = 中间脉冲（positronpulse）
--   BACK  = 后层光柱（positronbeam_back）
--   FRONT = 前层光柱（positronbeam_front）
--------------------------------------------------------------------------
Config.BEAM_COLOUR_PULSE = { 1, 0.2, 0.2, 1 }   -- 中间：红色
Config.BEAM_COLOUR_BACK = { 0.3, 0.5, 1, 1 }    -- 一侧：蓝色
Config.BEAM_COLOUR_FRONT = { 1, 1, 1, 1 }       -- 另一侧：白色

-- 预充能最短时长（对齐原版 moonbase 的 MIN_CHARGE_START_DELAY = 1）
Config.MIN_CHARGE_START_DELAY = 1

--------------------------------------------------------------------------
-- 模组配置读取
-- 注意：为保证服务器与客户端读到的值一致，这里用 pcall 兜底，
-- 缺失时回落到默认值（与 modinfo.lua 中的 default 保持一致）。
--------------------------------------------------------------------------
local function GetCfg(key, default)
	-- GetModConfigData 在某些加载阶段可能还不可用，必须显式判空，
	-- 否则 pcall(nil, key) 会直接抛错
	if GetModConfigData == nil then
		return default
	end
	local ok, v = pcall(GetModConfigData, key)
	if ok and v ~= nil then
		return v
	end
	return default
end

Config.ENABLE = GetCfg("ThunderSpear_Enable", true)
Config.CHARGES = GetCfg("ThunderSpear_Charges", 1)
Config.NIGHT_HOURS = GetCfg("ThunderSpear_NightHours", 12)

return Config
