--[[
    MiniMap —— 更小、更紧凑的世界生成
    ============================================================
    为什么逻辑在这个文件里：
      DST 的普通模式会先加载 modworldgenmain.lua 再加载 modmain.lua，
      但「世界生成」阶段只加载 modworldgenmain.lua（见 scripts/mods.lua）。
      世界生成的钩子必须写在这里才会生效。

    沙箱限制（见 scripts/mods.lua 的 CreateEnvironment）：
      只有 pairs / ipairs / print / math / table / type / string / tostring /
      require / Class / GLOBAL / WORLD_TILES / LOCKS / KEYS / LEVELTYPE 等，
      没有 tonumber、unpack、next、pcall、rawget、rawset —— 请不要直接使用。
      rawget / rawset 用下面的本地别名（从 GLOBAL 里取）代替，
      访问 _G 上的其他东西也一律走 GLOBAL.xxx。

    ------------------------------------------------------------------
    收缩原则：只做几何上的收缩，群落和内容种类一个都不裁。
      · 群落（任务 / 可选任务）保持原版，一个都不删
      · 房间种类、布景、海洋布景全部保留
    唯一的「减量」是为了达到目标边长：按比例减少「重复房间」的份数
    （每种房间至少保留 1 份），并且带自适应重试，见下面的「目标地图尺寸」。

    仍然生效的收缩手段：
      1) 目标尺寸：压缩重复房间份数，把边长压到目标以下（默认 300 x 300）
      2) 环形主大陆：分支拉到最小（branching=never）+ 首尾相连（loop=always），
         主大陆绕成一圈，中间的空地会被 Ocean_ConvertImpassibleToWater 变成内海
      3) 关闭 cove 死角节点（AddCoveNodes 会给每个房间再加 0.35 个节点）
      4) 背景填充节点减半
      5) 不让新群落变成孤立小岛、收窄浅海
      6) 放宽世界边长下限（引擎的边长档位只是下限）
      7) 奶奶岛 / 猴岛放进环内内海（找不到再退回贴岸），
         月岛挂到靠中心的节点上，尺寸也能单独缩小
]]

-- 世界生成沙箱（mods.lua:CreateEnvironment）没有把 rawget / rawset 放进 env，
-- 直接用会报 “attempt to call global 'rawget' (a nil value)” 导致世界生成失败。
-- GLOBAL 就是真正的 _G，从里面取出来当本地函数用。
local rawget = GLOBAL.rawget
local rawset = GLOBAL.rawset

-- 注意：不能设成 none。charlie_stage_post / terrariumchest / statueharp_hedgespawner /
-- balatro_machine 都是靠「背景房间」的 tags 放置的，没有背景节点会直接缺 prefab 导致生成失败
local BG_MODE = GetModConfigData("minimap_bg") or "half"
local WSIZE_MODE = GetModConfigData("minimap_world_size") or "small"

-- 活动 / 彩蛋内容：stageplays 会把 charlie_stage_post 和 statueharp_hedgespawner 一起干掉，
-- balatro 对应 balatro_machine，terrariumchest 对应泰拉瑞亚箱子
local EVENT_MODE = GetModConfigData("minimap_events") or "basic"

-- 环形主大陆（分支最小 + 首尾相连）
local RING = GetModConfigData("minimap_ring")
if RING == nil then RING = true end

-- 岛屿位置：keep = 原版 / near = 靠岸 / 其余 = 环内内海（默认）
--   注意：1.6.0 之前的旧存档里存的是 "moon" / "both" / "hermit"，
--   这些旧值也要当成「环内」，否则老世界升级后环内逻辑整个不生效。
local ISLANDS_MODE = GetModConfigData("minimap_islands") or "center"
local PREFER_CENTER = (ISLANDS_MODE ~= "keep"
    and ISLANDS_MODE ~= "near"
    and ISLANDS_MODE ~= "hermit")   -- 1.5 的「奶奶岛靠岸」旧值，等价于 near

local NARROW_SHALLOW = GetModConfigData("minimap_shallow")
if NARROW_SHALLOW == nil then NARROW_SHALLOW = true end

local SHRINK_CAVES = GetModConfigData("minimap_caves")
if SHRINK_CAVES == nil then SHRINK_CAVES = true end

-- 地面沉洞（通往洞穴的洞）数量上限
--   原版是 tasksets/forest.lua 里的 set_pieces.CaveEntrance.count = 10，
--   Level:ChooseSetPieces() 会给每个候选任务塞一个，最多 10 个洞。
local SINKHOLE_MAX = GetModConfigData("minimap_sinkholes")
if type(SINKHOLE_MAX) ~= "number" or SINKHOLE_MAX <= 0 then
    SINKHOLE_MAX = 4
end

------------------------------------------------------------------------------------------
-- 目标地图尺寸
--   DST 的 world_size 只是「下限」，最终边长由房间节点数量决定（原版小图约 415 x 415），
--   所以要把地图压到 N x N 以下，唯一的手段就是压缩每个群落里「重复房间」的份数
--   （房间种类、布景、内容一个都不删，只减少重复份数）。
--   带自适应重试：
--     · 生成失败（forest_map.Generate 返回 nil）→ 放宽比例（地图变大）再试
--     · 生成成功但边长仍超过目标 → 收紧一次比例再试
--     · 调整次数用尽就接受当前结果，不会把世界生成拖到彻底失败
------------------------------------------------------------------------------------------

local TARGET_SIZE = GetModConfigData("minimap_target_size")
if type(TARGET_SIZE) ~= "number" or TARGET_SIZE < 200 then
    TARGET_SIZE = 0        -- 0 = 不限制
end

local SHRINK_START = 0.55   -- 初始压缩比例（房间份数）
local SHRINK_MIN = 0.30
local SHRINK_UP = 0.15      -- 生成失败：放宽（地图变大）
local SHRINK_DOWN = 0.10    -- 仍然太大：收紧
local MAX_ADJUST = 3        -- 最多调整 3 次（系统一共给 5 次机会）

local shrink_ratio = SHRINK_START
local adjust_count = 0
local tighten_done = false
local ORIGINAL_ROOM_CHOICES = {}

