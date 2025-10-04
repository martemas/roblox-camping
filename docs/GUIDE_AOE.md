# AOE Weapons - Setup and Testing Guide

## Overview

AOE (Area of Effect) weapons damage multiple entities within a radius. This guide covers how to set up, test, and use AOE weapons in the game.

**What are AOE Weapons?**
- **Area damage** - Hits all entities in a radius
- **Three variants:**
  - **Instant AOE** - Immediate damage at target location (GroundSlam)
  - **Projectile AOE** - Projectile that explodes on impact (Fireball)
  - **Persistent zones** - Lingering damage/healing over time (PoisonCloud)
- **Visual telegraph** - Red circle warning during castDuration
- **Dodgeable** - Players can move out of area during cast time
- **Customizable** - Radius, falloff, max targets, duration, tick rate

---

## Quick Start

### 1. Weapon Configuration

Add AOE weapons to `GameConfig.weapons`:

```lua
weapons = {
    -- ========================================
    -- INSTANT AOE (Self-centered)
    -- ========================================
    GroundSlam = {
        type = "aoe",
        name = "Ground Slam",
        range = 0,                      -- Self-centered (0 = around caster)
        aoeDamage = 35,                 -- Damage amount
        aoeRadius = 20,                 -- Radius in studs
        aoeFalloff = true,              -- Damage decreases with distance
        maxTargets = 15,                -- Max entities hit
        castDuration = 0.7,             -- Telegraph/dodge window
        cooldown = 8.0,
    },

    -- ========================================
    -- PROJECTILE AOE (Explodes on impact)
    -- ========================================
    Fireball = {
        type = "projectile",            -- Projectile type!
        name = "Fireball",
        projectileSpeed = 40,
        damage = 30,                    -- Touch damage during flight
        aoeDamage = 50,                 -- Explosion damage
        range = 60,
        aoeRadius = 15,
        aoeFalloff = true,
        maxTargets = 10,
        aoeOnImpact = true,             -- Trigger AOE on impact
        damageTargetOnly = false,       -- IMPORTANT: Allows terrain hits
        castDuration = 1.0,
        cooldown = 5.0,

        projectileConfig = {
            modelPath = "Fireball",
            trailEnabled = true,
            trailColor = Color3.fromRGB(255, 100, 0),
            impactEffect = "Explosion",
        },
    },

    -- ========================================
    -- PERSISTENT ZONE (Damage over time)
    -- ========================================
    PoisonCloud = {
        type = "aoe",
        name = "Poison Cloud",
        range = 40,                     -- Max distance to place zone
        aoeDamage = 10,                 -- Damage per tick
        aoeRadius = 12,
        aoeFalloff = false,             -- Constant damage in radius
        maxTargets = 999,
        castDuration = 2.0,
        cooldown = 15.0,

        duration = 8.0,                 -- Zone lasts 8 seconds
        tickRate = 1.0,                 -- Damage every second (8 ticks total)
        targetFilter = "enemies",       -- Only damage enemies
    },

    -- ========================================
    -- HEALING ZONE (Negative damage = heal)
    -- ========================================
    HealingCircle = {
        type = "aoe",
        name = "Healing Circle",
        range = 40,
        aoeDamage = -20,                -- Negative = healing
        aoeRadius = 12,
        aoeFalloff = false,
        maxTargets = 5,
        castDuration = 2.0,
        cooldown = 15.0,

        duration = 5.0,
        tickRate = 1.0,
        targetFilter = "allies",        -- Only heal allies
    },

    -- ========================================
    -- HITSCAN + AOE (Beam with explosion)
    -- ========================================
    ExplosiveBolt = {
        type = "hitscan",               -- Hitscan type!
        name = "Explosive Bolt",
        range = 80,
        damage = 20,                    -- Direct hit damage
        visualEffect = "beam",
        requiresLineOfSight = true,

        aoeOnImpact = true,
        aoeDamage = 40,                 -- Explosion damage
        aoeRadius = 10,
        aoeFalloff = true,
        maxTargets = 5,

        castDuration = 0.4,
        cooldown = 4.0,
    },
}
```

### 2. Give Weapon to Players

Update `GameConfig.player.startingTools`:

```lua
player = {
    startingTools = {"Axe", "Pickaxe", "GroundSlam", "Fireball"},
}
```

### 3. Give Weapon to NPCs

Update entity config with `primaryWeapon`:

