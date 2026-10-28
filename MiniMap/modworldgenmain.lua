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
      没有 tonumber、unpack、next、pcall —— 请不要使用。

    ------------------------------------------------------------------
    实测结论（重要）：
      地图最终尺寸主要由「群落(task) 数量」和「每个群落保留的房间种类数」
      决定，而不是房间总个数。
        原版小图：20 群落 / ~119 房间 → 415 x 415
        房间 -22%：20 群落 / ~93 房间 → 396 x 396   （只小 4.6%）
      所以要真正缩小，必须削掉「重复地形房间」（Forest/Plain/Rocky/Marsh…），
      只给每个群落保留 1~2 个内容房间。

    三层收缩：
      1) 去重：每个群落只保留「内容房间」+ 少量通用地形房间（可配 0/1/2）
      2) 关闭 cove 死角节点（AddCoveNodes 会给每个房间再加 0.35 个节点）
      3) 收紧世界边长上限 / 减少背景填充节点
]]

local DEFAULT_SHRINK = 0.70
local DEFAULT_FILLER = 0
local MIN_ROOMS = 2          -- 每个群落至少保留的房间种类数

local SHRINK = GetModConfigData("minimap_shrink") or DEFAULT_SHRINK
if type(SHRINK) ~= "number" then
    SHRINK = DEFAULT_SHRINK
end
SHRINK = math.max(0.20, math.min(1.00, SHRINK))

local FILLER_KEEP = GetModConfigData("minimap_filler")
if type(FILLER_KEEP) ~= "number" then
    FILLER_KEEP = DEFAULT_FILLER
end
FILLER_KEEP = math.max(0, math.min(4, FILLER_KEEP))

-- 注意：不能设成 none。charlie_stage_post / terrariumchest / statueharp_hedgespawner /
-- balatro_machine 都是靠「背景房间」的 tags 放置的，没有背景节点会直接缺 prefab 导致生成失败
local BG_MODE = GetModConfigData("minimap_bg") or "half"
local WSIZE_MODE = GetModConfigData("minimap_world_size") or "small"

local MAX_ROOMS = GetModConfigData("minimap_maxrooms")
if type(MAX_ROOMS) ~= "number" then
    MAX_ROOMS = 2
end
MAX_ROOMS = math.max(2, math.min(5, MAX_ROOMS))

local TRIM = GetModConfigData("minimap_trim") or "strong"

-- 活动 / 彩蛋内容：stageplays 会把 charlie_stage_post 和 statueharp_hedgespawner 一起干掉，
-- balatro 对应 balatro_machine，terrariumchest 对应泰拉瑞亚箱子
local EVENT_MODE = GetModConfigData("minimap_events") or "basic"

-- 岛屿靠岸
local ISLANDS_MODE = GetModConfigData("minimap_islands") or "both"

local NARROW_SHALLOW = GetModConfigData("minimap_shallow")
if NARROW_SHALLOW == nil then NARROW_SHALLOW = true end

local SHRINK_SETPIECES = GetModConfigData("minimap_setpieces")
if SHRINK_SETPIECES == nil then SHRINK_SETPIECES = true end

local SHRINK_CAVES = GetModConfigData("minimap_caves")
if SHRINK_CAVES == nil then SHRINK_CAVES = true end

------------------------------------------------------------------------------------------
-- 「通用地形房间」名单：只提供面积/填充，没有专属内容（boss、村庄、祭坛…）
--   这些在去重时会被大量丢弃，只按需保留 FILLER_KEEP 个
------------------------------------------------------------------------------------------

local FILLER_ROOMS =
{
    ["Forest"] = true,
    ["DeepForest"] = true,
    ["CrappyForest"] = true,
    ["CrappyDeepForest"] = true,
    ["Clearing"] = true,
    ["Plain"] = true,
    ["BarePlain"] = true,
    ["Rocky"] = true,
    ["Marsh"] = true,
    ["ForestMole"] = true,
    ["GenericRockyNoThreat"] = true,
    ["DeciduousClearing"] = true,
    ["GrassyMoleColony"] = true,
    ["Empty_Cove"] = true,
    ["BGGrass"] = true,
    ["BGRocky"] = true,
    ["BGForest"] = true,
    ["BGDeepForest"] = true,
    ["BGMarsh"] = true,
    ["BGBadlands"] = true,
    ["BGNoise"] = true,
    ["BGDeciduous"] = true,
    ["BGLightningBluff"] = true,
}

