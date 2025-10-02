# Combat System - AOE & Hitscan Implementation Guide

## Overview

Implementation of Phase 2 combat mechanics: **Hitscan** and **AOE** weapon types, building on the existing projectile system.

**Current State:**
- ✅ Melee weapons (range-based)
- ✅ Projectile weapons (ProjectileManager, ProjectilePhysics, ProjectileLOS)
- ✅ DamageCalculator with hit locations
- ✅ CombatFeedback with damage types
- ❌ Hitscan (stub only)
- ❌ AOE (stub only)

---

## Hitscan Weapons

### Concept
Instant hit detection with two modes: **targeted** (uses TargetingSystem) or **free-aim** (raycast).

### Weapon Types

#### Type 1: Targeted Hitscan (No Raycast)
- Requires target selected via TargetingSystem
- Instant damage/heal if target in range
- No visual raycast needed
- Like extended-range melee

**Use Cases:**
- Direct healing spells
- Lock-on attacks
- Instant teleport strikes

#### Type 2: Free-Aim Hitscan (Raycast)
- No target required
- Raycast in aim direction
- Hits first entity/terrain in path
- Traditional FPS-style

**Use Cases:**
- Crossbows, guns
- Laser beams
- Ranged attacks without targeting

### Configuration

```lua
-- Targeted hitscan (no raycast)
DirectHeal = {
    type = "hitscan",
    requiresTarget = true,      -- Must have locked target
    range = 50,                 -- Max target distance
    damage = -30,               -- Negative = healing
    visualEffect = "none",      -- No beam visual
    targetFilter = "allies",    -- Only allies
    castDuration = 0.2,
    cooldown = 3.0,
}

-- Free-aim hitscan (raycast)
Crossbow = {
    type = "hitscan",
    requiresTarget = false,     -- Free aim
    range = 100,
    damage = 40,
    visualEffect = "beam",      -- Show beam
    castDuration = 0.3,
    cooldown = 2.0,
    -- spread = 2,              -- TODO: accuracy variance (degrees)
}

-- Hitscan with AOE on impact
ExplosiveBolt = {
    type = "hitscan",
    requiresTarget = false,
    range = 80,
    damage = 20,                -- Direct hit damage
    visualEffect = "beam",

    -- AOE properties
    aoeOnImpact = true,
    aoeDamage = 40,             -- Explosion damage (different from direct)
    aoeRadius = 10,
    aoeFalloff = true,
    maxTargets = 5,

    castDuration = 0.4,
    cooldown = 4.0,
}
```

### Implementation

#### CombatSystem.performHitscan()

**File:** `src/shared/CombatSystem.luau`

**Signature:**
```lua
function CombatSystem.performHitscan(
    origin: Vector3,
    direction: Vector3,
    weaponName: string,
    attacker: Model,
    attackingPlayer: Player?,
    lockedTarget: Model?
): AttackResult
```

**Logic:**
1. Get weapon config, validate type = "hitscan"
2. **Branch on requiresTarget:**
   - **If true:** Use `lockedTarget`, validate range only
   - **If false:** Perform raycast to find target
3. Check PvP rules
4. Check invulnerability
5. Calculate damage via DamageCalculator
6. Apply damage to target
7. Set invulnerability
8. Show CombatFeedback
9. **If aoeOnImpact:** Call `performAOEAttack()` at hit position
10. Show visual effects (beam/impact)
11. Return AttackResult

**Pseudocode:**
```lua
function CombatSystem.performHitscan(origin, direction, weaponName, attacker, attackingPlayer, lockedTarget)
    local weaponConfig = getWeaponConfig(weaponName)

    -- Determine target
    local hitEntity: Model?
    local hitPosition: Vector3

    if weaponConfig.requiresTarget then
        -- Mode 1: Targeted hitscan
        if not lockedTarget then
            return {hit = false, ...} -- No target
        end

        -- Check range
        local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart")
        local distance = (targetRoot.Position - origin).Magnitude

        if distance > weaponConfig.range then
            return {hit = false, wasInRange = false, ...} -- Out of range
        end

        hitEntity = lockedTarget
        hitPosition = targetRoot.Position

    else
        -- Mode 2: Free-aim raycast
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {attacker}

        local raycastResult = workspace:Raycast(origin, direction * weaponConfig.range, raycastParams)

        if not raycastResult then
            -- Miss - show beam to max range
            if weaponConfig.visualEffect == "beam" then
                HitscanEffects.showBeam(origin, origin + (direction * weaponConfig.range), weaponName, 0.05)
            end
            return {hit = false, ...}
        end

        hitPosition = raycastResult.Position
        hitEntity = findEntityFromPart(raycastResult.Instance)

        if not hitEntity then
            -- Hit terrain/wall
            if weaponConfig.visualEffect == "beam" then
                HitscanEffects.showBeam(origin, hitPosition, weaponName)
                HitscanEffects.showHitEffect(hitPosition, raycastResult.Normal, weaponName)
            end
            return {hit = false, ...}
        end
    end

    -- Validate target
    if not isPvPAllowed(attacker, hitEntity) then
        return {hit = false, ...}
    end

    if checkInvulnerability(hitEntity, weaponName) then
        return {hit = false, blockedByInvulnerability = true, ...}
    end

    -- Calculate and apply damage
    local targetHumanoid = hitEntity:FindFirstChildOfClass("Humanoid")
    if targetHumanoid and targetHumanoid.Health > 0 then
        local damageResult = DamageCalculator.calculateDamage({
            attacker = attacker,
            target = hitEntity,
            weaponName = weaponName,
            hitPart = hitEntity:FindFirstChild("HumanoidRootPart"),
        })

        if damageResult.wasHit then
            -- Apply damage/healing
            if weaponConfig.damage < 0 then
                -- Healing
                targetHumanoid.Health = math.min(targetHumanoid.Health - damageResult.finalDamage, targetHumanoid.MaxHealth)
            else
                targetHumanoid:TakeDamage(damageResult.finalDamage)
            end

            -- Set invulnerability
            setInvulnerability(hitEntity, weaponName, GameConfig.combat.invulnerabilityDuration)

            -- Show feedback
            local damageType = determineDamageType(hitEntity, attackingPlayer)
            CombatFeedback.showDamage(hitEntity, math.abs(damageResult.finalDamage), weaponName, damageType, attacker)

            -- Visual effects
            if weaponConfig.visualEffect == "beam" then
                HitscanEffects.showBeam(origin, hitPosition, weaponName)
                HitscanEffects.showHitEffect(hitPosition, Vector3.new(0, 1, 0), weaponName)
            end

            -- AOE on impact
            if weaponConfig.aoeOnImpact then
                performAOEAttack(attacker, hitPosition, weaponName, attackingPlayer, {
                    damageOverride = weaponConfig.aoeDamage,
                    radius = weaponConfig.aoeRadius,
                    falloff = weaponConfig.aoeFalloff,
                    maxTargets = weaponConfig.maxTargets,
                })
            end

            return {hit = true, target = hitEntity, damage = damageResult.finalDamage, ...}
        end
    end

    return {hit = false, ...}
end
```

