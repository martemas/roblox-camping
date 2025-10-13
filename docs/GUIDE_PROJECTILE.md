# Projectile Weapons - Setup and Testing Guide

## Overview

Projectile weapons fire physical objects that travel through space and hit targets. This guide covers how to set up, test, and use projectile weapons in the game.

**What are Projectile Weapons?**
- **Travel time** - Projectiles fly through space with physics simulation
- **Two modes controlled by `combat.autoAim`:**
  - **Auto-aim** (`autoAim = true`) - Aims at locked target with leading
  - **Free-aim** (`autoAim = false`) - Fires in look direction
- **Dodgeable** - Targets can dodge during flight time
- **Customizable visuals** - Use template models or procedural projectiles
- **Physics-based** - Real collision detection and trajectory

---

## Quick Start

### 1. Weapon Configuration

Add projectile weapons to `GameConfig.weapons`:

```lua
weapons = {
    -- Basic projectile weapon
    Bow = {
        type = "projectile",
        name = "Bow",
        damage = 30,
        range = 100,                     -- Max travel distance
        cooldown = 1.5,
        castDuration = 0.5,              -- Draw/charge time
        projectileSpeed = 80,            -- Studs per second
        requiresLineOfSight = true,      -- Cannot shoot through walls
        damageTargetOnly = nil,          -- Use combat.damageTargetOnly
        penetratesEntities = false,      -- Stops at first hit
        projectileConfig = {
            modelPath = "Arrow1",        -- Model name in ReplicatedStorage.Models.Projectiles
            trailEnabled = true,
            trailColor = Color3.fromRGB(255, 200, 100),
            impactEffect = "ArrowImpact",
        },
    },

    -- AOE projectile
    SpiderWeb = {
        type = "projectile",
        name = "Spider Web",
        damage = 5,
        range = 40,
        cooldown = 3,
        castDuration = 0.6,
        projectileSpeed = 30,
        requiresLineOfSight = true,
        damageTargetOnly = false,        -- Can hit entities along path
        penetratesEntities = false,      -- Stops at first hit
        projectileConfig = {
            modelPath = "Web1",
            trailEnabled = true,
            trailColor = Color3.fromRGB(200, 200, 200),
            impactEffect = "WebSplat",
        },
    },
}
```

**Combat Modes:**
The game supports two combat modes that control when players can attack:

```lua
combat = {
    combatMode = GameConfig.CombatMode.ACTION, -- ACTION or TACTICAL
}
```

- **ACTION Mode** (`CombatMode.ACTION`): Players can attack at any time
  - If target selected: Uses auto-aim or free-aim (based on `autoAim` setting)
  - If no target: Uses click-targeting or fires in look direction
  - Best for: Fast-paced action gameplay, free-form combat

- **TACTICAL Mode** (`CombatMode.TACTICAL`): Players must select target to attack
  - Target selection required before attacking (no target = no animation/attack)
  - Once targeted: Uses auto-aim or free-aim (based on `autoAim` setting)
  - Best for: Strategic gameplay, turn-based combat feel

**Auto-aim Configuration:**
Set `combat.autoAim` in GameConfig to control targeting behavior:

```lua
combat = {
    autoAim = false, -- true = locked target override, false = always use tap position
    -- When true: Locked target overrides tap position (tab-target style)
    -- When false: Always uses tap position (click-to-aim style)
}
```

**Targeting System Behavior:**

**Default Behavior (applies to both autoAim ON/OFF):**
1. Player taps/clicks to fire projectile
2. System searches 8-stud radius around tap point for targetable entities
3. If entity found near tap: Projectile aims at that entity
4. If no entity near tap: Projectile aims at 3D tap position
5. Fallback (no tap): Projectile uses look direction

**autoAim = true (Tab-Target Override):**
- **With locked target**: Aims at locked target (ignores tap position completely)
- **Without locked target**: Uses default behavior (aims at tap position)

**autoAim = false (Pure Click-to-Aim):**
- **Always** uses tap position (locked target ignored for aiming)
- Uses default behavior for all attacks

**Example Scenarios:**
- `autoAim=true` + locked target + tap ground → Aims at locked target
- `autoAim=true` + no target + tap ground → Aims at tap position
- `autoAim=false` + locked target + tap ground → Aims at tap position (ignores locked target)
- `autoAim=false` + locked target + tap enemy → Aims at tapped enemy (ignores locked target)

