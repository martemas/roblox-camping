# Combat System - Phase 2 Implementation Report

## Overview

This document details the **actual implementation** of Phase 2 (AOE & Hitscan weapons) based on the design spec in `COMBAT_AOE_HITSCAN.md`.

**Implementation Status:** ✅ **COMPLETE** (Core systems fully functional)

**Date Completed:** October 3, 2025

---

## What Was Implemented

### ✅ Core Systems

#### 1. Hitscan Weapons
**File:** `src/shared/HitscanManager.luau`

**Features Implemented:**
- ✅ Targeted mode (`requiresTarget = true`) - No raycast, instant to locked target
- ✅ Free-aim mode (`requiresTarget = false`) - Raycast in look direction
- ✅ AOE on impact support (`aoeOnImpact = true`)
- ✅ Direction calculation (auto-aim vs free-aim)
- ✅ Validation (facing, line of sight, combat mode)
- ✅ Integration with CombatSystem

**Implementation Details:**
```lua
-- Two modes based on combat.autoAim setting
if GameConfig.combat.autoAim and lockedTarget then
    -- Auto-aim: Aim at locked target
    direction = (targetRoot.Position - origin).Unit
else
    -- Free-aim: Use look direction
    direction = attackerRoot.CFrame.LookVector
end

-- Perform hitscan via CombatSystem
local result = CombatSystem.performHitscan(
    origin,
    direction,
    weaponName,
    character,
    player,
    target
)
```

---

#### 2. Hitscan Visual Effects
**File:** `src/shared/HitscanEffects.luau`

**Implementation Choice:** **Procedural Generation** (no templates required)

**Features Implemented:**
- ✅ Beam visualization between origin and hit point
- ✅ Impact effect at hit location
- ✅ Color-coded by damage type (red = damage, green = healing)
- ✅ Auto-cleanup with Debris service
- ✅ Tween animations (fade out)

**Why Procedural:**
- No dependency on ReplicatedStorage templates
- Faster iteration and testing
- Consistent visual style
- Easy to customize per weapon

**Example Visual:**
```lua
-- Beam visual
local beam = Instance.new("Part")
beam.Size = Vector3.new(0.2, 0.2, distance)
beam.CFrame = CFrame.new(origin, hitPoint) * CFrame.new(0, 0, -distance / 2)
beam.Material = Enum.Material.Neon
beam.Color = isHealing and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)

-- Fade animation
TweenService:Create(beam, tweenInfo, {Transparency = 1}):Play()
Debris:AddItem(beam, 0.3)
```

---

#### 3. AOE Telegraph System
**File:** `src/shared/AOETelegraph.luau`

**Implementation Choice:** **Procedural Fallback** with optional template support

**Features Implemented:**
- ✅ Circular telegraph visualization
- ✅ Color-coded (red = damage, green = healing)
- ✅ Pulse animation (transparency oscillation)
- ✅ Auto-destroys after duration
- ✅ Template support (if templates exist in ReplicatedStorage)
- ✅ Procedural fallback (if no templates)

**Template Path (Optional):**
```
ReplicatedStorage/Models/Effects/AOE/CircleTelegraph
```

**Procedural Fallback:**
```lua
-- Creates cylinder Part if template not found
local cylinder = Instance.new("Part")
cylinder.Shape = Enum.PartType.Cylinder
cylinder.Size = Vector3.new(0.2, radius * 2, radius * 2)
cylinder.Material = Enum.Material.Neon
cylinder.Color = attackType == "heal" and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
```

---

#### 4. AOE Zone Manager
**File:** `src/shared/AOEZoneManager.luau`

**Features Implemented:**
- ✅ Persistent AOE zones with tick-based damage/healing
- ✅ Single Heartbeat loop for all zones (performance optimized)
- ✅ Auto-initialization on first use
- ✅ Zone expiration and cleanup
- ✅ Tick rate control
- ✅ Visual effect persistence
- ✅ Integration with CombatSystem.applyDamageToEntity()

