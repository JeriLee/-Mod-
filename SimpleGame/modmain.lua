GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })  --GLOBAL相关照抄

--------------------------------------------------------------------------
-- 灭火器（Ice Flingomatic / prefab: firesuppressor）工作范围
--
-- 相关的两个原版数值：
--   灭火器检测范围  TUNING.FIRE_DETECTOR_RANGE = 15      -- scripts/tuning.lua
--   避雷针吸引范围  LIGHTNINGSTRIKE_SEARCH_RANGE = 40    -- scripts/components/weather.lua
--                   （40 范围内落下的闪电都会被引到避雷针上）
--
-- 本模组把灭火器改成和避雷针一样大（默认 40），
-- 并且让放置预览圆环、雪球飞行速度一起跟着变。
--------------------------------------------------------------------------

local VANILLA_RANGE = 15          -- 原版 TUNING.FIRE_DETECTOR_RANGE
local ROD_RANGE = 40              -- 避雷针范围
local PLACER_SCALE = 1.55         -- 原版灭火器地面圆环的缩放（firesuppressor.lua 的 PLACER_SCALE）

local range_config = GetModConfigData("range")
local RANGE = (type(range_config) == "number" and range_config > 0) and range_config or ROD_RANGE
local SYNC_PLACER = GetModConfigData("sync_placer") ~= false
local SPEED_COMP = GetModConfigData("speed_comp") ~= false

local RANGE_RATIO = RANGE / VANILLA_RANGE
-- 地面圆环美术是按 15 的范围画的，等比放大后正好对上新范围
local HELPER_SCALE = PLACER_SCALE * RANGE_RATIO
-- 雪球水平速度同比放大，保持飞行时间和原版接近
local SPEED_MULT = SPEED_COMP and RANGE_RATIO or 1

-- firedetector 组件在构造时读取 TUNING，改掉之后新造的灭火器直接就是新范围；
-- 旧存档里已经存在的灭火器在下面的 AddPrefabPostInit 里再补一次
TUNING.FIRE_DETECTOR_RANGE = RANGE

local easing = require("easing")

-- 照抄原版 firesuppressor.lua 的 LaunchProjectile，
-- 唯一的区别是水平速度整体乘了 SPEED_MULT
local function LaunchProjectile(inst, targetpos)
    local x, y, z = inst.Transform:GetWorldPosition()

    local projectile = SpawnPrefab("snowball")
    projectile.Transform:SetPosition(x, y, z)

    local dx = targetpos.x - x
    local dz = targetpos.z - z
    local rangesq = dx * dx + dz * dz
    local maxrange = TUNING.FIRE_DETECTOR_RANGE
    local speed = easing.linear(rangesq, 15 * SPEED_MULT, 3 * SPEED_MULT, maxrange * maxrange)
    projectile.components.complexprojectile:SetHorizontalSpeed(speed)
    projectile.components.complexprojectile:SetGravity(-25)
    projectile.components.complexprojectile:Launch(targetpos, inst, inst)
end

AddPrefabPostInit("firesuppressor", function(inst)
    if inst.components.firedetector ~= nil then
        inst.components.firedetector.range = RANGE
    end

    -- 只有主机端会用这个函数发雪球
    if SPEED_COMP and inst.LaunchProjectile ~= nil and TheWorld ~= nil and TheWorld.ismastersim then
        inst.LaunchProjectile = LaunchProjectile
    end

    -- 建造辅助（放置时地面圆环）在每次启用时新建，这里包一层把缩放改大
    local deployhelper = inst.components.deployhelper
    if SYNC_PLACER and deployhelper ~= nil then
        local old_enablehelper = deployhelper.onenablehelper
        deployhelper.onenablehelper = function(inst, enabled)
            if old_enablehelper ~= nil then
                old_enablehelper(inst, enabled)
            end
            if enabled and inst.helper ~= nil and inst.helper:IsValid() then
                inst.helper.Transform:SetScale(HELPER_SCALE, HELPER_SCALE, HELPER_SCALE)
            end
        end
    end
end)

-- 放置时整根 placer 实体就是那个地面圆环，放大它；
-- 站在圆环上的灭火器预览模型（placer.linked）缩小同样的倍数，保持原大小
if SYNC_PLACER then
    AddPrefabPostInit("firesuppressor_placer", function(inst)
        inst.Transform:SetScale(HELPER_SCALE, HELPER_SCALE, HELPER_SCALE)

        local placer = inst.components.placer
        if placer ~= nil and placer.linked ~= nil then
            local inv = 1 / HELPER_SCALE
            for _, ent in ipairs(placer.linked) do
                if ent:IsValid() then
                    ent.Transform:SetScale(inv, inv, inv)
                end
            end
        end
    end)
end