#### HitscanEffects Module

**File:** `src/shared/HitscanEffects.luau`

**Purpose:** Visual effects for hitscan weapons (optional, based on config).

**Functions:**
```lua
-- Show beam from origin to hit point
function HitscanEffects.showBeam(origin: Vector3, hitPoint: Vector3, weaponName: string, duration: number?)
    -- Create beam Part or use Beam instance
    -- Color based on weapon type (damage vs healing)
    -- Tween transparency and destroy
end

-- Show impact effect at hit location
function HitscanEffects.showHitEffect(position: Vector3, normal: Vector3, weaponName: string)
    -- Spawn particle effect at impact point
    -- Play impact sound
    -- Destroy after duration
end
```

**Implementation:**
- Use **template models** from `ReplicatedStorage.Models.Effects.Hitscan`
- Templates: `BeamEffect`, `ImpactEffect`
- Clone and position at runtime
- Color based on damage type (red = damage, green = healing)

---

## AOE Weapons

### Concept
Area-of-effect attacks that damage/heal multiple entities in a radius. Three variants:

1. **Instant AOE** - Activates immediately at target position
2. **Projectile AOE** - Travels as projectile, explodes on impact
3. **Persistent AOE** - Lingering zone that ticks over time

### Configuration

```lua
-- Instant AOE (self-centered)
GroundSlam = {
    type = "aoe",
    range = 0,                  -- Self-centered (attacker position)
    aoeDamage = 35,             -- Use aoeDamage for clarity
    aoeRadius = 20,
    aoeFalloff = true,          -- Damage decreases with distance
    maxTargets = 15,
    castDuration = 0.7,         -- Telegraph window
    cooldown = 8.0,
}

-- Projectile AOE (explodes on impact)
Fireball = {
    type = "aoe",
    projectileSpeed = 40,       -- Travels as projectile
    damage = 30,                -- Touch damage during flight
    aoeDamage = 50,             -- Explosion damage (different)
    range = 60,                 -- Max projectile travel
    aoeRadius = 15,
    aoeFalloff = true,
    maxTargets = 10,
    castDuration = 1.0,
    cooldown = 5.0,

    projectileConfig = {
        modelPath = "Fireball",
        trailEnabled = true,
        trailColor = Color3.fromRGB(255, 100, 0),
        impactEffect = "Explosion",
    },
}

-- Persistent AOE zone (damage over time)
PoisonCloud = {
    type = "aoe",
    range = 40,                 -- Cast range
    aoeDamage = 10,             -- Damage per tick
    aoeRadius = 12,
    aoeFalloff = false,
    maxTargets = 999,
    castDuration = 2.0,
    cooldown = 15.0,

    -- Persistent zone properties
    duration = 8.0,             -- Lasts 8 seconds
    tickRate = 1.0,             -- Tick every 1 second (8 ticks total)
    targetFilter = "enemies",
}

-- Healing zone
HealingCircle = {
    type = "aoe",
    range = 40,
    aoeDamage = -20,            -- Negative = healing
    aoeRadius = 12,
    aoeFalloff = false,
    maxTargets = 5,
    castDuration = 2.0,
    cooldown = 15.0,
    duration = 5.0,
    tickRate = 1.0,
    targetFilter = "allies",
}
```

### Implementation

#### AOETelegraph Module

**File:** `src/shared/AOETelegraph.luau`

**Purpose:** Show visual telegraph during `castDuration` to warn targets.

**Functions:**
```lua
-- Show circular telegraph on ground
function AOETelegraph.showCircleTelegraph(
    position: Vector3,
    radius: number,
    duration: number,
    attackType: "damage" | "heal"
): Instance
    -- Clone template from ReplicatedStorage.Models.Effects.AOE.CircleTelegraph
    -- Scale to radius
    -- Color based on attackType (red = damage, green = heal)
    -- Pulse animation
    -- Destroy after duration
end
```

**Template Location:**
- `ReplicatedStorage.Models.Effects.AOE.CircleTelegraph`
- Template is a cylinder Part with decal/texture
- Has attachment for particle emitter around perimeter

#### AOEZoneManager Module

**File:** `src/shared/AOEZoneManager.luau`

**Purpose:** Manage persistent AOE zones (duration + tickRate).

**Types:**
```lua
export type AOEZone = {
    position: Vector3,
    radius: number,
    weaponName: string,
    attacker: Model,
    attackingPlayer: Player?,
    startTime: number,
    duration: number,
    tickRate: number,
    lastTickTime: number,
    visualEffect: Instance?,
}
```