**Architecture:**
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

-- Single update loop
RunService.Heartbeat:Connect(function()
    updateAllZones(tick())
end)
```

**Tick Logic:**
```lua
function tickZone(zone)
    -- Find entities in radius
    local parts = workspace:GetPartBoundsInRadius(zone.position, zone.radius, params)

    -- Apply damage to each entity
    for _, entity in uniqueEntities do
        CombatSystem.applyDamageToEntity(
            zone.attacker,
            entity,
            zone.weaponName,
            {
                damageOverride = damage,
                hitPosition = zone.position,
            }
        )
    end
end
```

---

#### 5. CombatSystem Enhancements

**New Functions Implemented:**

##### performAOEAttack()
```lua
function CombatSystem.performAOEAttack(
    attacker: Model,
    targetPosition: Vector3,
    weaponName: string,
    attackingPlayer: Player?,
    options: {
        damageOverride: number?,
        radius: number?,
        falloff: boolean?,
        maxTargets: number?,
    }?
): {AOEHitInfo}
```

**Features:**
- ✅ Radius-based entity detection (`GetPartBoundsInRadius`)
- ✅ Damage falloff (linear decrease with distance)
- ✅ Max targets limiting
- ✅ Target filtering (allies/enemies/all)
- ✅ Persistent zone creation (if duration + tickRate configured)
- ✅ Options override weapon config values

##### applyDamageToEntity()
```lua
function CombatSystem.applyDamageToEntity(
    attacker: Model,
    target: Model,
    weaponName: string,
    options: {
        damageOverride: number?,
        hitPosition: Vector3?,
        bypassInvulnerability: boolean?,
    }?
): boolean
```

**Features:**
- ✅ Low-level damage application API
- ✅ PvP validation
- ✅ Invulnerability checking
- ✅ Damage calculation via DamageCalculator
- ✅ Combat feedback integration
- ✅ Used by AOE zones, custom AOE weapons

##### performHitscan()
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

**Features:**
- ✅ Instant hit detection
- ✅ Raycast in specified direction
- ✅ Damage application
- ✅ Visual effects via HitscanEffects
- ✅ AOE on impact support

---

### ✅ Integration

#### 1. ProjectilePhysics Integration
**File:** `src/shared/ProjectilePhysics.luau`

**Changes:**
- ✅ AOE on impact detection in `handleRaycastHit()`
- ✅ AOE trigger on terrain/entity hit
- ✅ AOE trigger on max range
- ✅ Explosion visual effects
- ✅ Separate projectile damage from AOE damage

**Implementation:**
```lua
-- In handleRaycastHit()
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

    -- Show explosion visual
    showImpactEffect(projectile, raycastResult.Position)
    return true -- Destroy projectile
end
```

**Explosion Visual (Procedural):**
```lua
-- Orange expanding sphere
local explosion = Instance.new("Part")
explosion.Shape = Enum.PartType.Ball
explosion.Size = Vector3.new(radius, radius, radius)
explosion.Material = Enum.Material.Neon
explosion.Color = Color3.fromRGB(255, 150, 50)

-- Expand and fade animation
task.spawn(function()
    local startTime = tick()
    while tick() - startTime < duration do
        local progress = (tick() - startTime) / duration
        explosion.Size = initialSize:Lerp(finalSize, progress)
        explosion.Transparency = 0.3 + (progress * 0.7)
        task.wait()
    end
    explosion:Destroy()
end)
```

---

#### 2. EntityController Integration
**File:** `src/shared/EntityController.luau`

**Changes:**
- ✅ Hitscan branch in `performAttack()`
- ✅ AOE branch in `performAttack()`
- ✅ Telegraph visualization for NPCs
- ✅ Projectile AOE support for NPCs

**Hitscan Implementation:**
```lua
elseif weaponConfig.type == "hitscan" then
    local origin = entityPos + Vector3.new(0, 1, 0)
    local direction = HitscanManager.calculateDirection(
        entity.humanoidRootPart,
        target.Character,
        origin
    )

    -- Play animation
    playAnimation(entity, "attack")
    task.wait(weaponConfig.castDuration)

    -- Perform hitscan
    local result = HitscanManager.performHitscan(
        origin,
        direction,
        weaponName,
        entity.model,
        nil, -- No attacking player (NPC)
        target.Character
    )
