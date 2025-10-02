# Hitscan Weapons - Setup and Testing Guide

## Overview

Hitscan weapons provide instant hit detection for ranged attacks. This guide covers how to set up, test, and use hitscan weapons in the game.

**What are Hitscan Weapons?**
- **Instant hit** - No travel time, hits immediately on activation
- **Two modes controlled by `combat.autoAim`:**
  - **Auto-aim** (`autoAim = true`) - Aims at locked target, checks range/facing
  - **Free-aim** (`autoAim = false`) - Uses raycast in look direction, hits first entity in path
- **Optional visuals** - Can show beam effects or be completely silent
- **Healing support** - Negative damage values heal instead of damage

---

## Quick Start

### 1. Weapon Configuration

Add hitscan weapons to `GameConfig.weapons`:

```lua
weapons = {
    -- Damage hitscan with visual beam
    Crossbow = {
        type = "hitscan",
        name = "Crossbow",
        range = 100,                -- Max range (auto-aim) or raycast distance (free-aim)
        damage = 40,
        visualEffect = "beam",      -- Show beam visual
        castDuration = 0.3,         -- Aim/charge time
        cooldown = 2.0,
    },

    -- Healing hitscan (no visual)
    DirectHeal = {
        type = "hitscan",
        name = "Direct Heal",
        range = 50,
        damage = -30,               -- Negative = healing
        visualEffect = "none",      -- Silent/instant
        targetFilter = "allies",    -- Only heal allies
        castDuration = 0.2,
        cooldown = 3.0,
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
  - If no target: Shoots in look direction (unless weapon has `requiresTarget = true`)
  - Best for: Fast-paced action gameplay, free-form combat

- **TACTICAL Mode** (`CombatMode.TACTICAL`): Players must select target to attack
  - Target selection required before attacking (no target = no animation/attack)
  - Once targeted: Uses auto-aim or free-aim (based on `autoAim` setting)
  - Best for: Strategic gameplay, turn-based combat feel

**Auto-aim Configuration:**
Set `combat.autoAim` in GameConfig to control how attacks aim when target is selected:

```lua
combat = {
    autoAim = true, -- true = aim at locked target, false = free-aim (aim direction)
    -- When true: attacks auto-aim at locked target when one is selected
    -- When false: attacks use look direction (even when target selected)
}
```

**Force Target Selection (Optional):**
Some weapons always need a target (e.g., healing allies) even in free-aim mode:

```lua
DirectHeal = {
    requiresTarget = true, -- Forces target selection even when autoAim = false
    targetFilter = "allies", -- Only valid targets are allies
}
```

### 2. Create Visual Effect Templates (Optional)

If you want custom visuals beyond the procedural fallback:

**Location:** `ReplicatedStorage.Models.Effects.Hitscan`

**BeamEffect Template:**
```
BeamEffect (Model)
  ├── PrimaryPart (Part) - Invisible anchor
  ├── Beam (Part) - Neon material, cyan color
  └── ... (additional visual parts)
```

**ImpactEffect Template:**
```
ImpactEffect (Model)
  ├── PrimaryPart (Part) - Invisible, size (0.1, 0.1, 0.1)
  └── ParticleEmitter
      ├── Lifetime: 0.2-0.5
      ├── Speed: 5-10
      ├── SpreadAngle: 45, 45
      └── Burst emission (20 particles)