-- room_choices 里的数量既可能是数字，也可能是 function() return <数字> end
local function ShrinkRoomChoices(room_choices, k)
    local result = {}
    for name, count in pairs(room_choices) do
        if type(count) == "number" then
            result[name] = math.max(1, math.floor(count * k + 0.5))
        elseif type(count) == "function" then
            result[name] = function()
                local n = count()
                if type(n) ~= "number" then
                    return 1
                end
                return math.max(1, math.floor(n * k + 0.5))
            end
        else
            result[name] = count
        end
    end
    return result
end

------------------------------------------------------------------------------------------
-- 群落 / 房间：不做任何裁剪，只做一处几何修正
--   （月岛房间数量的缩放单独在下面的「月岛尺寸」里处理）
------------------------------------------------------------------------------------------

local function AdjustTask(task)
    if type(task) ~= "table" or task._minimap_adjusted then
        return
    end
    task._minimap_adjusted = true

    -- 关闭 cove 死角：AddCoveNodes 里 cove_room_chance == 0 会直接 return 整个函数
    -- 月岛任务同样生效，少掉一圈无关的 cove 节点
    task.cove_room_chance = 0
end

local function AdjustTaskList(tasklist)
    if type(tasklist) ~= "table" then
        return
    end
    for _, task in ipairs(tasklist) do
        AdjustTask(task)
    end
end

------------------------------------------------------------------------------------------
-- 世界边长：引擎的 sizes 表只认 tiny/small/medium/default/large/huge
--   未知取值会回落到 350（见 scripts/map/forest_map.lua 的 min_size 逻辑）
--   实测：min_size 只是下限，最终尺寸由内容决定
------------------------------------------------------------------------------------------

local WORLD_SIZE_RANK =
{
    ["tiny"]    = 0,
    ["small"]   = 0,
    ["medium"]  = 1,
    ["compact"] = 1,   -- 哨兵值：引擎回落 350
    ["default"] = 2,
    ["large"]   = 2,
    ["huge"]    = 3,
}

local TARGET_WORLD_SIZE = nil
if WSIZE_MODE == "small" then
    TARGET_WORLD_SIZE = { key = "small", rank = 0 }
elseif WSIZE_MODE == "medium" then
    TARGET_WORLD_SIZE = { key = "medium", rank = 1 }
elseif WSIZE_MODE == "compact" then
    TARGET_WORLD_SIZE = { key = "compact", rank = 1 }
end

------------------------------------------------------------------------------------------
-- 包一层 forest_map.Generate：
--   进入前按目标尺寸压缩房间份数，返回后读 save.map.width/height 判断是否达标，
--   不达标/生成失败就调整比例交给系统的重试机制再来一次
------------------------------------------------------------------------------------------

local HOOKED = false

local function ApplyTargetShrink(tasks, is_cave)
    if TARGET_SIZE <= 0 or (is_cave and not SHRINK_CAVES) then
        return
    end
    for _, task in ipairs(tasks or {}) do
        local id = task.id
        local choices = task.room_choices
        -- 月岛任务由「月岛尺寸」单独控制，这里跳过，免得被压两次
        -- （"MoonIsland_" 是 11 个字符，sub 1..11 正好是它）
        if type(id) == "string" and type(choices) == "table"
            and string.sub(id, 1, 11) ~= "MoonIsland_" then
            local orig = ORIGINAL_ROOM_CHOICES[id]
            if orig == nil then
                orig = {}
                for name, count in pairs(choices) do
                    orig[name] = count
                end
                ORIGINAL_ROOM_CHOICES[id] = orig
            end
            task.room_choices = ShrinkRoomChoices(orig, shrink_ratio)
        end
    end
end

local function HookWorldGen()
    if HOOKED then
        return
    end
    HOOKED = true

    local ForestMap = require("map/forest_map")
    if type(ForestMap) ~= "table" or type(ForestMap.Generate) ~= "function" then
        return
    end

    local old_generate = ForestMap.Generate
    ForestMap.Generate = function(prefab, map_width, map_height, tasks, level, level_type)
        local is_cave = (type(level) == "table" and level.location == "cave")
        ApplyTargetShrink(tasks, is_cave)

        local save = old_generate(prefab, map_width, map_height, tasks, level, level_type)

        local width = (type(save) == "table" and type(save.map) == "table" and save.map.width) or 0
        local height = (type(save) == "table" and type(save.map) == "table" and save.map.height) or 0
        local size = math.max(width, height)

        if save ~= nil then
            print(string.format("[MiniMap] 最终地图尺寸: %d x %d 格（目标 %d，房间份数 %.0f%%）",
                width, height, TARGET_SIZE, shrink_ratio * 100))
        end

        if TARGET_SIZE <= 0 or adjust_count >= MAX_ADJUST then
            return save
        end

        if save == nil then
            -- 放不下 / PANIC：放宽压缩（地图变大）后重试
            adjust_count = adjust_count + 1
            shrink_ratio = math.min(1, shrink_ratio + SHRINK_UP)
            print(string.format("[MiniMap] 世界生成失败，放宽到 %.0f%% 再试（第 %d/%d 次调整）",
                shrink_ratio * 100, adjust_count, MAX_ADJUST))
            return nil
        end

        if size > TARGET_SIZE and not tighten_done then
            -- 成功了但还是太大：收紧一次再生成，尽量压到目标以下
            tighten_done = true
            adjust_count = adjust_count + 1
            shrink_ratio = math.max(SHRINK_MIN, shrink_ratio - SHRINK_DOWN)
            print(string.format("[MiniMap] 超过目标尺寸，收紧到 %.0f%% 再生成一次", shrink_ratio * 100))
            return nil
        end

        adjust_count = 0
        tighten_done = false
        return save
    end
end

------------------------------------------------------------------------------------------
-- 世界创建界面：把「世界大小」的默认值显示成「小」
--   界面上的当前值是 option.default，来源见 scripts/map/customize.lua:953-996：
--     取 Levels.GetDataForLocation(location).overrides[option.name]，
--     地点没定义时用 customize.lua 里写死的 value = "default"。
--   所以这里直接改这三个函数的返回值，只动「默认值」：
--   玩家自己在界面里选了中/大，仍然以玩家的选择为准（生成时也不会被改小）。
--   只在「世界边长下限 = 极小(50)」时生效，其它档位不动界面。
------------------------------------------------------------------------------------------

local DEFAULT_WORLD_SIZE = "small"

