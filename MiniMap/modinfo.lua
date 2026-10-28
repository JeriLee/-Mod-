name = "MiniMap - 更小的世界"
description = [[让世界生成得更小、更紧凑。

实测数据（同内容量对比）：
  原版小图 415 x 415 → 房间去重后 294 x 294
世界尺寸由「群落(task) 数量」和「每个群落保留的房间种类数」决定，
引擎会把地图烘焙到刚好装下所有节点的大小，所以只能靠减少内容来缩小。

本模组的三层收缩：
1. 每个群落只保留有内容的房间（猪王、龙蝇竞技场、月岛矿井…），
   重复的通用地形（Forest/Plain/Rocky/Marsh）只留 0~2 个
2. 砍掉重复/太小的群落（蜜蜂地块、魔法草原、鼹鼠、猎人…），
   可选群落从 5 个减到 3 个
3. 关闭 cove 死角、不让群落变成孤立小岛、收窄浅海
   海洋布景去重（水中木、盐池各 1 个；只留帝王蟹/珍珠岛/猴岛/大漩涡）

只影响「新世界生成」。生成完世界后可以安全地关闭或移除本模组。]]
author = "MiniMap"
version = "1.2.0"
api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
all_clients_require_mod = false
client_only_mod = false

server_filter_tags = { "worldgen", "map" }

configuration_options =
{
    {
        name = "minimap_trim",
        label = "群落精简",
        hover = "关闭：保留全部 20 个群落（每次都要重新挑 5 个可选群落）。\n温和：可选群落固定为蜘蛛巢/蛙池/麋鹿巢 3 个。\n标准：再去掉「蜜蜂地块」（房间太少放不下多个杀人蜂巢和蜂后）。\n极限：连可选群落也不生成，只剩 14 个固定群落。",
        options =
        {
            { description = "关闭", data = "off" },
            { description = "温和", data = "mild" },
            { description = "标准", data = "strong" },
            { description = "极限（最小）", data = "extreme" },
        },
        default = "strong",
    },

    {
        name = "minimap_events",
        label = "活动 / 彩蛋内容",
        hover = "保留：跟原版一样。\n去掉舞台剧与小丑牌：不生成 charlie_stage_post、statueharp_hedgespawner、balatro_machine（舞台剧设置会把竖琴雕像一起关掉），并从必需 prefab 里移除，不会导致世界生成失败。\n全部去掉：再把泰拉瑞亚箱子也去掉，这样才可以把「外围背景节点」设为关闭，是地图最后一大块能省的地方。",
        options =
        {
            { description = "保留", data = "keep" },
            { description = "去掉舞台剧与小丑牌", data = "basic" },
            { description = "全部去掉（含泰拉箱）", data = "all" },
        },
        default = "basic",
    },

    {
        name = "minimap_islands",
        label = "岛屿靠岸",
        hover = "保持原版：月岛是独立区域，会被丢到地图最空的角落，中间插 8 个中继节点；奶奶岛在深海。\n月岛并入主大陆：清掉 region_id，月岛 5 个任务变成普通任务，直接接在主大陆旁边，会紧贴陆地甚至连成一片，同时省掉中继节点，地图也会变小。\n月岛 + 奶奶岛靠岸：再把奶奶岛从深海（OceanRough）搬到近岸海域（OceanCoastal）。",
        options =
        {
            { description = "保持原版", data = "keep" },
            { description = "只月岛并陆", data = "moon" },
            { description = "月岛并陆 + 奶奶岛靠岸", data = "both" },
        },
        default = "both",
    },

    {
        name = "minimap_maxrooms",
        label = "每个群落最多保留几种房间",
        hover = "2 = 最紧凑。带静态布景的房间（猪王、雕像、泰拉箱、月岛矿井）优先保留，所以关键内容不会丢。\n如果生成时频繁出现 PANIC 重试，把它调回 3。",
        options =
        {
            { description = "2 种（最小）", data = 2 },
            { description = "3 种", data = 3 },
            { description = "4 种", data = 4 },
        },
        default = 2,
    },

    {
        name = "minimap_filler",
        label = "额外保留的通用地形",
        hover = "在上面的内容房间之外，每个群落再额外保留几个通用地形房间（Forest/Plain/Rocky/Marsh）。\n0 = 最紧凑；1~2 会让地形过渡自然很多，但地图明显变大。",
        options =
        {
            { description = "0 个", data = 0 },
            { description = "1 个", data = 1 },
            { description = "2 个", data = 2 },
        },
        default = 0,
    },

    {
        name = "minimap_shrink",
        label = "保留房间的重复份数比例",
        hover = "被保留下来的房间，其数量（重复份数）再按此比例削减。\n例如 Squeltch 原本 6 个 Marsh，压成 3 个（55%）或 2 个（25%）。",
        options =
        {
            { description = "85%", data = 0.85 },
            { description = "70%", data = 0.70 },
            { description = "55%", data = 0.55 },
            { description = "40%", data = 0.40 },
            { description = "25%", data = 0.25 },
        },
        default = 0.25,
    },

    {
        name = "minimap_bg",
        label = "外围背景节点",
        hover = "泰拉瑞亚箱子等 prefab 是靠背景房间的 tags 放置的，所以「关闭」必须配合把「活动/彩蛋内容」设为「全部去掉（含泰拉箱）」，否则会缺 prefab 导致世界生成失败。\n减半 = 每个房间 0~1 个背景节点，安全。",
        options =
        {
            { description = "保持原样", data = "keep" },
            { description = "减半 (0~1)", data = "half" },
            { description = "关闭 (需去掉泰拉箱)", data = "none" },
        },
        default = "half",
    },

    {
        name = "minimap_world_size",
        label = "世界边长下限",
        hover = "引擎的边长档位是 50 / 350 / 400 / 425 / 450，它只是「下限」，最终尺寸由内容量决定。\n选 50 才能去掉 350 这个下限，让地图跟着内容一起缩小。",
        options =
        {
            { description = "跟随玩家设置", data = "keep" },
            { description = "中 (400)", data = "medium" },
            { description = "大 (350 哨兵)", data = "compact" },
            { description = "极小 (50，推荐)", data = "small" },
        },
        default = "small",
    },

    {
        name = "minimap_shallow",
        label = "收窄浅海",
        hover = "把大部分「浅海」推成深海，减少大片空荡的浅海区域。\n关闭后恢复原版的海域分带。",
        options =
        {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },

    {
        name = "minimap_setpieces",
        label = "布景与海洋去重",
        hover = "复活石/虫洞/洞穴入口按比例缩减；海洋只保留 1 个水中木、1 个盐池。",
        options =
        {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },

    {
        name = "minimap_caves",
        label = "洞穴也一起缩小",
        hover = "关闭后只缩小地面世界，洞穴（含远古、中庭）保持原样。",
        options =
        {
            { description = "是", data = true },
            { description = "否", data = false },
        },
        default = true,
    },
}