```lua
enemies = {
    BerserkerBoss = {
        health = 200,
        walkSpeed = 10,
        runSpeed = 14,
        aggroRange = 50,
        primaryWeapon = "GroundSlam", -- Self-centered AOE
    },

    FireMage = {
        health = 80,
        walkSpeed = 6,
        runSpeed = 10,
        aggroRange = 50,
        primaryWeapon = "Fireball", -- Projectile AOE
    },

    ToxicShaman = {
        health = 100,
        walkSpeed = 8,
        runSpeed = 12,
        aggroRange = 45,
        primaryWeapon = "PoisonCloud", -- Persistent zone
    },
}
```

---

## AOE Variants

### Variant 1: Instant AOE (Self-Centered)

**Use Case:** Berserker slam, shockwave, defensive explosion

```lua
GroundSlam = {
    type = "aoe",
    range = 0,              -- Self-centered
    aoeDamage = 35,
    aoeRadius = 20,
    castDuration = 0.7,
}
```

**Player Experience:**
1. Equip GroundSlam tool
2. Click to activate
3. Red circle appears around player (telegraph)
4. After castDuration, damage applied to all in radius
5. Orange explosion visual at player position

**NPC Behavior:**
- Triggers at NPC position (self-centered)
- Shows telegraph warning
- Players can dodge by moving away

---

### Variant 2: Instant AOE (Targeted)

**Use Case:** Meteor strike, targeted explosion

```lua
MeteorStrike = {
    type = "aoe",
    range = 50,             -- Can target up to 50 studs away
    aoeDamage = 60,
    aoeRadius = 15,
    castDuration = 1.5,
}
```

**Player Experience:**
1. Target enemy with X key (or aim in look direction)
2. Click to activate
3. Red circle appears at target position
4. After castDuration, damage applied
5. Explosion visual at target location

**Targeting:**
- If target selected: AOE at target position
- If no target: AOE at position in look direction

---

### Variant 3: Projectile AOE (Explodes on Impact)

**Use Case:** Fireball, grenade, rocket

```lua
Fireball = {
    type = "projectile",        -- NOT "aoe"!
    projectileSpeed = 40,
    damage = 30,                -- Touch damage
    aoeDamage = 50,             -- Explosion damage
    aoeOnImpact = true,         -- Trigger explosion
    damageTargetOnly = false,   -- IMPORTANT for terrain hits
    aoeRadius = 15,
}
```

**Player Experience:**
1. Fire weapon (click)
2. Projectile flies toward target/look direction
3. On impact (entity, terrain, or max range):
   - Orange explosion sphere appears
   - Red circle shows blast radius
   - All entities in radius take damage

**Total Damage Potential:**
- Direct hit: `damage` + `aoeDamage` (30 + 50 = 80)
- Nearby entities: `aoeDamage` only (50)

---

### Variant 4: Persistent Zone (Damage/Heal Over Time)

**Use Case:** Poison cloud, healing circle, fire zone

```lua
PoisonCloud = {
    type = "aoe",
    range = 40,
    aoeDamage = 10,         -- Per tick
    aoeRadius = 12,
    duration = 8.0,         -- Lasts 8 seconds
    tickRate = 1.0,         -- Tick every second (8 ticks)
    targetFilter = "enemies",
}
```

**Player Experience:**
1. Place zone at target location
2. Visual effect persists for duration
3. Entities inside take damage every tickRate seconds
4. Zone auto-destroys after duration

**Tick Calculations:**
- Total damage: `aoeDamage * (duration / tickRate)`
- Example: 10 damage × (8s / 1s) = 80 total damage
- Each tick respects invulnerability frames

---

### Variant 5: Hitscan + AOE (Beam with Explosion)

**Use Case:** Explosive sniper, charged blast

```lua
ExplosiveBolt = {
    type = "hitscan",
    damage = 20,            -- Direct beam damage
    aoeDamage = 40,         -- Explosion damage
    aoeOnImpact = true,
    aoeRadius = 10,
}
```

**Player Experience:**
1. Fire beam (instant hitscan)
2. Beam hits target
3. Explosion at impact point
4. All entities in radius take AOE damage

---

## Weapon Properties Reference

### Required Properties

| Property | Type | Description |
|----------|------|-------------|
| `type` | `"aoe"` or `"projectile"` | Weapon type (projectile for Fireball-style) |
| `name` | `string` | Display name |
| `aoeDamage` | `number` | Damage amount (negative = healing) |
| `aoeRadius` | `number` | Radius in studs |
| `range` | `number` | Max distance (0 = self-centered) |
| `castDuration` | `number` | Telegraph/charge time (seconds) |
| `cooldown` | `number` | Seconds between uses |

### Optional Properties