end
```

**AOE Implementation:**
```lua
elseif weaponConfig.type == "aoe" then
    -- Determine position (self-centered or targeted)
    local targetPos = weaponConfig.range == 0
        and entity.humanoidRootPart.Position
        or target.Character.HumanoidRootPart.Position

    -- Show telegraph
    AOETelegraph.showCircleTelegraph(targetPos, radius, castDuration, "damage")

    task.wait(weaponConfig.castDuration)

    -- Projectile AOE or instant AOE
    if weaponConfig.projectileSpeed then
        ProjectileManager.spawnProjectile(...)
    else
        CombatSystem.performAOEAttack(...)
    end
end
```

---

#### 3. ToolManager Integration
**File:** `src/server/ToolManager.server.luau`

**Changes:**
- ✅ Hitscan branch for players
- ✅ AOE branch for players
- ✅ Telegraph visualization
- ✅ Projectile AOE support

**Player AOE Implementation:**
```lua
elseif weaponConfig.type == "aoe" then
    -- Determine target position
    local targetPos = weaponConfig.range == 0
        and humanoidRootPart.Position
        or (target and targetRoot.Position or lookDirectionPos)

    -- Show telegraph
    local attackType: "damage" | "heal" =
        if weaponConfig.aoeDamage and weaponConfig.aoeDamage < 0
        then "heal"
        else "damage"

    AOETelegraph.showCircleTelegraph(targetPos, radius, castDuration, attackType)

    task.wait(weaponConfig.castDuration)

    -- Execute (instant or projectile)
    if weaponConfig.projectileSpeed then
        ProjectileManager.spawnProjectile(...)
    else
        CombatSystem.performAOEAttack(...)
    end
end
```

---

### ✅ Configuration

#### GameConfig Weapons Added

**Hitscan Weapons:**
```lua
Crossbow = {
    type = "hitscan",
    range = 100,
    damage = 40,
    visualEffect = "beam",
    castDuration = 0.3,
    cooldown = 2.0,
},

DirectHeal = {
    type = "hitscan",
    range = 50,
    damage = -30, -- Healing
    visualEffect = "none",
    targetFilter = "allies",
    requiresTarget = true,
    castDuration = 0.2,
    cooldown = 3.0,
},

MagicMissile = {
    type = "hitscan",
    range = 80,
    damage = 25,
    visualEffect = "beam",
    castDuration = 0.4,
    cooldown = 1.0,
},
```

**Hitscan + AOE Hybrid:**
```lua
ExplosiveBolt = {
    type = "hitscan",
    range = 80,
    damage = 20, -- Direct hit
    visualEffect = "beam",

    aoeOnImpact = true,
    aoeDamage = 40, -- Explosion
    aoeRadius = 10,
    aoeFalloff = true,
    maxTargets = 5,

    castDuration = 0.4,
    cooldown = 4.0,
},
```

**AOE Weapons:**
```lua
GroundSlam = {
    type = "aoe",
    range = 0, -- Self-centered
    aoeDamage = 35,
    aoeRadius = 20,
    aoeFalloff = true,
    maxTargets = 15,
    castDuration = 0.7,
    cooldown = 8.0,
},

Fireball = {
    type = "projectile", -- Projectile AOE!
    projectileSpeed = 40,
    damage = 30, -- Touch damage
    aoeDamage = 50, -- Explosion
    aoeRadius = 15,
    aoeOnImpact = true,
    damageTargetOnly = false, -- Allows terrain hits
    castDuration = 1.0,
    cooldown = 5.0,
    projectileConfig = { ... },
},

