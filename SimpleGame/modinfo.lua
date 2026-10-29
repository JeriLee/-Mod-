local function Adaptive(en, zh, zht)
	local specify = { zh = zh, zht = zht }
	return specify[locale] or en
end

name = Adaptive(
	"Bigger Ice Flingomatic range",
	"灭火器增大范围",
	"灭火器增大范围"
)

description = Adaptive(
[[
Small quality-of-life tweaks.

1. Ice Flingomatic range
   - The vanilla detection range is 15 (TUNING.FIRE_DETECTOR_RANGE).
   - The lightning rod attracts any lightning within 40 (LIGHTNINGSTRIKE_SEARCH_RANGE).
   - Default: make the flingomatic cover as much as a lightning rod.
   - The placement circle and the snowball speed follow the new range.

Version: 0.1
]],
[[
一些简单的数值调整。

1. 灭火器（雪球发射器）范围
   - 原版检测范围是 15（TUNING.FIRE_DETECTOR_RANGE）。
   - 避雷针能吸引 40 范围内的闪电（LIGHTNINGSTRIKE_SEARCH_RANGE）。
   - 默认把灭火器的范围和避雷针改成一样大。
   - 放置时地面圆环、雪球飞行速度都会跟着范围一起调整。

版本: 0.1
]],
[[
一些簡單的數值調整。

1. 滅火器（雪球發射器）範圍
   - 原版檢測範圍是 15（TUNING.FIRE_DETECTOR_RANGE）。
   - 避雷針能吸引 40 範圍內的閃電（LIGHTNINGSTRIKE_SEARCH_RANGE）。
   - 預設把滅火器的範圍和避雷針改成一樣大。
   - 放置時地面圓環、雪球飛行速度都會跟著範圍一起調整。

版本: 0.1
]]
)

author = "LarkinRon"
version = "0.1"

forumthread = ""

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
-- 只改服务端逻辑（范围判定、投射物都在主机端跑），
-- 客户端装不装都不影响功能，只是没装的人看不到放大的放置圆环
all_clients_require_mod = false

api_version = 10

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "flingomatic", "灭火器" }

configuration_options =
{
	{
		name = "range",
		label = "灭火器工作范围",
		hover = "原版是 15。避雷针能吸引 40 范围内的闪电，选 40 就是和避雷针一样大。",
		options =
		{
			{ description = "15（原版）", data = 15 },
			{ description = "20", data = 20 },
			{ description = "30", data = 30 },
			{ description = "40（与避雷针相同）", data = 40 },
		},
		default = 40,
	},
	{
		name = "sync_placer",
		label = "放置圆环跟随范围",
		hover = "放置时地面的范围圆环按比例放大，顺手把灭火器预览模型缩回原大小。关闭后圆环仍是原版大小，会看着比实际范围小。",
		options =
		{
			{ description = "关闭", data = false },
			{ description = "开启", data = true },
		},
		default = true,
	},
	{
		name = "speed_comp",
		label = "雪球速度补偿",
		hover = "范围变大后如果还用原版速度（15），远处目标会够不着、雪球落在半路。开启后水平速度按比例放大，飞行时间和原版接近。",
		options =
		{
			{ description = "关闭", data = false },
			{ description = "开启", data = true },
		},
		default = true,
	},
}