```

**Colors:**
- **Damage**: Cyan (100, 200, 255) or Yellow (255, 255, 200)
- **Healing**: Green (100, 255, 100)

### 3. Give Weapon to Players

Update `GameConfig.player.startingTools`:

```lua
player = {
    startingTools = {"Axe", "Pickaxe", "MagicMissile", "DirectHeal"},
}
```

### 4. Give Weapon to NPCs

Update entity config with `primaryWeapon`:

```lua
enemies = {
    DarkMage = {
        health = 60,
        walkSpeed = 8,
        runSpeed = 12,
        aggroRange = 40,
        primaryWeapon = "MagicMissile", -- Hitscan weapon
        -- ... other properties
    },
}
```

---

## Weapon Properties Reference

### Required Properties

| Property | Type | Description |
|----------|------|-------------|
| `type` | `"hitscan"` | Weapon type identifier |
| `name` | `string` | Display name |
| `range` | `number` | Max distance (studs) |
| `damage` | `number` | Damage amount (negative = healing) |
| `visualEffect` | `"beam" \| "none"` | Visual effect type |
| `castDuration` | `number` | Charge/aim time (seconds) |
| `cooldown` | `number` | Seconds between uses |

### Optional Properties

| Property | Type | Description |
|----------|------|-------------|
| `targetFilter` | `"allies" \| "enemies" \| "all"` | Who can be targeted |
| `requiresTarget` | `boolean` | Force target selection even in free-aim mode |
| `requiresLineOfSight` | `boolean` | Blocked by walls (auto-aim mode only) |
| `requireFacingForDamage` | `boolean` | Override global facing requirement per weapon |
| `spread` | `number` | Accuracy variance (degrees) - **TODO: Not yet implemented** |
| `aoeOnImpact` | `boolean` | Trigger AOE at hit point - **TODO: Phase 2** |
| `aoeDamage` | `number` | AOE explosion damage - **TODO: Phase 2** |
| `aoeRadius` | `number` | AOE explosion radius - **TODO: Phase 2** |

---

## Usage Patterns

### Pattern 1: Auto-Aim Damage (Target-Based)

**Use Case:** Magic missiles, lock-on abilities
**Requires:** `combat.autoAim = true`

```lua
MagicMissile = {
    type = "hitscan",
    range = 80,
    damage = 25,
    visualEffect = "beam",
    castDuration = 0.4,
    cooldown = 1.0,
}
```

**Player Experience:**
1. Equip MagicMissile
2. Target enemy with X key (TargetingSystem)
3. Click to fire (auto-aims at target)
4. Instant hit if target in range/facing
5. Beam shows path to target

---

### Pattern 2: Free-Aim Precision (Look Direction)

**Use Case:** Crossbow, sniper weapons, laser beams
**Requires:** `combat.autoAim = false`

```lua
Crossbow = {
    type = "hitscan",
    range = 100,
    damage = 40,
    visualEffect = "beam",
    castDuration = 0.3,
    cooldown = 2.0,
}
```

**Player Experience:**
1. Equip Crossbow
2. Aim at enemy (no target selection needed)
3. Click to fire in look direction
4. Instant hit on first entity in raycast path
5. Beam shows path to hit point

---

### Pattern 3: Ally Healing (Requires Target)

**Use Case:** Medic spells, support abilities
**Requires:** Target selection (regardless of autoAim setting)

```lua
DirectHeal = {
    type = "hitscan",
    range = 50,
    damage = -30,                    -- Healing
    visualEffect = "none",           -- Silent
    targetFilter = "allies",         -- Only heal allies
    requiresTarget = true,           -- Always requires target (even in free-aim mode)
    requiresLineOfSight = false,     -- Can heal through walls
    requireFacingForDamage = false,  -- Don't need to face ally to heal
    castDuration = 0.2,
    cooldown = 3.0,
}
```

**Player Experience:**
1. Equip DirectHeal
2. Target ally with X key (required)
3. Click to heal
4. Instant heal if target in range (and facing, if autoAim enabled)
5. Works same in auto-aim and free-aim modes (always targets selected ally)

---

## Testing Checklist

### Basic Functionality

**Combat Modes:**
- [ ] **ACTION Mode**: Set `combatMode = GameConfig.CombatMode.ACTION`
  - [ ] Can attack without target (shoots in look direction)
  - [ ] Can attack with target (uses autoAim or free-aim setting)
  - [ ] DirectHeal still requires target (requiresTarget = true)
- [ ] **TACTICAL Mode**: Set `combatMode = GameConfig.CombatMode.TACTICAL`
  - [ ] Cannot attack without target (no animation/sound)
  - [ ] Can attack with target selected
  - [ ] All weapons require target in TACTICAL mode

**Auto-Aim Mode (`combat.autoAim = true`):**
- [ ] Equip hitscan weapon (MagicMissile)
- [ ] Target enemy with X key
- [ ] Fire weapon (click)
- [ ] Weapon auto-aims at target regardless of look direction
- [ ] Beam visual appears from player to target
- [ ] Damage applied instantly if target in range/facing
- [ ] Attack fails if not facing target (requireFacingForDamage)
- [ ] Cooldown prevents spam

**Free-Aim Mode (`combat.autoAim = false`):**
- [ ] Set `combat.autoAim = false` in GameConfig
- [ ] Equip hitscan weapon (Crossbow)
- [ ] Aim at entity (no target selection needed)
- [ ] Fire weapon (click)
- [ ] Raycast fires in look direction
- [ ] Beam visual appears from player to hit point
- [ ] Damage applied to first entity hit
- [ ] Impact effect shows at hit point

**Targeted Healing (requiresTarget = true):**
- [ ] Equip DirectHeal tool
- [ ] Try to fire without target → "No target selected" error
- [ ] Select ally with X key
- [ ] Click to heal (works in both auto-aim and free-aim modes)
- [ ] No visual effect (silent)
- [ ] Ally health increases
- [ ] Out of range = no heal message
- [ ] Try to heal enemy → blocked by targetFilter

**Entity AI:**
- [ ] Spawn enemy with hitscan weapon (e.g., DarkMage with MagicMissile)
- [ ] Enemy aggros on player
- [ ] Enemy fires hitscan attack
- [ ] Beam appears from enemy to player
- [ ] Damage applied to player

### Edge Cases

- [ ] **Miss terrain** - Firing at wall shows beam and impact effect
- [ ] **Miss completely** - Firing at sky shows short beam fade
- [ ] **PvP disabled** - Player cannot hit another player
- [ ] **Invulnerability** - Recently hit entity cannot be hit again immediately
- [ ] **Out of range** - Targeted heal fails if ally too far
- [ ] **No target** - Targeted hitscan with no target selected does nothing
- [ ] **Healing** - Negative damage correctly heals, shows green visuals
- [ ] **Multiple hitscans** - Multiple beams can be active simultaneously

### Visual/Audio

- [ ] **Beam color** - Damage = cyan/blue, Healing = green
- [ ] **Impact particles** - Spawn at hit location
- [ ] **Beam duration** - Beam visible for ~0.1s
- [ ] **Hit sound** - CombatFeedback plays hit sound
- [ ] **Damage numbers** - Floating damage/heal numbers appear

---

## Player Controls (ToolManager Integration)

Hitscan weapons are fully integrated into ToolManager and work for both players and NPCs.

### How It Works

**Auto-Aim Mode (`combat.autoAim = true`):**
1. Player equips hitscan weapon
2. Player targets entity with X key
3. Player clicks to fire
4. HitscanManager validates: weapon type, target requirement, facing check
5. After castDuration, HitscanManager calculates direction (auto-aims at target)
6. performHitscan checks range and applies damage
7. Visual effects show beam from tool Handle to target

**Free-Aim Mode (`combat.autoAim = false`):**
1. Player equips hitscan weapon
2. Player aims at target (no X key needed)
3. Player clicks to fire
4. HitscanManager validates: weapon type
5. After castDuration, HitscanManager calculates direction (look direction)
6. performHitscan raycasts in direction and hits first entity
7. Visual effects show beam from tool Handle to hit point

### Implementation Details

ToolManager uses HitscanManager for all hitscan logic:

```lua
elseif weaponConfig.type == "hitscan" then
    local target = TargetingSystem.getTarget(player)
    local isValid, errorMsg = HitscanManager.validateAttack(character, target, weaponName)
    if not isValid then return end

    task.wait(weaponConfig.castDuration)

    local origin = tool.Handle.Position or humanoidRootPart.Position + Vector3.new(0, 1.5, 0)
    local direction = HitscanManager.calculateDirection(humanoidRootPart, target, origin)

    local result = HitscanManager.performHitscan(origin, direction, weaponName, character, player, target)