**Platform Support:**
- **PC/Mac**: Click with mouse to aim
- **Mobile/Tablet**: Tap on screen to aim
- **Console**: Uses look direction (touch not available)

**Force Target Selection (Optional):**
Some weapons always need a target (e.g., healing projectiles) even in free-aim mode:

```lua
HealingOrb = {
    type = "projectile",
    requiresTarget = true,           -- Forces target selection even when autoAim = false
    targetFilter = "allies",         -- Only valid targets are allies
    requireFacingForDamage = false,  -- Don't need to face ally
}
```

### 2. Create Projectile Models

Create projectile models in ReplicatedStorage:

**Location:** `ReplicatedStorage.Models.Projectiles`

**Example Structure:**
```
ReplicatedStorage
  └── Models
      └── Projectiles
          ├── Arrow1 (Model)
          │   ├── PrimaryPart (Part) - Front tip of arrow
          │   ├── Shaft (Part)
          │   ├── Fletching (Part)
          │   └── Trail (Trail) - Optional
          └── Web1 (Model)
              ├── PrimaryPart (Part)
              └── Particles (ParticleEmitter)
```

**Projectile Model Requirements:**
- Must be a `Model` with a `PrimaryPart` set
- PrimaryPart is the collision point (front tip)
- All parts should be `CanCollide = false`
- All parts should be `Anchored = false` (will be set by system)
- Size affects collision detection
- Orientation: PrimaryPart faces forward (+Z direction)

**Trail Setup (Optional):**
Add a `Trail` object to the PrimaryPart for visual effect:
```
Trail Properties:
  - Attachment0: Front of projectile
  - Attachment1: Back of projectile
  - Lifetime: 0.3-0.5
  - Color: Match weapon theme
  - Transparency: NumberSequence (0 → 1)
```

### 3. Give Weapon to Players

Update `GameConfig.player.startingTools`:

```lua
player = {
    startingTools = {"Axe", "Pickaxe", "Bow"},
}
```

### 4. Give Weapon to NPCs

Update entity config with `primaryWeapon`:

```lua
enemies = {
    SpiderArcher = {
        health = 60,
        walkSpeed = 8,
        runSpeed = 12,
        aggroRange = 40,
        primaryWeapon = "SpiderWeb", -- References weapons.SpiderWeb
    },
}
```

---

## Usage Patterns

### Pattern 1: Auto-Aim Projectile (Tab-Target Style)

**Use Case:** Lock-on arrows, MMO-style combat
**Requires:** `combat.autoAim = true`

```lua
Bow = {
    type = "projectile",
    damage = 30,
    range = 100,
    projectileSpeed = 80,
    requiresLineOfSight = true,
}
```

**Player Experience:**
1. Equip Bow
2. Target enemy with X key (TargetingSystem)
3. Click to fire (auto-aims at locked target)
4. Projectile flies toward target position
5. Target can dodge by moving

**Auto-aim Features:**
- Aims at locked target automatically
- Ignores look direction and mouse position
- Works even if you're looking away
- Best for: MMO-style combat, accessibility

---

### Pattern 2: Click-Targeting Projectile (FPS Style)

**Use Case:** Point-and-click combat, MOBA-style targeting
**Requires:** `combat.autoAim = false`

```lua
Bow = {
    type = "projectile",
    damage = 30,
    range = 100,
    projectileSpeed = 80,
    requiresLineOfSight = true,
}
```

**Player Experience:**
1. Equip Bow
2. Click on/near enemy to fire
3. System finds closest target within 8 studs of click
4. Projectile aims at clicked target
5. If no target nearby, shoots at click position

**Click-targeting Features:**
- Smart target detection (8-stud radius)
- Aims at 3D click position if no target
- Locked targets are for UI/info only
- Best for: FPS/MOBA gameplay, precise aiming

---

### Pattern 3: Free-Aim Projectile (Pure Look Direction)

**Use Case:** Skill-based archery, no targeting assistance
**Requires:** `combat.autoAim = false` + no clicking on targets

```lua
Bow = {
    type = "projectile",
    damage = 30,
    range = 100,
    projectileSpeed = 80,
    requiresLineOfSight = true,
}
```