**Functions:**
```lua
-- Create persistent zone
function AOEZoneManager.createZone(
    position: Vector3,
    radius: number,
    weaponName: string,
    attacker: Model,
    attackingPlayer: Player?,
    duration: number,
    tickRate: number
): AOEZone

-- Tick a zone (apply damage/heal to entities inside)
function AOEZoneManager.tickZone(zone: AOEZone)
    -- Find entities in radius
    -- Filter by targetFilter (allies/enemies)
    -- Apply damage via applyDamageToEntity
    -- Update lastTickTime
end

-- Update all zones (called every frame)
function AOEZoneManager.updateZones()
    -- For each active zone:
    --   Check if expired (currentTime - startTime >= duration)
    --   If expired: destroy zone, remove from list
    --   Else if time to tick: tickZone()
end

-- Auto-initialize on first use
function AOEZoneManager.initialize()
    -- Connect Heartbeat to updateZones
    -- Only initialize once
end
```

**Initialization:**
- Auto-initialize on first `createZone()` call
- Single update loop for all zones
- No manual initialization required

#### CombatSystem.performAOEAttack()

**File:** `src/shared/CombatSystem.luau`

**Signature:**
```lua
function CombatSystem.performAOEAttack(
    attacker: Model,
    targetPosition: Vector3,
    weaponName: string,
    attackingPlayer: Player?,
    options: {
        damageOverride: number?,    -- Use aoeDamage instead of damage
        radius: number?,            -- Override aoeRadius
        falloff: boolean?,
        maxTargets: number?,
    }?
): {AOEHitInfo}
```

**Logic:**
1. Get weapon config
2. Use options to override config values (for hitscan AOE, projectile AOE)
3. Find all entities in radius via `workspace:GetPartBoundsInRadius()`
4. For each entity:
   - Check targetFilter (allies/enemies/all)
   - Check PvP rules
   - Check invulnerability
   - Calculate damage with falloff
   - Apply damage via `applyDamageToEntity()`
   - Stop if maxTargets reached
5. If weapon has `duration` + `tickRate`: Create persistent zone via AOEZoneManager
6. Return list of hit entities

**Pseudocode:**
```lua
function CombatSystem.performAOEAttack(attacker, targetPosition, weaponName, attackingPlayer, options)
    local weaponConfig = getWeaponConfig(weaponName)

    -- Get effective values (options override config)
    local damage = options.damageOverride or weaponConfig.aoeDamage or weaponConfig.damage
    local radius = options.radius or weaponConfig.aoeRadius or 10
    local falloff = options.falloff ~= nil and options.falloff or weaponConfig.aoeFalloff
    local maxTargets = options.maxTargets or weaponConfig.maxTargets or 999

    local hits: {AOEHitInfo} = {}

    -- Find entities in radius
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {attacker}

    local parts = workspace:GetPartBoundsInRadius(targetPosition, radius, params)

    -- Find unique entities
    local hitEntities: {[Model]: boolean} = {}

    for _, part in parts do
        local entity = findEntityFromPart(part)
        if entity and not hitEntities[entity] then
            hitEntities[entity] = true

            -- Check target filter
            if not shouldAffectEntity(entity, attacker, weaponConfig.targetFilter) then
                continue
            end

            -- Check PvP
            if not isPvPAllowed(attacker, entity) then
                continue
            end

            -- Check invulnerability
            if checkInvulnerability(entity, weaponName) then
                continue
            end

            local entityRoot = entity:FindFirstChild("HumanoidRootPart")
            if entityRoot then
                local distance = (targetPosition - entityRoot.Position).Magnitude

                -- Calculate damage with falloff
                local damageMultiplier = 1.0
                if falloff then
                    damageMultiplier = 1 - (distance / radius)
                    damageMultiplier = math.max(0, damageMultiplier)
                end

                local finalDamage = damage * damageMultiplier

                -- Apply damage
                applyDamageToEntity(attacker, entity, weaponName, {
                    damageOverride = finalDamage,
                    hitPosition = targetPosition,
                })

                table.insert(hits, {
                    entity = entity,
                    damage = finalDamage,
                    distance = distance,
                })

                if #hits >= maxTargets then
                    break
                end
            end
        end
    end

    -- Create persistent zone if configured
    if weaponConfig.duration and weaponConfig.tickRate then
        AOEZoneManager.createZone(
            targetPosition,
            radius,
            weaponName,
            attacker,
            attackingPlayer,
            weaponConfig.duration,
            weaponConfig.tickRate
        )
    end

    return hits
end

-- Helper: Check if entity should be affected by AOE
function shouldAffectEntity(entity: Model, attacker: Model, targetFilter: string?): boolean
    if not targetFilter or targetFilter == "all" then
        return true
    end

    local entityPlayer = Players:GetPlayerFromCharacter(entity)
    local attackerPlayer = Players:GetPlayerFromCharacter(attacker)

    if targetFilter == "allies" then
        -- Only affect allies (same player or self)
        if entityPlayer == attackerPlayer then
            return true
        end
        -- TODO: Team support
        return false

    elseif targetFilter == "enemies" then
        -- Only affect enemies (different player or NPCs)
        if entityPlayer ~= attackerPlayer then
            return true
        end
        return false
    end

    return true
end
```

#### CombatSystem.applyDamageToEntity()

**Purpose:** Low-level API for applying damage to a single entity. Used by:
- `performAOEAttack()` for each entity hit
- Custom spell Tool scripts
- Special attacks with custom logic

**Signature:**
```lua
function CombatSystem.applyDamageToEntity(
    attacker: Model,
    target: Model,
    weaponName: string,
    options: {
        damageOverride: number?,        -- Use instead of weapon damage
        hitPosition: Vector3?,          -- Where target was hit (for DamageCalculator)
        bypassInvulnerability: boolean?, -- Skip invuln check
    }?
): boolean
```

