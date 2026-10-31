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

-- snowball 的弹道参数，用于复算原版手感
local GRAVITY = 25                   -- snowball 的 SetGravity(-25)
local LAUNCH_HEIGHT = 2.5            -- snowball 的 SetLaunchOffset(0, 2.5, 0)
local HIT_HEIGHT = 0.05              -- ComplexProjectile:OnUpdate 的落地判定高度
local VANILLA_FLIGHT_TIME = 1.2      -- 原版打满 15 格时的滞空时间（按高抛解算约 1.2 秒）

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
local SPEED_MULT = math.max(0.5, tonumber(GetModConfigData("speed_mult")) or 2)
local MAX_TARGETS = math.max(1, tonumber(GetModConfigData("max_targets")) or 3)

-- 实际滞空时间 = 原版 1.2 秒 / 倍率。
-- 倍率 1：完全原版手感；倍率 2：水平速度翻倍、滞空减半、弹道压平。
local FLIGHT_TIME = VANILLA_FLIGHT_TIME / SPEED_MULT

-- “随距离加速”用的固定垂直初速：
--   从发射高度 2.5 出发，在 FLIGHT_TIME 内落到 0.05，
--   反解出 vy = (0.5*g*T^2 - (h - hit)) / T
--   倍率 1 时 ≈ 12.96（正好等于原版打满 15 格时的垂直初速），落地垂直速度 ≈ 17 与原版一致；
--   倍率越高 vy 越小，弹道越平、落地越快。
local FIXED_VY = (0.5 * GRAVITY * FLIGHT_TIME * FLIGHT_TIME
    - (LAUNCH_HEIGHT - HIT_HEIGHT)) / FLIGHT_TIME

local FUEL_PER_SHOT = 60             -- 消耗燃料时，每次开火扣掉的燃料（fueled 单位是秒）
local DAMAGE_RADIUS = 4              -- 与原版雪球 SpreadProtection 的默认半径一致
local SCAN_PERIOD = 0.2              -- 索敌任务周期（越小反应越快）
local SCAN_COOLDOWN = 0.3            -- 两次 FindEntities 之间的最小间隔（兼顾 40 格范围的开销）
local LAUNCH_GRACE = 1.5             -- 从发事件到 SG 真正发射的容错时间（spin_up + 6 帧）

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

-- 返回距离最近的若干个可攻击目标（用于一轮齐射）
local function FindTargets(inst, range, count)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = G.TheSim:FindEntities(x, y, z, range, { "_combat" }, IGNORE_TAGS, HOSTILE_TAGS)

    local sorted = {}
    for _, ent in ipairs(ents) do
        if IsAttackable(ent) then
            table.insert(sorted, { ent = ent, sq = ent:GetDistanceSqToPoint(x, y, z) })
        end
    end
    table.sort(sorted, function(a, b) return a.sq < b.sq end)

    local targets = {}
    for i = 1, math.min(count, #sorted) do
        targets[i] = sorted[i].ent
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
        -- 垂直初速恒定、滞空时间恒定 FLIGHT_TIME，水平速度 = 距离 / FLIGHT_TIME 线性增大。
        -- 结果：不管打多远，落地垂直速度都一样，弹道角度随距离变平。
        local vx = dist / FLIGHT_TIME
        cp:SetHorizontalSpeed(math.sqrt(vx * vx + FIXED_VY * FIXED_VY))
        cp:SetOnLaunch(function(p)
            local c = p.components.complexprojectile
            if c ~= nil then
                -- Launch 里 CalculateTrajectory 算好的角度在这里被覆盖，
                -- 但 ForceFacePoint 已经让实体朝向目标，SetMotorVel 是实体局部坐标，
                -- 所以 velocity.x 就是“朝目标方向”的水平速度
                c.velocity.x = vx
                c.velocity.y = FIXED_VY
                c.velocity.z = 0
            end
        end)
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
