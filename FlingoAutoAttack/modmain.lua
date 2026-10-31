--[[
    雪球发射器自动攻击 (Flingomatic Auto Attack)

    原理：
      1. 原版 firesuppressor 只在 firedetector 找到火时，通过 "putoutfire" 事件让
         SGfiresuppressor 进入 spin_up -> shoot，并在 shoot 第 6 帧调用
         inst:LaunchProjectile(firePos) 发射 snowball。
      2. 这里挂一个周期任务，在发射器空闲时找最近的敌对生物，把它的位置当作
         "firePos" 发给同一个事件，于是复用完整的原版开火动画/音效/抛物线。
      3. snowball 的 onhitfn（OnHitSnow）只做 wateryprotection:SpreadProtection，
         命中点 4 格内带 freezable 的实体会 AddColdness(2)，中型生物 resistance 恰好
         是 2，所以一发就能冻住。额外伤害默认 0，可在配置里加。
]]

local G = GLOBAL
local Vector3 = G.Vector3

-- 避雷针吸引闪电的范围（scripts/components/weather.lua 的 LIGHTNINGSTRIKE_SEARCH_RANGE）
-- 也是这里可选的最大攻击半径
local ROD_RANGE = 40
local DEFAULT_RANGE = 35             -- 未读到配置时的兜底值（与 modinfo 的 default 一致）
local VANILLA_RANGE = 15             -- 原版 TUNING.FIRE_DETECTOR_RANGE，雪球速度公式的校准基准
local SPEED_MARGIN = 1.15            -- 关掉“随距离加速”时，相对“刚好够打到目标”的速度余量

-- snowball 的弹道参数
local GRAVITY = 25                   -- snowball 的 SetGravity(-25)，同时也是原版值

------------------------------------------------------------------
-- 配置（GetModConfigData 由模组环境的 env 提供，不要走 GLOBAL）
------------------------------------------------------------------
-- 注意：模组环境的白名单里没有 tonumber，必须从 GLOBAL 取
local tonumber = GLOBAL.tonumber

local ENABLED = GetModConfigData("enable_attack") ~= false
local ATTACK_RANGE = math.min(tonumber(GetModConfigData("attack_range")) or DEFAULT_RANGE, ROD_RANGE)
local ATTACK_INTERVAL = tonumber(GetModConfigData("attack_interval")) or 0.5
local ATTACK_DAMAGE = tonumber(GetModConfigData("attack_damage")) or 0
local CONSUME_FUEL = GetModConfigData("consume_fuel") == true
local SPEED_BY_DISTANCE = GetModConfigData("speed_by_distance") ~= false
-- 旧存档里可能留着 2/3 这类档位，钳到 1.5 避免角度接近垂直、滞空两三秒
local SPEED_MULT = math.min(1.5, math.max(0.5, tonumber(GetModConfigData("speed_mult")) or 1))
local MAX_TARGETS = math.max(1, tonumber(GetModConfigData("max_targets")) or 3)

-- 速度基准 = 原版曲线按新射程归一化，再乘“射程 / 原版射程”。
-- 倍率 1 时和 SimpleGame 的公式完全一致：
--   easing.linear(rangesq, 15*M, 3*M, maxrange^2) == M * (15 + 3 * rangesq / maxrange^2)
--   M = ATTACK_RANGE / VANILLA_RANGE
local SPEED_BASE_MULT = ATTACK_RANGE / VANILLA_RANGE

local FUEL_PER_SHOT = 60             -- 消耗燃料时，每次开火扣掉的燃料（fueled 单位是秒）
local DAMAGE_RADIUS = 4              -- 与原版雪球 SpreadProtection 的默认半径一致
local SCAN_PERIOD = 0.2              -- 索敌任务周期（越小反应越快）
local SCAN_COOLDOWN = 0.3            -- 两次 FindEntities 之间的最小间隔（兼顾 40 格范围的开销）
local LAUNCH_GRACE = 1.5             -- 从发事件到 SG 真正发射的容错时间（spin_up + 6 帧）
local DEDUPE_TIME = 2                -- 与原版 firedetector:RegisterDetectedItem 的 2 秒一致

------------------------------------------------------------------
-- 工具
------------------------------------------------------------------
local HOSTILE_TAGS = { "monster", "hostile" }
local IGNORE_TAGS = {
    "player", "playerghost", "INLIMBO", "FX", "NOCLICK", "DECOR", "INVISIBLE", "notarget",
}

local function IsAttackable(ent)
    if ent == nil or not ent:IsValid() then
        return false
    end
    local health = ent.components.health
    if health == nil or health:IsDead() then
        return false
    end
    if ent.components.combat == nil then
        return false
    end
    if ent:HasTag("structure") or ent:HasTag("wall") then
        return false
    end
    return ent:HasTag("monster") or ent:HasTag("hostile")