**Logic:**
1. Validate target has Humanoid
2. Check PvP rules (unless bypassed)
3. Check invulnerability (unless bypassed)
4. Get damage value (override or weapon config)
5. Calculate damage via DamageCalculator (with hit location if provided)
6. Apply damage/healing to Humanoid
7. Set invulnerability
8. Show CombatFeedback
9. Return true if damage applied

---

## Projectile + AOE Integration

### ProjectilePhysics Update

**File:** `src/shared/ProjectilePhysics.luau`

**Change:** When projectile impacts, check if weapon has `aoeOnImpact`.

**Modified Section:**
```lua
-- In updateProjectile(), when raycast hits something:
if raycastResult then
    local hitEntity = findEntityFromPart(raycastResult.Instance)

    -- Check for AOE on impact
    local weaponConfig = CombatSystem.getWeaponConfig(projectile.weapon)

    if weaponConfig and weaponConfig.aoeOnImpact then
        -- Trigger AOE at impact position
        local hits = CombatSystem.performAOEAttack(
            projectile.attacker,
            raycastResult.Position,
            projectile.weapon,
            projectile.attackingPlayer,
            {
                damageOverride = weaponConfig.aoeDamage,
                radius = weaponConfig.aoeRadius,
                falloff = weaponConfig.aoeFalloff,
                maxTargets = weaponConfig.maxTargets,
            }
        )

        print(`Projectile AOE hit {#hits} entities at {raycastResult.Position}`)
    elseif hitEntity then
        -- Normal projectile hit (existing logic)
        -- Apply damage to single entity
    end

    -- Destroy projectile
    return true -- shouldDestroy
end
```

**Note:** Projectile AOE can hit entities along flight path (via `damage`) AND entities in explosion radius (via `aoeDamage`). These are separate damage instances.

---

## EntityController Integration

**File:** `src/shared/EntityController.luau`

**Update `performAttack()` function** to support hitscan and AOE.

**Added Logic:**
```lua
-- After existing melee and projectile handling:

elseif weaponConfig.type == "hitscan" then
    -- Hitscan attack
    local targetPos = target.Character.HumanoidRootPart.Position
    local entityPos = entity.humanoidRootPart.Position

    -- Aim at target's center mass
    local aimTarget = targetPos + Vector3.new(0, 2, 0)
    local direction = (aimTarget - entityPos).Unit

    playAnimation(entity, "attack")
    playSound(entity, "attack")
    updateEntityState(entity, "attacking")

    task.wait(weaponConfig.castDuration)

    -- Perform hitscan
    local origin = entityPos + Vector3.new(0, 1, 0)
    local result = CombatSystem.performHitscan(
        origin,
        direction,
        weaponName,
        entity.model,
        nil, -- No attacking player (NPC)
        weaponConfig.requiresTarget and target.Character or nil
    )

    if result.hit then
        print(`*** {entity.entityType} hit {target.Name} with {weaponName}`)
    else
        print(`*** {entity.entityType} missed with {weaponName}`)
    end

elseif weaponConfig.type == "aoe" then
    -- AOE attack
    local targetPos: Vector3

    if weaponConfig.range == 0 then
        -- Self-centered AOE
        targetPos = entity.humanoidRootPart.Position
    else
        -- Targeted at player position
        targetPos = target.Character.HumanoidRootPart.Position
    end

    playAnimation(entity, "attack")
    playSound(entity, "attack")
    updateEntityState(entity, "attacking")

    -- Show telegraph
    local telegraph = AOETelegraph.showCircleTelegraph(
        targetPos,
        weaponConfig.aoeRadius or 10,
        weaponConfig.castDuration,
        "damage"
    )

    task.wait(weaponConfig.castDuration)

    -- If projectile AOE, spawn projectile
    if weaponConfig.projectileSpeed then
        local direction = (targetPos - entity.humanoidRootPart.Position).Unit
        local origin = entity.humanoidRootPart.Position + (direction * 2)

        ProjectileManager.spawnProjectile(
            origin,
            direction,
            weaponName,
            entity.model,
            nil, -- No attacking player
            target.Character -- Locked target
        )
    else
        -- Instant AOE
        local hits = CombatSystem.performAOEAttack(
            entity.model,
            targetPos,
            weaponName,
            nil
        )

        print(`*** {entity.entityType} hit {#hits} entities with {weaponName} AOE`)
    end
end

entity.lastAttackTime = tick()
```

---

## GameConfig Updates

**File:** `src/shared/GameConfig.luau`

**Add to `weapons` table:**

```lua
weapons = {
    -- Existing weapons (Axe, Pickaxe, WolfClaw, etc.)
    -- ...

    -- ============================================
    -- HITSCAN WEAPONS
    -- ============================================

    -- Standard hitscan with visual beam
    Crossbow = {
        type = "hitscan",
        name = "Crossbow",
        requiresTarget = false,     -- Free aim
        range = 100,
        damage = 40,
        visualEffect = "beam",
        castDuration = 0.3,
        cooldown = 2.0,
        -- spread = 2,              -- TODO: Future accuracy variance
    },

    -- Targeted healing (no raycast, no visual)
    DirectHeal = {
        type = "hitscan",
        name = "Direct Heal",
        requiresTarget = true,      -- Must select ally target
        range = 50,
        damage = -30,               -- Negative = healing
        visualEffect = "none",
        targetFilter = "allies",
        castDuration = 0.2,
        cooldown = 3.0,
    },

    -- Hitscan with AOE explosion
    ExplosiveBolt = {
        type = "hitscan",
        name = "Explosive Bolt",
        requiresTarget = false,
        range = 80,
        damage = 20,                -- Direct hit damage
        visualEffect = "beam",

        aoeOnImpact = true,
        aoeDamage = 40,             -- Explosion damage
        aoeRadius = 10,
        aoeFalloff = true,
        maxTargets = 5,

        castDuration = 0.4,
        cooldown = 4.0,
    },

    -- ============================================
    -- AOE WEAPONS
    -- ============================================

    -- Instant self-centered AOE
    GroundSlam = {
        type = "aoe",
        name = "Ground Slam",
        range = 0,                  -- Self-centered
        aoeDamage = 35,
        aoeRadius = 20,
        aoeFalloff = true,
        maxTargets = 15,
        castDuration = 0.7,
        cooldown = 8.0,
    },

    -- Projectile AOE (explodes on impact)
    Fireball = {
        type = "aoe",
        name = "Fireball",
        projectileSpeed = 40,
        damage = 30,                -- Touch damage during flight
        aoeDamage = 50,             -- Explosion damage
        range = 60,
        aoeRadius = 15,
        aoeFalloff = true,
        maxTargets = 10,
        castDuration = 1.0,
        cooldown = 5.0,

        projectileConfig = {
            modelPath = "Fireball",
            speed = 40,
            maxRange = 60,
            trailEnabled = true,
            trailColor = Color3.fromRGB(255, 100, 0),
            impactEffect = "Explosion",
        },
    },

    -- Persistent healing zone
    HealingCircle = {
        type = "aoe",
        name = "Healing Circle",
        range = 40,
        aoeDamage = -20,            -- Heal per tick
        aoeRadius = 12,
        aoeFalloff = false,
        maxTargets = 5,
        castDuration = 2.0,
        cooldown = 15.0,

        duration = 5.0,             -- Lasts 5 seconds
        tickRate = 1.0,             -- Heal every second (5 ticks)
        targetFilter = "allies",
    },

    -- Persistent damage zone
    PoisonCloud = {
        type = "aoe",
        name = "Poison Cloud",
        range = 40,
        aoeDamage = 10,             -- Damage per tick
        aoeRadius = 12,
        aoeFalloff = false,
        maxTargets = 999,
        castDuration = 2.0,
        cooldown = 15.0,

        duration = 8.0,
        tickRate = 1.0,
        targetFilter = "enemies",
    },
}
```

---

## Template Models Setup

Create template models in ReplicatedStorage for visual effects:

### Structure:
```
ReplicatedStorage
└── Models
    └── Effects
        ├── Hitscan
        │   ├── BeamEffect (Part with Beam instance)
        │   └── ImpactEffect (Part with ParticleEmitter)
        └── AOE
            ├── CircleTelegraph (Cylinder with decal + particles)
            └── ZoneEffect (Cylinder with particles for persistent zones)
```

### Template Details:

**BeamEffect:**
- Part with two Attachments (start, end)
- Beam instance connecting them
- Semi-transparent, neon material
- Default color: cyan (recolored at runtime based on damage type)

**ImpactEffect:**
- Small Part (0.1, 0.1, 0.1)
- ParticleEmitter with burst emission
- Default color: white (recolored at runtime)

**CircleTelegraph:**
- Cylinder Part (radius x 2, 0.1, radius x 2)
- SurfaceGui on top with circular decal/image
- ParticleEmitter around perimeter (attached to outer edge)
- Pulse TweenAnimation (transparency 0.3 ↔ 0.7)
- Default color: red for damage, green for healing

**ZoneEffect:**
- Cylinder Part (same as CircleTelegraph)
- Continuous particle emission (not burst)
- Transparent, glowing effect

---

## Custom AOE System (Advanced)

For spells with complex, non-standard behavior (custom shapes, special mechanics), use the **Custom AOE** system.

### Overview

**Standard AOE** (config-driven) handles 90% of spells:
- Simple circular radius
- Config properties: `aoeRadius`, `aoeFalloff`, etc.
- Handled entirely by `CombatSystem.performAOEAttack()`

**Custom AOE** (script-driven) for complex spells:
- Custom hitbox shapes (cone, rectangle, wall, chain lightning, etc.)
- Tool contains custom detection script
- Script finds affected entities
- Uses `CombatSystem.applyDamageToEntity()` for each entity

### Architecture

#### Two-Tier System

**Tier 1: Standard AOE** (90% of spells)
```lua
Fireball = {
    type = "aoe",
    aoeRadius = 15,
    aoeDamage = 50,
    -- CombatSystem handles everything
}
```

**Tier 2: Custom AOE** (complex spells)
```
Tool (DragonBreathSpell)
  ├── Handle (mesh/parts for visual)
  ├── CustomAOEScript (Script) ← Custom detection logic
  └── Configuration (ModuleScript with weapon stats)
```

### Custom AOE API

#### CombatSystem.applyDamageToEntity()

Low-level API for applying damage to a single entity.

**Signature:**
```lua
function CombatSystem.applyDamageToEntity(
    attacker: Model,
    target: Model,
    weaponName: string,
    options: {
        damageOverride: number?,        -- Custom damage per entity
        hitPosition: Vector3?,          -- Where target was hit
        bypassInvulnerability: boolean?, -- Skip invuln check (use carefully)
    }?
): boolean
```

**What it does:**
- ✅ Validates PvP rules
- ✅ Checks invulnerability (unless bypassed)
- ✅ Calculates damage via DamageCalculator
- ✅ Shows CombatFeedback
- ✅ Sets invulnerability
- ✅ Returns true if damage applied

**What it does NOT do:**
- ❌ Find targets (your script does this)
- ❌ Create visual effects (your script does this)
- ❌ Handle telegraphs (your script does this)

---

### Custom AOE Implementation Guide

#### Step 1: Create Weapon Config

Add to `GameConfig.weapons`:

```lua
DragonBreath = {
    type = "aoe",              -- Still type "aoe" for classification
    name = "Dragon Breath",
    customDetection = true,    -- Flag as custom AOE

    -- Custom properties (used by your script)
    coneRange = 25,
    coneAngle = 60,
    aoeDamage = 40,            -- Your script reads this

    -- Standard properties
    castDuration = 1.5,
    cooldown = 10.0,
}
```

#### Step 2: Create Tool Structure

```
ReplicatedStorage
└── Tools
    └── DragonBreathSpell (Tool)
        ├── Handle (MeshPart - visual representation)
        ├── DragonBreathScript (Script - custom logic)
        └── DragonBreathConfig (ModuleScript - optional, weapon-specific config)
```

#### Step 3: Implement Custom Detection Script

**File:** `DragonBreathScript` (inside Tool)

```lua
--!strict

local Tool = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatSystem = require(ReplicatedStorage.Shared.CombatSystem)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local weaponName = "DragonBreath"
local weaponConfig = GameConfig.weapons[weaponName]

-- Custom cone detection function
local function findEntitiesInCone(
    origin: Vector3,
    direction: Vector3,
    range: number,
    angleDegrees: number
): {Model}
    local entitiesHit: {Model} = {}

    -- Get all potential entities in range (using sphere for initial filter)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Tool.Parent} -- Exclude player

    local parts = workspace:GetPartBoundsInRadius(origin, range, params)

    -- Filter to cone shape
    local seenEntities: {[Model]: boolean} = {}

    for _, part in parts do
        local entity = findEntityFromPart(part)

        if entity and not seenEntities[entity] then
            seenEntities[entity] = true

            local entityRoot = entity:FindFirstChild("HumanoidRootPart")
            if entityRoot then
                local toEntity = (entityRoot.Position - origin).Unit
                local dotProduct = direction:Dot(toEntity)

                -- Check if within cone angle
                local angleThreshold = math.cos(math.rad(angleDegrees / 2))

                if dotProduct >= angleThreshold then
                    -- Entity is in cone
                    local distance = (entityRoot.Position - origin).Magnitude
                    if distance <= range then
                        table.insert(entitiesHit, entity)
                    end
                end
            end
        end
    end

    return entitiesHit