end
```

---

## Visual Effect Setup (Advanced)

If you want custom beam/impact effects beyond the procedural fallback:

### Step 1: Create Effect Models

**In Roblox Studio:**

1. Create `ReplicatedStorage.Models.Effects.Hitscan` folder
2. Create `BeamEffect` model:
   - Add Part (PrimaryPart, invisible)
   - Add visual beam Parts (Neon material, cyan color)
   - Size: Long cylinder (0.2 x 0.2 x 10)
3. Create `ImpactEffect` model:
   - Add Part (PrimaryPart, invisible, 0.1 x 0.1 x 0.1)
   - Add ParticleEmitter child
   - Configure burst emission (20 particles)

### Step 2: Configure Template Properties

**BeamEffect:**
- All Parts should be `Anchored = true`, `CanCollide = false`
- Use Neon material for glow
- Default color: Cyan (will be recolored at runtime)

**ImpactEffect:**
- ParticleEmitter settings:
  - `Rate = 0` (burst only)
  - `Lifetime = NumberRange.new(0.2, 0.5)`
  - `Speed = NumberRange.new(5, 10)`
  - `SpreadAngle = Vector2.new(45, 45)`
  - `Size = NumberSequence.new(0.3, 0)`
  - `Transparency = NumberSequence.new(0, 1)`

### Step 3: Test Templates

Templates are automatically loaded by `HitscanEffects.luau`. If not found, procedural fallback is used.

---

## Troubleshooting

### Issue: No beam visible

**Causes:**
- `visualEffect = "none"` in weapon config
- Template models not found → Using procedural fallback (smaller beam)
- Beam duration too short (0.05s for misses)

**Solution:**
- Set `visualEffect = "beam"`
- Create template models or verify path
- Beams last 0.1s on hit, 0.05s on miss

---

### Issue: "No target selected" error (Auto-Aim Mode)

**Causes:**
- `combat.autoAim = true` requires target selection
- No target selected via TargetingSystem

**Solution:**
- Press X key to select target first
- Or set `combat.autoAim = false` for free-aim mode

---

### Issue: Weapon auto-aims instead of using look direction

**Causes:**
- `combat.autoAim = true` enables auto-aim behavior
- Weapon aims at locked target regardless of look direction

**Solution:**
- Set `combat.autoAim = false` in GameConfig for free-aim
- Free-aim uses look direction (raycast-based)

---

### Issue: Healing not working

**Causes:**
- `damage` value is positive (should be negative)
- `targetFilter = "enemies"` (should be `"allies"`)
- PvP disabled and trying to heal another player

**Solution:**
- Set `damage = -30` (negative for healing)
- Set `targetFilter = "allies"`
- Green damage numbers = healing working

---

### Issue: Entity not using hitscan weapon

**Causes:**
- `primaryWeapon` not set in entity config
- Weapon type mismatch (not `"hitscan"`)
- Entity out of aggro range

**Solution:**
- Add `primaryWeapon = "MagicMissile"` to entity config
- Verify weapon exists in `GameConfig.weapons`
- Get closer to trigger aggro

---

## Performance Notes

### Raycasts

- Each free-aim hitscan performs **1 raycast** (very cheap)
- Raycasts are instant and efficient
- No performance concerns with multiple hitscans

### Visual Effects

- Beams are destroyed after 0.1s (Debris service)
- Template models are cloned from cache (efficient)
- Particles emit once (burst) then clean up
- Multiple concurrent beams are fine (tested up to 10+)

### Auto-Aim vs Free-Aim

**Auto-Aim Mode (`combat.autoAim = true`):**
- No raycast needed (cheaper)
- Only checks distance calculation (very fast)
- Requires target selection
- Best for healing, support abilities, lock-on weapons

**Free-Aim Mode (`combat.autoAim = false`):**
- Single raycast per shot (still very cheap)
- No target selection needed
- Best for precision weapons, crossbows, sniper-style gameplay

---

## Comparison: Hitscan vs Projectile

| Feature | Hitscan | Projectile |
|---------|---------|------------|
| **Hit Detection** | Instant | Travel time |
| **Dodge-able** | Only during castDuration | During flight |
| **Visual** | Beam (instant) | Flying object |
| **Range** | Range limit (auto-aim) or raycast (free-aim) | Max range + physics |
| **Performance** | No/single raycast (very cheap) | Tracked every frame (more expensive) |
| **Targeting** | Auto-aim or free-aim (combat.autoAim) | Auto-aim or free-aim (combat.autoAim) |
| **Use Cases** | Lasers, healing, precision | Arrows, fireballs, grenades |

**When to use Hitscan:**
- Instant feedback needed
- Healing/support abilities
- Precision weapons (sniper, crossbow)
- Magic missiles
- No projectile visual needed

**When to use Projectile:**
- Visual travel time important
- Want to see projectile fly
- Need to hit multiple targets along path
- Physics-based interactions

---

## Advanced: Custom Spell Tools

For complex hitscan behavior, create custom Tool scripts using `CombatSystem.applyDamageToEntity()`.

**Example: Multi-target Hitscan**

```lua
-- Tool script
local CombatSystem = require(ReplicatedStorage.Shared.CombatSystem)