end

-- 借用 firedetector 的 detectedItems 做“2 秒内不重复打同一个目标”的轮询，
-- 效果和原版轮流照顾多个火点一样
local function RegisterTargeted(inst, target)
    local fd = inst.components.firedetector
    if fd == nil or fd.detectedItems == nil or not target:IsValid() then
        return
    end
    if fd.detectedItems[target] ~= nil then
        fd.detectedItems[target]:Cancel()
    end
    fd.detectedItems[target] = inst:DoTaskInTime(DEDUPE_TIME, function(_, t)
        if fd.detectedItems ~= nil then
            fd.detectedItems[t] = nil
        end
    end, target)
end

-- 返回若干个可攻击目标：优先取最近 2 秒没打过的，都被打过才回退到全部
local function FindTargets(inst, range, count)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = G.TheSim:FindEntities(x, y, z, range, { "_combat" }, IGNORE_TAGS, HOSTILE_TAGS)

    local fd = inst.components.firedetector
    local recent = fd ~= nil and fd.detectedItems or nil

    local fresh, pool = {}, {}
    for _, ent in ipairs(ents) do
        if IsAttackable(ent) then
            local item = { ent = ent, sq = ent:GetDistanceSqToPoint(x, y, z) }
            table.insert(pool, item)
            if recent == nil or recent[ent] == nil then
                table.insert(fresh, item)
            end
        end
    end
    if #fresh > 0 then
        pool = fresh
    end
    table.sort(pool, function(a, b) return a.sq < b.sq end)

    local targets = {}
    for i = 1, math.min(count, #pool) do
        targets[i] = pool[i].ent
    end
    return targets
end

local function DamageEnemiesNear(x, z)
    local ents = G.TheSim:FindEntities(x, 0, z, DAMAGE_RADIUS, { "_combat" }, IGNORE_TAGS, HOSTILE_TAGS)
    for _, ent in ipairs(ents) do
        if IsAttackable(ent) then
            ent.components.health:DoDelta(-ATTACK_DAMAGE, false, nil, false)
        end
    end
end

------------------------------------------------------------------
-- 发射雪球（复制原版 LaunchProjectile，并额外挂上伤害结算）
------------------------------------------------------------------
local function LaunchSnowball(inst, targetpos, isattack)
    local x, y, z = inst.Transform:GetWorldPosition()
    local projectile = G.SpawnPrefab("snowball")
    if projectile == nil then
        return
    end
    projectile.Transform:SetPosition(x, y, z)

    local dx = targetpos.x - x
    local dz = targetpos.z - z
    local rangesq = dx * dx + dz * dz
    local dist = math.sqrt(rangesq)

    local cp = projectile.components.complexprojectile
    if cp == nil then
        projectile:Remove()
        return
    end

    if SPEED_BY_DISTANCE then
        -- 和 SimpleGame 一样：只给速度、不接管角度，保留 ComplexProjectile 默认的
        -- usehigharc 高抛弹道。速度越大，高抛解算出的角度越陡，抛物线越大。
        local speed = SPEED_BASE_MULT
            * (15 + 3 * rangesq / (ATTACK_RANGE * ATTACK_RANGE))
            * SPEED_MULT
        -- 兜底：无论如何先保证能打到目标
        local minspeed = cp:CalculateMinimumSpeedForDistance(dist)
        if minspeed ~= nil and speed < minspeed then
            speed = minspeed + 0.2
        end
        cp:SetHorizontalSpeed(speed)
    else
        -- 原版手感：15 + 3*d²/225（15 格内 15~18）
        local speed = 15 + 3 * rangesq / (VANILLA_RANGE * VANILLA_RANGE)
        -- 超过 15 格时线性外推不够快，用组件自算的最低速度兜底，避免打不到
        local minspeed = cp:CalculateMinimumSpeedForDistance(dist)
        if minspeed ~= nil and speed < minspeed then
            speed = minspeed * SPEED_MARGIN
        end
        cp:SetHorizontalSpeed(speed)
    end

    cp:SetGravity(-GRAVITY)

    local old_onhit = cp.onhitfn
    cp:SetOnHit(function(p, attacker, target)
        if isattack and ATTACK_DAMAGE > 0 and p ~= nil and p:IsValid() then
            local px, _, pz = p.Transform:GetWorldPosition()
            DamageEnemiesNear(px, pz)
        end
        if old_onhit ~= nil then
            old_onhit(p, attacker, target)   -- OnHitSnow：特效 + 灭火/降温/冰冻 + 移除自身
        end
    end)

    cp:Launch(targetpos, inst, inst)
end

------------------------------------------------------------------
-- 后置钩子：替换发射函数 + 索敌周期任务
------------------------------------------------------------------
local function OnFiresuppressorPostInit(inst)
    if not G.TheWorld.ismastersim then
        return
    end

    -- 每台发射器各有一份：标记“即将射出的这一发是不是攻击弹”
    local attack_time = nil

    -- 捕获链上的上一个实现（原版，或 SimpleGame 之类的速度补偿）
    -- 我们不覆盖灭火弹的逻辑，只接管自己发的攻击弹
    local old_launch = inst.LaunchProjectile

    inst.LaunchProjectile = function(self, targetpos)
        local isattack = attack_time ~= nil and (G.GetTime() - attack_time) <= LAUNCH_GRACE
        attack_time = nil
        -- 给 SG 的 animover 处理用：攻击弹打完直接回 idle_on，灭火弹照走 spin_down
        self._asf_attackshot = isattack

        local volley = self._asf_volley
        self._asf_volley = nil

        if isattack and volley ~= nil and #volley > 0 then
            -- 齐射：同一帧内对每个目标各发一颗雪球
            for _, pos in ipairs(volley) do
                LaunchSnowball(self, pos, true)
            end
        elseif not isattack and old_launch ~= nil then
            -- 灭火弹交还给之前装上的实现，保留其它 mod 的弹道/速度改动
            old_launch(self, targetpos)
        else
            LaunchSnowball(self, targetpos, isattack)
        end
    end

    local function TryAttack()
        if not inst:IsValid() or not ENABLED then
            return
        end
        if not inst.on or inst:IsAsleep() then
            return
        end
        -- 只在 idle 起手。直接进 shoot（跳过 spin_up），打完由 animover 直接回 idle_on
        -- （跳过 spin_down），一整轮只剩 launch 这段动画，节奏从 ~3 秒压到 ~1 秒。
        if inst.sg == nil or not inst.sg:HasStateTag("idle") then
            return
        end
        if inst.components.fueled == nil or inst.components.fueled:IsEmpty() then
            return
        end

        -- 上一发还没结算
        if attack_time ~= nil then
            if G.GetTime() - attack_time <= LAUNCH_GRACE then
                return
            end
            attack_time = nil
        end

        local now = G.GetTime()
        if inst._flingo_nextshot ~= nil and now < inst._flingo_nextshot then
            return
        end
        -- 40 格半径的 FindEntities 不便宜，靠 SCAN_COOLDOWN 把实际扫描节流到约 0.4 秒一次
        if inst._flingo_nextscan ~= nil and now < inst._flingo_nextscan then
            return
        end
        inst._flingo_nextscan = now + SCAN_COOLDOWN

        local targets = FindTargets(inst, ATTACK_RANGE, MAX_TARGETS)
        if #targets == 0 then
            return
        end

        inst._flingo_nextshot = now + ATTACK_INTERVAL
        attack_time = now

        -- 组装这一轮的齐射目标点，等 shoot 的第 6 帧一次性全部发射
        local volley = {}
        for _, target in ipairs(targets) do
            local tx, _, tz = target.Transform:GetWorldPosition()
            volley[#volley + 1] = Vector3(tx, 0, tz)
            -- 登记 2 秒，下一轮会优先挑别的怪物，形成轮流照顾的群体效果
            RegisterTargeted(inst, target)
        end
        inst._asf_volley = volley

        if CONSUME_FUEL then
            inst.components.fueled:DoDelta(-FUEL_PER_SHOT * #volley)
        end

        -- 直接进 shoot，跳过 spin_up 起手动画；
        -- 真正发射仍由 shoot 状态 timeline 第 6 帧的 LaunchProjectile 完成
        inst.sg:GoToState("shoot", { firePos = volley[1] })
    end

    inst:DoPeriodicTask(SCAN_PERIOD, TryAttack, 1 + math.random())
end

AddPrefabPostInit("firesuppressor", OnFiresuppressorPostInit)

------------------------------------------------------------------
-- 缩短攻击弹的一轮动画：打完直接回 idle_on，跳过 spin_down
-- （灭火弹不受影响，_asf_attackshot 为 false 时仍走原版 spin_down）
------------------------------------------------------------------
AddStategraphPostInit("firesuppressor", function(sg)
    local shoot = sg.states ~= nil and sg.states["shoot"] or nil
    local animover = shoot ~= nil and shoot.events ~= nil and shoot.events["animover"] or nil
    if animover ~= nil then
        animover.fn = function(inst)
            inst.sg:GoToState(inst._asf_attackshot and "idle_on" or "spin_down")
        end
    end
end)
