name = "Wigfrid Plus Package"
description = "Just Wigfrid plus cpackage \nAuthor TomCruise \nQQ 874387202 \nAnd thanks all"
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

server_filter_tags = {"Wigfrid plus package"} --服务器标签可以不写

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
        default = 12,
    },
}