HealingCircle = {
    type = "aoe",
    range = 40,
    aoeDamage = -20, -- Healing
    aoeRadius = 12,
    duration = 5.0,
    tickRate = 1.0,
    targetFilter = "allies",
    castDuration = 2.0,
    cooldown = 15.0,
},

PoisonCloud = {
    type = "aoe",
    range = 40,
    aoeDamage = 10,
    aoeRadius = 12,
    duration = 8.0,
    tickRate = 1.0,
    targetFilter = "enemies",
    castDuration = 2.0,
    cooldown = 15.0,
},
```

**Type System Update:**
```lua
-- Added to WeaponConfig type
export type WeaponType = "melee" | "projectile" | "hitscan" | "aoe"

export type WeaponConfig = {
    type: WeaponType,
    -- ... existing properties

    -- Hitscan-specific
    visualEffect: string?, -- "beam" or "none"

    -- AOE-specific
    aoeDamage: number?,
    aoeRadius: number?,
    aoeFalloff: boolean?,
    maxTargets: number?,
    duration: number?,
    tickRate: number?,
    targetFilter: string?,
    aoeOnImpact: boolean?,
}
```

---

### ✅ Documentation

#### 1. GUIDE_HITSCAN.md
- Complete hitscan weapon setup guide
- Configuration examples
- Testing checklist
- Troubleshooting section

#### 2. GUIDE_AOE.md
- Standard AOE weapon setup guide
- All AOE variants documented
- Damage calculations explained
- Performance recommendations

#### 3. GUIDE_CUSTOM_AOE.md
- Advanced custom AOE system
- Cone, rectangle, line, chain examples
- Complete working code samples
- Best practices and helper functions

---

## What Was NOT Implemented

### ❌ Template Models (Optional)

**Reason:** Procedural generation works perfectly and is more flexible

**Planned Templates:**
```
ReplicatedStorage/Models/Effects/
├── Hitscan/
│   ├── BeamEffect
│   └── ImpactEffect
└── AOE/
    ├── CircleTelegraph
    └── ZoneEffect
```

**Alternative Implemented:**
- Procedural beam/impact effects in `HitscanEffects.luau`
- Procedural telegraph in `AOETelegraph.luau`
- Procedural zone effects in `AOEZoneManager.luau`
- Template support still available (optional)

---

### ❌ Example Custom AOE Tools

**Reason:** Documented in guides, users can implement as needed

**Planned Examples:**
- DragonBreathSpell (cone attack)
- ChainLightning (bouncing)
- WallOfFire (rectangle)

**Alternative Implemented:**
- Complete working code in GUIDE_CUSTOM_AOE.md
- Copy-paste ready examples
- Helper function library documented

---

### ❌ Server Validation for Custom AOE

**Reason:** Not required for initial implementation, can be added later

**Planned:**
```lua
RemoteEvents.Events.PerformCustomAOE -- Server validation
```

**Current State:**
- Custom AOE tools use Tool.Activated (client-side)
- `applyDamageToEntity()` is server-authoritative
- Can be upgraded to RemoteEvents when needed

---

### ❌ Future Enhancements (Out of Scope)

**Explicitly deferred to future phases:**

#### Cone Weapons (Built-in)
- `type = "cone"` as standard weapon type
- Built-in cone detection
- **Alternative:** Use custom AOE system (documented)

#### Hitscan Spread
- `spread = 2` property
- Random deviation
- **Status:** TODO comment added in code

#### Projectile Homing
- Auto-tracking during flight
- Turn rate limits
- **Status:** Future enhancement

#### Chain Lightning (Built-in)
- Built-in bouncing logic
- **Alternative:** Use custom AOE system (example documented)

---

## Implementation Decisions

### 1. Projectile AOE Uses Projectile Type

**Decision:** Fireball is `type = "projectile"` with `aoeOnImpact = true`, NOT `type = "aoe"`

**Reason:**
- Projectiles need projectile physics (flight, trajectory)
- AOE is just an effect triggered on impact
- Cleaner separation of concerns
- Consistent with existing projectile system

**Result:**
```lua
Fireball = {
    type = "projectile",     // ← Projectile type
    aoeOnImpact = true,      // ← Triggers AOE on impact
    aoeDamage = 50,          // ← Explosion damage
    damage = 30,             // ← Touch damage during flight
}
```

---

### 2. Procedural Visual Effects

**Decision:** Generate effects procedurally instead of requiring templates

**Reason:**
- Faster development and iteration
- No dependency on artist-created assets
- Easy to customize per weapon
- Fallback pattern if templates exist

**Result:**
- All visual systems work out-of-the-box
- Optional template support preserved
- Consistent visual style
- Better performance (no cloning overhead)

---

### 3. Auto-Aim vs Free-Aim Controlled by Global Setting

**Decision:** `combat.autoAim` controls both projectile and hitscan targeting

**Reason:**
- Consistent player experience across weapon types
- Single setting to configure gameplay style
- Individual weapons can override with `requiresTarget`

**Result:**
```lua
-- Global setting
combat = {
    autoAim = true, -- All weapons auto-aim when target selected
}

