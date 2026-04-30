version = "1.0.7"
name = "Extra Equip Slots Plus +"
description = 
ChooseTranslationTable({
[[
Can be set in options

Extra item slots

Extra backpack slot

Extra amulet slot

Extra compass slot

Too many items slots maybe cause UI overflow

Compatible with the latest version, directly made of materials in the box
]],
["zht"] =
[[
可以在選項裏設置

額外的物品欄格子

額外的背包格子

額外的護符格子

額外的指南針格子

過多的物品欄格子可能會導致UI溢出

兼容最新版本使用箱子內材料直接製作
]],
["zh"] =
[[
可以在选项里设置

额外的物品栏格子

额外的背包格子

额外的护符格子

额外的指南针格子

过多的物品栏格子可能会导致UI溢出

兼容最新版本使用箱子内材料直接制作
]],
})

author = "xVars, The Jobs and DoomOfMax"

forumthread = ""

api_version = 6
api_version_dst = 10
priority = -1e99

all_clients_require_mod = true

client_only_mod = false

dont_starve_compatible = true
reign_of_giants_compatible = true
dst_compatible = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

local function AddConfigOption(name, label, hover, options, default)
    local config = {
        name = name or "",
        label = label or "",
        hover = hover or "",
        options = options or { { description = "", data = 0 } },
        default = default == nil and 0 or default
    }
    return config
end

configuration_options =
{
	--[[{
        name = "render_strategy",
        label = "渲染策略(Render Strategy)",
		hover = "同时装备护符和身体部位装备时，您希望渲染哪一个贴图？(When equip both amulet and body equipment, which do you want to render?)",
        options =
        {
            {description = "默认(default)", data = "none", hover = "渲染最后装备的那个(Render the last equipment)"},
			{description = "护符(amulet)", data = "neck", hover = "渲染护符贴图(Render amulet)"},
			{description = "身体(body)", data = "body", hover = "渲染身体部位装备贴图(Render body equipment)"},
        },
        default = "none",
    },]]--

    {
        name = "slots_num",
        label = "额外物品栏格子(Extra Item Slots)",
        hover = "您想要多少额外的物品栏格子？(How many extra item slots do you want?)",
        options =
        {
            {description = "默认(default)", data = 0},
			{description = "+1", data = 1},
			{description = "+2", data = 2},
			{description = "+3", data = 3},
			{description = "+4", data = 4},
            {description = "+5", data = 5},
			{description = "+10", data = 10},
			{description = "+15", data = 15, hover = "可能会导致UI溢出(Maybe cause UI overflow)"},
			{description = "+20", data = 20, hover = "可能会导致UI溢出(Maybe cause UI overflow)"},
        },
        default = 0,
    },
	{
        name = "backpack_slot",
        label = "额外背包格子(Extra Backpack Slot)",
        hover = "你想要一个额外的背包格子吗？(Do you want an extra backpack slot?)",
        options =
        {
            {description = "否(no)", data = false},
            {description = "是(yes)", data = true},
        },
        default = true,
    },
    {
        name = "amulet_slot",
        label = "额外护符格子(Extra Amulet Slot)",
        hover = "你想要一个额外的护符格子吗？(Do you want an extra amulet slot?)",
        options =
        {
            {description = "否(no)", data = false},
            {description = "是(yes)", data = true},
        },
        default = true,
    },
    {
        name = "compass_slot",
        label = "额外指南针格子(Extra Compass Slot)",
        hover = "你想要一个额外的指南针格子吗？(Do you want an extra compass slot?)",
        options =
        {
            {description = "否(no)", data = false},
            {description = "是(yes)", data = true},
        },
        default = false,
    },
    {
        name = "drop_hand_item_when_heavy",
        label = "负重时卸下手部装备(Drop Handitem)",
        hover = "背起重物时，是否让你的手部装备被卸下？(Remove handitem when you carry heavy?)",
        options =
        {
            {description = "否(no)", data = false},
            {description = "是(yes)", data = true},
        },
        default = true,
    },
    {
        name = "show_compass",
        label = "显示指南针(Show Compass)",
        hover = "装备指南针时是否显示贴图(Show compass when equipped?)",
        options =
        {
            {description = "否(no)", data = false},
            {description = "是(yes)", data = true},
        },
        default = true,
    },
    {
        name = "chesspiece_fix",
        label = "搬雕像渲染修复(Chesspiece Fix)",
        hover = "修复可能出现的渲染错误(Fix some render problems)",
        options =
        {
            {description = "否(no)", data = false},
            {description = "是(yes)", data = true},
        },
        default = true,
    },
	{
        name = "slots_bg_length_adapter",
        label = "物品栏背景长度(Background Length)",
        hover = "改变物品栏背景长度(Change inventory background length)",
        options =
        {
			{ description = "-10", data = -10 },
			{ description = "-9", data = -9 },
			{ description = "-8", data = -8 },
			{ description = "-7", data = -7 },
			{ description = "-6", data = -6 },
			{ description = "-5", data = -5 },
			{ description = "-4", data = -4 },
			{ description = "-3", data = -3 },
			{ description = "-2", data = -2 },
			{ description = "-1", data = -1 },
			{ description = "默认(default)", data = 0 },
			{ description = "+1", data = 1 },
			{ description = "+2", data = 2 },
			{ description = "+3", data = 3 },
			{ description = "+4", data = 4 },
			{ description = "+5", data = 5 },
			{ description = "+6", data = 6 },
			{ description = "+7", data = 7 },
			{ description = "+8", data = 8 },
			{ description = "+9", data = 9 },
			{ description = "+10", data = 10 },
        },
        default = 0,
    },
    {
        name = "slots_bg_length_adapter_no_bg",
        label = "去除物品栏背景(Remove inventory background)",
        hover = "去除物品栏背景(Remove inventory background)",
        options =
        {
			{ description = "不去除(no)", data = false },
            { description = "去除(yes)", data = true },
        },
        default = false,
    },
	--[[{
        name = "drop_bp_if_heavy",
        label = "搬运重物时使用的格子",
        hover = "搬运重物时，您想使用哪个格子？",
        options =
        {
			{description = "背包格子", data = true},
            {description = "身体格子", data = false},
        },
        default = false,
    },]]--
}