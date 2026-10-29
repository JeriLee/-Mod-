-- 多语言：locale 是游戏当前语言(zh = 简体,zht = 繁体),其它语言一律显示英文
local function Adaptive(en, zh, zht)
	local specify = { zh = zh, zht = zht }
	return specify[locale] or en
end

local NAME_MOD = Adaptive(
	"MiniMap - Smaller World",
	"MiniMap更小的世界(2026.10月更)",
	"MiniMap更小的世界(2026.10月更)"
)

local DESC_MOD = Adaptive(
[[
Shrinks a newly generated world to fit within a target edge length (300 x 300 by default), without cutting any biome or content type.

Ring-shaped terrain, roughly 30% the size of a small world map.
When generating the map, be sure to choose a small map. Otherwise, it will be reduced to 30% of the current size.

How it shrinks:
1. Target size: duplicate rooms are scaled down proportionally (at least one of every room type is kept). Room types, set pieces and ocean set pieces are all preserved.
2. Adaptive retry: if generation fails, the ratio is relaxed (bigger map) and retried; if it succeeds but the map is still too large, it is tightened once and retried. After 3 adjustments the result is accepted.
3. Ring-shaped mainland: minimal branching + looped end to end, so the mainland forms a ring and the middle becomes an inland sea.
4. Cove dead-end nodes disabled, background fill nodes halved, no isolated islands, shallow coastal water narrowed.
5. The engine's minimum world edge is relaxed (the size preset is only a lower bound).
6. Hermit Island, Monkey Island and Moon Island are all placed inside the ring; Moon Island size can be scaled separately (60% by default).
7. The number of surface sinkholes can be limited (vanilla spawns up to 10, the default here is 4).

Two options do remove some content: "Events / Easter eggs" and "Surface Sinkholes". Set them to "Keep" and "Vanilla" to stay completely vanilla.

Only affects new world generation. The mod can be safely disabled or removed once the world has been generated.
]],
[[
把地图压到目标边长以内(默认 300 x 300),群落和内容种类一个都不裁。

环形地形,约为小地图30%大小,非常牛逼
如果想要最小的地图,地图生成的时候,一定要选择地图小。否则会在当前大小的基础上缩减为30%

收缩手段：
1. 目标边长：按比例减少「重复房间」的份数(每种房间至少留 1 份),
   房间种类、布景、海洋布景全部保留
2. 自适应重试：生成失败会自动放宽比例(地图变大)再试；
   生成成功但仍超过目标会收紧一次再试；最多调整 3 次,之后接受结果
3. 环形主大陆：分支拉到最小 + 首尾相连,主大陆绕成一圈,中间成为内海
4. 关闭 cove 死角节点、背景填充节点减半、不让群落变成孤立小岛、收窄浅海
5. 放宽世界边长下限(引擎的边长档位只是下限)
6. 奶奶岛、猴岛、月岛都往环内放；月岛可单独调小尺寸(默认 60%)
7. 地面沉洞数量可调(原版最多 10 个,默认 4 个)

会去掉一点内容的是「活动 / 彩蛋内容」和「地面沉洞数量」两个开关,
前者设成「保留」、后者设成「原版」就完全跟原版一致。

只影响「新世界生成」。生成完世界后可以安全地关闭或移除本模组。
]],
[[
把地圖壓到目標邊長以內(預設 300 x 300),群落和內容種類一個都不裁。

環形地形,約為小地圖30%大小,非常牛逼
地图生成的时候,一定要选择地图小。否则会在当前大小的基础上缩减为30%

收縮手段：
1. 目標邊長：按比例減少「重複房間」的份數(每種房間至少留 1 份),
   房間種類、佈景、海洋佈景全部保留
2. 自適應重試：生成失敗會自動放寬比例(地圖變大)再試；
   生成成功但仍超過目標會收緊一次再試；最多調整 3 次,之後接受結果
3. 環形主大陸：分支拉到最小 + 首尾相連,主大陸繞成一圈,中間成為內海
4. 關閉 cove 死角節點、背景填充節點減半、不讓群落變成孤立小島、收窄淺海
5. 放寬世界邊長下限(引擎的邊長檔位只是下限)
6. 奶奶島、猴島、月島都往環內放；月島可單獨調小尺寸(預設 60%)
7. 地面沉洞數量可調(原版最多 10 個,預設 4 個)

會去掉一點內容的是「活動 / 彩蛋內容」和「地面沉洞數量」兩個開關,
前者設成「保留」、後者設成「原版」就完全跟原版一致。

只影響「新世界生成」。生成完世界後可以安全地關閉或移除本模組。
]]
)

name = NAME_MOD
description = DESC_MOD

author = "MiniMap"
version = "1.7.1"
api_version = 10

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
all_clients_require_mod = false
client_only_mod = false

server_filter_tags = { "worldgen", "map" }

-- 配置项只需要中英两种语言(其它语言一律英文,繁体沿用简体)
local function Loc(en, zh)
	return (locale == "zh" or locale == "zht") and zh or en