local function OverrideWorldSizeDefault(options, location, Levels)
    if type(options) ~= "table" then
        return options
    end
    -- 地点自己显式定义了 world_size 时不覆盖（避免踩到别的模组/自定义地点）
    local data = Levels.GetDataForLocation(location)
    if type(data) == "table" and type(data.overrides) == "table"
        and data.overrides.world_size ~= nil then
        return options
    end
    for _, option in ipairs(options) do
        if type(option) == "table" and option.name == "world_size" then
            option.default = DEFAULT_WORLD_SIZE
        end
    end
    return options
end

local function HookWorldSizeDefault()
    if WSIZE_MODE ~= "small" then
        return
    end
    if rawget(GLOBAL, "_minimap_worldsize_hooked") == true then
        return
    end

    local Customize = require("map/customize")
    local Levels = require("map/levels")
    if type(Customize) ~= "table" or type(Levels) ~= "table" then
        return
    end
    rawset(GLOBAL, "_minimap_worldsize_hooked", true)

    -- 三个入口：旧版世界设置页、新版世界生成页 / 世界设置页
    for _, fname in ipairs(
    {
        "GetOptionsWithLocationDefaults",
        "GetWorldGenOptionsWithLocationDefaults",
        "GetWorldSettingsOptionsWithLocationDefaults",
    }) do
        local old = Customize[fname]
        if type(old) == "function" then
            Customize[fname] = function(location, is_master_world)
                return OverrideWorldSizeDefault(old(location, is_master_world), location, Levels)
            end
        end
    end
end

-- 世界生成进程里没有设置界面，不用挂（WORLDGEN_MAIN 见 scripts/worldgen_main.lua:24）
if rawget(GLOBAL, "WORLDGEN_MAIN") ~= 1 then
    HookWorldSizeDefault()
end

------------------------------------------------------------------------------------------
-- 海洋布景：不再做去重，OceanXXX 房间的 countstaticlayouts 保持原版
--   （唯一的改动是猴岛 / 奶奶岛的落点，见下面的「岛屿放置」；勾上钩子后为了不重复生成，
--     才会把这两个布局从海洋房间里摘掉，见 TrimOceanRooms 末尾）
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- 岛屿放置（猴岛 / 奶奶岛）
--   原版把这两座岛交给海洋布景随机放置：在地图上随便找一片符合条件的水域，
--   OCEAN_ROUGH 是离岸最远的深水带，落点又完全随机，所以经常孤零零飘在很远的角落。
--   这里改成自己放，按「环内内海 → 贴岸 → 原版」的顺序找位置：
--     1) 环形主大陆中间是一片内海，优先把岛放进去（岛屿位置 = 环内中心）
--     2) 找不到再退回「离陆地最近的一层」（岛屿位置 = 靠岸）
--     3) 实在找不到就交给原版逻辑，保证不会丢岛
------------------------------------------------------------------------------------------

local MONKEY_LAYOUT_LARGE = "MonkeyIsland"
local MONKEY_LAYOUT_SMALL = "MonkeyIslandSmall"
local HERMIT_LAYOUT = "HermitcrabIsland"
local LAND_DIST_LIMIT = 40
local NEAR_LAYER_LIMIT = 12        -- 贴岸模式只在离陆地 12 格以内找位置
local NEAR_ANCHORS_PER_LAYER = 24

-- 原版 Ocean_PlaceSetPieces，兜底时用
local ORIG_OCEAN_PLACE_SETPIECES = nil