end

-- Helper: Find entity from part
local function findEntityFromPart(part: BasePart): Model?
    local current = part.Parent
    while current and current ~= workspace do
        if current:IsA("Model") then
            local player = Players:GetPlayerFromCharacter(current)
            if player then
                return current
            end

            local entityType = current:GetAttribute("EntityType")
            if entityType then
                return current
            end
        end
        current = current.Parent
    end
    return nil
end

-- Tool activation
Tool.Activated:Connect(function()
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    -- Get attack parameters
    local origin = humanoidRootPart.Position + Vector3.new(0, 2, 0) -- Chest height
    local direction = humanoidRootPart.CFrame.LookVector

    -- Show telegraph (custom visual effect)
    showConeTelegraph(origin, direction, weaponConfig.coneRange, weaponConfig.coneAngle, weaponConfig.castDuration)

    -- Wait cast duration
    task.wait(weaponConfig.castDuration)

    -- Find entities in cone
    local entitiesHit = findEntitiesInCone(
        origin,
        direction,
        weaponConfig.coneRange,
        weaponConfig.coneAngle
    )

    -- Apply damage to each entity via central system
    for _, entity in entitiesHit do
        CombatSystem.applyDamageToEntity(
            character,
            entity,
            weaponName,
            {
                damageOverride = weaponConfig.aoeDamage,
                hitPosition = entity:FindFirstChild("HumanoidRootPart").Position,
            }
        )
    end

    -- Show impact effects (custom)
    showConeImpactEffect(origin, direction, weaponConfig.coneRange, weaponConfig.coneAngle)

    print(`DragonBreath hit {#entitiesHit} entities`)
end)

