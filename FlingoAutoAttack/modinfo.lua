local function Adaptive(en, zh, zht)
    local specify = { zh = zh, zht = zht }
    return specify[locale] or en
end

name = Adaptive(
    "Flingomatic Auto Attack",
    "雪球发射器自动攻击",
    "雪球發射器自動攻擊"
)

description = Adaptive(
[[An idle Ice Flingomatic will automatically target nearby hostile creatures and fire snowballs at them.

The snowball's vanilla on-hit effect is kept: everything within 4 units of the impact point still gets extinguished / cooled / frozen (freezable entities get AddColdness), so monsters get frozen on hit.

Options:
- Range: search radius (vanilla fire detection range is 15)
- Interval: seconds between two auto attacks
- Damage: extra damage dealt to enemies at the impact point. Default 0 = freeze only, which is close to vanilla balance
- Fuel: whether each auto attack consumes a bit of fuel]],
[[开启后，空闲状态下的雪球发射器会自动索敌，并向附近的敌对生物发射雪球。

完全沿用原版雪球命中效果：命中点 4 格范围内的生物会被灭火/降温/冰冻（freezable 加 coldness），所以怪物被打中会被冻住。

可调项：
- 射程：索敌半径（原版火焰侦测范围是 15）
- 间隔：两次自动攻击之间的秒数
- 伤害：命中点范围内敌人额外受到的伤害。默认 0 = 只冰冻不伤害，接近原版平衡
- 燃料：每次自动攻击是否额外消耗一点燃料]],

[[開啟後，空閒狀態下的雪球發射器會自動索敵，並向附近的敵對生物發射雪球。

完全沿用原版雪球命中效果：命中點 4 格範圍內的生物會被滅火/降溫/冰凍（freezable 加 coldness），所以怪物被打中會被凍住。

可調項：
- 射程：索敵半徑（原版火焰偵測範圍是 15）
- 間隔：兩次自動攻擊之間的秒數
- 傷害：命中點範圍內敵人額外受到的傷害。預設 0 = 只冰凍不傷害，接近原版平衡
- 燃料：每次自動攻擊是否額外消耗一點燃料]]
)

author = "Larkin"
version = "1.0.0"

forumthread = ""
api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = false
client_only_mod = false

-- 负优先级 = 比普通模组更晚加载，这样能捕获到其它模组对
-- inst.LaunchProjectile 的改动，改为委托而不是互相覆盖
priority = -100

server_filter_tags = { "flingomatic" }