| Property | Type | Description |
|----------|------|-------------|
| `aoeFalloff` | `boolean` | Damage decreases with distance (default: false) |
| `maxTargets` | `number` | Max entities hit (default: 999) |
| `targetFilter` | `"allies" \| "enemies" \| "all"` | Who can be affected |
| `duration` | `number` | Zone duration (persistent zones only) |
| `tickRate` | `number` | Seconds between ticks (persistent zones only) |
| `aoeOnImpact` | `boolean` | Trigger AOE on projectile/hitscan impact |
| `damageTargetOnly` | `boolean` | For projectile AOE: false allows terrain hits |
| `projectileSpeed` | `number` | For projectile AOE: speed in studs/second |
| `projectileConfig` | `table` | Projectile visual configuration |

### Damage Falloff

When `aoeFalloff = true`, damage decreases linearly with distance:

```lua
damageMultiplier = 1 - (distance / radius)
finalDamage = aoeDamage * damageMultiplier
```

**Example:**
- `aoeDamage = 100`, `aoeRadius = 10`
- At center (0 studs): 100 damage (100%)
- At 5 studs: 50 damage (50%)
- At edge (10 studs): 0 damage (0%)

---

## Testing Checklist

### Basic Functionality

**Instant AOE (Self-Centered):**
- [ ] Equip GroundSlam tool
- [ ] Click to activate
- [ ] Red circle appears around player
- [ ] Orange explosion appears after castDuration
- [ ] Damage applied to all entities in radius
- [ ] Cooldown prevents spam

**Instant AOE (Targeted):**
- [ ] Target enemy with X key
- [ ] Click to activate
- [ ] Red circle appears at target position
- [ ] Damage applied after castDuration
- [ ] Works without target (fires in look direction)

**Projectile AOE:**
- [ ] Equip Fireball tool
- [ ] Click to fire
- [ ] Projectile flies toward target
- [ ] Explosion on impact (entity, terrain, max range)
- [ ] Orange sphere + red circle visual
- [ ] AOE damage applied to all in radius
- [ ] Touch damage + explosion damage both work

**Persistent Zone:**
- [ ] Place PoisonCloud
- [ ] Visual effect persists for duration
- [ ] Damage ticks every tickRate seconds
- [ ] Zone auto-destroys after duration
- [ ] Each tick respects invulnerability frames

**Hitscan AOE:**
- [ ] Fire ExplosiveBolt
- [ ] Beam appears (instant)
- [ ] Explosion at impact point
- [ ] Direct hit + AOE damage both applied

### Edge Cases

- [ ] **Falloff** - Damage decreases with distance when `aoeFalloff = true`
- [ ] **MaxTargets** - Only hits up to maxTargets entities
- [ ] **Target Filter** - "allies" only heals allies, "enemies" only damages enemies
- [ ] **Terrain Hit** - Projectile AOE explodes on terrain (requires `damageTargetOnly = false`)
- [ ] **Max Range** - Projectile AOE explodes at max range if no hit
- [ ] **PvP Disabled** - AOE cannot hit other players when `pvpEnabled = false`
- [ ] **Invulnerability** - Respects invulnerability frames per weapon

### Visual/Audio

- [ ] **Telegraph** - Red circle during castDuration (instant AOE)
- [ ] **Explosion** - Orange sphere expands and fades (projectile AOE)
- [ ] **Radius indicator** - Red circle on ground shows blast radius
- [ ] **Zone visual** - Persistent effect for duration (zones)
- [ ] **Damage numbers** - Floating numbers appear on each entity hit
- [ ] **Sound effects** - Attack sound plays on activation

### Entity AI

- [ ] Spawn enemy with AOE weapon (e.g., BerserkerBoss with GroundSlam)
- [ ] Enemy aggros on player
- [ ] Enemy shows telegraph at target position
- [ ] Enemy applies AOE damage after castDuration
- [ ] Player can dodge by moving out of telegraph area

---

## Troubleshooting

### Issue: AOE doesn't trigger

**Causes:**
- Missing required properties (`aoeDamage`, `aoeRadius`, `aoeOnImpact`)
- Incorrect weapon type (projectile AOE must be `type = "projectile"`, not `"aoe"`)

**Solution:**
- Verify all required properties are set
- For projectile AOE: Use `type = "projectile"` with `aoeOnImpact = true`
- Check console for error messages

---

### Issue: Projectile AOE doesn't explode on terrain

**Causes:**
- `damageTargetOnly = true` (default from `combat.damageTargetOnly`)
- Projectile is configured to only hit locked target

**Solution:**
```lua
Fireball = {
    type = "projectile",
    damageTargetOnly = false,  -- ← Add this
    aoeOnImpact = true,
    ...
}
```

---

### Issue: No explosion visual

**Causes:**
- `aoeOnImpact` not set
- Projectile reaches max range without AOE trigger

**Solution:**
- Set `aoeOnImpact = true`
- AOE now triggers on terrain, entity, AND max range