-- Custom visual: Cone telegraph
function showConeTelegraph(origin, direction, range, angleDegrees, duration)
    -- Create wedge/cone-shaped Part to show affected area
    local telegraph = Instance.new("Part")
    telegraph.Anchored = true
    telegraph.CanCollide = false
    telegraph.Transparency = 0.5
    telegraph.Material = Enum.Material.Neon
    telegraph.Color = Color3.fromRGB(255, 100, 100) -- Red for damage
    telegraph.Size = Vector3.new(range * math.tan(math.rad(angleDegrees / 2)) * 2, 0.5, range)
    telegraph.CFrame = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -range / 2)
    telegraph.Parent = workspace

    -- Pulse animation
    local tween = game:GetService("TweenService"):Create(
        telegraph,
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Transparency = 0.8}
    )
    tween:Play()

    -- Destroy after duration
    game:GetService("Debris"):AddItem(telegraph, duration)
end

-- Custom visual: Cone impact effect
function showConeImpactEffect(origin, direction, range, angleDegrees)
    -- Particle burst, flame effects, etc.
    -- ... custom VFX
end
```

#### Step 4: Server-Side Validation (Optional)

For server-authoritative custom AOE, use RemoteEvents:

**Tool Script (Client):**
```lua
Tool.Activated:Connect(function()
    -- Show telegraph immediately (client-side prediction)
    showConeTelegraph(...)

    -- Request server to perform attack
    local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
    RemoteEvents.Events.PerformCustomAOE:FireServer(weaponName, origin, direction)
end)
```

**Server Script:**
```lua
RemoteEvents.Events.PerformCustomAOE.OnServerEvent:Connect(function(player, weaponName, origin, direction)
    -- Validate cooldown, range, etc.

    -- Find entities (same logic as client)
    local entitiesHit = findEntitiesInCone(origin, direction, range, angle)

    -- Apply damage (server-authoritative)
    for _, entity in entitiesHit do
        CombatSystem.applyDamageToEntity(character, entity, weaponName, {...})
    end
end)
```

---

### Custom AOE Examples

#### Example 1: Cone Attack (Dragon Breath)

**Weapon Config:**
```lua
DragonBreath = {
    type = "aoe",
    customDetection = true,
    coneRange = 25,
    coneAngle = 60,
    aoeDamage = 40,
    castDuration = 1.5,
    cooldown = 10.0,
}
```

**Detection:** Cone-shaped area in front of attacker

**Visual:** Wedge-shaped telegraph, flame particle effects

---

#### Example 2: Chain Lightning

**Weapon Config:**
```lua
ChainLightning = {
    type = "aoe",
    customDetection = true,
    initialDamage = 50,
    bounceCount = 3,
    bounceRange = 15,
    damageFalloff = 0.7,  -- Each bounce does 70% of previous
    castDuration = 0.8,
    cooldown = 6.0,
}
```

**Detection Logic:**
```lua
-- Hit initial target
local firstTarget = findClosestEnemy(origin, direction, maxRange)
applyDamageToEntity(attacker, firstTarget, weaponName, {damageOverride = initialDamage})

