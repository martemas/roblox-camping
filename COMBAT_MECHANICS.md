# Combat System - Complete Implementation Guide

## Table of Contents
1. [Problem Statement](#problem-statement)
2. [Solution Overview](#solution-overview)
3. [Combat System Architecture](#combat-system-architecture)
4. [Weapon System Architecture](#weapon-system-architecture)
5. [Implementation Steps](#implementation-steps)
6. [Code Examples](#code-examples)
7. [Testing Checklist](#testing-checklist)

---

## Problem Statement

### Current System Issues
**Location:** `src/server/ToolManager.server.luau:108-243`, `src/shared/EntityController.luau:236-286`

**Problems:**
1. **Inconsistent damage detection:**
   - Players use touch-based collision detection (tool handle touches entity)
   - Entities use range-based detection (distance check)
   - Different systems = different bugs and balance issues

2. **Touch detection problems:**
   - Unreliable in multiplayer (lag, timing issues)
   - Can miss fast-moving targets
   - Hard to debug and predict

3. **No weapon stats for entities:**
   - Wolf, Bear, Zombie have hardcoded `damage`, `attackDistance`, `attackCooldown`
   - Not scalable for adding new entities or weapons
   - Players can't see what weapon an entity is using

4. **No telegraph system:**
   - Attacks are instant (no counterplay)
   - Players can't dodge entity attacks
   - No skill-based combat

5. **Separate damage systems:**
   - Players and entities have different damage calculation/display logic
   - Code duplication and inconsistency

### Goal
Create a unified, range-based weapon system where:
- ✅ All combatants (players + entities) use the same combat logic
- ✅ All damage is calculated by weapon range (configurable with collision fallback)
- ✅ All entities have a `primaryWeapon` with stats (damage, range, cooldown)
- ✅ Telegraph system (`castDuration`) allows dodging
- ✅ Unified damage calculation and display for all entity types
- ✅ Support for PvE and PvP combat modes
- ✅ Supports multiple weapon types: melee, projectile, hitscan, AOE

---

## Solution Overview

### Core Concept
**Every combatant has a weapon. Every weapon has stats. All damage flows through unified systems.**

```
Player with Axe equipped → weaponRef: "Axe" → weapons.Axe = {damage: 20, range: 8}
Wolf entity → primaryWeapon: "WolfClaw" → weapons.WolfClaw = {damage: 8, range: 10}
Player targeting another player (PvP) → same weapon system
```

### Attack Flow (All Combatants)
```
1. Initiate attack (player clicks, entity AI decides)
2. Check cooldown (weapon.cooldown)
3. Check invulnerability (target immune to this weapon type?)
4. Play attack animation
5. Wait castDuration (telegraph window - target can dodge)
6. After castDuration: Detect hits based on mode
   - Mode A (damageTargetOnly=true): Check if targeted entity in range
   - Mode B (damageTargetOnly=false): Find ALL entities in range
7. For each valid target:
   - Apply damage via CombatSystem
   - Set invulnerability for weapon type
   - Show feedback via CombatFeedback (damage numbers, sounds)
8. Return attack result
```

### Key Innovation: castDuration
The `castDuration` property creates a **telegraph window** between animation start and damage application:

**Example: Wolf attacks player**
```
t=0.0s: Wolf starts attack animation (castDuration = 0.5s)
t=0.1s: Player sees wolf lunging
t=0.2s: Player starts running away
t=0.5s: castDuration ends → Check if player in range (10 studs)
        - If player ran 12 studs away: NO DAMAGE (successful dodge!)
        - If player still within 10 studs: DAMAGE APPLIED
```

This allows **skill-based counterplay** - fast reactions = avoid damage.

---

## Combat System Architecture

### Module Structure

```
src/shared/
  ├── CombatSystem.luau        # Core combat logic (hit detection, damage calculation)
  ├── CombatFeedback.luau      # Damage display, hit effects (unified for all entities)
  ├── EntityController.luau    # Entity AI and behavior (updated to use CombatSystem)
  ├── GameConfig.luau          # Configuration (add weapons + combat sections)
  └── TargetingSystem.luau     # Target selection (existing, updated for PvP)

src/server/
  └── ToolManager.server.luau  # Player weapon handling (updated to use CombatSystem)
```

### New GameConfig.combat Section

```lua
combat = {
    -- Hit Detection Mode
    damageTargetOnly = false,  -- true: only damage targeted entity
                               -- false: damage all entities in range

    -- Invulnerability Frames (prevent weapon spam)
    invulnerabilityFrames = true,      -- Enable/disable invulnerability system
    invulnerabilityDuration = 0.5,     -- Seconds of immunity per weapon type

    -- Game Modes
    pvpEnabled = false,        -- Enable player vs player damage
    teamBased = false,         -- Enable team-based combat (future)
    friendlyFire = false,      -- Can teammates damage each other (future)
}
```

### Invulnerability System

**Goal:** Prevent multiple entities with the same weapon type from overwhelming targets.

**How it works:**
- When entity is hit by weapon type "WolfClaw", it becomes immune to ALL "WolfClaw" attacks
- Other weapon types (BearClaw, Axe, etc.) can still damage during immunity
- Each weapon type has independent immunity timer

**Implementation:**
```lua
-- On Humanoid, track immunity per weapon type
Humanoid:SetAttribute("InvulnerableTo_WolfClaw", true)
Humanoid:SetAttribute("InvulnerableTo_BearClaw", false)
Humanoid:SetAttribute("InvulnerableTo_Axe", false)

-- After invulnerabilityDuration seconds, clear the attribute
task.delay(invulnerabilityDuration, function()
    Humanoid:SetAttribute("InvulnerableTo_WolfClaw", false)
end)
```

**Example Scenario:**
```
t=0.0s: Wolf1 hits Player with WolfClaw (8 damage)
        → Player gets "InvulnerableTo_WolfClaw" for 0.5s
t=0.2s: Wolf2 tries to hit Player with WolfClaw
        → BLOCKED (player still immune to WolfClaw)
t=0.3s: Bear tries to hit Player with BearClaw
        → SUCCESS (25 damage, BearClaw ≠ WolfClaw)
t=0.5s: Immunity to WolfClaw expires
t=0.6s: Wolf1 can hit Player again
```

### Hit Detection Modes

#### Mode 1: Target-Only (`damageTargetOnly = true`)
- Only damages the entity currently targeted by TargetingSystem
- Requires player to select target (X key) before attacking
- More tactical, encourages target prioritization
- Simpler hit detection logic

**Use case:** Tactical combat where focus-fire matters

#### Mode 2: Area-of-Effect (`damageTargetOnly = false`)
- Damages ALL entities within weapon range
- No targeting required, swing hits everything nearby
- Better for crowd control
- More forgiving for new players

**Use case:** Action-oriented combat, handling groups of enemies

### Unified Damage System

All damage flows through **CombatSystem** → **CombatFeedback**:

```
Player attacks Wolf:
  ToolManager → CombatSystem.attemptMeleeAttack() → CombatFeedback.showDamage()

Wolf attacks Player:
  EntityController → CombatSystem.attemptMeleeAttack() → CombatFeedback.showDamage()

Player attacks Player (PvP):
  ToolManager → CombatSystem.attemptMeleeAttack() → CombatFeedback.showDamage()
```

**Benefits:**
- Single source of truth for damage
- Consistent visuals across all combat
- Easier to balance and debug
- No code duplication

---

## Weapon System Architecture

### 1. Weapon Types

#### Type: Melee
**Description:** Close-range weapons with swing animation

**Required Properties:**
- `type`: "melee"
- `name`: Display name for UI (e.g., "Axe", "Wolf Claw")
- `damage`: Base damage value
- `range`: Attack range in studs
- `cooldown`: Seconds between attacks
- `castDuration`: Seconds from animation start to hit detection

**Detection Logic:**
1. Play swing animation
2. Wait `castDuration` seconds
3. Check if target within `range` studs
4. Apply damage if in range

**Example Configuration:**
```lua
weapons = {
    Axe = {
        type = "melee",
        name = "Axe",
        damage = 20,
        range = 8,              -- Can hit targets up to 8 studs away
        cooldown = 0.5,         -- 2 swings per second
        castDuration = 0.3,     -- 0.3s from swing start to hit check
    },

    WolfClaw = {
        type = "melee",
        name = "Wolf Claw",
        damage = 8,
        range = 10,
        cooldown = 2,
        castDuration = 0.5,     -- Players have 0.5s to dodge wolf attacks
    },

    BearClaw = {
        type = "melee",
        name = "Bear Claw",
        damage = 25,
        range = 12,
        cooldown = 2,
        castDuration = 0.8,     -- Slow, telegraphed attack - easier to dodge
    },

    ZombieBite = {
        type = "melee",
        name = "Zombie Bite",
        damage = 15,
        range = 8,
        cooldown = 2,
        castDuration = 0.4,
    },
}
```

---

#### Type: Projectile
**Description:** Weapons that fire physical projectiles (arrows, fireballs)

**Required Properties:**
- `type`: "projectile"
- `name`: Display name
- `damage`: Base damage
- `range`: Maximum travel distance before projectile despawns
- `cooldown`: Seconds between shots
- `castDuration`: Draw/charge time before projectile spawns
- `projectileSpeed`: Studs per second

**Detection Logic:**
1. Play draw/charge animation
2. Wait `castDuration` seconds
3. Spawn projectile instance at attacker position
4. Projectile travels at `projectileSpeed` in aimed direction
5. Hit detection via `projectile.Touched` or continuous raycasts
6. On hit: Apply `damage`, destroy projectile
7. After traveling `range` studs: Despawn projectile (missed)

**Example Configuration:**
```lua
weapons = {
    Bow = {
        type = "projectile",
        name = "Bow",
        damage = 30,
        range = 100,            -- Arrow travels max 100 studs
        cooldown = 1.5,
        castDuration = 0.5,     -- 0.5s to draw arrow
        projectileSpeed = 80,   -- Arrow flies at 80 studs/sec
    },

    -- Example: Enemy that shoots projectiles
    SpiderWeb = {
        type = "projectile",
        name = "Spider Web",
        damage = 5,
        range = 40,
        cooldown = 3,
        castDuration = 0.6,
        projectileSpeed = 30,   -- Slow projectile, easier to dodge
    },
}
```

**Implementation Notes:**
- Create projectile Model/Part with proper collision settings
- Use BodyVelocity or LinearVelocity for movement
- Raycast ahead each frame to prevent tunneling through thin objects
- Add trail effects for visual clarity
- Projectile should ignore attacker (add to collision filter)

---

#### Type: Hitscan
**Description:** Instant-hit weapons using raycasting (crossbows, guns, lasers)

**Required Properties:**
- `type`: "hitscan"
- `name`: Display name
- `damage`: Base damage
- `range`: Maximum raycast distance
- `cooldown`: Seconds between shots
- `castDuration`: Aim/charge time before instant hit

**Detection Logic:**
1. Play aim/charge animation
2. Wait `castDuration` seconds
3. Perform raycast from attacker to target direction
4. Raycast parameters:
   - Origin: Attacker's weapon/barrel position
   - Direction: Attacker's aim direction
   - Max distance: `range`
   - Filter: Ignore attacker, teammates, environment (if applicable)
5. If raycast hits entity: Apply `damage` instantly
6. If raycast misses or exceeds range: No damage

**Example Configuration:**
```lua
weapons = {
    Crossbow = {
        type = "hitscan",
        name = "Crossbow",
        damage = 40,
        range = 120,            -- Can shoot up to 120 studs
        cooldown = 2.0,
        castDuration = 0.3,     -- 0.3s aim time
    },

    MagicMissile = {
        type = "hitscan",
        name = "Magic Missile",
        damage = 25,
        range = 80,
        cooldown = 1.0,
        castDuration = 0.4,
    },
}
```

**Implementation Notes:**
- Use `workspace:Raycast()` with proper RaycastParams
- Show visual beam/tracer from origin to hit point
- Play hit effect at impact location
- Consider adding spread/accuracy for balance

---

#### Type: AOE (Area of Effect)
**Description:** Attacks that damage multiple targets in an area

**Required Properties:**
- `type`: "aoe"
- `name`: Display name
- `damage`: Base damage (negative = healing)
- `range`: Cast range / targeting distance (0 = self-centered)
- `cooldown`: Seconds between casts
- `castDuration`: Cast/channel time - **CRITICAL for telegraphing AOE**
- `aoeRadius`: Damage radius in studs from impact point
- `aoeFalloff`: Boolean - if true, damage decreases with distance from center
- `maxTargets`: Maximum number of entities that can be hit

**Optional Properties:**
- `projectileSpeed`: If AOE effect travels (e.g., fireball)
- `duration`: For lingering AOE (damage over time zones)
- `tickRate`: Damage/heal frequency for DOT/HOT
- `targetFilter`: "allies", "enemies", "all"

**Detection Logic:**
1. Attacker targets position (player clicks ground, entity targets player location)
2. Play cast animation + show visual telegraph (red circle on ground)
3. Wait `castDuration` seconds (targets can see and dodge)
4. If `projectileSpeed` exists:
   - Spawn projectile traveling to target position
   - On arrival: Activate AOE at that position
5. If no `projectileSpeed`:
   - Instantly activate AOE at target position
6. Use `workspace:GetPartBoundsInRadius(targetPosition, aoeRadius)` to find all parts
7. For each part, find parent entity
8. For each unique entity in radius:
   - Calculate distance from center
   - If `aoeFalloff`: damageMultiplier = 1 - (distance / aoeRadius)
   - If no falloff: damageMultiplier = 1.0
   - Apply damage = `damage * damageMultiplier`
   - Stop if `maxTargets` reached
9. Play explosion/impact effects

**Example Configurations:**
```lua
weapons = {
    -- Projectile AOE (fireball)
    Fireball = {
        type = "aoe",
        name = "Fireball",
        damage = 50,
        range = 60,             -- Can cast up to 60 studs away
        cooldown = 5.0,
        castDuration = 1.0,     -- 1 second cast - enemies see it coming

        aoeRadius = 15,         -- 15 stud explosion radius
        aoeFalloff = true,      -- Edge damage reduced
        maxTargets = 10,

        projectileSpeed = 40,   -- Fireball travels at 40 studs/sec
    },

    -- Instant self-centered AOE
    GroundSlam = {
        type = "aoe",
        name = "Ground Slam",
        damage = 35,
        range = 0,              -- Centered on caster
        cooldown = 8.0,
        castDuration = 0.7,     -- Windup animation - visual telegraph

        aoeRadius = 20,         -- 20 studs around caster
        aoeFalloff = true,
        maxTargets = 15,
    },

    -- Healing AOE
    HealingCircle = {
        type = "aoe",
        name = "Healing Circle",
        damage = -20,           -- Negative = healing
        range = 40,
        cooldown = 15.0,
        castDuration = 2.0,     -- Long channel

        aoeRadius = 12,
        aoeFalloff = false,     -- Everyone gets full heal
        maxTargets = 5,
        duration = 5.0,         -- Lasts 5 seconds
        tickRate = 1.0,         -- Heal every second (5 ticks total)
        targetFilter = "allies",
    },

    -- Boss AOE attack
    DragonBreath = {
        type = "aoe",
        name = "Dragon Breath",
        damage = 60,
        range = 0,              -- Dragon's position
        cooldown = 10.0,
        castDuration = 1.5,     -- Long telegraph - players must dodge

        aoeRadius = 30,         -- Huge radius
        aoeFalloff = true,
        maxTargets = 20,
    },
}
```

**Implementation Notes:**
- Always show visual telegraph during `castDuration` (ground decal, particle effects)
- Telegraph should clearly show `aoeRadius` so players know where to dodge
- For projectile AOE: Show projectile trail and anticipate impact location
- Use OverlapParams to filter collision groups properly
- For `duration` effects: Track lingering zones, tick damage/heal over time
- Consider performance: Large `aoeRadius` with many entities can be expensive

---

### 2. GameConfig Integration

**File:** `src/shared/GameConfig.luau`

#### Add Weapons Table
Add this NEW section to GameConfig:

```lua
-- Weapon System - defines all weapons for players and entities
weapons = {
    -- ========================================
    -- PLAYER WEAPONS (Tools as weapons)
    -- ========================================
    Axe = {
        type = "melee",
        name = "Axe",
        damage = 20,
        range = 8,
        cooldown = 0.5,
        castDuration = 0.3,
    },

    Pickaxe = {
        type = "melee",
        name = "Pickaxe",
        damage = 15,
        range = 7,
        cooldown = 0.5,
        castDuration = 0.3,
    },

    Bow = {
        type = "projectile",
        name = "Bow",
        damage = 30,
        range = 100,
        cooldown = 1.5,
        castDuration = 0.5,
        projectileSpeed = 80,
    },

    Crossbow = {
        type = "hitscan",
        name = "Crossbow",
        damage = 40,
        range = 120,
        cooldown = 2.0,
        castDuration = 0.3,
    },

    -- ========================================
    -- WILDLIFE WEAPONS
    -- ========================================
    WolfClaw = {
        type = "melee",
        name = "Wolf Claw",
        damage = 8,
        range = 10,
        cooldown = 2,
        castDuration = 0.5,
    },

    BearClaw = {
        type = "melee",
        name = "Bear Claw",
        damage = 25,
        range = 12,
        cooldown = 2,
        castDuration = 0.8,
    },

    -- ========================================
    -- ENEMY WEAPONS
    -- ========================================
    ZombieBite = {
        type = "melee",
        name = "Zombie Bite",
        damage = 15,
        range = 8,
        cooldown = 2,
        castDuration = 0.4,
    },

    -- ========================================
    -- MAGIC/SPECIAL WEAPONS (future)
    -- ========================================
    Fireball = {
        type = "aoe",
        name = "Fireball",
        damage = 50,
        range = 60,
        cooldown = 5.0,
        castDuration = 1.0,
        aoeRadius = 15,
        aoeFalloff = true,
        maxTargets = 10,
        projectileSpeed = 40,
    },
},
```

#### Update Wildlife Section
REPLACE the current wildlife configs to use `primaryWeapon`:

```lua
wildlife = {
    Wolf = {
        maxCount = 5,
        health = 60,
        walkSpeed = 12,
        runSpeed = 22,
        aggroRange = 30,
        wanderRange = 10,
        jumpCooldown = 3,
        respawnTime = 60,
        canJump = true,
        drops = {"Food", "Hide", "Bones"},
        targetPriority = "players",
        animations = {
            walk = "rbxassetid://125448487250472",
            run = "rbxassetid://70972717905830",
            jump = "rbxassetid://130986182083396",
            attack = "rbxassetid://83719559878946",
        },

        -- NEW: Reference to weapon
        primaryWeapon = "WolfClaw",

        -- REMOVE these (now in weapons.WolfClaw):
        -- damage = 8,
        -- attackDistance = 10,
        -- attackStoppingDistance = 8,
        -- attackCooldown = 2,
    },

    Bear = {
        maxCount = 3,
        health = 100,
        walkSpeed = 5,
        runSpeed = 10,
        aggroRange = 25,
        wanderRange = 35,
        jumpCooldown = 4,
        respawnTime = 90,
        canJump = false,
        drops = {"Meat", "Hide", "Bones"},
        targetPriority = "players",
        animations = {
            walk = "rbxassetid://97593039109435",
            attack = "rbxassetid://97384715486637",
        },

        primaryWeapon = "BearClaw",

        -- REMOVE: damage, attackDistance, attackStoppingDistance, attackCooldown
    },
},
```

#### Update Enemies Section
```lua
enemies = {
    Zombie = {
        health = 50,
        walkSpeed = 8,
        runSpeed = 12,
        aggroRange = 25,
        wanderRange = 5,
        jumpCooldown = 4,
        spawnWeight = 1,
        canJump = false,
        targetPriority = "both",
        animations = {
            walk = "rbxassetid://125448487250472",
            run = "rbxassetid://70972717905830",
            jump = "rbxassetid://130986182083396",
            attack = "rbxassetid://83719559878946",
        },

        primaryWeapon = "ZombieBite",

        -- REMOVE: damage, attackDistance, attackStoppingDistance, attackCooldown
    },
},
```

#### Update Tools Section
Add `weaponRef` to link tools to weapons:

```lua
tools = {
    Axe = {
        miningEfficiency = 1.0,
        canMine = {"Wood"},
        swingCooldown = 0.5,        -- Keep for mining
        weaponRef = "Axe",          -- NEW: References weapons.Axe for combat
    },
    Pickaxe = {
        miningEfficiency = 1.0,
        canMine = {"Stone", "Metal"},
        swingCooldown = 0.5,        -- Keep for mining
        weaponRef = "Pickaxe",      -- NEW: References weapons.Pickaxe for combat
    },
},
```

**Note:** Tools still have their mining properties. The `weaponRef` is ONLY used for combat calculations.

---

### 3. CombatSystem Module

**File:** `src/shared/CombatSystem.luau` (NEW FILE)

This is the core module that all combat goes through.

#### Type Definitions

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

-- Export types
export type WeaponType = "melee" | "projectile" | "hitscan" | "aoe"

export type WeaponConfig = {
    type: WeaponType,
    name: string,
    damage: number,
    range: number,
    cooldown: number,
    castDuration: number,

    -- Projectile-specific
    projectileSpeed: number?,

    -- AOE-specific
    aoeRadius: number?,
    aoeFalloff: boolean?,
    maxTargets: number?,
    duration: number?,
    tickRate: number?,
    targetFilter: string?,
}

export type AttackResult = {
    hit: boolean,           -- Was attack successful
    target: Model?,         -- Entity that was hit (nil for AOE/miss)
    damage: number?,        -- Damage dealt (nil if miss)
    wasInRange: boolean,    -- Was target in range after castDuration
    wasDodged: boolean,     -- Did target dodge (was in range, now isn't)
}

export type AOEHitInfo = {
    entity: Model,
    damage: number,
    distance: number,       -- Distance from AOE center
}

local CombatSystem = {}
```

#### Core Functions

```lua
-- Get weapon config from GameConfig
function CombatSystem.getWeaponConfig(weaponName: string): WeaponConfig?
    local weaponConfig = GameConfig.weapons[weaponName]
    if not weaponConfig then
        warn(`Weapon config not found: {weaponName}`)
        return nil
    end
    return weaponConfig
end

-- Get entity's weapon (for wildlife/enemies)
function CombatSystem.getEntityWeapon(entityType: string): string?
    -- Check wildlife
    local wildlifeConfig = GameConfig.wildlife[entityType]
    if wildlifeConfig and wildlifeConfig.primaryWeapon then
        return wildlifeConfig.primaryWeapon
    end

    -- Check enemies
    local enemyConfig = GameConfig.enemies[entityType]
    if enemyConfig and enemyConfig.primaryWeapon then
        return enemyConfig.primaryWeapon
    end

    return nil
end

-- Get player's equipped weapon (from tool)
function CombatSystem.getPlayerWeapon(player: Player): string?
    local character = player.Character
    if not character then
        return nil
    end

    -- Check for equipped tool
    for _, toolName in GameConfig.player.startingTools do
        local tool = character:FindFirstChild(toolName)
        if tool and tool:IsA("Tool") then
            -- Get weapon reference from tool config
            local toolConfig = GameConfig.tools[toolName]
            if toolConfig and toolConfig.weaponRef then
                return toolConfig.weaponRef
            end
        end
    end

    return nil
end

-- Calculate distance between two positions
local function getDistance(pos1: Vector3, pos2: Vector3): number
    return (pos2 - pos1).Magnitude
end

-- Find entity model from a part
local function findEntityFromPart(part: BasePart): Model?
    local current = part.Parent
    while current and current ~= workspace do
        if current:IsA("Model") then
            local entityType = current:GetAttribute("EntityType")
            if entityType then
                return current
            end
        end
        current = current.Parent
    end
    return nil
end

-- Main attack function for melee weapons
function CombatSystem.attemptMeleeAttack(
    attacker: Model,
    target: Model,
    weaponName: string
): AttackResult
    local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
    if not weaponConfig then
        return {hit = false, target = nil, damage = nil, wasInRange = false, wasDodged = false}
    end

    -- Get positions
    local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
    local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?

    if not attackerRoot or not targetRoot then
        return {hit = false, target = nil, damage = nil, wasInRange = false, wasDodged = false}
    end

    -- Check if target is in range
    local distance = getDistance(attackerRoot.Position, targetRoot.Position)
    local inRange = distance <= weaponConfig.range

    if inRange then
        -- Target is in range - apply damage
        return {
            hit = true,
            target = target,
            damage = weaponConfig.damage,
            wasInRange = true,
            wasDodged = false,
        }
    else
        -- Target out of range - dodged
        return {
            hit = false,
            target = target,
            damage = nil,
            wasInRange = false,
            wasDodged = true,
        }
    end
end

-- Perform AOE attack
function CombatSystem.performAOEAttack(
    attacker: Model,
    targetPosition: Vector3,
    weaponName: string
): {AOEHitInfo}
    local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
    if not weaponConfig or weaponConfig.type ~= "aoe" then
        return {}
    end

    local hits: {AOEHitInfo} = {}

    -- Get all parts in radius
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {attacker}

    local parts = workspace:GetPartBoundsInRadius(
        targetPosition,
        weaponConfig.aoeRadius or 10,
        params
    )

    -- Find unique entities
    local hitEntities: {[Model]: boolean} = {}

    for _, part in parts do
        local entity = findEntityFromPart(part)
        if entity and not hitEntities[entity] then
            hitEntities[entity] = true

            local entityRoot = entity:FindFirstChild("HumanoidRootPart") :: BasePart?
            if entityRoot then
                local distance = getDistance(targetPosition, entityRoot.Position)

                -- Calculate damage with falloff
                local damageMultiplier = 1.0
                if weaponConfig.aoeFalloff then
                    damageMultiplier = 1 - (distance / (weaponConfig.aoeRadius or 10))
                    damageMultiplier = math.max(0, damageMultiplier) -- Clamp to 0
                end

                local finalDamage = weaponConfig.damage * damageMultiplier

                table.insert(hits, {
                    entity = entity,
                    damage = finalDamage,
                    distance = distance,
                })

                -- Check max targets
                if #hits >= (weaponConfig.maxTargets or 999) then
                    break
                end
            end
        end
    end

    return hits
end

-- Perform hitscan attack
function CombatSystem.performHitscan(
    origin: Vector3,
    direction: Vector3,
    weaponName: string,
    attacker: Model
): AttackResult
    local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
    if not weaponConfig or weaponConfig.type ~= "hitscan" then
        return {hit = false, target = nil, damage = nil, wasInRange = false, wasDodged = false}
    end

    -- Perform raycast
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {attacker}

    local raycastResult = workspace:Raycast(
        origin,
        direction.Unit * weaponConfig.range,
        raycastParams
    )

    if raycastResult then
        local hitEntity = findEntityFromPart(raycastResult.Instance)
        if hitEntity then
            return {
                hit = true,
                target = hitEntity,
                damage = weaponConfig.damage,
                wasInRange = true,
                wasDodged = false,
            }
        end
    end

    return {hit = false, target = nil, damage = nil, wasInRange = false, wasDodged = false}
end

return CombatSystem
```

**Note:** Projectile system is more complex and would need additional functions for spawning/tracking projectiles. This can be added later.

---

## Implementation Steps

### Overview

**Phase 1: Core Melee System** (Implement first)
1. Create CombatFeedback module (unified damage display)
2. Create CombatSystem module (core combat logic)
3. Update GameConfig (weapons + combat sections)
4. Update EntityController (use new systems)
5. Update ToolManager (use new systems)
6. Update TargetingSystem (support players as targets)
7. Test and iterate

**Phase 2: Advanced Weapon Types** (Implement after Phase 1 works)
8. Add projectile support (stubs + basic implementation)
9. Add hitscan support (stubs + basic implementation)
10. Add AOE support (stubs + basic implementation)

---

### Step 1: Backup Current System
```bash
# Create backup branch
git checkout -b backup-before-combat-system
git add .
git commit -m "Backup before implementing unified combat system"
git checkout main
```

### Step 2: Create CombatFeedback Module
**File:** `src/shared/CombatFeedback.luau` (NEW FILE)

This module handles all damage display and hit effects for all entity types.

```lua
--!strict

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatFeedback = {}

-- Create floating damage number above any entity (player or NPC)
function CombatFeedback.showDamage(
    targetModel: Model,
    damage: number,
    damageSource: string?,
    damageType: string?
)
    local humanoidRootPart = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoidRootPart then
        return
    end

    -- Determine color based on damage type
    local textColor: Color3
    local displayText: string

    if damageType == "self" then
        -- Damage you dealt (your attacks on entities)
        textColor = Color3.fromRGB(255, 255, 100) -- Yellow
        displayText = "-" .. tostring(math.floor(damage))
    elseif damageType == "other_player" then
        -- Damage dealt by another player
        textColor = Color3.fromRGB(150, 150, 150) -- Gray
        displayText = "-" .. tostring(math.floor(damage))
    elseif damageType == "incoming" then
        -- Damage dealt to you
        textColor = Color3.fromRGB(255, 100, 100) -- Red
        displayText = "-" .. tostring(math.floor(damage))
    else
        -- Default damage color (fallback)
        textColor = Color3.fromRGB(255, 150, 150) -- Light red
        displayText = "-" .. tostring(math.floor(damage))
    end

    -- Create BillboardGui for damage display
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 2, 0)
    billboardGui.Parent = humanoidRootPart

    -- Create damage text label
    local damageLabel = Instance.new("TextLabel")
    damageLabel.Size = UDim2.new(1, 0, 1, 0)
    damageLabel.BackgroundTransparency = 1
    damageLabel.Text = displayText
    damageLabel.TextColor3 = textColor
    damageLabel.TextScaled = true
    damageLabel.Font = Enum.Font.SourceSansBold
    damageLabel.TextStrokeTransparency = 0
    damageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    damageLabel.Parent = billboardGui

    -- Animate the damage number
    local tweenInfo = TweenInfo.new(
        1.5, -- Duration
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )

    -- Tween upward movement and fade
    local tween = TweenService:Create(billboardGui, tweenInfo, {
        StudsOffset = Vector3.new(math.random(-1, 1), 4, math.random(-1, 1))
    })

    local fadeTween = TweenService:Create(damageLabel, tweenInfo, {
        TextTransparency = 1,
        TextStrokeTransparency = 1
    })

    -- Start animations
    tween:Play()
    fadeTween:Play()

    -- Clean up after animation
    Debris:AddItem(billboardGui, 1.5)
end

-- Play hit sound effect on target
function CombatFeedback.playHitSound(targetModel: Model, soundName: string?)
    local humanoidRootPart = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoidRootPart then
        return
    end

    local sound = humanoidRootPart:FindFirstChild(soundName or "Hit")
    if sound and sound:IsA("Sound") then
        sound.PlaybackSpeed = 1 + (math.random() * 0.2 - 0.1) -- Slight pitch variation
        sound:Play()
    end
end

return CombatFeedback
```

### Step 3: Create CombatSystem Module
**File:** `src/shared/CombatSystem.luau`

1. Create the file with the code from [CombatSystem Module](#3-combatsystem-module) section above
2. Include all type definitions and core functions
3. Test that it requires properly: `local CombatSystem = require(ReplicatedStorage.Shared.CombatSystem)`

### Step 3: Update GameConfig
**File:** `src/shared/GameConfig.luau`

1. Add `weapons` table with all weapon configurations
2. Update `wildlife` section:
   - Add `primaryWeapon` property to Wolf, Bear
   - Remove `damage`, `attackDistance`, `attackStoppingDistance`, `attackCooldown`
3. Update `enemies` section:
   - Add `primaryWeapon` property to Zombie
   - Remove attack-related properties
4. Update `tools` section:
   - Add `weaponRef` to Axe, Pickaxe
5. Run `rojo build` to check for syntax errors

### Step 4: Update EntityController
**File:** `src/shared/EntityController.luau`

#### Changes to `performAttack` function (lines 236-286):

**BEFORE:**
```lua
local function performAttack(entity: EntityInstance, target: Player)
    if not target.Character or not target.Character:FindFirstChild("Humanoid") then
        return
    end

    local targetHumanoid = target.Character.Humanoid :: Humanoid
    local config = getEntityConfig(entity.entityType)

    if targetHumanoid.Health <= 0 then
        return
    end

    if targetHumanoid:GetAttribute("RecentlyBit") then
        return
    end

    -- Calculate and apply damage
    local damage = EnemyController.calculateDamage(entity.entityType, targetHumanoid)
    targetHumanoid:TakeDamage(damage)

    -- ... rest of function
end
```

**AFTER:**
```lua
local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))

local function performAttack(entity: EntityInstance, target: Player)
    if not target.Character or not target.Character:FindFirstChild("Humanoid") then
        return
    end

    local targetHumanoid = target.Character.Humanoid :: Humanoid
    local config = getEntityConfig(entity.entityType)

    if targetHumanoid.Health <= 0 then
        return
    end

    -- Get entity's weapon
    local weaponName = config.primaryWeapon
    if not weaponName then
        warn(`Entity {entity.entityType} has no primaryWeapon configured`)
        return
    end

    local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
    if not weaponConfig then
        return
    end

    -- Check recently hit (use weapon cooldown)
    if targetHumanoid:GetAttribute("RecentlyBit") then
        return
    end

    -- Play attack animation
    playAnimation(entity, "attack")
    playSound(entity, "attack")

    -- Set state to attacking
    updateEntityState(entity, "attacking")

    -- Wait castDuration (telegraph window)
    task.wait(weaponConfig.castDuration)

    -- After castDuration: Check if target still in range
    local result = CombatSystem.attemptMeleeAttack(
        entity.model,
        target.Character,
        weaponName
    )

    if result.hit and result.damage then
        -- Target was in range - apply damage
        targetHumanoid:TakeDamage(result.damage)

        -- Show floating damage number above player
        if target.Character:FindFirstChild("HumanoidRootPart") then
            local playerHRP = target.Character.HumanoidRootPart :: BasePart
            local tempEntity = {
                entityType = "Player",
                humanoidRootPart = playerHRP
            }
            createDamageDisplay(tempEntity :: any, result.damage, entity.entityType, "incoming")
        end

        print(`*** {entity.entityType} attacked {target.Name} for {result.damage} damage`)
    else
        -- Target dodged!
        print(`*** {target.Name} dodged {entity.entityType} attack!`)
    end

    -- Set recently hit protection
    targetHumanoid:SetAttribute("RecentlyBit", true)
    task.delay(weaponConfig.cooldown, function()
        if targetHumanoid then
            targetHumanoid:SetAttribute("RecentlyBit", false)
        end
    end)

    entity.lastAttackTime = tick()
end
```

#### Changes to `updateEntityAI` function (lines 341-428):

Update the attack distance check to use weapon range:

**BEFORE (lines 367-390):**
```lua
-- Attack if close enough
local attackDistance = config.attackDistance or 5
local stoppingDistance = config.attackStoppingDistance or attackDistance

if distToTarget <= stoppingDistance then
    -- ... movement logic
end

if distToTarget <= attackDistance then
    local attackCooldown = config.attackCooldown or 2
    if currentTime - entity.lastAttackTime >= attackCooldown then
        updateEntityState(entity, "attacking")
        performAttack(entity, entity.target)
    end
end
```

**AFTER:**
```lua
-- Get weapon config for range/cooldown
local weaponName = config.primaryWeapon
local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
if not weaponConfig then
    return -- Can't attack without weapon
end

local attackDistance = weaponConfig.range
local stoppingDistance = attackDistance * 0.8 -- Stop a bit before attack range

if distToTarget <= stoppingDistance then
    -- Within stopping distance: reduce speed
    entity.humanoid.WalkSpeed = (config.walkSpeed or 12) * 0.6
    updateEntityState(entity, "chasing")
    playAnimation(entity, "walk")
else
    -- Outside stopping distance: full chase speed
    entity.humanoid.WalkSpeed = config.runSpeed or 12
    updateEntityState(entity, "chasing")
    playAnimation(entity, "run")
end

if distToTarget <= attackDistance then
    if currentTime - entity.lastAttackTime >= weaponConfig.cooldown then
        -- Perform attack (performAttack now handles castDuration internally)
        performAttack(entity, entity.target)
    end
end
```

#### Remove `calculateDamage` function (lines 219-233):
This function is no longer needed - damage comes from weapon config.

**DELETE:**
```lua
function EnemyController.calculateDamage(entityType: string, targetHumanoid: Humanoid, attackType: string?): number
    -- ... DELETE THIS ENTIRE FUNCTION
end
```

### Step 5: Update ToolManager
**File:** `src/server/ToolManager.server.luau`

#### Add CombatSystem import:
```lua
local CombatSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatSystem"))
```

#### Delete `enableToolHitDetection` function (lines 108-243):
**DELETE THIS ENTIRE FUNCTION** - we're replacing touch detection with range detection.

#### Update `onToolSwing` function (lines 333-402):

**BEFORE:**
```lua
local function onToolSwing(player: Player, toolType: ToolType)
    print('Swinging tool...')
    if isOnCooldown(player, "swing") then
        return
    end

    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local toolConfig = GameConfig.tools[toolType]
    if not toolConfig then
        return
    end

    -- Set swing cooldown
    setCooldown(player, "swing", toolConfig.swingCooldown)

    -- Enable tool hit detection for a short time
    enableToolHitDetection(player, toolType)

    -- Play swing animation
    -- ... animation code ...
end
```

**AFTER:**
```lua
local function onToolSwing(player: Player, toolType: ToolType)
    print('Swinging tool...')
    if isOnCooldown(player, "swing") then
        return
    end

    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local toolConfig = GameConfig.tools[toolType]
    if not toolConfig then
        return
    end

    -- Get weapon config
    local weaponName = toolConfig.weaponRef
    if not weaponName then
        warn(`Tool {toolType} has no weaponRef`)
        return
    end

    local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
    if not weaponConfig then
        return
    end

    -- Set swing cooldown
    setCooldown(player, "swing", weaponConfig.cooldown)

    -- Play swing animation
    local animateScript = character:FindFirstChild("Animate")
    if animateScript then
        local toolSlashAnim = animateScript:FindFirstChild("toolslash")
        if toolSlashAnim then
            local slashAnimation = toolSlashAnim:FindFirstChildOfClass("Animation")
            if slashAnimation then
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    local success, animationTrack = pcall(function()
                        local track = animator:LoadAnimation(slashAnimation)
                        track.Priority = Enum.AnimationPriority.Action
                        return track
                    end)

                    if success and animationTrack then
                        animationTrack:Play()
                        print(`Playing swing animation for {player.Name}`)
                    end
                end
            end
        end
    end

    -- Wait castDuration for telegraph
    task.wait(weaponConfig.castDuration)

    -- After castDuration: Check for targets in range
    local target = getPlayerTarget(player) -- Need to implement this

    if target then
        -- Attempt attack on targeted entity
        local result = CombatSystem.attemptMeleeAttack(
            character,
            target,
            weaponName
        )

        if result.hit and result.damage then
            -- Hit! Apply damage through EntityController
            local EntityController = _G.EntityController
            if EntityController and EntityController.handleDamage then
                EntityController.handleDamage(target, result.damage, toolType, player)
                playToolSound(player, toolType, "attack")
            end
        else
            -- Miss - play swing sound
            playToolSound(player, toolType, "swing")
        end
    else
        -- No target - play swing sound (swinging at air)
        playToolSound(player, toolType, "swing")
    end

    print(`{player.Name} swung {toolType}`)
end
```

#### Add helper function to get player's target:
```lua
-- Get player's current target from TargetingSystem
local function getPlayerTarget(player: Player): Model?
    -- This assumes targeting system stores targets
    -- Adjust based on your TargetingSystem implementation
    local TargetingSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TargetingSystem"))
    return TargetingSystem.getTarget(player)
end
```

### Step 6: Test Basic Melee Combat

#### Test Player vs Entity:
1. Start game in Roblox Studio
2. Equip Axe
3. Find a Wolf
4. Target the Wolf (click or press X)
5. Swing at Wolf from various distances:
   - Within 8 studs: Should hit
   - Beyond 8 studs: Should miss
6. Check console for hit/miss messages
7. Verify damage numbers appear

#### Test Entity vs Player:
1. Let Wolf aggro on you
2. Watch for Wolf attack animation
3. During the 0.5s castDuration, run away
4. If you get far enough (>10 studs): Should dodge
5. If you stay close: Should take damage
6. Check console for dodge messages

#### Test Different Weapons:
1. Test Pickaxe (7 stud range, 15 damage)
2. Test against Bear (12 stud range, 25 damage, 0.8s castDuration)
3. Verify ranges and damage values match config

### Step 7: Add Projectile Support (Optional - Can do later)

This is more complex. Create new functions:

```lua
-- In CombatSystem.luau
function CombatSystem.spawnProjectile(
    origin: Vector3,
    direction: Vector3,
    weaponName: string,
    attacker: Model
): ProjectileInstance?
    -- Create projectile model
    -- Set up physics (BodyVelocity or LinearVelocity)
    -- Track for collision
    -- Despawn after range reached
end
```

Then in ToolManager or EntityController, after castDuration:
```lua
if weaponConfig.type == "projectile" then
    CombatSystem.spawnProjectile(origin, direction, weaponName, character)
end
```

### Step 8: Add AOE Support (Optional - Can do later)

For AOE weapons:

```lua
-- In ToolManager or EntityController
if weaponConfig.type == "aoe" then
    -- Show telegraph for castDuration
    -- After castDuration:
    local hits = CombatSystem.performAOEAttack(attacker, targetPosition, weaponName)
    for _, hitInfo in hits do
        -- Apply damage to hitInfo.entity
        EntityController.handleDamage(hitInfo.entity, hitInfo.damage, weaponName, player)
    end
end
```

### Step 9: Build and Test

```bash
# Build the project
rojo build -o "roblox-camping.rbxlx"

# Check for errors in output
# If successful, open in Roblox Studio and test
```

### Step 10: Balance Testing

Test and adjust these values:
- **castDuration**: Too short = no counterplay, too long = clunky
- **range**: Too long = unfair, too short = frustrating
- **damage**: Balance with health pools
- **cooldown**: Affects DPS and combat pace

Recommended starting points:
- Fast melee: castDuration 0.2-0.3s, range 6-8 studs
- Slow melee: castDuration 0.6-0.8s, range 10-14 studs
- Projectiles: castDuration 0.4-0.6s, speed 60-100 studs/sec
- AOE: castDuration 0.8-1.5s, radius 10-20 studs

---

## Testing Checklist

### Phase 1: Basic Melee (Players)
- [ ] Player can swing Axe at Wolf
- [ ] Hit detection works within 8 studs
- [ ] Miss detection works beyond 8 studs
- [ ] Damage numbers appear correctly
- [ ] Sounds play (hit vs miss)
- [ ] Cooldown prevents spam
- [ ] Works with Pickaxe (7 stud range)

### Phase 2: Basic Melee (Entities)
- [ ] Wolf attacks player with WolfClaw
- [ ] Player can dodge during 0.5s castDuration
- [ ] Wolf attack animation plays correctly
- [ ] Damage applies if player in range after castDuration
- [ ] No damage if player dodged
- [ ] Works with Bear (BearClaw, 0.8s castDuration)
- [ ] Works with Zombie (ZombieBite)

### Phase 3: Edge Cases
- [ ] Multiple players attacking same entity
- [ ] Multiple entities attacking same player
- [ ] Entity dies during castDuration
- [ ] Player dies during castDuration
- [ ] Target out of range at start of castDuration
- [ ] Target teleports during castDuration
- [ ] Works in multiplayer (network latency)

### Phase 4: Projectiles (If Implemented)
- [ ] Arrow spawns after castDuration
- [ ] Arrow travels at correct speed
- [ ] Arrow hits entities correctly
- [ ] Arrow despawns after max range
- [ ] Arrow collision with environment
- [ ] Multiple projectiles in flight

### Phase 5: AOE (If Implemented)
- [ ] Telegraph shows during castDuration
- [ ] AOE activates at target position
- [ ] All entities in radius take damage
- [ ] Damage falloff works correctly
- [ ] MaxTargets limit respected
- [ ] Visual effects play correctly

### Phase 6: Performance
- [ ] No lag with 10+ entities attacking
- [ ] No memory leaks from projectiles
- [ ] AOE doesn't freeze game
- [ ] Works smoothly at 60 FPS

---

## Common Issues and Solutions

### Issue: "Weapon config not found"
**Cause:** Weapon name doesn't exist in GameConfig.weapons
**Solution:** Check spelling, ensure weapon is defined in GameConfig

### Issue: Entity still using old damage values
**Cause:** Entity config still has old `damage` property
**Solution:** Remove `damage`, `attackDistance`, `attackCooldown` from entity config, add `primaryWeapon`

### Issue: Player swings but nothing happens
**Cause:** Tool doesn't have `weaponRef` or targeting is broken
**Solution:** Add `weaponRef` to tool config, verify TargetingSystem works

### Issue: Dodge not working
**Cause:** castDuration too short or range check incorrect
**Solution:** Increase castDuration, verify distance calculation uses HumanoidRootPart positions

### Issue: Projectile goes through walls
**Cause:** No raycast tunneling prevention
**Solution:** Add continuous raycasts each frame projectile moves

### Issue: AOE hits too many entities
**Cause:** maxTargets not set or too high
**Solution:** Lower maxTargets value in weapon config

---

## Summary

### What This System Does

**Unified Combat Flow:**
- ✅ All combatants (players, wolves, bears, zombies) use the same combat logic
- ✅ All damage flows through CombatSystem → CombatFeedback
- ✅ Weapon-based stats (damage, range, cooldown, castDuration)
- ✅ Telegraph system (castDuration) allows skill-based dodging
- ✅ Invulnerability frames prevent weapon type spam
- ✅ Configurable hit detection (target-only vs area-of-effect)
- ✅ Support for PvE and PvP combat modes
- ✅ Extensible for future weapon types (projectile, hitscan, AOE)

### Implementation Checklist

**Phase 1: Core Melee System**
- [ ] Create `src/shared/CombatFeedback.luau` - unified damage display
- [ ] Create `src/shared/CombatSystem.luau` - core combat logic
- [ ] Update `src/shared/GameConfig.luau`:
  - [ ] Add `weapons` table with all weapon definitions
  - [ ] Add `combat` section with hit detection and PvP settings
  - [ ] Update wildlife/enemies to use `primaryWeapon`
  - [ ] Update tools to use `weaponRef`
- [ ] Update `src/shared/EntityController.luau`:
  - [ ] Replace damage calculation with CombatSystem
  - [ ] Use CombatFeedback for damage numbers
  - [ ] Implement invulnerability system
  - [ ] Add castDuration wait before damage
- [ ] Update `src/server/ToolManager.server.luau`:
  - [ ] Use CombatSystem for player attacks
  - [ ] Implement damageTargetOnly mode switching
  - [ ] Add castDuration wait (0.3s for Axe)
  - [ ] Support range-based hit detection
- [ ] Update `src/shared/TargetingSystem.luau`:
  - [ ] Support players as valid targets (for PvP/healing)
  - [ ] Add different highlight colors for allies
- [ ] Test thoroughly and balance

**Phase 2: Advanced Weapon Types** (After Phase 1 works)
- [ ] Add projectile weapon support (Bow, arrows)
- [ ] Add hitscan weapon support (Crossbow)
- [ ] Add AOE weapon support (Fireball, GroundSlam)
- [ ] Add visual telegraphs for entity attacks

### Key Configuration

```lua
-- GameConfig.combat
combat = {
    damageTargetOnly = false,         -- false = hit all in range
    invulnerabilityFrames = true,     -- Prevent weapon spam
    invulnerabilityDuration = 0.5,    -- 0.5s immunity per weapon type
    pvpEnabled = false,               -- Disable PvP for now
    teamBased = false,                -- Future: team-based combat
    friendlyFire = false,             -- Future: friendly fire
}

-- Example weapon
weapons = {
    Axe = {
        type = "melee",
        name = "Axe",
        damage = 20,
        range = 8,             -- 8 studs
        cooldown = 0.5,        -- 0.5s between swings
        castDuration = 0.3,    -- 0.3s telegraph before hit check
    },
}
```

### Key Files to Create/Modify

**NEW FILES:**
- `src/shared/CombatSystem.luau` - Core combat logic
- `src/shared/CombatFeedback.luau` - Unified damage display

**MODIFIED FILES:**
- `src/shared/GameConfig.luau` - Add weapons + combat sections
- `src/shared/EntityController.luau` - Use new combat systems
- `src/server/ToolManager.server.luau` - Use new combat systems
- `src/shared/TargetingSystem.luau` - Support player targets

### Expected Result

A robust, unified combat system where:
1. **Players and entities use identical combat logic** - no more separate systems
2. **Damage is predictable** - range-based, not collision-based
3. **Combat is skill-based** - dodge attacks during castDuration window
4. **System is extensible** - easy to add new weapons and abilities
5. **Code is maintainable** - single source of truth for combat
6. **Supports multiple game modes** - PvE, PvP, team-based

### Module Access Pattern

All combat modules exposed via `_G` for simplicity:
```lua
-- Server-side only
_G.CombatSystem = CombatSystem
_G.CombatFeedback = CombatFeedback
_G.EntityController = EntityController
_G.ToolManager = ToolManager

-- Usage
local CombatSystem = _G.CombatSystem
local result = CombatSystem.attemptMeleeAttack(attacker, target, weaponName)
```

**Note:** This pattern will be refactored to use `require()` after initial implementation and testing.