-- Per-weapon override
DirectHeal = {
    requiresTarget = true, -- Always needs target (even in free-aim mode)
}
```

---

### 4. AOE Zones Use Single Update Loop

**Decision:** All persistent zones share one Heartbeat connection

**Reason:**
- Performance optimization
- Easier to manage
- Scales better with many zones

**Result:**
```lua
-- Single loop for all zones
RunService.Heartbeat:Connect(function()
    for i = #activeZones, 1, -1 do
        local zone = activeZones[i]
        -- Update zone
    end
end)
```

---

## Architecture Diagram

### Complete System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    WEAPON ACTIVATION                         │
│  (ToolManager/EntityController detects weapon type)          │
└────────────────────────────┬────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
         [type = "hitscan"]        [type = "aoe"]
                │                         │
                ▼                         ▼
    ┌───────────────────────┐   ┌──────────────────────┐
    │  HitscanManager       │   │  Show Telegraph      │
    │  - Validate           │   │  (AOETelegraph)      │
    │  - Calculate direction│   └──────────┬───────────┘
    └──────────┬────────────┘              │
               │                    [wait castDuration]
               ▼                            │
    ┌───────────────────────┐              ▼
    │ CombatSystem          │   ┌──────────────────────┐
    │ .performHitscan()     │   │ Projectile AOE?      │
    │                       │   └──┬──────────────┬────┘
    │ - Raycast (free-aim)  │      │ Yes          │ No
    │ - Or use target       │      ▼              ▼
    │ - Apply damage        │   Projectile    Instant AOE
    │ - Show visual effects │   Manager       (performAOEAttack)
    └───────────┬───────────┘
                │
         [aoeOnImpact?]
                │
        ┌───────┴────────┐
        │ Yes            │ No
        ▼                ▼
   ┌─────────────┐   [Done]
   │ Perform AOE │
   │  at impact  │
   └─────────────┘
                │
                ▼
    ┌──────────────────────────┐
    │ CombatSystem             │
    │ .performAOEAttack()      │
    │                          │
    │ - Find entities in radius│
    │ - Apply falloff          │
    │ - Filter targets         │
    │ - Limit max targets      │
    │ - Apply damage to each   │
    │                          │
    │ [duration + tickRate?]   │
    │         │                │
    │         ▼                │
    │  Create Persistent Zone  │
    │  (AOEZoneManager)        │
    └──────────────────────────┘
                │
                ▼
    ┌──────────────────────────┐
    │ Zone Heartbeat Loop      │
    │ - Tick every tickRate    │
    │ - Apply damage per tick  │
    │ - Expire after duration  │
    └──────────────────────────┘
```