-- Bounce to nearby enemies
local previousTarget = firstTarget
local currentDamage = initialDamage * damageFalloff

for i = 1, bounceCount do
    local nextTarget = findClosestEnemyExcluding(previousTarget.Position, bounceRange, hitTargets)
    if nextTarget then
        applyDamageToEntity(attacker, nextTarget, weaponName, {damageOverride = currentDamage})
        previousTarget = nextTarget
        currentDamage = currentDamage * damageFalloff
    else
        break -- No more targets
    end
end
```

**Visual:** Lightning beam between each target

---

#### Example 3: Wall of Fire

**Weapon Config:**
```lua
WallOfFire = {
    type = "aoe",
    customDetection = true,
    wallLength = 20,
    wallWidth = 2,
    aoeDamage = 15,
    duration = 6.0,
    tickRate = 0.5,
    castDuration = 1.0,
    cooldown = 12.0,
}
```

**Detection:** Rectangular zone perpendicular to aim direction

**Logic:**
```lua
-- Create custom AOE zone (rectangular, not circular)
local zoneData = {
    shape = "rectangle",
    position = targetPosition,
    direction = aimDirection,
    length = wallLength,
    width = wallWidth,
    -- ... rest of zone data
}

-- Custom tick function
function tickWallZone(zone)
    local entitiesInWall = findEntitiesInRectangle(zone.position, zone.direction, zone.length, zone.width)
    for _, entity in entitiesInWall do
        applyDamageToEntity(zone.attacker, entity, zone.weaponName, {damageOverride = zone.damage})
    end
end
```

**Visual:** Rectangular fire particles forming a wall

---

#### Example 4: Healing Nova (Self-Centered AOE with Custom Filter)

**Weapon Config:**
```lua
HealingNova = {
    type = "aoe",
    customDetection = true,
    novaRadius = 20,
    baseHealing = 40,
    healingPerAlly = -5,  -- Reduces healing if more allies present (balance)
    castDuration = 1.5,
    cooldown = 20.0,
}
```

**Detection:** All allies within radius

**Logic:**
```lua
local alliesInRange = findAlliesInRadius(origin, novaRadius)

