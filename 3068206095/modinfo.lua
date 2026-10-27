local function Adaptive(en, zh, zht)
	local specify = { zh = zh, zht = zht }
	return specify[locale] or en
end

local NAME_MOD = Adaptive(
	"Wigfrid Thunder Spear Plus",
	"女武神·奔雷矛扩展",
	"女武神·奔雷矛擴展"
)

local DESC_MOD = Adaptive(
[[
	Expand the Elding Spear (Wigfrid's exclusive weapon) with new gameplay:

	1. Moonstone Ritual / Moonforged
	   - Insert the spear into the Moon Stone to charge it on a full-moon night.
	   - Moonforged: bonus damage vs. Shadow creatures, slow durability regen at night.
	2. Lightning Rod Charge
	   - Charge the spear at a lightning rod to gain a damage buff.
	3. Ancient Cast
	   - At the Ancient Pseudoscience Station, spend 5 Thulecite to "ancient-cast" the spear.
	   - Immunity to Bee Queen's slow + bonus damage vs. Giant bosses.
	4. Gem Attunement (Ancient Charged Elding Spear only)
	   - Green Gem: +30 planar damage, lasts one day.
	   - Yellow Gem: lunge damage x2, lunge electrocute stun 2.4s, lasts one day.
	   - Each spear can hold one gem of each colour; re-apply after it expires.
	5. Notes
	   - The item name shows the remaining attunement time.
	   - With the Insight mod installed, the green gem timer is shown in the inspect description.
	Main features can be toggled or tuned in the mod configuration.

	Version: 0.3
]],
[[
	为女武神的专属武器「奔雷矛」扩展全新玩法：

	1. 月台充能 / 月淬
	   - 把奔雷矛插进月亮台，在月圆之夜完成充能。
	   - 月淬：对暗影生物增伤，夜里缓慢恢复耐久。
	2. 避雷针充能
	   - 在避雷针处给奔雷矛充能，获得伤害加成。
	3. 古铸
	   - 在远古伪科学站花 5 个铥矿给奔雷矛「古铸」。
	   - 免疫蜂后减速，并对巨人 boss 增伤。
	4. 宝石改造（仅「古铸的充能奔雷矛」）
	   - 绿宝石：位面伤害 +30，持续一天。
	   - 黄宝石：冲刺伤害 x2，冲刺造成的电击僵直 2.4 秒，持续一天。
	   - 每把矛每种宝石只能吸收一颗，到期后可以再次改造。
	5. 其它
	   - 物品名会显示宝石改造的剩余时间。
	   - 安装 Insight 模组时，绿宝石的剩余时间显示在物品悬浮描述里。
	月台充能、古铸等功能可在模组设置里开关或调整。

	版本: 0.3
]],
[[
	為女武神的專屬武器「奔雷矛」擴展全新玩法：

	1. 月台充能 / 月淬
	   - 把奔雷矛插進月亮台，在月圓之夜完成充能。
	   - 月淬：對暗影生物增傷，夜裡緩慢恢復耐久。
	2. 避雷針充能
	   - 在避雷針處給奔雷矛充能，獲得傷害加成。
	3. 古鑄
	   - 在遠古偽科學站花 5 個銩礦給奔雷矛「古鑄」。
	   - 免疫蜂后減速，並對巨人 boss 增傷。
	4. 寶石改造（僅「古鑄的充能奔雷矛」）
	   - 綠寶石：位面傷害 +30，持續一天。
	   - 黃寶石：衝刺傷害 x2，衝刺造成的電擊僵直 2.4 秒，持續一天。
	   - 每把矛每種寶石只能吸收一顆，到期後可以再次改造。
	5. 其它
	   - 物品名會顯示寶石改造的剩餘時間。
	   - 安裝 Insight 模組時，綠寶石的剩餘時間顯示在物品懸浮描述裡。
	月台充能、古鑄等功能可在模組設定裡開關或調整。

	版本: 0.3
]]
)

name = NAME_MOD
description = DESC_MOD
author = "LarkinRon"
version = "0.3"

forumthread = ""

dst_compatible = true --兼容联机
dont_starve_compatible = false --不兼容单机
reign_of_giants_compatible = false --不兼容巨人
all_clients_require_mod=true --所有人mod

api_version = 10

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {"Wigfrid Thunder Spear Plus", "女武神 奔雷矛"} --服务器标签可以不写

-- 为了保证服务器与客户端读到的 RPC 序号一致，这里必须用硬编码的数字，
-- 不能用 GetModConfigData("xxx") or 默认值 这种写法。
-- 已有配置项的顺序不要改动，新配置项一律追加到末尾。

configuration_options =
{
    {
        name = "ThunderSpear_Enable",
        label = "奔雷矛 · 月台充能",
        hover = "启用后，奔雷矛可以插进月亮台，在月圆之夜完成充能。",
        options =
        {
            {description = "关闭", data = false},
            {description = "开启", data = true},
        },
        default = true,
    },
    {
        name = "ThunderSpear_Charges",
        label = "需要充能的月圆次数",
        hover = "需要经历几个满月之夜，奔雷矛才会变成充能形态。",
        options =
        {
            {description = "1 次", data = 1},
            {description = "2 次", data = 2},
            {description = "3 次", data = 3},
        },
        default = 1,
    },
    {
        name = "ThunderSpear_NightHours",
        label = "夜间耐久恢复速度",
        hover = "奔雷矛在夜里自动恢复耐久，这里填多少个夜晚能回满一整条耐久。",
        options =
        {
            {description = "6 个夜晚回满", data = 6},
            {description = "12 个夜晚回满", data = 12},
            {description = "24 个夜晚回满", data = 24},
            {description = "48 个夜晚回满", data = 48},
            {description = "不恢复", data = 0},
        },
        default = 24,
    },
    {
        -- 代码里一直在读这个开关（ancient_cast/config.lua），
        -- 之前 modinfo 漏写了，导致选项无法关闭，这里补上。追加在末尾不影响已有索引。
        name = "AncientCast_Enable",
        label = "奔雷矛 · 古铸",
        hover = "启用后，可以在远古伪科学站花 5 个铥矿给奔雷矛「古铸」。",
        options =
        {
            {description = "关闭", data = false},
            {description = "开启", data = true},
        },
        default = true,
    },
}