tool.Activated:Connect(function()
    local character = player.Character
    local origin = character.HumanoidRootPart.Position
    local direction = character.HumanoidRootPart.CFrame.LookVector

    -- Perform multiple raycasts in a spread pattern
    for angle = -15, 15, 5 do
        local spreadDirection = CFrame.fromEulerAnglesXYZ(0, math.rad(angle), 0) * direction

        local raycastResult = workspace:Raycast(origin, spreadDirection * 50, params)

        if raycastResult then
            local entity = findEntityFromPart(raycastResult.Instance)
            if entity then
                -- Apply damage via central system
                CombatSystem.applyDamageToEntity(
                    character,
                    entity,
                    "MultiHitscan",
                    {damageOverride = 15}
                )
            end
        end
    end
end)
```

See `COMBAT_AOE_HITSCAN.md` for full custom AOE guide.

---

## Summary

**Hitscan Weapons:**
- ✅ Instant hit detection (no travel time)
- ✅ Two modes: Targeted (no raycast) and Free-aim (raycast)
- ✅ Optional visuals (beam or silent)
- ✅ Healing support (negative damage)
- ✅ NPC support (EntityController integration)
- ✅ Custom spell API (`applyDamageToEntity`)
- ✅ DamageCalculator integration (hit locations, multipliers)
- ✅ PvP validation, invulnerability frames

**Current Status:**
- ✅ Core systems implemented
- ✅ NPC AI integration complete
- ⏳ Player ToolManager integration pending
- ⏳ Visual effect templates optional (procedural fallback works)

**Next Steps:**
1. Test in-game with NPCs
2. Add ToolManager integration for player weapons
3. Create custom visual effect templates (optional)
4. Balance damage/cooldown values
5. Add more weapon varieties