-- Adjust healing based on number of allies
local healPerAlly = baseHealing + (healingPerAlly * #alliesInRange)
healPerAlly = math.max(healPerAlly, 10) -- Minimum 10 healing

for _, ally in alliesInRange do
    applyDamageToEntity(
        character,
        ally,
        weaponName,
        {damageOverride = -healPerAlly}  -- Negative = healing
    )
end
```

**Visual:** Expanding ring of green particles

---

### Custom AOE Best Practices

#### 1. Always Use applyDamageToEntity()
**DON'T:**
```lua
-- Bypasses all game rules!
targetHumanoid:TakeDamage(50)
```

**DO:**
```lua
-- Validates PvP, invulnerability, shows feedback
CombatSystem.applyDamageToEntity(attacker, target, weaponName, {damageOverride = 50})
```

#### 2. Validate Input Parameters
```lua
-- Validate weapon config exists
local weaponConfig = GameConfig.weapons[weaponName]
if not weaponConfig then
    warn(`Weapon {weaponName} not found`)
    return
end

-- Validate custom properties
if not weaponConfig.coneRange or not weaponConfig.coneAngle then
    warn(`DragonBreath missing required properties`)
    return
end
```

#### 3. Show Clear Telegraphs
```lua
-- Players should see the attack coming
showConeTelegraph(origin, direction, range, angle, castDuration)
task.wait(castDuration) -- Give players time to dodge
-- Then apply damage
```

#### 4. Use Spatial Filtering
```lua
-- First filter by sphere (cheap)
local parts = workspace:GetPartBoundsInRadius(origin, maxRange, params)

-- Then filter by custom shape (cone, rectangle, etc.)
for _, part in parts do
    if isInCone(part, origin, direction, angle) then
        -- Process entity
    end
end
```

#### 5. Avoid Hitting Same Entity Multiple Times
```lua
local hitEntities: {[Model]: boolean} = {}

for _, part in parts do
    local entity = findEntityFromPart(part)
    if entity and not hitEntities[entity] then
        hitEntities[entity] = true
        -- Apply damage once per entity
    end
end
```

#### 6. Limit Max Targets
```lua
local hitCount = 0
local maxTargets = weaponConfig.maxTargets or 10

for _, entity in potentialTargets do
    if hitCount >= maxTargets then
        break
    end

    applyDamageToEntity(...)
    hitCount = hitCount + 1
end
```

---

### When to Use Custom AOE

**Use Standard AOE when:**
- ✅ Simple circular/spherical radius
- ✅ Standard falloff behavior
- ✅ No special mechanics

**Use Custom AOE when:**
- ✅ Non-circular shapes (cone, rectangle, line, etc.)
- ✅ Chain/bounce mechanics
- ✅ Custom damage calculations (distance-based, ally-count-based, etc.)
- ✅ Special visual effects
- ✅ Complex targeting logic

---

### Benefits of Custom AOE System

**For Developers:**
- Full control over hitbox detection
- Custom visual effects
- Unique spell mechanics
- Reuses damage validation/calculation/feedback

**For Players:**
- Unique, interesting spells
- Consistent damage rules (PvP, invulnerability work the same)
- Clear visual feedback (telegraphs, effects)

**For Game Balance:**
- Central damage system enforces rules
- No bypassing invulnerability or PvP settings
- DamageCalculator applies to all custom spells
- Server can validate custom AOE (if using RemoteEvents)

---

## Implementation Checklist

### Phase 1: Hitscan
- [ ] Create `src/shared/HitscanEffects.luau`
  - [ ] `showBeam()` function
  - [ ] `showHitEffect()` function
  - [ ] Use template models from ReplicatedStorage
- [ ] Implement `CombatSystem.performHitscan()`
  - [ ] Targeted mode (requiresTarget = true)
  - [ ] Free-aim mode (requiresTarget = false)
  - [ ] AOE on impact support
  - [ ] Optional visual effects
  - [ ] Add TODO comment for spread

### Phase 2: AOE
- [ ] Create `src/shared/AOETelegraph.luau`
  - [ ] `showCircleTelegraph()` function
  - [ ] Use template models
- [ ] Create `src/shared/AOEZoneManager.luau`
  - [ ] `createZone()` function
  - [ ] `tickZone()` function
  - [ ] `updateZones()` function
  - [ ] `initialize()` function (auto-init)
  - [ ] Single Heartbeat loop
- [ ] Implement `CombatSystem.performAOEAttack()`
  - [ ] Radius detection
  - [ ] Damage falloff
  - [ ] MaxTargets limiting
  - [ ] Target filtering (allies/enemies)
  - [ ] Persistent zone creation
- [ ] Implement `CombatSystem.applyDamageToEntity()`
  - [ ] Damage calculation
  - [ ] PvP validation
  - [ ] Invulnerability handling
  - [ ] Feedback integration

### Phase 3: Integration
- [ ] Update `src/shared/ProjectilePhysics.luau`
  - [ ] Check for `aoeOnImpact` on impact
  - [ ] Trigger AOE at impact position
- [ ] Update `src/shared/EntityController.luau`
  - [ ] Add hitscan branch in `performAttack()`
  - [ ] Add AOE branch in `performAttack()`
  - [ ] Telegraph for entity AOE attacks

### Phase 4: Config & Assets
- [ ] Update `src/shared/GameConfig.luau`
  - [ ] Add hitscan weapons
  - [ ] Add AOE weapons
  - [ ] Add hybrid weapons (hitscan+AOE, projectile+AOE)
- [ ] Create template models in ReplicatedStorage
  - [ ] Hitscan templates (BeamEffect, ImpactEffect)
  - [ ] AOE templates (CircleTelegraph, ZoneEffect)

### Phase 5: Testing
- [ ] `rojo build` to validate syntax
- [ ] Test targeted hitscan (DirectHeal)
- [ ] Test free-aim hitscan (Crossbow)
- [ ] Test hitscan + AOE (ExplosiveBolt)
- [ ] Test instant AOE (GroundSlam)
- [ ] Test projectile AOE (Fireball)
- [ ] Test persistent zones (HealingCircle, PoisonCloud)
- [ ] Test entity AI with new weapon types
- [ ] Test healing (negative damage)
- [ ] Test target filtering (allies/enemies)

---

## Performance Considerations

### AOE Zone Management
- Single update loop for all zones (not one per zone)
- Auto-cleanup expired zones
- Limit max concurrent zones (e.g., 20 max)

### AOE Entity Detection
- Use spatial partitioning (`GetPartBoundsInRadius`)
- Filter unique entities (avoid duplicate hits)
- Respect maxTargets to prevent hitting entire server

### Hitscan Raycasting
- Single raycast per shot (very cheap)
- Filter params to ignore attacker/allies

### Visual Effects
- Use object pooling for beam/impact effects (future optimization)
- Destroy effects with Debris service
- Keep particle counts reasonable

---

## Future Enhancements (Not in Phase 2)

### Cone Weapons
- New weapon type: `type = "cone"`
- Properties: `coneRange`, `coneAngle`
- Custom detection logic (not circular radius)
- Use cases: Shotgun, Dragon Breath, Flame Spray

### Hitscan Spread
- `spread = 2` (degrees of random deviation)
- Accuracy variance for balance
- Could be stat-based (player accuracy stat)

### Projectile Homing
- Track locked target during flight
- Adjust trajectory to follow moving target
- Balance with turn rate limitation

### Chain Lightning
- Custom spell that bounces between targets
- Uses `applyDamageToEntity()` for each hit
- Decreasing damage per bounce

---

## Summary

**What This Implements:**

1. **Hitscan Weapons**
   - Two modes: Targeted (no raycast) and Free-Aim (raycast)
   - Optional visual effects (beam/none)
   - AOE on impact support
   - Instant damage application

2. **AOE Weapons**
   - Three variants: Instant, Projectile, Persistent
   - Radius-based detection with falloff
   - Target filtering (allies/enemies)
   - Telegraph system for counterplay
   - Persistent zones with tick-based damage/healing

3. **Unified Damage System**
   - All weapon types use DamageCalculator
   - All feedback through CombatFeedback
   - Consistent PvP/invulnerability rules
   - Negative damage = healing (universal)

4. **Extensibility**
   - Custom spell Tools via `applyDamageToEntity()` API
   - Template-based visual effects
   - Config-driven behavior

**Key Design Principles:**
- ✅ Reuse existing systems (ProjectileManager, DamageCalculator, CombatFeedback)
- ✅ Config-driven for simplicity, API for complexity
- ✅ Server-authoritative (all damage validated)
- ✅ Visual clarity (telegraphs, beams, zones)
- ✅ Performance-conscious (single loops, spatial partitioning)