---

### Issue: Zone doesn't persist

**Causes:**
- Missing `duration` and `tickRate` properties
- Zone treats as instant AOE instead of persistent

**Solution:**
```lua
PoisonCloud = {
    type = "aoe",
    duration = 8.0,    -- ← Add duration
    tickRate = 1.0,    -- ← Add tick rate
    ...
}
```

---

### Issue: Players can't dodge AOE

**Causes:**
- `castDuration` too short
- No visual telegraph

**Solution:**
- Increase `castDuration` to 0.7-2.0 seconds
- Telegraph shows automatically during castDuration
- Players see red circle and can move away

---

### Issue: AOE hits allies

**Causes:**
- No target filter set
- Default hits all entities

**Solution:**
```lua
PoisonCloud = {
    targetFilter = "enemies",  -- Only damage enemies
}

HealingCircle = {
    targetFilter = "allies",   -- Only heal allies
}
```

---

## Performance Notes

### AOE System Optimization

- **Instant AOE** - Very efficient, single `GetPartBoundsInRadius` call
- **Projectile AOE** - Efficient, reuses projectile physics system
- **Persistent zones** - Single Heartbeat loop for all zones
- **Auto-cleanup** - Zones and explosions auto-destroy

### Recommended Limits

- **AOE radius:** 10-25 studs (larger = more performance cost)
- **Max targets:** 10-20 for balance
- **Tick rate:** 0.5-2 seconds (faster = more performance cost)
- **Duration:** 5-10 seconds max
- **Concurrent zones:** 5-10 active zones

---

## Advanced: Damage Calculation

### Falloff Formula

```lua
if aoeFalloff then
    local distance = (targetPos - entityPos).Magnitude
    local damageMultiplier = 1 - (distance / radius)
    damageMultiplier = math.max(0, damageMultiplier)
    finalDamage = aoeDamage * damageMultiplier
end
```

### Persistent Zone Total Damage

```lua
totalDamage = aoeDamage * (duration / tickRate)
```

**Example:**
- `aoeDamage = 10`
- `duration = 8.0`
- `tickRate = 1.0`
- Total: 10 × (8 / 1) = **80 damage** over 8 seconds

### Target Filtering

```lua
-- Allies: Same player or self
if targetFilter == "allies" then
    if entity == attacker then return true end
    if entityPlayer and attackerPlayer and entityPlayer == attackerPlayer then return true end
    return false
end

-- Enemies: Different player or NPCs
if targetFilter == "enemies" then
    if entity == attacker then return false end
    if entityPlayer and attackerPlayer and entityPlayer == attackerPlayer then return false end
    return true
end
```

---

## Comparison: AOE Variants

| Feature | Instant AOE | Projectile AOE | Persistent Zone | Hitscan AOE |
|---------|-------------|----------------|-----------------|-------------|
| **Travel Time** | None | Yes | None | None |
| **Dodge Window** | castDuration | castDuration + flight | castDuration | castDuration |
| **Multi-Hit** | Single burst | Single burst | Multiple ticks | Single burst |
| **Visual** | Circle + explosion | Projectile + explosion | Persistent effect | Beam + explosion |
| **Use Cases** | Slams, shockwaves | Grenades, fireballs | Zones, DoT | Explosive shots |

---

## Code Integration

### For Players (ToolManager)

AOE weapons are fully integrated into ToolManager:

```lua
elseif weaponConfig.type == "aoe" then
    -- Show telegraph
    AOETelegraph.showCircleTelegraph(targetPos, radius, castDuration, attackType)

    task.wait(weaponConfig.castDuration)

    if weaponConfig.projectileSpeed then
        -- Projectile AOE
        ProjectileManager.spawnProjectile(...)
    else
        -- Instant AOE
        CombatSystem.performAOEAttack(...)
    end
end
```

### For NPCs (EntityController)

NPCs can use all AOE variants:

```lua
elseif weaponConfig.type == "aoe" then
    -- Determine position (self or target)
    local targetPos = weaponConfig.range == 0
        and entity.humanoidRootPart.Position
        or target.Character.HumanoidRootPart.Position

    -- Show telegraph
    AOETelegraph.showCircleTelegraph(...)

    task.wait(weaponConfig.castDuration)

    -- Execute (instant or projectile)
end
```

---

## Summary

AOE weapons provide rich, strategic combat with:
- ✅ Instant, projectile, and persistent zone variants
- ✅ Visual telegraphs for counterplay
- ✅ Damage falloff and target filtering
- ✅ Full NPC AI support
- ✅ Explosion visuals and feedback
- ✅ Integration with existing combat systems

Configure weapons in GameConfig and the system handles the rest!