------------------------------------------------------------------------------------------
-- 数量缩放
------------------------------------------------------------------------------------------

-- room_choices 里的数量既可能是数字，也可能是 function() return <数字> end
local function ScaleCount(count, k)
    if type(count) == "number" then
        return math.max(1, math.floor(count * k + 0.5))
    elseif type(count) == "function" then
        return function()
            local n = count()
            if type(n) ~= "number" then
                n = 1
            end
            return math.max(1, math.floor(n * k + 0.5))
        end
    end
    return count
end

------------------------------------------------------------------------------------------
-- 群落去重：内容房间全留，通用地形房间只留 FILLER_KEEP 个
------------------------------------------------------------------------------------------

-- 房间数据查询（地形 / 内容量）
local ROOMS_MOD = nil
local ROOMS_READY = false

local function GetRoomData(name)
    if not ROOMS_READY then
        ROOMS_READY = true
        local mod = require("map/rooms")
        if type(mod) == "table" then
            ROOMS_MOD = mod
        end
    end
    if ROOMS_MOD ~= nil and type(ROOMS_MOD.GetRoomByName) == "function" then
        local room = ROOMS_MOD.GetRoomByName(name)
        if type(room) == "table" then
            return room
        end
    end
    return nil
end

local function GetRoomTerrain(name)
    local room = GetRoomData(name)
    if room ~= nil then
        return room.value
    end
    return nil
end

-- 保留优先级：1 = 带静态布景（猪王、雕像、泰拉箱、月岛矿井…），2 = 带 prefab，3 = 纯地形
local function GetRoomPriority(name)
    local room = GetRoomData(name)
    if room == nil or type(room.contents) ~= "table" then
        return 3
    end
    local layouts = room.contents.countstaticlayouts
    if type(layouts) == "table" then
        for _ in pairs(layouts) do
            return 1
        end
    end
    local prefabs = room.contents.countprefabs
    if type(prefabs) == "table" then
        for _ in pairs(prefabs) do
            return 2
        end
    end
    return 3
end