**Player Experience:**
1. Equip Bow
2. Aim with camera at enemy
3. Click to fire in look direction
4. Projectile travels in straight line
5. Manual leading required for moving targets

**Free-aim Features:**
- Fires in camera look direction
- No targeting assistance
- Pure skill-based aiming
- Best for: Hardcore FPS gameplay

---

### Pattern 4: AOE Projectile (Hits Multiple Targets)

**Use Case:** Grenades, splash damage, crowd control

```lua
SpiderWeb = {
    type = "projectile",
    damage = 5,
    damageTargetOnly = false,    -- Hits all entities in path
    penetratesEntities = false,  -- Stops at first hit
    projectileSpeed = 30,        -- Slower for easier dodging
}
```

**Player Experience:**
1. Fire at enemy
2. Projectile hits first entity in path
3. Deals damage to that entity
4. Projectile destroyed on impact

**Future Enhancement (Phase 2):**
```lua
Grenade = {
    aoeOnImpact = true,
    aoeRadius = 10,
    aoeDamage = 20,  -- Damages all entities in radius
}
```

---

## Weapon Properties Reference

### Required Properties

| Property | Type | Description |
|----------|------|-------------|
| `type` | `"projectile"` | Weapon type identifier |
| `name` | `string` | Display name |
| `damage` | `number` | Damage amount (negative = healing) |
| `range` | `number` | Max travel distance (studs) |
| `projectileSpeed` | `number` | Speed in studs/second |
| `castDuration` | `number` | Draw/charge time (seconds) |
| `cooldown` | `number` | Seconds between uses |
| `projectileConfig` | `table` | Visual configuration (see below) |

### Optional Properties

| Property | Type | Description |
|----------|------|-------------|
| `requiresTarget` | `boolean` | Force target selection even in free-aim mode |
| `requiresLineOfSight` | `boolean` | Blocked by walls (auto-aim mode only) |
| `requireFacingForDamage` | `boolean` | Override global facing requirement per weapon |
| `targetFilter` | `"allies" \| "enemies" \| "all"` | Who can be targeted |
| `damageTargetOnly` | `boolean` | Only damage locked target vs all entities in path |
| `penetratesEntities` | `boolean` | Pass through entities or stop at first hit |

### Projectile Config Properties

| Property | Type | Description |
|----------|------|-------------|
| `modelPath` | `string` | Model name in ReplicatedStorage.Models.Projectiles |
| `trailEnabled` | `boolean` | Enable trail effect |
| `trailColor` | `Color3` | Trail color |
| `impactEffect` | `string` | Impact effect name (future) |

---

## Testing Checklist

### Basic Functionality

**Combat Modes:**
- [ ] **ACTION Mode**: Set `combatMode = GameConfig.CombatMode.ACTION`
  - [ ] Can attack without target (fires in look direction)
  - [ ] Can attack with target (uses autoAim or free-aim setting)
  - [ ] Weapons with requiresTarget still require target selection
- [ ] **TACTICAL Mode**: Set `combatMode = GameConfig.CombatMode.TACTICAL`
  - [ ] Cannot attack without target (no animation/sound)
  - [ ] Can attack with target selected
  - [ ] All weapons require target in TACTICAL mode

**Auto-Aim Mode (`combat.autoAim = true`):**
- [ ] Equip projectile weapon (Bow)
- [ ] Target enemy with X key
- [ ] Fire weapon (click)
- [ ] Projectile auto-aims at target
- [ ] Projectile leads target movement (velocity prediction)
- [ ] Projectile flies toward predicted position
- [ ] Damage applied on impact
- [ ] Attack fails if not facing target (requireFacingForDamage)
- [ ] Attack fails if blocked by wall (requiresLineOfSight)
- [ ] Cooldown prevents spam

**Free-Aim Mode (`combat.autoAim = false`):**
- [ ] Set `combat.autoAim = false` in GameConfig
- [ ] Equip projectile weapon (Bow)
- [ ] Aim at entity (no target selection needed)
- [ ] Fire weapon (click)
- [ ] Projectile fires in look direction
- [ ] Projectile travels in straight line
- [ ] Damage applied to first entity hit
- [ ] Manual leading required for moving targets