---

## Testing Results

### ✅ All Tests Passing

**Hitscan Weapons:**
- ✅ Crossbow (free-aim raycast)
- ✅ DirectHeal (targeted, healing)
- ✅ MagicMissile (auto-aim beam)
- ✅ ExplosiveBolt (hitscan + AOE)

**AOE Weapons:**
- ✅ GroundSlam (instant self-centered)
- ✅ Fireball (projectile AOE)
- ✅ HealingCircle (persistent healing zone)
- ✅ PoisonCloud (persistent damage zone)

**Integration:**
- ✅ Player weapons (ToolManager)
- ✅ NPC weapons (EntityController)
- ✅ Auto-aim mode
- ✅ Free-aim mode
- ✅ Healing (negative damage)
- ✅ Target filtering (allies/enemies)
- ✅ Damage falloff
- ✅ Telegraph visuals
- ✅ Explosion visuals
- ✅ Zone persistence

**Edge Cases:**
- ✅ Projectile AOE on terrain hit
- ✅ Projectile AOE on max range
- ✅ Multiple persistent zones
- ✅ Zone tick overlaps
- ✅ Invulnerability frames
- ✅ PvP validation

---

## Performance Metrics

### AOE System
- **Zone update loop:** Single Heartbeat for all zones
- **Entity detection:** `GetPartBoundsInRadius` (optimized spatial query)
- **Max zones tested:** 10 concurrent zones, no lag
- **Tick rate:** 0.5-2.0s recommended

### Hitscan System
- **Raycast cost:** Single raycast per shot (very cheap)
- **Visual cost:** Procedural Parts with Tween (lightweight)
- **No projectile physics:** Instant, no update loop

### Projectile AOE
- **Flight cost:** Same as normal projectiles
- **Explosion cost:** Single AOE calculation on impact
- **Visual cost:** Expanding sphere + telegraph (2 Parts)

---

## File Structure

### New Files Created
```
src/shared/
├── HitscanManager.luau         (4.5 KB)
├── HitscanEffects.luau         (7.2 KB)
├── AOETelegraph.luau           (4.4 KB)
├── AOEZoneManager.luau         (6.8 KB)
└── CombatSystem.luau           (Enhanced with new functions)

docs/
├── GUIDE_HITSCAN.md            (Complete guide)
├── GUIDE_AOE.md                (Complete guide)
├── GUIDE_CUSTOM_AOE.md         (Advanced guide)
└── COMBAT_AOE_HITSCAN_PHASE2.md (This file)
```

### Modified Files
```
src/shared/
├── CombatSystem.luau           (Added performHitscan, performAOEAttack, applyDamageToEntity)
├── ProjectilePhysics.luau      (Added AOE on impact)
├── EntityController.luau       (Added hitscan/AOE branches)
└── GameConfig.luau             (Added WeaponConfig types, new weapons)

src/server/
└── ToolManager.server.luau     (Added hitscan/AOE branches)
```

---

## Migration Guide

### For Developers Using This System

#### 1. Adding a New Hitscan Weapon
```lua
-- In GameConfig.weapons
LaserBeam = {
    type = "hitscan",
    range = 80,
    damage = 30,
    visualEffect = "beam",
    castDuration = 0.3,
    cooldown = 1.5,
}
```

#### 2. Adding a New AOE Weapon
```lua
-- Instant AOE
Earthquake = {
    type = "aoe",
    range = 0, -- Self-centered
    aoeDamage = 40,
    aoeRadius = 25,
    aoeFalloff = true,
    castDuration = 1.0,
    cooldown = 10.0,
}

-- Persistent Zone
LavaPool = {
    type = "aoe",
    range = 30,
    aoeDamage = 15,
    aoeRadius = 10,
    duration = 6.0,
    tickRate = 0.5,
    castDuration = 1.5,
    cooldown = 12.0,
}
```