local function PruneTask(task)
    local rooms = task.room_choices
    if type(rooms) ~= "table" then
        return
    end

    local keep, fillers = {}, {}
    for name in pairs(rooms) do
        if FILLER_ROOMS[name] then
            fillers[#fillers + 1] = name
        else
            keep[#keep + 1] = name
        end
    end

    -- 内容房间：按「承载内容的重要性」排序，只保留前 MAX_ROOMS 种。
    -- 带静态布景的房间优先，保证猪王 / 龙蝇竞技场 / 月岛矿井这类房间不被裁掉。
    table.sort(keep, function(a, b)
        local pa, pb = GetRoomPriority(a), GetRoomPriority(b)
        if pa ~= pb then
            return pa < pb
        end
        return a < b
    end)

    if #keep > MAX_ROOMS then
        local trimmed = {}
        for i = 1, MAX_ROOMS do
            trimmed[i] = keep[i]
        end
        keep = trimmed
    end

    -- 通用房间：优先取与本群落主地形相同的那几个（Dig that rock 优先留 Rocky）
    table.sort(fillers, function(a, b)
        local a_match = (task.room_bg ~= nil and GetRoomTerrain(a) == task.room_bg)
        local b_match = (task.room_bg ~= nil and GetRoomTerrain(b) == task.room_bg)
        if a_match ~= b_match then
            return a_match
        end
        return a < b
    end)

    local result = {}
    for _, name in ipairs(keep) do
        result[name] = ScaleCount(rooms[name], SHRINK)
    end

    local want_filler = FILLER_KEEP
    if #keep < MIN_ROOMS then
        want_filler = math.max(FILLER_KEEP, MIN_ROOMS - #keep)
    end

    for i = 1, math.min(#fillers, want_filler) do
        result[fillers[i]] = ScaleCount(rooms[fillers[i]], SHRINK)
    end

    task.room_choices = result
end

local function ScaleTask(task)
    if type(task) ~= "table" or task._minimap_scaled then
        return
    end
    task._minimap_scaled = true

    PruneTask(task)

    -- 关闭 cove 死角：AddCoveNodes 里 cove_room_chance == 0 会直接 return 整个函数
    task.cove_room_chance = 0

    -- 月岛并入主大陆后会走 LinkNodesByKeys。
    -- IslandShards 原本 locks = {}（空表）：
    --   空锁表 => unlocked 恒为 true，但 unlockingNodes 为空，
    --   GetRandomItem({}) 返回 nil，于是崩在 storygen.lua:579 的 effectiveLastNode.id。
    -- 注意不能改成 {LOCKS.NONE}：LOCKS_KEYS[NONE] 也是空表，unlockingNodes 一样为空，照崩。
    -- 必须给一个真能拿到钥匙的锁。起始任务 "Make a pick" 提供 KEYS.TIER1，
    -- 而 LOCKS.TIER1 需要 KEYS.TIER1/TIER2，所以一定能接在主大陆起始节点后。
    if ISLANDS_MODE ~= "keep" and task.id == "MoonIsland_IslandShards" then
        task.locks = { LOCKS.TIER1 }
    end
end

local function ScaleTaskList(tasklist)
    if type(tasklist) ~= "table" then
        return
    end
    for _, task in ipairs(tasklist) do
        ScaleTask(task)
    end
end

local function CountRoomKinds(tasklist)
    local n = 0
    for _, task in ipairs(tasklist or {}) do
        if type(task.room_choices) == "table" then
            for _ in pairs(task.room_choices) do
                n = n + 1
            end
        end
    end
    return n
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
-- 打印最终尺寸（包一层 forest_map.Generate，读 save.map.width/height）
------------------------------------------------------------------------------------------

local INSTRUMENTED = false

local function InstrumentWorldGen()
    if INSTRUMENTED then
        return
    end
    INSTRUMENTED = true

    local ForestMap = require("map/forest_map")
    if type(ForestMap) ~= "table" or type(ForestMap.Generate) ~= "function" then
        return
    end

    local old_generate = ForestMap.Generate
    ForestMap.Generate = function(...)
        local save = old_generate(...)
        if type(save) == "table" and type(save.map) == "table" then
            print(string.format("[MiniMap] 最终地图尺寸: %s x %s 格",
                tostring(save.map.width), tostring(save.map.height)))
        end
        return save
    end
end

------------------------------------------------------------------------------------------
-- 海洋布景去重：保留帝王蟹 / 珍珠岛 / 猴岛 / 大漩涡，去掉废弃小船、海碑、多余海带农场
------------------------------------------------------------------------------------------

local OCEAN_STATIC_KEEP =
{
    ["OceanSwell"] =
    {
        ["CrabKing"] = true,
    },
    ["OceanRough"] =
    {
        ["HermitcrabIsland"] = true,
        ["OceanWhirlBigPortal"] = true,
        -- 猴岛：默认由 PlaceMonkeyIslandNearShore 贴岸放置；万一挂不上钩子，
        -- 这两个留着让原版逻辑照常放（远一点，但不会丢岛）
        ["MonkeyIsland"] = true,
        ["MonkeyIslandSmall"] = true,
    },
    ["OceanCoastal"] =
    {
        ["BullkelpFarmSmall"] = true,
        ["HermitcrabIsland"] = true,   -- 靠岸模式下会被搬到这里（近岸海域）
    },
}

local function TrimStaticLayouts(room, keep)
    if type(room) ~= "table" or type(room.contents) ~= "table" then
        return
    end
    local layouts = room.contents.countstaticlayouts
    if type(layouts) ~= "table" then
        return
    end
    for name in pairs(layouts) do
        if keep[name] == nil then
            layouts[name] = nil
        end
    end
end

------------------------------------------------------------------------------------------
-- 猴岛贴岸放置
--   原版把猴岛交给 OceanRough 房间的随机布景：在地图上随便找一片「整片都是
--   OCEAN_ROUGH」的方形区域。OCEAN_ROUGH 是离岸最远的深水带，落点又完全随机，
--   所以猴岛常常孤零零飘在很远的海里。
--   这里改成自己放：
--     1) 用 BFS 算出每格到陆地的距离；
--     2) 从离陆地最近的一层开始，找能塞下整个猴岛布局的方形空位；
--     3) 实在找不到就回退到原版逻辑，保证不会因为找不到位置而丢岛。
------------------------------------------------------------------------------------------

local MONKEY_LAYOUT_LARGE = "MonkeyIsland"
local MONKEY_LAYOUT_SMALL = "MonkeyIslandSmall"
local LAND_DIST_LIMIT = 40
local MONKEY_LAYER_LIMIT = 12   -- 只在离陆地 12 格以内找位置
local MONKEY_ANCHORS_PER_LAYER = 24

-- 原版 Ocean_PlaceSetPieces，兜底时用
local ORIG_OCEAN_PLACE_SETPIECES = nil

local function GetMonkeyLayoutSize(layout, prefabs)
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

local function MonkeySlotFree(world, dist, x, y, size, min_clear)
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
            if world:IsTileReserved(xx, yy) then
                return false
            end
        end
    end
    return true
end

-- 复刻 ocean_gen.lua 里的 AddSquareTopology（它是局部函数，mod 拿不到）。
-- 猴岛布局带 add_topology，世界生成后 MonkeyIsland_GenerateDocks 要靠这个节点生成码头。
local function AddMonkeySquareTopology(world, encoded_topology, tile_left, tile_top, area_size, map_width, map_height, add_topology)
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
    local add_entity =
    {
        fn = function(prefab, points_x, points_y, pos_idx, ents, w, h, prefab_list, prefab_data, rand_offset)
            local add_one = rawget(GLOBAL, "PopulateWorld_AddEntity")
            if type(add_one) == "function" then
                add_one(prefab, points_x, points_y, nil, ents, w, h, prefab_list, prefab_data, rand_offset)
            end
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

local function PlaceMonkeyIslandNearShore(entitiesOut, width, height, encoded_topology, min_dist_from_land)
    if rawget(GLOBAL, "_minimap_monkey_todo") ~= true then
        return
    end
    if type(entitiesOut) ~= "table" or type(width) ~= "number" or type(height) ~= "number" then
        return
    end

    local world = rawget(GLOBAL, "WorldSim")
    local obj_layout = require("map/object_layout")
    if world == nil or type(obj_layout) ~= "table"
        or type(obj_layout.LayoutForDefinition) ~= "function" then
        return
    end

    local size_ok, world_size = pcall(function() return world:GetWorldSize() end)
    local name = (size_ok and type(world_size) == "number" and world_size >= 425)
        and MONKEY_LAYOUT_LARGE or MONKEY_LAYOUT_SMALL

    local layout = obj_layout.LayoutForDefinition(name)
    if type(layout) ~= "table" then
        return
    end
    local prefabs = obj_layout.ConvertLayoutToEntitylist(layout)
    local size = GetMonkeyLayoutSize(layout, prefabs)
    local add_entity = MakeOceanAddEntity(entitiesOut, width, height)

    local edge = (rawget(GLOBAL, "OCEAN_WATERFALL_MAX_DIST") or 8) + 2

    if size + edge * 2 < width and size + edge * 2 < height then
        local dist = BuildLandDistanceField(world, width, height)

        -- 按离陆地距离分桶
        local buckets = {}
        for y = 0, height - 1 do
            local row = dist[y]
            for x = 0, width - 1 do
                local d = row[x]
                if type(d) == "number" and d >= 1 and d <= MONKEY_LAYER_LIMIT then
                    local b = buckets[d]
                    if b == nil then
                        b = {}
                        buckets[d] = b
                    end
                    b[#b + 1] = y * width + x
                end
            end
        end

        for d = 1, MONKEY_LAYER_LIMIT do
            local anchors = buckets[d]
            if anchors ~= nil then
                for i = #anchors, 2, -1 do
                    local j = math.random(i)
                    anchors[i], anchors[j] = anchors[j], anchors[i]
                end

                local tries = math.min(#anchors, MONKEY_ANCHORS_PER_LAYER)
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
                            and MonkeySlotFree(world, dist, x, y, size, 1) then
                            obj_layout.ReserveAndPlaceLayout("POSITIONED", layout, prefabs, add_entity, { x, y }, world)
                            for yy = y, y + size - 1 do
                                for xx = x, x + size - 1 do
                                    world:ReserveTile(xx, yy)
                                end
                            end
                            if type(layout.add_topology) == "table" then
                                AddMonkeySquareTopology(world, encoded_topology, x, y, size, width, height, layout.add_topology)
                            end
                            print(string.format("[MiniMap] 猴岛（%s）贴岸放置：离陆地约 %d 格，(%d, %d)", name, d, x, y))
                            return
                        end
                    end
                end
            end
        end
    end

    -- 兜底：交给原版逻辑去深海随机找位置
    local world_tiles = rawget(GLOBAL, "WORLD_TILES") or WORLD_TILES
    if type(ORIG_OCEAN_PLACE_SETPIECES) == "function" and world_tiles ~= nil then
        print("[MiniMap] 没找到贴岸空位，猴岛回退到原版深海放置")
        local set_pieces = {}
        set_pieces[name] = 1
        ORIG_OCEAN_PLACE_SETPIECES(set_pieces, add_entity, obj_layout, world_tiles.OCEAN_ROUGH,
            min_dist_from_land, encoded_topology, width, height)
    end
end

local OCEAN_TRIMMED = false

-- 直接改 Rooms 表：确保 ocean_gen 读到的也是精简后的内容（AddRoomPreInit 走的是另一条路径）
local function TrimOceanRooms()
    if OCEAN_TRIMMED then
        return
    end
    OCEAN_TRIMMED = true

    local Rooms = require("map/rooms")
    if type(Rooms) ~= "table" or type(Rooms.GetRoomByName) ~= "function" then
        return
    end

    for roomname, keep in pairs(OCEAN_STATIC_KEEP) do
        TrimStaticLayouts(Rooms.GetRoomByName(roomname), keep)
    end

    -- 地图缩得很小以后，海洋环带已经放不下猴岛；如果还强制要求 monkeyqueen，
    -- 世界生成会连续 5 次 PANIC。这里把「猴岛必须存在」的要求去掉：
    -- 有位置它照样会生成，没位置也不会让整个世界生成失败。
    local OCEAN_ROOMS =
    {
        "OceanCoastalShore",
        "OceanCoastal",
        "OceanSwell",
        "OceanRough",
        "OceanHazardous",
    }

    for _, roomname in ipairs(OCEAN_ROOMS) do
        local room = Rooms.GetRoomByName(roomname)
        if type(room) == "table" and type(room.required_prefabs) == "table" then
            local kept = {}
            for _, name in ipairs(room.required_prefabs) do
                if name ~= "monkeyqueen" then
                    kept[#kept + 1] = name
                end
            end
            room.required_prefabs = kept
        end
    end

    -- 奶奶岛（珍珠岛）从深海搬到近岸海域：OceanRough → OceanCoastal
    if ISLANDS_MODE == "both" then
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

    -- 包一层 PopulateOcean：原版把海洋布景放完之后，自己把猴岛放到离陆地最近的空位。
    -- 只有挂上了钩子才把猴岛从房间表里摘掉，否则保留原版行为（宁可放得远，也不要丢岛）。
    -- 注意：世界生成环境启用了 strict.lua，往 _G 上新增/读取未声明字段都会直接 error，
    -- 所以这里一律用 rawget / rawset。
    ORIG_OCEAN_PLACE_SETPIECES = rawget(GLOBAL, "Ocean_PlaceSetPieces")
    if type(rawget(GLOBAL, "PopulateOcean")) == "function" and rawget(GLOBAL, "_minimap_ocean_hooked") ~= true then
        rawset(GLOBAL, "_minimap_ocean_hooked", true)
        local orig_populate_ocean = rawget(GLOBAL, "PopulateOcean")
        rawset(GLOBAL, "PopulateOcean", function(spawnFn, entitiesOut, width, height, ocean_contents, world_gen_choices, min_dist_from_land, encoded_topology)
            orig_populate_ocean(spawnFn, entitiesOut, width, height, ocean_contents, world_gen_choices, min_dist_from_land, encoded_topology)
            PlaceMonkeyIslandNearShore(entitiesOut, width, height, encoded_topology, min_dist_from_land)
        end)
    end

    if rawget(GLOBAL, "_minimap_ocean_hooked") == true then
        rawset(GLOBAL, "_minimap_monkey_todo", true)
        for _, roomname in ipairs(OCEAN_ROOMS) do
            local room = Rooms.GetRoomByName(roomname)
            local layouts = (type(room) == "table" and type(room.contents) == "table")
                and room.contents.countstaticlayouts or nil
            if type(layouts) == "table" then
                layouts[MONKEY_LAYOUT_LARGE] = nil
                layouts[MONKEY_LAYOUT_SMALL] = nil
            end
        end
    end
end

------------------------------------------------------------------------------------------
-- 月岛并入主大陆
--   月岛 5 个任务原本 region_id = "island1"，会被 AddRegionsToMainland 丢到最空的角落，
--   中间还要插 4+4 个 REGION_LINK 中继节点。清掉 region_id 后它们变成普通任务，
--   由 RestrictNodesByKey 直接接在主大陆旁边，于是月岛会紧贴陆地甚至连成一片。
------------------------------------------------------------------------------------------

local MOON_TASKS =
{
    "MoonIsland_IslandShards",
    "MoonIsland_Beach",
    "MoonIsland_Forest",
    "MoonIsland_Baths",
    "MoonIsland_Mine",
}

if ISLANDS_MODE ~= "keep" and type(AddTaskPreInit) == "function" then
    for _, taskname in ipairs(MOON_TASKS) do
        AddTaskPreInit(taskname, function(task)
            task.region_id = nil
        end)
    end

    -- 碎片任务必须带一个「能拿到钥匙」的锁，否则 LinkNodesByKeys 里
    -- unlockingNodes 为空会把 storygen 崩掉（详见 ScaleTask 里的说明）。
    -- 这里在 task 创建时就补上，作为 ScaleTask 之外的第二道保险。
    AddTaskPreInit("MoonIsland_IslandShards", function(task)
        task.locks = { LOCKS.TIER1 }
    end)
end

------------------------------------------------------------------------------------------
-- 活动 / 彩蛋内容：从必需 prefab 列表里删掉，避免因为裁房间而触发 PANIC 重试
------------------------------------------------------------------------------------------

local EVENT_DROP =
{
    ["charlie_stage_post"] = true,
    ["statueharp_hedgespawner"] = true,
    ["balatro_machine"] = true,
}

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

    InstrumentWorldGen()
    TrimOceanRooms()

    level.overrides = level.overrides or {}

    -- 0) 活动 / 彩蛋内容：不生成舞台剧、竖琴雕像、小丑牌（可选再去掉泰拉箱）
    if EVENT_MODE ~= "keep" then
        level.overrides.balatro = "never"
        level.overrides.stageplays = "never"
        if EVENT_MODE == "all" then
            level.overrides.terrariumchest = "never"
        end
        RemoveRequiredPrefabs(level)
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

    -- 3) 群落去重 + 房间数量缩放
    --    注意 ChooseTasks 的顺序：先入队主任务 → ApplyModsToTasks → 再入队可选任务，
    --    所以两个钩子都挂上：前者覆盖主任务，后者覆盖包含可选任务的完整列表。
    local old_apply = level.ApplyModsToTasks
    if type(old_apply) == "function" and not level._minimap_apply_hooked then
        level._minimap_apply_hooked = true
        level.ApplyModsToTasks = function(self, tasklist)
            old_apply(self, tasklist)
            ScaleTaskList(tasklist)
        end
    end

    local old_get = level.GetTasksForLevel
    if type(old_get) == "function" and not level._minimap_get_hooked then
        level._minimap_get_hooked = true
        level.GetTasksForLevel = function(self)
            local tasklist = old_get(self)
            ScaleTaskList(tasklist)
            if type(tasklist) == "table" then
                print(string.format("[MiniMap] %s 世界：%d 个群落 / %d 种房间（每群落最多 %d 种，通用地形 %d，比例 %.0f%%，精简=%s）",
                    tostring(self.location or "?"), #tasklist, CountRoomKinds(tasklist),
                    MAX_ROOMS, FILLER_KEEP, SHRINK * 100, TRIM))
            end
            return tasklist
        end
    end
end)

------------------------------------------------------------------------------------------
-- TaskSet 钩子：群落精简 + 布景去重
------------------------------------------------------------------------------------------

local OCEAN_PREFILL_KEEP =
{
    ["BrinePool1"] = 1,     -- 盐的来源，留 1
    ["Waterlogged1"] = 1,   -- 水中木，留 1
}

-- 可选群落里内容独特的三个（蜘蛛巢 / 蛙池 / 麋鹿巢），其余都是重复地形
local TRIM_OPTIONAL_KEEP = { "Kill the spiders", "Frogs and bugs", "MooseBreedingTask" }

-- 蜜蜂地块：房间太少放不下多个杀人蜂巢与蜂后，整块去掉
local TRIM_DROP_FIXED = { ["Beeeees!"] = true }

local function ListContains(list, name)
    for _, v in ipairs(list) do
        if v == name then
            return true
        end
    end
    return false
end

local function TrimTaskSet(taskset)
    -- 可选群落：只留内容独特的几个（必须是本 taskset 里真实存在的名字，否则会报错）
    local opt = taskset.optionaltasks
    if type(opt) == "table" then
        local newopt = {}
        if TRIM ~= "extreme" then
            for _, name in ipairs(TRIM_OPTIONAL_KEEP) do
                if ListContains(opt, name) then
                    newopt[#newopt + 1] = name
                end
            end
        end
        taskset.optionaltasks = newopt
        taskset.numoptionaltasks = #newopt
    end

    -- 固定群落：去掉重复/太小的地块
    if TRIM ~= "mild" then
        local list = taskset.tasks
        if type(list) == "table" then
            local newlist = {}
            for _, name in ipairs(list) do
                if not TRIM_DROP_FIXED[name] then
                    newlist[#newlist + 1] = name
                end
            end
            taskset.tasks = newlist
        end
    end
end

AddTaskSetPreInitAny(function(taskset)
    if type(taskset) ~= "table" then
        return
    end
    if taskset.location == "cave" and not SHRINK_CAVES then
        return
    end

    if TRIM ~= "off" then
        TrimTaskSet(taskset)
    end

    if not SHRINK_SETPIECES then
        return
    end

    local function scale_entry(entry, min_count)
        if type(entry) == "table" and type(entry.count) == "number" then
            entry.count = math.max(min_count, math.floor(entry.count * SHRINK + 0.5))
        end
    end

    for name, entry in pairs(taskset.set_pieces or {}) do
        -- 复活石是复活刚需，保底 2 个
        scale_entry(entry, name == "ResurrectionStone" and 2 or 1)
    end

    -- 海洋布景去重：只留必要的
    local prefill = taskset.ocean_prefill_setpieces
    if prefill ~= nil then
        for name, entry in pairs(prefill) do
            if OCEAN_PREFILL_KEEP[name] ~= nil then
                if type(entry) == "table" then
                    entry.count = OCEAN_PREFILL_KEEP[name]
                end
            else
                prefill[name] = nil
            end
        end
    end
end)

------------------------------------------------------------------------------------------
-- 房间钩子：同一套保留表，走 AddRoomPreInit 官方路径（与 TrimOceanRooms 互为兜底）
------------------------------------------------------------------------------------------

do
    for roomname, keep in pairs(OCEAN_STATIC_KEEP) do
        AddRoomPreInit(roomname, function(room)
            TrimStaticLayouts(room, keep)
        end)
    end
end