**Target Selection (requiresTarget = true):**
- [ ] Equip weapon with `requiresTarget = true`
- [ ] Try to fire without target → "No target selected" error
- [ ] Select target with X key
- [ ] Click to fire (works in both auto-aim and free-aim modes)

### Edge Cases

- [ ] **Miss completely** - Projectile travels to max range and despawns
- [ ] **Hit terrain/wall** - Projectile stops and despawns
- [ ] **Target moves** - Projectile misses if target dodges (auto-aim leads but not perfect)
- [ ] **Out of range** - Validation prevents firing (orange HUD border)
- [ ] **Blocked by wall** - Validation prevents firing (red HUD border)
- [ ] **Not facing** - Validation prevents firing (orange HUD border)
- [ ] **PvP disabled** - Projectile cannot hit another player
- [ ] **Multiple projectiles** - Multiple projectiles can be active simultaneously

### Visual/Audio

- [ ] **Projectile model** - Correct model spawns and rotates to face direction
- [ ] **Trail effect** - Trail appears behind projectile
- [ ] **Impact effect** - Effect plays on hit (future)
- [ ] **Fire sound** - Sound plays when projectile spawns
- [ ] **Impact sound** - Sound plays on hit (future)
- [ ] **Damage numbers** - Floating damage numbers appear on hit

### Entity AI

- [ ] Spawn enemy with projectile weapon (e.g., SpiderArcher with SpiderWeb)
- [ ] Enemy aggros on player
- [ ] Enemy fires projectile at player
- [ ] Projectile flies from enemy to player
- [ ] Damage applied to player on hit
- [ ] Enemy leads player movement (velocity prediction)

---

## Player Controls (ToolManager Integration)

Projectile weapons are fully integrated into ToolManager and work for both players and NPCs.

### How It Works

**Auto-Aim Mode (`combat.autoAim = true`):**
1. Player equips projectile weapon
2. Player targets entity with X key
3. Player clicks to fire
4. ProjectileManager validates: weapon type, target requirement, facing check, LOS
5. After castDuration, ProjectileManager calculates direction (auto-aims at predicted position)
6. Projectile spawns and flies toward target
7. Damage applied on impact

**Free-Aim Mode (`combat.autoAim = false`):**
1. Player equips projectile weapon
2. Player aims at target (no X key needed)
3. Player clicks to fire
4. ProjectileManager validates: weapon type
5. After castDuration, ProjectileManager calculates direction (look direction)
6. Projectile spawns and flies in straight line
7. Damage applied to first entity hit

### Implementation Details

ToolManager uses ProjectileManager for all projectile logic:

```lua
elseif weaponConfig.type == "projectile" then
    local target = TargetingSystem.getTarget(player)
    local isValid, errorMsg = ProjectileManager.validateAttack(character, target, weaponName)
    if not isValid then return end

    task.wait(weaponConfig.castDuration)

    local origin = humanoidRootPart.Position + Vector3.new(0, 1.5, 0)
    local direction = -- Auto-aim or free-aim based on combat.autoAim

    local projectile = ProjectileManager.spawnProjectile(origin, direction, weaponName, character, player, target)
end
```

---

## Troubleshooting

### Issue: Projectile doesn't spawn

**Causes:**
- Model not found in ReplicatedStorage.Models.Projectiles
- Model name mismatch (check `projectileConfig.modelPath`)
- Model doesn't have PrimaryPart set

**Solution:**
- Verify model exists at correct path
- Check model name matches config exactly (case-sensitive)
- Set PrimaryPart on the model (front tip of projectile)

---

### Issue: "No target selected" error (Auto-Aim Mode)

**Causes:**
- `combat.autoAim = true` requires target selection
- No target selected via TargetingSystem

**Solution:**
- Press X key to select target first
- Or set `combat.autoAim = false` for free-aim mode

---

### Issue: Projectile aims at target instead of look direction

**Causes:**
- `combat.autoAim = true` enables auto-aim behavior
- Projectile auto-aims at locked target regardless of look direction

**Solution:**
- Set `combat.autoAim = false` in GameConfig for free-aim
- Free-aim uses look direction instead of target

---

### Issue: Projectile passes through entities

**Causes:**
- `penetratesEntities = true` or `damageTargetOnly = true`
- Collision detection disabled

