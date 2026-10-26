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

	1. Moonbase Ritual (月台充能/月淬)
	   - Insert the spear into the Moon Stone to charge it on a full-moon night.
	   - Moonforged: bonus damage vs. Shadow creatures, slow durability regen at night.
	2. Lightning Rod Charge (避雷针充能)
	   - Charge the spear at a lightning rod to gain a damage buff.
	3. Ancient Cast (古铸)
	   - At the Ancient Pseudoscience Station, spend 5 Thulecite to "ancient-cast" the spear.
	   - Immunity to Bee Queen's slow + bonus damage vs. Giant bosses.
	All features can be toggled in the mod configuration.

	Version: 0.2
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
	所有功能均可在模组设置里开关。

	版本: 0.2
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

	所有功能均可在模組設定裡開關。

	版本: 0.2
]]
)

name = NAME_MOD
description = DESC_MOD
author = "LarkinRon"
version = "0.2"

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
}