end

configuration_options =
{
    {
        name = "minimap_events",
        label = Loc("Events / Easter Eggs", "活动 / 彩蛋内容"),
        hover = Loc(
            "Keep: same as vanilla.\nNo stage plays & Balatro: charlie_stage_post, statueharp_hedgespawner and balatro_machine are not generated, and are removed from the required prefabs.\nRemove all: also removes the Terraria chest, which is required before Background Nodes can be turned off.",
            "保留：跟原版一样。\n去掉舞台剧与小丑牌：不生成 charlie_stage_post、statueharp_hedgespawner、balatro_machine,并从必需 prefab 里移除。\n全部去掉：再把泰拉瑞亚箱子也去掉,这样才可以把「外围背景节点」设为关闭。"
        ),
        options =
        {
            { description = Loc("Keep", "保留"), data = "keep" },
            { description = Loc("No stage plays & Balatro", "去掉舞台剧与小丑牌"), data = "basic" },
            { description = Loc("Remove all (incl. Terraria chest)", "全部去掉(含泰拉箱)"), data = "all" },
        },
        default = "basic",
    },

    {
        name = "minimap_ring",
        label = Loc("Ring Mainland", "环形主大陆"),
        hover = Loc(
            "On: branching is minimized (branching=never) and the mainland is looped end to end (loop=always),\nso the mainland wraps into a ring with an inland sea in the middle - Hermit Island, Monkey Island and Moon Island are placed there.\nOff: restores vanilla branching and paths.",
            "开启：地图分支拉到最小(branching=never),并让主大陆首尾相连(loop=always),\n主大陆会绕成一圈,中间剩下一片内海——奶奶岛、猴岛、月岛都往这里放。\n关闭：恢复原版的分支与路径。"
        ),
        options =
        {
            { description = Loc("On", "开启"), data = true },
            { description = Loc("Off", "关闭"), data = false },
        },
        default = true,
    },

    {
        name = "minimap_islands",
        label = Loc("Island Placement", "岛屿位置"),
        hover = Loc(
            "Inland sea (recommended): Hermit Island and Monkey Island are placed in the sea inside the ring first (they may hug the mainland, at least 1 tile of water away),\nand Moon Island is attached to the two mainland nodes closest to the center.\nOnly when the inland sea is too small do they fall back outside the ring: near the shore first, then vanilla random deep water.\nNear shore: no inland search; Hermit Island moves to coastal water, Monkey Island goes to the layer of water closest to land.\nVanilla: all three islands are placed randomly by vanilla logic and often drift far out into deep ocean.",
            "环内内海(推荐)：优先把奶奶岛、猴岛放进环形主大陆中间的内海(允许紧贴主大陆,最近只隔 1 格水),\n月岛也挂到最靠中心的两个主大陆节点上。\n内海太小放不下时才退到环外：先贴岸,再交给原版随机丢到深水。\n靠岸：不找环内,奶奶岛搬到近岸海域、猴岛放在离陆地最近的一层水域。\n保持原版：三座岛都由原版逻辑随机找位置,经常飘在很远的深海。"
        ),
        options =
        {
            { description = Loc("Inland sea", "环内内海"), data = "center" },
            { description = Loc("Near shore", "靠岸"), data = "near" },
            { description = Loc("Vanilla", "保持原版"), data = "keep" },
        },
        default = "center",
    },

    {
        name = "minimap_target_size",
        label = Loc("Target Map Size", "目标地图边长"),
        hover = Loc(
            "DST's world_size is only a lower bound; the final edge length is decided by the number of room nodes (vanilla small map is about 415 x 415).\nTo get below the target the only lever is reducing duplicate rooms (room types, set pieces and content are all kept).\nIf generation fails the ratio is relaxed and retried; if it succeeds but is still too large it is tightened once and retried; after 3 adjustments the result is accepted.",
            "DST 的 world_size 只是「下限」,最终边长由房间节点数量决定(原版小图约 415 x 415)。\n要压到目标以下,只能减少「重复房间」的份数(房间种类、布景、内容都不删)。\n生成失败会自动放宽比例再试；生成成功但仍超过目标会收紧一次再试；最多调整 3 次,之后接受结果。"
        ),
        options =
        {
            { description = Loc("No limit", "不限制"), data = 0 },
            { description = Loc("350 x 350", "350 x 350"), data = 350 },
            { description = Loc("300 x 300 (recommended)", "300 x 300(推荐)"), data = 300 },
            { description = Loc("250 x 250", "250 x 250"), data = 250 },
        },
        default = 300,
    },

    {
        name = "minimap_moon_size",
        label = Loc("Moon Island Size", "月岛尺寸"),
        hover = Loc(
            "Only shrinks the room count of Moon Island (5 tasks); the mainland is untouched.\nMoon Island is still a vanilla separate region, just a bit smaller, so altars, moonstone mines, baths and the rest still generate.\nIf generation keeps hitting PANIC retries (altar set pieces do not fit), set this back to 100%.",
            "只缩小月岛(5 个任务)的房间数量,主大陆一个房间都不动。\n月岛仍然是原版的独立区域,只是岛本身小一圈,岛上的祭坛、月石矿、浴场等内容照常生成。\n如果生成时频繁出现 PANIC 重试(祭坛布景放不下),把它调回 100%。"
        ),
        options =
        {
            { description = Loc("100% (vanilla)", "100%(原版)"), data = 1.0 },
            { description = Loc("80%", "80%"), data = 0.8 },
            { description = Loc("60% (recommended)", "60%(推荐)"), data = 0.6 },
            { description = Loc("40% (smallest)", "40%(最小)"), data = 0.4 },
        },
        default = 0.6,
    },

    {
        name = "minimap_bg",
        label = Loc("Outer Background Nodes", "外围背景节点"),
        hover = Loc(
            "Background nodes only serve the tags of background rooms; their count does not affect content.\nHalf = 0-1 background nodes per room, safe.\nTurning them off requires setting Events / Easter Eggs to \"Remove all (incl. Terraria chest)\", otherwise missing prefabs make world generation fail.",
            "背景节点只为「背景房间」的 tags 服务,数量不影响内容。\n减半 = 每个房间 0~1 个背景节点,安全。\n关闭必须配合把「活动/彩蛋内容」设为「全部去掉(含泰拉箱)」,否则会缺 prefab 导致世界生成失败。"
        ),
        options =
        {
            { description = Loc("Keep as is", "保持原样"), data = "keep" },
            { description = Loc("Half (0-1)", "减半 (0~1)"), data = "half" },
            { description = Loc("Off (needs Terraria chest removed)", "关闭 (需去掉泰拉箱)"), data = "none" },
        },
        default = "half",
    },

    {
        name = "minimap_world_size",
        label = Loc("Min World Size", "世界边长下限"),
        hover = Loc(
            "The engine's size presets are 50 / 350 / 400 / 425 / 450 and are only a lower bound; the final size follows the amount of content.\nPick 50 to drop the 350 floor so the map can shrink together with its content.",
            "引擎的边长档位是 50 / 350 / 400 / 425 / 450,它只是「下限」,最终尺寸由内容量决定。\n选 50 才能去掉 350 这个下限,让地图跟着内容一起缩小。"
        ),
        options =
        {
            { description = Loc("Follow player setting", "跟随玩家设置"), data = "keep" },
            { description = Loc("Medium (400)", "中 (400)"), data = "medium" },
            { description = Loc("Large (350 sentinel)", "大 (350 哨兵)"), data = "compact" },
            { description = Loc("Tiny (50, recommended)", "极小 (50,推荐)"), data = "small" },
        },
        default = "small",
    },

    {
        name = "minimap_shallow",
        label = Loc("Narrow Shallow Water", "收窄浅海"),
        hover = Loc(
            "Pushes most shallow water into deep ocean, reducing large empty shallow areas.\nTurn off to restore vanilla ocean bands.",
            "把大部分「浅海」推成深海,减少大片空荡的浅海区域。\n关闭后恢复原版的海域分带。"
        ),
        options =
        {
            { description = Loc("On", "开启"), data = true },
            { description = Loc("Off", "关闭"), data = false },
        },
        default = true,
    },

    {
        name = "minimap_caves",
        label = Loc("Shrink Caves Too", "洞穴也一起缩小"),
        hover = Loc(
            "When off, only the surface world is shrunk; caves (including ruins and atrium) stay vanilla.",
            "关闭后只缩小地面世界,洞穴(含远古、中庭)保持原样。"
        ),
        options =
        {
            { description = Loc("Yes", "是"), data = true },
            { description = Loc("No", "否"), data = false },
        },
        default = true,
    },

    {
        name = "minimap_sinkholes",
        label = Loc("Surface Sinkholes", "地面沉洞数量"),
        hover = Loc(
            "How many cave entrances (sinkholes) may spawn on the surface.\nVanilla places up to 10 (set_pieces.CaveEntrance.count = 10); each candidate task gets at most one.\nOnly affects new world generation. Fewer holes also means fewer places to enter the caves, so 2 may be inconvenient.",
            "地面通往洞穴的沉洞最多生成几个。\n原版最多 10 个(tasksets/forest.lua 里 set_pieces.CaveEntrance.count = 10),每个候选任务最多放一个。\n只影响新世界生成。数量太少会不方便下洞,2 个可能偏极限。"
        ),
        options =
        {
            { description = Loc("Vanilla (10)", "原版(10 个)"), data = 10 },
            { description = Loc("6", "6 个"), data = 6 },
            { description = Loc("4 (recommended)", "4 个(推荐)"), data = 4 },
            { description = Loc("2", "2 个"), data = 2 },
        },
        default = 4,
    },
}