**Solution:**
- Set `penetratesEntities = false` to stop at first hit
- Set `damageTargetOnly = false` to hit all entities in path
- Check projectile model collision parts

---

### Issue: Projectile doesn't lead moving targets

**Causes:**
- Free-aim mode doesn't lead targets
- `combat.autoAim = false`

**Solution:**
- Set `combat.autoAim = true` for automatic leading
- Or manually lead targets in free-aim mode (player skill)

---

### Issue: Projectile blocked even with clear shot

**Causes:**
- `requiresLineOfSight = true` and obstacle detected
- Obstacle between attacker and target

**Solution:**
- Move to clear position
- Set `requiresLineOfSight = false` if weapon should ignore obstacles
- Check TargetHUD for red "BLOCKED" indicator

---

## Performance Notes

### Projectile Physics

- Each projectile runs physics simulation every frame (Heartbeat)
- Raycasts used for collision detection (very efficient)
- Projectiles auto-destroy on hit or max range
- Registry auto-cleans destroyed projectiles

### Optimization Tips

- Use reasonable `projectileSpeed` (30-100 recommended)
- Keep `range` under 200 studs for fast despawn
- Limit concurrent projectiles per player (cooldown)
- Use simple models (low poly count) for projectiles

### Recommended Limits

- **Projectile speed:** 30-100 studs/second
- **Range:** 40-150 studs
- **Cooldown:** 0.5-3 seconds
- **Concurrent projectiles:** 5-10 per player max

---

## Comparison: Projectile vs Hitscan

| Feature | Projectile | Hitscan |
|---------|-----------|---------|
| **Hit Detection** | Travel time + collision | Instant |
| **Dodge-able** | During entire flight | Only during castDuration |
| **Visual** | Flying object with trail | Beam (instant) |
| **Range** | Max distance before despawn | Range limit (auto-aim) or raycast (free-aim) |
| **Performance** | Tracked every frame (more expensive) | Single/no raycast (very cheap) |
| **Targeting** | Auto-aim or free-aim (combat.autoAim) | Auto-aim or free-aim (combat.autoAim) |
| **Use Cases** | Arrows, fireballs, grenades | Lasers, healing, magic missiles |

**When to use Projectile:**
- Visual travel time important
- Want projectiles to be dodge-able
- Physics-based gameplay desired
- Multiple targets along path
- Projectile visual is core to weapon identity

**When to use Hitscan:**
- Instant feedback needed
- Precision weapons (sniper, laser)
- Healing/support abilities
- Performance-critical situations
- No projectile visual needed

---

## Advanced: Velocity Prediction (Auto-Aim)

Auto-aim mode predicts target movement for better accuracy:

```lua
-- EntityController calculates lead for NPCs
local targetVelocity = target.Character.HumanoidRootPart.AssemblyLinearVelocity
local projectileSpeed = weaponConfig.projectileSpeed or 50
local timeToImpact = (targetPos - entityPos).Magnitude / projectileSpeed
local leadTarget = targetPos + (targetVelocity * timeToImpact)
local direction = (leadTarget - entityPos).Unit
```

This makes projectiles more accurate against moving targets but still dodge-able with unpredictable movement.

---

## Future Enhancements (Phase 2)

**AOE on Impact:**
```lua
Grenade = {
    aoeOnImpact = true,
    aoeRadius = 10,
    aoeDamage = 20,
    -- Damages all entities within radius on impact
}
```

**Gravity/Arc:**
```lua
Bow = {
    projectileGravity = 50, -- Studs/s² downward acceleration
    -- Creates realistic arrow arc
}
```

**Bounce/Ricochet:**
```lua
BouncyBall = {
    maxBounces = 3,
    bounceMultiplier = 0.8, -- Loses 20% speed per bounce
}
```

**Piercing:**
```lua
LaserBeam = {
    penetratesEntities = true,
    maxPenetrations = 5, -- Hits up to 5 entities
}
```

---

## Summary

Projectile weapons provide rich, physics-based combat with:
- ✅ Auto-aim and free-aim modes
- ✅ Velocity prediction for moving targets
- ✅ Customizable models and visuals
- ✅ Full validation before animation
- ✅ Target HUD feedback
- ✅ NPC AI support
- ✅ Dodge-able during flight

Configure weapons in GameConfig, create models in ReplicatedStorage, and the system handles the rest!