configuration_options =
{
    {
        name = "enable_attack",
        label = Adaptive("Auto Attack", "自动攻击", "自動攻擊"),
        hover = Adaptive(
            "Enable automatic targeting and firing.",
            "开启后自动索敌并开火。",
            "開啟後自動索敵並開火。"
        ),
        options =
        {
            { description = Adaptive("Off", "关闭", "關閉"), data = false },
            { description = Adaptive("On", "开启", "開啟"), data = true },
        },
        default = true,
    },

    {
        name = "attack_range",
        label = Adaptive("Range", "射程", "射程"),
        hover = Adaptive(
            "Search radius for hostile creatures. Vanilla fire detection range is 15.",
            "索敌半径，原版火焰侦测范围是 15。",
            "索敵半徑，原版火焰偵測範圍是 15。"
        ),
        options =
        {
            { description = "25", data = 25 },
            { description = "30", data = 30 },
            { description = "35", data = 35 },
            { description = "40", data = 40 },
        },
        default = 35,
    },

    {
        name = "speed_by_distance",
        label = Adaptive("High Arc Trajectory", "大抛物线弹道", "大拋物線彈道"),
        hover = Adaptive(
            "Same formula as the SimpleGame mod: speed scales with range and the default high-arc solver is kept, so shots lob high and far. Off = vanilla speed curve (15~18) with only the minimum speed needed to reach.",
            "与 SimpleGame 相同的算法：速度按射程放大，并保留默认的高抛解算，弹道会高高抛起再落下。关闭则沿用原版速度曲线（15~18），远距离只用“刚好够打到”的速度。",
            "與 SimpleGame 相同的算法：速度按射程放大，並保留預設的高拋解算，彈道會高高拋起再落下。關閉則沿用原版速度曲線（15~18），遠距離只用「剛好夠打到」的速度。"
        ),
        options =
        {
            { description = Adaptive("Off", "关闭", "關閉"), data = false },
            { description = Adaptive("On", "开启", "開啟"), data = true },
        },
        default = true,
    },

    {
        name = "speed_mult",
        label = Adaptive("Speed Multiplier", "弹速倍率", "彈速倍率"),
        hover = Adaptive(
            "Extra multiplier on the projectile speed. 1x matches SimpleGame. Higher = even steeper and longer-hanging arc, lower = flatter and faster.",
            "在基准速度上再乘一个倍数。1 倍 = 与 SimpleGame 一致；越高抛物线越陡、滞空越久，越低越平越快。",
            "在基準速度上再乘一個倍數。1 倍 = 與 SimpleGame 一致；越高拋物線越陡、滯空越久，越低越平越快。"
        ),
        options =
        {
            { description = Adaptive("0.8x", "0.8 倍", "0.8 倍"), data = 0.8 },
            { description = Adaptive("1x", "1 倍", "1 倍"), data = 1 },
            { description = Adaptive("1.25x", "1.25 倍", "1.25 倍"), data = 1.25 },
            { description = Adaptive("1.5x", "1.5 倍", "1.5 倍"), data = 1.5 },
        },
        default = 1,
    },

    {
        name = "max_targets",
        label = Adaptive("Targets per Volley", "同时攻击目标数", "同時攻擊目標數"),
        hover = Adaptive(
            "How many enemies are fired at in the same volley (one snowball each).",
            "每轮齐射同时攻击几个敌人（每个敌人各发一颗雪球）。",
            "每輪齊射同時攻擊幾個敵人（每個敵人各發一顆雪球）。"
        ),
        options =
        {
            { description = "1", data = 1 },
            { description = "2", data = 2 },
            { description = "3", data = 3 },
            { description = "4", data = 4 },
            { description = "5", data = 5 },
        },
        default = 3,
    },

    {
        name = "attack_interval",
        label = Adaptive("Interval", "攻击间隔", "攻擊間隔"),
        hover = Adaptive(
            "Seconds between two auto attacks. The state graph animation cycle is roughly 1s, so values below that are effectively capped by the animation.",
            "两次自动攻击之间的秒数。开火动画一轮约 1 秒，低于这个值的设置实际上会被动画卡住。",
            "兩次自動攻擊之間的秒數。開火動畫一輪約 1 秒，低於這個值的設定實際上會被動畫卡住。"
        ),
        options =
        {
            { description = "0.25s", data = 0.25 },
            { description = "0.5s", data = 0.5 },
            { description = "1s", data = 1 },
            { description = "2s", data = 2 },
        },
        default = 0.25,
    },

    {
        name = "attack_damage",
        label = Adaptive("Damage", "伤害", "傷害"),
        hover = Adaptive(
            "Extra damage to enemies within 4 units of the impact point. 0 = freeze only (vanilla-like).",
            "命中点 4 格内敌人额外受到的伤害。0 = 只冰冻不伤害（接近原版）。",
            "命中點 4 格內敵人額外受到的傷害。0 = 只冰凍不傷害（接近原版）。"
        ),
        options =
        {
            { description = "0", data = 0 },
            { description = "10", data = 10 },
            { description = "20", data = 20 },
            { description = "34", data = 34 },
            { description = "50", data = 50 },
        },
        default = 0,
    },

    {
        name = "consume_fuel",
        label = Adaptive("Fuel Cost", "消耗燃料", "消耗燃料"),
        hover = Adaptive(
            "Each auto attack consumes some fuel.",
            "每次自动攻击额外消耗一点燃料。",
            "每次自動攻擊額外消耗一點燃料。"
        ),
        options =
        {
            { description = Adaptive("No", "否", "否"), data = false },
            { description = Adaptive("Yes", "是", "是"), data = true },
        },
        default = false,
    },
}