local function GetLayoutSize(layout, prefabs)
    local size = 2
    if type(layout.ground) == "table" then
        size = math.max(size, #layout.ground)
    elseif type(prefabs) == "table" then
        local xmin, ymin, xmax, ymax = 1e9, 1e9, -1e9, -1e9
        for i = 1, #prefabs do
            local p = prefabs[i]
            if type(p) == "table" then
                if type(p.x) == "number" then
                    xmin = math.min(xmin, p.x)
                    xmax = math.max(xmax, p.x)
                end
                if type(p.y) == "number" then
                    ymin = math.min(ymin, p.y)
                    ymax = math.max(ymax, p.y)
                end
            end
        end
        size = math.ceil((layout.scale or 1) * math.max(xmax - xmin, ymax - ymin))
    end
    return math.max(2, size)
end

-- 到陆地的曼哈顿距离场：陆地 0，海洋 >0，IMPASSABLE 与超出范围的是 -1
local function BuildLandDistanceField(world, width, height)
    local dist = {}
    local queue = {}
    local tail = 0

    local is_land_tile = rawget(GLOBAL, "IsLandTile")
    local world_tiles = rawget(GLOBAL, "WORLD_TILES") or WORLD_TILES
    local impassable = world_tiles and world_tiles.IMPASSABLE

    for y = 0, height - 1 do
        local row = {}
        dist[y] = row
        for x = 0, width - 1 do
            local tile = world:GetTile(x, y)
            if type(tile) == "number" and type(is_land_tile) == "function" and is_land_tile(tile) then
                row[x] = 0
                tail = tail + 1
                queue[tail] = y * width + x
            elseif impassable ~= nil and tile == impassable then
                row[x] = -1
            else
                row[x] = LAND_DIST_LIMIT + 1
            end
        end
    end

    local head = 1
    while head <= tail do
        local idx = queue[head]
        head = head + 1
        local x = idx % width
        local y = (idx - x) / width
        local d = dist[y][x]
        if d >= 0 and d < LAND_DIST_LIMIT then
            local nd = d + 1
            if x > 0 and dist[y][x - 1] > nd then
                dist[y][x - 1] = nd
                tail = tail + 1
                queue[tail] = idx - 1
            end
            if x < width - 1 and dist[y][x + 1] > nd then
                dist[y][x + 1] = nd
                tail = tail + 1
                queue[tail] = idx + 1
            end
            if y > 0 and dist[y - 1][x] > nd then
                dist[y - 1][x] = nd
                tail = tail + 1
                queue[tail] = idx - width
            end
            if y < height - 1 and dist[y + 1][x] > nd then
                dist[y + 1][x] = nd
                tail = tail + 1
                queue[tail] = idx + width
            end
        end
    end

    return dist
end

local function SlotFree(world, dist, x, y, size, min_clear, ignore_reserved)
    if type(dist[y]) ~= "table" or type(dist[y + size - 1]) ~= "table" then
        return false
    end
    for yy = y, y + size - 1 do
        local row = dist[yy]
        for xx = x, x + size - 1 do
            local d = row[xx]
            if type(d) ~= "number" or d < min_clear then
                return false
            end
            if not ignore_reserved and world:IsTileReserved(xx, yy) then
                return false
            end
        end
    end
    return true
end

-- 复刻 ocean_gen.lua 里的 AddSquareTopology（它是局部函数，mod 拿不到）。
-- 猴岛布局带 add_topology，世界生成后 MonkeyIsland_GenerateDocks 要靠这个节点生成码头。
local function AddSquareTopology(world, encoded_topology, tile_left, tile_top, area_size, map_width, map_height, add_topology)
    if type(encoded_topology) ~= "table" or type(encoded_topology.ids) ~= "table"
        or type(encoded_topology.nodes) ~= "table" or type(encoded_topology.story_depths) ~= "table"
        or type(add_topology) ~= "table" then
        return
    end

    local tile_scale = rawget(GLOBAL, "TILE_SCALE")
    local node_type = rawget(GLOBAL, "NODE_TYPE")
    if type(tile_scale) ~= "number" or type(node_type) ~= "table" then
        return
    end

    local left = tile_left * tile_scale - (map_width * 0.5 * tile_scale)
    local top = tile_top * tile_scale - (map_height * 0.5 * tile_scale)
    local size = area_size * tile_scale

    local index = #encoded_topology.ids + 1
    encoded_topology.ids[index] = add_topology.room_id
    encoded_topology.story_depths[index] = 0

    local node = {}
    node.area = size * size
    node.c = 1
    node.cent = { left + size / 2, top + size / 2 }
    node.neighbours = {}
    node.poly =
    {
        { left, top },
        { left + size, top },
        { left + size, top + size },
        { left, top + size },
    }
    node.tags = add_topology.tags
    node.type = add_topology.node_type or node_type.Default
    node.x = node.cent[1]
    node.y = node.cent[2]
    node.validedges = {}
    encoded_topology.nodes[index] = node

    for x = tile_left, tile_left + area_size do
        for y = tile_top, tile_top + area_size do
            world:SetTileNodeId(x, y, index)
        end
    end
end

local function MakeOceanAddEntity(entitiesOut, width, height)
    -- 注意参数形态（见 object_layout.lua:481）：
    --   add_entity.fn(prefab, {x}, {y}, 1, entitiesOut, width, height, prefab_list, prefab_data, false)
    -- points_x / points_y 是「数组」，pos_idx 才是下标；
    -- 而 PopulateWorld_AddEntity（graphnode.lua:188）要的是单个数字坐标，
    -- 直接传数组会崩在 (tile_x - width/2)。
    local add_entity =
    {
        fn = function(prefab, points_x, points_y, pos_idx, ents, w, h, prefab_list, prefab_data, rand_offset)
            local add_one = rawget(GLOBAL, "PopulateWorld_AddEntity")
            if type(add_one) ~= "function" then
                return
            end

            local i = pos_idx or 1
            local px = (type(points_x) == "table") and points_x[i] or points_x
            local py = (type(points_y) == "table") and points_y[i] or points_y
            if type(px) ~= "number" or type(py) ~= "number" then
                return
            end

            add_one(prefab, px, py, nil, ents, w, h, prefab_list, prefab_data, rand_offset)
        end,
        args =
        {
            entitiesOut = entitiesOut,
            width = width,
            height = height,
            rand_offset = true,
            -- PopulateWorld_AddEntity 会往这个表里累加计数，不能给 nil
            debug_prefab_list = {},
        },
    }
    return add_entity
end

-- 把布局放到 (x, y)，并把这些格子标记为已占用
local function PlaceLayoutAt(world, obj_layout, layout, prefabs, add_entity, x, y, size, encoded_topology, width, height)
    obj_layout.ReserveAndPlaceLayout("POSITIONED", layout, prefabs, add_entity, { x, y }, world)
    for yy = y, y + size - 1 do
        for xx = x, x + size - 1 do
            world:ReserveTile(xx, yy)
        end
    end
    if type(layout.add_topology) == "table" then
        AddSquareTopology(world, encoded_topology, x, y, size, width, height, layout.add_topology)
    end
end

-- 环内内海：找离地图中心最近的可用方形空位
--   min_clear = 1 表示允许紧贴主大陆（水域最外一圈），这样内海窄一点也能塞进去
local function FindCenterSlot(world, dist, width, height, size, edge, ignore_reserved)
    local cx, cy = (width - 1) * 0.5, (height - 1) * 0.5
    local best, best_d = nil, math.huge
    -- 步长取 size/4，环内的缝比较窄时也不会漏掉
    local step = math.max(1, math.floor(size / 4))

    local x = edge
    while x + size - 1 <= width - edge - 1 do
        local y = edge
        while y + size - 1 <= height - edge - 1 do
            local dx = x + size * 0.5 - cx
            local dy = y + size * 0.5 - cy
            local d = dx * dx + dy * dy
            if d < best_d and SlotFree(world, dist, x, y, size, 1, ignore_reserved) then
                best_d = d
                best = { x, y }
            end
            y = y + step
        end
        x = x + step
    end

    return best
end

-- 贴岸：从离陆地最近的一层开始，找能塞下整个布局的方形空位
local function FindNearShoreSlot(world, dist, width, height, size, edge, ignore_reserved)
    local buckets = {}
    for y = 0, height - 1 do
        local row = dist[y]
        for x = 0, width - 1 do
            local d = row[x]
            if type(d) == "number" and d >= 1 and d <= NEAR_LAYER_LIMIT then
                local b = buckets[d]
                if b == nil then
                    b = {}
                    buckets[d] = b
                end
                b[#b + 1] = y * width + x
            end
        end
    end

    for d = 1, NEAR_LAYER_LIMIT do
        local anchors = buckets[d]
        if anchors ~= nil then
            for i = #anchors, 2, -1 do
                local j = math.random(i)
                anchors[i], anchors[j] = anchors[j], anchors[i]
            end

            local tries = math.min(#anchors, NEAR_ANCHORS_PER_LAYER)
            for i = 1, tries do
                local idx = anchors[i]
                local ax = idx % width
                local ay = (idx - ax) / width

                -- 锚点当作布局的四个角之一，取最先可用的一种
                local corners =
                {
                    { ax, ay },
                    { ax - size + 1, ay },
                    { ax, ay - size + 1 },
                    { ax - size + 1, ay - size + 1 },
                }

                for _, corner in ipairs(corners) do
                    local x, y = corner[1], corner[2]
                    if x >= edge and y >= edge
                        and x + size - 1 <= width - edge - 1
                        and y + size - 1 <= height - edge - 1
                        and SlotFree(world, dist, x, y, size, 1, ignore_reserved) then
                        return { x, y }, d
                    end
                end
            end
        end
    end

    return nil
end

-- 放一座海洋岛屿；返回 true 表示已经放好
--   candidates 可以是单个布局名，也可以是按优先级排列的表（比如猴岛大号 → 小号）
--   顺序：环内内海（离地图中心最近）→ 贴岸 → 返回 false 交给原版兜底
local function PlaceOceanIsland(candidates, label, entitiesOut, width, height, encoded_topology, prefer_center)
    if type(entitiesOut) ~= "table" or type(width) ~= "number" or type(height) ~= "number" then
        return false
    end

    local world = rawget(GLOBAL, "WorldSim")
    local obj_layout = require("map/object_layout")
    if world == nil or type(obj_layout) ~= "table"
        or type(obj_layout.LayoutForDefinition) ~= "function" then
        return false
    end

    local list = type(candidates) == "table" and candidates or { candidates }
    local edge = (rawget(GLOBAL, "OCEAN_WATERFALL_MAX_DIST") or 8) + 2

    -- 把所有候选布局整理成「名字 + 布局 + 尺寸」，放不下的直接跳过
    local infos = {}
    for _, name in ipairs(list) do
        local layout = obj_layout.LayoutForDefinition(name)
        if type(layout) == "table" then
            local prefabs = obj_layout.ConvertLayoutToEntitylist(layout)
            local size = GetLayoutSize(layout, prefabs)
            if size + edge * 2 < width and size + edge * 2 < height then
                infos[#infos + 1] = { name = name, layout = layout, prefabs = prefabs, size = size }
            end
        end
    end
    if #infos == 0 then
        return false
    end

    local add_entity = MakeOceanAddEntity(entitiesOut, width, height)
    local dist = BuildLandDistanceField(world, width, height)

    -- 1) 环内内海（离地图中心最近）  2) 贴岸（离陆地最近的一圈水域）
    --    先严格要求不压到已占用格子；实在放不下再忽略占用情况，宁可压一点也别丢岛
    local function try_place(ignore_reserved)
        if prefer_center then
            for _, info in ipairs(infos) do
                local slot = FindCenterSlot(world, dist, width, height, info.size, edge, ignore_reserved)
                if slot ~= nil then
                    PlaceLayoutAt(world, obj_layout, info.layout, info.prefabs, add_entity, slot[1], slot[2], info.size, encoded_topology, width, height)
                    print(string.format("[MiniMap] %s（%s）放进环内中心：(%d, %d)%s",
                        label, info.name, slot[1], slot[2], ignore_reserved and "（忽略已占用格）" or ""))
                    return true
                end
            end
        end

        for _, info in ipairs(infos) do
            local slot, layer = FindNearShoreSlot(world, dist, width, height, info.size, edge, ignore_reserved)
            if slot ~= nil then
                PlaceLayoutAt(world, obj_layout, info.layout, info.prefabs, add_entity, slot[1], slot[2], info.size, encoded_topology, width, height)
                print(string.format("[MiniMap] %s（%s）贴岸放置：离陆地约 %d 格，(%d, %d)%s",
                    label, info.name, layer, slot[1], slot[2], ignore_reserved and "（忽略已占用格）" or ""))
                return true
            end
        end

        return false
    end

    if try_place(false) then
        return true
    end
    return try_place(true)
end

-- 兜底：交给原版海洋布景逻辑随机找位置
local function PlaceOceanIslandVanilla(name, entitiesOut, width, height, encoded_topology, min_dist_from_land)
    local world_tiles = rawget(GLOBAL, "WORLD_TILES") or WORLD_TILES
    local obj_layout = require("map/object_layout")
    if type(ORIG_OCEAN_PLACE_SETPIECES) ~= "function" or world_tiles == nil then
        return
    end
    local add_entity = MakeOceanAddEntity(entitiesOut, width, height)
    local set_pieces = {}
    set_pieces[name] = 1
    ORIG_OCEAN_PLACE_SETPIECES(set_pieces, add_entity, obj_layout, world_tiles.OCEAN_ROUGH,
        min_dist_from_land, encoded_topology, width, height)
end

local OCEAN_TRIMMED = false

-- 直接改 Rooms 表：确保 ocean_gen 读到的是调整后的内容（现在只剩三件事：
-- 删掉「猴岛必须存在」的要求、决定猴岛 / 奶奶岛的落点，不再裁剪任何静态布景）
local function TrimOceanRooms(is_cave)
    if OCEAN_TRIMMED or is_cave then
        return
    end
    OCEAN_TRIMMED = true

    local Rooms = require("map/rooms")
    if type(Rooms) ~= "table" or type(Rooms.GetRoomByName) ~= "function" then
        return
    end

    -- 地图缩得很小以后，海洋环带放不下这些布景；如果还硬性要求它们存在，
    -- 世界生成会连续 PANIC 直到失败（forest_map.lua:945-974 会检查
    -- storygen.ocean_population 里每个海洋房间的 required_prefabs）。
    -- 这里只取消「必须存在」的要求：有位置照样生成，没位置也不会让世界生成失败。
    --   monkeyqueen              猴岛
    --   hermithouse_construction1 奶奶岛的房子
    --   oceanwhirlbigportal      大漩涡
    local OCEAN_ROOMS =
    {
        "OceanCoastalShore",
        "OceanCoastal",
        "OceanSwell",
        "OceanRough",
        "OceanHazardous",
    }

    local OCEAN_REQUIRED_DROP =
    {
        ["monkeyqueen"] = true,
        ["hermithouse_construction1"] = true,
        ["oceanwhirlbigportal"] = true,
    }

    for _, roomname in ipairs(OCEAN_ROOMS) do
        local room = Rooms.GetRoomByName(roomname)
        if type(room) == "table" and type(room.required_prefabs) == "table" then
            local kept = {}
            for _, name in ipairs(room.required_prefabs) do
                if OCEAN_REQUIRED_DROP[name] ~= true then
                    kept[#kept + 1] = name
                end
            end
            room.required_prefabs = kept
        end
    end

    -- 奶奶岛（珍珠岛）从深海搬到近岸海域：OceanRough → OceanCoastal
    -- 环内中心模式不走这里，改由下面的 PopulateOcean 钩子自己放
    if ISLANDS_MODE == "near" or ISLANDS_MODE == "hermit" then
        local rough = Rooms.GetRoomByName("OceanRough")
        local coastal = Rooms.GetRoomByName("OceanCoastal")
        if type(rough) == "table" and type(coastal) == "table"
            and type(rough.contents) == "table" and type(coastal.contents) == "table" then
            local rl = rough.contents.countstaticlayouts
            local cl = coastal.contents.countstaticlayouts
            if type(rl) == "table" and type(cl) == "table" and rl["HermitcrabIsland"] ~= nil then
                cl["HermitcrabIsland"] = rl["HermitcrabIsland"]
                rl["HermitcrabIsland"] = nil
            end
        end
    end

    -- 岛屿位置 = 保持原版：完全不接管，全部交给原版逻辑
    if ISLANDS_MODE == "keep" then
        return
    end

    -- 包一层 PopulateOcean：原版把海洋布景放完之后，自己把猴岛 / 奶奶岛放到选好的位置。
    -- 只有挂上了钩子才把这两座岛从房间表里摘掉，否则保留原版行为（宁可放得远，也不要丢岛）。
    -- 注意：世界生成环境启用了 strict.lua，往 _G 上新增/读取未声明字段都会直接 error，
    -- 所以这里一律用 rawget / rawset。
    ORIG_OCEAN_PLACE_SETPIECES = rawget(GLOBAL, "Ocean_PlaceSetPieces")
    if type(rawget(GLOBAL, "PopulateOcean")) == "function" and rawget(GLOBAL, "_minimap_ocean_hooked") ~= true then
        rawset(GLOBAL, "_minimap_ocean_hooked", true)
        local orig_populate_ocean = rawget(GLOBAL, "PopulateOcean")
        rawset(GLOBAL, "PopulateOcean", function(spawnFn, entitiesOut, width, height, ocean_contents, world_gen_choices, min_dist_from_land, encoded_topology)
            -- 地图变小以后海洋面积也变小，原版「布景必须离陆地 5 格」经常找不到位置，
            -- 导致 missing required prefab（大漩涡 / 奶奶岛房子）→ PANIC。
            -- 这里把余量放宽到 3 格，能放下就放下。
            local min_land_dist = min_dist_from_land or 0
            if min_land_dist > 3 then
                min_land_dist = 3
            end

            orig_populate_ocean(spawnFn, entitiesOut, width, height, ocean_contents, world_gen_choices, min_land_dist, encoded_topology)

            -- 环内中心模式：优先放进环形主大陆中间的内海
            local prefer_center = PREFER_CENTER

            if rawget(GLOBAL, "_minimap_hermit_todo") == true then
                if not PlaceOceanIsland({ HERMIT_LAYOUT }, "奶奶岛", entitiesOut, width, height, encoded_topology, prefer_center) then
                    print("[MiniMap] 没找到合适空位，奶奶岛回退到原版随机放置")
                    PlaceOceanIslandVanilla(HERMIT_LAYOUT, entitiesOut, width, height, encoded_topology, min_land_dist)
                end
            end

            if rawget(GLOBAL, "_minimap_monkey_todo") == true then
                local world = rawget(GLOBAL, "WorldSim")
                local world_size = world ~= nil and world:GetWorldSize() or 0
                -- 大地图优先大猴岛，塞不进环内再试小猴岛；小地图直接用小的
                local names = (type(world_size) == "number" and world_size >= 425)
                    and { MONKEY_LAYOUT_LARGE, MONKEY_LAYOUT_SMALL }
                    or { MONKEY_LAYOUT_SMALL }
                if not PlaceOceanIsland(names, "猴岛", entitiesOut, width, height, encoded_topology, prefer_center) then
                    print("[MiniMap] 没找到合适空位，猴岛回退到原版随机放置")
                    PlaceOceanIslandVanilla(names[1], entitiesOut, width, height, encoded_topology, min_land_dist)
                end
            end
        end)
    end

    if rawget(GLOBAL, "_minimap_ocean_hooked") == true then
        rawset(GLOBAL, "_minimap_monkey_todo", true)
        if PREFER_CENTER then
            rawset(GLOBAL, "_minimap_hermit_todo", true)
        end
        for _, roomname in ipairs(OCEAN_ROOMS) do
            local room = Rooms.GetRoomByName(roomname)
            local layouts = (type(room) == "table" and type(room.contents) == "table")
                and room.contents.countstaticlayouts or nil
            if type(layouts) == "table" then
                layouts[MONKEY_LAYOUT_LARGE] = nil
                layouts[MONKEY_LAYOUT_SMALL] = nil
                if PREFER_CENTER then
                    layouts[HERMIT_LAYOUT] = nil
                end
            end
        end
    end
end

------------------------------------------------------------------------------------------
-- 月岛尺寸
--   月岛保持原版的「独立区域」生成方式（region_id = "island1"，不清除、不并入主大陆），
--   只是把它自己的房间数量按比例缩一缩：月岛 5 个任务的 room_choices 决定岛的格子数，
--   减少重复房间就能让月岛小一圈，岛上的内容（祭坛、月石矿、浴场…）仍然原样保留。
--
--   注意：MoonIsland_Baths 带着 required_prefabs（月祭坛石块、junk_pile_big…），
--   缩得太狠可能放不下而触发 PANIC 重试，所以最小只给到 40%。
------------------------------------------------------------------------------------------

local MOON_TASKS =
{
    "MoonIsland_IslandShards",
    "MoonIsland_Beach",
    "MoonIsland_Forest",
    "MoonIsland_Baths",
    "MoonIsland_Mine",
}

local MOON_SIZE = GetModConfigData("minimap_moon_size")
if type(MOON_SIZE) ~= "number" or MOON_SIZE <= 0 or MOON_SIZE > 1 then
    MOON_SIZE = 0.6
end

if MOON_SIZE < 1 and type(AddTaskPreInit) == "function" then
    for _, taskname in ipairs(MOON_TASKS) do
        AddTaskPreInit(taskname, function(task)
            if type(task.room_choices) == "table" then
                task.room_choices = ShrinkRoomChoices(task.room_choices, MOON_SIZE)
            end
        end)
    end
end

------------------------------------------------------------------------------------------
-- 月岛挂到环内
--   原版 FindMainlandNodesForNewRegion 明确「绝不选中心桶」（storygen.lua:760），
--   于是独立区域永远被丢到最外圈的空位。环形主大陆时中心的内海才是目标位置：
--   这里改成挑「离主大陆包围盒中心最近」的两个节点，并且分居中心两侧，
--   让引擎把月岛的节点铺到环中间去。
--   （节点坐标是引擎算的，这里只能影响它挂在哪两个节点上，不能精确指定位置）
------------------------------------------------------------------------------------------

local MOON_CENTER_HOOKED = false

local function HookMoonRegionCenter()
    if MOON_CENTER_HOOKED or not PREFER_CENTER then
        return
    end
    MOON_CENTER_HOOKED = true

    local Story = require("map/storygen")
    if type(Story) ~= "table" or type(Story.FindMainlandNodesForNewRegion) ~= "function" then
        return
    end

    local old_find = Story.FindMainlandNodesForNewRegion
    Story.FindMainlandNodesForNewRegion = function(self)
        -- 排查用：这条打印出现说明已经进入本 Hook（用于区分崩溃点是在 Hook 内还是在更早的引擎阶段）
        print("[MiniMap] 月岛居中：开始挑环内锚点")
        local world = rawget(GLOBAL, "WorldSim")
        local terrain = (type(self) == "table") and self.TERRAIN or nil
        if world == nil or type(terrain) ~= "table" then
            return old_find(self)
        end

        -- 和原版一致：Blank 节点（闭环用的 LOOP_BLANK 等）不能当作主大陆锚点
        local node_type = rawget(GLOBAL, "NODE_TYPE")
        local blank_type = (type(node_type) == "table") and node_type.Blank or nil

        local pos = {}
        local count = 0
        local min_x, max_x = math.huge, -math.huge
        local min_y, max_y = math.huge, -math.huge
        for _, t in pairs(terrain) do
            local nodes = (type(t) == "table") and t.nodes or nil
            if type(nodes) == "table" then
                for n_id, n in pairs(nodes) do
                    if type(n) == "table" and type(n.data) == "table" and n.data.task ~= nil
                        and (blank_type == nil or n.data.type ~= blank_type) then
                        local x, y = world:GetSite(n_id)
                        -- GetSite 偶尔拿不到坐标，交给 math.min 会直接报错让世界生成失败
                        if type(x) == "number" and type(y) == "number" then
                            pos[n_id] = { x = x, y = y, node = n }
                            count = count + 1
                            min_x, max_x = math.min(x, min_x), math.max(x, max_x)
                            min_y, max_y = math.min(y, min_y), math.max(y, max_y)
                        end
                    end
                end
            end
        end

        if count == 0 then
            return old_find(self)
        end

        local cx, cy = (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
        local span = math.max(max_x - min_x, max_y - min_y)

        local n1, best1 = nil, math.huge
        for _, p in pairs(pos) do
            local d = (p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy)
            if d < best1 then
                best1 = d
                n1 = p
            end
        end

        -- 这里绝对不能调 WorldSim:GetTile / IsLandTile：
        --   本函数在 WorldGen_VoronoiPass(100) 之后、WorldGen_Commit 之前执行，
        --   此时瓦片地图还没生成（见 forest_map.lua:499-527），读瓦片会让引擎直接崩溃，
        --   日志停在 "GenerateVoronoiMap ... Done." 之后、没有任何 Lua 报错。
        --   所以改用纯几何判断「中心是不是空心」：主大陆节点离中心越远，越像环形内海。
        if span > 0 then
            local hole = math.sqrt(best1)
            if hole < span * 0.10 then
                print(string.format(
                    "[MiniMap] 主大陆中心不空（最近节点距中心 %.0f，主大陆跨度 %.0f），月岛交给原版放置",
                    hole, span))
                return old_find(self)
            end
        end

        local n2, best2 = nil, math.huge

        -- 第一优先：分居中心两侧 —— 月岛的节点会被这段连线拉着横跨内海
        for _, p in pairs(pos) do
            if n1 ~= nil and p.node.data.task ~= n1.node.data.task then
                local dot = (p.x - cx) * (n1.x - cx) + (p.y - cy) * (n1.y - cy)
                local d = (p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy)
                if dot < 0 and d < best2 then
                    best2 = d
                    n2 = p
                end
            end
        end

        -- 第二优先：环太细、找不到对侧节点时，只要求是离中心最近的另一个任务，
        -- 至少保证月岛挂在靠内的位置上（实在不行才交给原版丢到外圈）
        if n2 == nil then
            for _, p in pairs(pos) do
                if n1 ~= nil and p.node.data.task ~= n1.node.data.task then
                    local d = (p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy)
                    if d < best2 then
                        best2 = d
                        n2 = p
                    end
                end
            end
        end

        if n1 == nil or n2 == nil then
            print("[MiniMap] 环内凑不出两个不同任务的主大陆节点，月岛交给原版放置")
            return old_find(self)
        end

        print(string.format("[MiniMap] 月岛挂到环内节点：中心附近 (%.0f, %.0f) 与 (%.0f, %.0f)",
            n1.x, n1.y, n2.x, n2.y))
        return n1, n2
    end
end

HookMoonRegionCenter()

------------------------------------------------------------------------------------------
-- 活动 / 彩蛋内容：关掉对应开关后，从必需 prefab 列表里一起删掉，避免触发 PANIC 重试
------------------------------------------------------------------------------------------

local EVENT_DROP =
{
    ["charlie_stage_post"] = true,
    ["statueharp_hedgespawner"] = true,
    ["balatro_machine"] = true,
}

-- 通用：把指定的 prefab 从 level.required_prefabs 里删掉
--   （只是不再「必须存在」，能放下照样生成；放不下也不会让整个世界生成 PANIC）
local function DropRequiredPrefabs(level, drop)
    local list = level.required_prefabs
    if type(list) ~= "table" or type(drop) ~= "table" then
        return
    end
    local kept = {}
    for _, name in ipairs(list) do
        if drop[name] ~= true then
            kept[#kept + 1] = name
        end
    end
    level.required_prefabs = kept
end

local function RemoveRequiredPrefabs(level)
    local list = level.required_prefabs
    if type(list) ~= "table" then
        return
    end

    local drop_all = (EVENT_MODE == "all")
    local kept = {}
    for _, name in ipairs(list) do
        local should_drop = (EVENT_DROP[name] == true) or (drop_all and name == "terrariumchest")
        if not should_drop then
            kept[#kept + 1] = name
        end
    end
    level.required_prefabs = kept
end

------------------------------------------------------------------------------------------
-- Level 钩子
------------------------------------------------------------------------------------------

AddLevelPreInitAny(function(level)
    if type(level) ~= "table" then
        return
    end

    local is_cave = (level.location == "cave")
    if is_cave and not SHRINK_CAVES then
        return
    end

    HookWorldGen()
    TrimOceanRooms(is_cave)

    if not is_cave then
        -- 排查用：确认当前取自哪个岛屿模式（旧存档可能是 moon / both / hermit）
        print(string.format("[MiniMap] 岛屿位置模式: %s（环内=%s），环形主大陆=%s",
            tostring(ISLANDS_MODE), tostring(PREFER_CENTER), tostring(RING)))
    end

    level.overrides = level.overrides or {}

    -- 0) 环形主大陆：分支最小 + 首尾相连
    --   branching = "never"：任务图尽量不分叉，一路走到底
    --   loop = "always"   ：storygen 会把起点和终点用 Blank 房间接起来（SeperateStoryByBlanks），
    --                       主大陆变成一条闭合环路，中间留出的空地会被
    --                       Ocean_ConvertImpassibleToWater 转成内海
    if RING and not is_cave then
        level.overrides.branching = "never"
        level.overrides.loop = "always"
    end

    -- 0.5) 活动 / 彩蛋内容：不生成舞台剧、竖琴雕像、小丑牌（可选再去掉泰拉箱）
    if EVENT_MODE ~= "keep" then
        level.overrides.balatro = "never"
        level.overrides.stageplays = "never"
        if EVENT_MODE == "all" then
            level.overrides.terrariumchest = "never"
        end
        RemoveRequiredPrefabs(level)
    end

    -- 0.6) 小地图里海洋面积变少，这两件海洋布景经常没地方放：
    --   oceanwhirlbigportal      大漩涡
    --   hermithouse_construction1 奶奶岛的房子
    -- 放不下时原版会 PANIC 重试直到世界生成失败，所以允许它们缺失
    -- （能放下照样会生成，这里只是取消「必须存在」的硬校验）
    if not is_cave then
        DropRequiredPrefabs(level,
        {
            ["oceanwhirlbigportal"] = true,
            ["hermithouse_construction1"] = true,
        })
    end

    -- 1) 世界边长：只收紧、不放大
    if TARGET_WORLD_SIZE ~= nil then
        local cur_rank = WORLD_SIZE_RANK[level.overrides.world_size]
        if cur_rank == nil or cur_rank > TARGET_WORLD_SIZE.rank then
            level.overrides.world_size = TARGET_WORLD_SIZE.key
        end
    end

    -- 2) 背景填充节点：AddBGNodes 会为每个房间再加 0~2 个背景节点
    if BG_MODE == "half" then
        level.background_node_range = { 0, 1 }
    elseif BG_MODE == "none" then
        level.background_node_range = { 0, 0 }
    end

    -- 2.5) 不让新群落变成孤立小岛（孤岛之间全是空水域）
    level.overrides.island_percent = 0

    -- 2.6) 收窄浅海：把大部分 OCEAN_COASTAL 推成深海，减少"空白浅海"
    if NARROW_SHALLOW then
        local oceancfg = require("map/ocean_gen_config")
        if type(oceancfg) == "table" then
            oceancfg.final_level_shallow = 0.70
        end
    end

    -- 2.7) 地面沉洞数量
    --   洞是 set piece：level.set_pieces["CaveEntrance"]，原版 count = 10
    --   （tasksets/forest.lua:54），Level:ChooseSetPieces() 按 count 逐个塞进候选任务
    --   （scripts/map/level.lua:187-215，每个任务最多一个）。
    --   这里在分配之前把 count 压下来；必须在 ChooseSetPieces 之前改，
    --   而 AddLevelPreInitAny 正好在 Level:ChooseTasks 末尾（level.lua:117-121），时机合适。
    if not is_cave and type(level.set_pieces) == "table" then
        local entrance = level.set_pieces["CaveEntrance"]
        if type(entrance) == "table" and type(entrance.count) == "number"
            and entrance.count > SINKHOLE_MAX then
            print(string.format("[MiniMap] 地面沉洞数量：%d -> %d", entrance.count, SINKHOLE_MAX))
            entrance.count = SINKHOLE_MAX
        end
    end

    -- 3) 群落不做裁剪，只补 cove / 月岛锁这类必要修改
    --    注意 ChooseTasks 的顺序：先入队主任务 → ApplyModsToTasks → 再入队可选任务，
    --    所以两个钩子都挂上：前者覆盖主任务，后者覆盖包含可选任务的完整列表。
    local old_apply = level.ApplyModsToTasks
    if type(old_apply) == "function" and not level._minimap_apply_hooked then
        level._minimap_apply_hooked = true
        level.ApplyModsToTasks = function(self, tasklist)
            old_apply(self, tasklist)
            AdjustTaskList(tasklist)
        end
    end

    local old_get = level.GetTasksForLevel
    if type(old_get) == "function" and not level._minimap_get_hooked then
        level._minimap_get_hooked = true
        level.GetTasksForLevel = function(self)
            local tasklist = old_get(self)
            AdjustTaskList(tasklist)
            if type(tasklist) == "table" then
                print(string.format("[MiniMap] %s 世界：%d 个群落（保持原版，未裁剪）",
                    tostring(self.location or "?"), #tasklist))
            end
            return tasklist
        end
    end
end)