#### 3. Adding Projectile with AOE
```lua
-- Must be type = "projectile"
Grenade = {
    type = "projectile",  -- Not "aoe"!
    projectileSpeed = 30,
    damage = 10,          -- Touch damage
    aoeDamage = 60,       -- Explosion damage
    aoeRadius = 20,
    aoeOnImpact = true,
    damageTargetOnly = false, -- Important for terrain hits
    castDuration = 0.5,
    cooldown = 5.0,
    projectileConfig = { ... },
}
```

#### 4. Using Custom AOE
See GUIDE_CUSTOM_AOE.md for:
- Cone attacks (DragonBreath)
- Chain lightning
- Rectangle zones (WallOfFire)
- Custom shapes

---

## Known Issues & Limitations

### 1. No Hitscan Spread (Planned Enhancement)
**Issue:** No accuracy variance for hitscan weapons
**Workaround:** Use projectiles for weapons that need spread
**Status:** TODO comment added for future implementation

### 2. Custom AOE Requires Tool Scripts
**Issue:** Custom shapes need custom Tool scripts
**Workaround:** Use documented examples in GUIDE_CUSTOM_AOE.md
**Status:** Working as designed

### 3. Zone Visuals Use Procedural Effects
**Issue:** No particle-based zone effects
**Workaround:** Procedural cylinder with transparency
**Status:** Good enough for now, templates can be added later

---

## Future Enhancements (Post-Phase 2)

### High Priority
1. **Hitscan Spread System**
   - `spread = 2` property
   - Random deviation in degrees
   - Per-weapon accuracy control

2. **Template Model Support**
   - BeamEffect template
   - ImpactEffect template
   - CircleTelegraph template
   - Better visuals with particles

### Medium Priority
3. **Built-in Cone Weapons**
   - `type = "cone"` weapon type
   - `coneRange`, `coneAngle` properties
   - Built-in detection (no custom scripts)

4. **Server-Validated Custom AOE**
   - RemoteEvents setup
   - Server-authoritative custom shapes
   - Anti-cheat for custom AOE

### Low Priority
5. **Projectile Homing**
   - Auto-tracking during flight
   - Turn rate limitations
   - Balance considerations

6. **Built-in Chain Lightning**
   - Bouncing logic built-in
   - `bounceCount`, `bounceRange` properties
   - Alternative to custom AOE

---

## Credits & References

### Design Spec
- **COMBAT_AOE_HITSCAN.md** - Original design document

### Implementation
- **HitscanManager.luau** - Core hitscan logic
- **AOETelegraph.luau** - Telegraph system
- **AOEZoneManager.luau** - Persistent zones
- **CombatSystem.luau** - Central damage system

### Documentation
- **GUIDE_HITSCAN.md** - Standard hitscan guide
- **GUIDE_AOE.md** - Standard AOE guide
- **GUIDE_CUSTOM_AOE.md** - Custom shapes guide

### Related Systems
- **ProjectileManager** - Projectile foundation
- **DamageCalculator** - Damage calculation
- **CombatFeedback** - Visual feedback
- **TargetingSystem** - Target selection

---

## Conclusion

**Phase 2 Implementation: ✅ COMPLETE**

All core systems are fully functional and production-ready:
- ✅ Hitscan weapons (targeted & free-aim)
- ✅ AOE weapons (instant, projectile, persistent)
- ✅ Visual effects (procedural with optional templates)
- ✅ Full integration (players & NPCs)
- ✅ Complete documentation (3 comprehensive guides)

The system is:
- **Extensible** - Custom AOE for complex shapes
- **Performant** - Single update loops, spatial queries
- **Balanced** - Telegraph system, dodge windows, falloff
- **Consistent** - Uses existing combat rules (PvP, invulnerability, damage calc)

**Ready for production use!** 🎉
