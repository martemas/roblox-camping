# Entity Spawning System Guide

Complete guide for configuring and using the unified entity spawning system.

## 📚 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Configuring Entities](#configuring-entities)
- [AI Behavior Profiles](#ai-behavior-profiles)
- [Spawn Locations](#spawn-locations)
- [Spawning Entities](#spawning-entities)
- [Examples](#examples)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

---

## Overview

The unified spawning system provides a clean, stateless architecture for spawning and managing entities (wildlife, creatures, NPCs) with custom AI behaviors.

### Key Features

✅ **Stateless Spawning** - No entity tracking in spawners
✅ **Flexible Spawn Locations** - Point, area, perimeter, random, multiple points
✅ **Custom AI Profiles** - Configure behavior per entity type
✅ **Priority-Based Targeting** - Entities target by category priority
✅ **Spawn Memory** - Entities remember spawn location and return when idle
✅ **Configurable Retargeting** - Control aggro behavior (locked, closest, priority)
✅ **Auto-Population** - Wildlife automatically maintains population levels
✅ **Wave Spawning** - Creatures spawn in waves during night

---

## Quick Start

### Spawn a Single Entity

```lua
local SpawnManager = _G.SpawnManager

-- Spawn a wolf at a specific position
SpawnManager.spawnEntity("Wolf", Vector3.new(100, 10, 50), 5)
```

### Configure Entity AI Behavior

Edit `src/shared/config/EntitiesConfig.luau`:

```lua
Wolf = {
    category = "Wildlife",
    health = 60,
    walkSpeed = 12,
    runSpeed = 22,
    primaryWeapon = "WolfClaw",

    -- AI Behavior Configuration
    ai = {
        profile = "aggressive_wildlife",
        behaviors = {
            idle = "wander",
            onDamaged = "retaliate_closest",
            onPlayerNear = "chase",
        },
        targetPriority = {"Player"},
        aggroRange = 30,
        wanderRadius = 50,
        returnToSpawn = true,
        returnSpeed = 0.5,
        retargetBehavior = "closest",
    },
}
```

---

## Architecture

```
┌─────────────────────────────────────────┐
│         SpawnManager.server             │
│    (High-level spawning logic)          │
│  - Wildlife population maintenance      │
│  - Creature wave spawning               │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│       EntitySpawner (Shared)            │
│      (Stateless spawning facade)        │
│  - Creates models from templates        │
│  - Positions via spawn configs          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│      EntityController (Shared)          │
│   (Central AI & entity management)      │
│  - All active entity tracking           │
│  - AI behavior system                   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│      EntitiesConfig (Shared)            │
│     (Entity definitions + AI profiles)  │
└─────────────────────────────────────────┘
```

### File Locations

- **SpawnManager**: `src/server/SpawnManager.server.luau`
- **EntitySpawner**: `src/shared/EntitySpawner.luau`
- **EntityController**: `src/shared/EntityController.luau`
- **EntitiesConfig**: `src/shared/config/EntitiesConfig.luau`

---

## Configuring Entities

All entity configurations are in `EntitiesConfig.luau`.

### Basic Entity Structure

```lua
Wolf = {
    -- Entity Properties
    category = "Wildlife",      -- "Wildlife", "Creature", "NPC", "Player", "Structure"
    health = 60,
    walkSpeed = 12,
    runSpeed = 22,
    canJump = true,
    jumpCooldown = 3,

    -- Combat
    primaryWeapon = "WolfClaw",
    baseStats = {
        strength = 3,
        magic = 0,
        stamina = 2,
        accuracy = 6
    },

    -- Loot
    drops = {"Food", "Hide", "Bones"},

    -- Spawning
    maxCount = 5,              -- Max entities of this type
    respawnTime = 60,          -- Seconds to respawn after death

    -- Animations
    animations = {
        walk = "rbxassetid://...",
        run = "rbxassetid://...",
        attack = "rbxassetid://...",
        jump = "rbxassetid://...",
    },

    -- Flags
    canTakeDamage = true,

    -- AI Configuration (see next section)
    ai = { ... }
}
```

---

## AI Behavior Profiles

AI behavior profiles define how entities act in different situations.

### Complete AI Configuration

```lua
ai = {
    -- Profile identifier (for debugging)
    profile = "aggressive_wildlife",

    -- Behavior Responses
    behaviors = {
        idle = "wander",              -- What to do when no target
        onDamaged = "retaliate_closest", -- How to respond to damage
        onPlayerNear = "chase",       -- What to do when player in range
    },

    -- Targeting
    targetPriority = {"Player", "Structure", "Wildlife"},  -- Attack priority

    -- Ranges
    aggroRange = 30,              -- Detection/aggro range
    seekRange = 100,              -- Active seeking range (for seek_target)
    wanderRadius = 50,            -- Wander area from spawn point
    fleeDistance = 30,            -- Minimum flee distance (future)

    -- Return Behavior
    returnToSpawn = true,         -- Walk back to spawn when idle
    returnSpeed = 0.5,            -- Speed multiplier when returning (0.5 = 50%)

    -- Retargeting
    retargetBehavior = "closest", -- "locked", "closest", or "priority"
}
```

### Behavior Options

#### Idle Behaviors (`behaviors.idle`)

| Behavior | Description | Use Case |
|----------|-------------|----------|
| `"wander"` | Random wandering within `wanderRadius` from spawn | Passive wildlife |
| `"seek_target"` | Actively seek targets within `seekRange`, wander while seeking | Aggressive creatures |
| `"patrol"` | Follow patrol points (future) | Guards, sentries |
| `"stationary"` | Stand still, only aggro if target enters range | Turrets, static enemies |

#### Damage Response (`behaviors.onDamaged`)

| Behavior | Description | Use Case |
|----------|-------------|----------|
| `"retaliate_locked"` | Attack attacker, never switch target | Vengeful enemies |
| `"retaliate_closest"` | Attack attacker, switch to closer threats | Smart wildlife |
| `"ignore"` | Don't retarget from damage | Mission-focused creatures |

#### Player Detection (`behaviors.onPlayerNear`)

| Behavior | Description | Use Case |
|----------|-------------|----------|
| `"chase"` | Chase and attack player | Aggressive entities |
| `"flee"` | Run away from player (future) | Passive animals |
| `"ignore"` | Continue current behavior | Neutral entities |

#### Retargeting Behavior (`retargetBehavior`)

| Behavior | Description | When to Use |
|----------|-------------|-------------|
| `"locked"` | Never switch targets once engaged | Focused enemies |
| `"closest"` | Switch to closest threat if current target out of range | Opportunistic |
| `"priority"` | Always check for higher priority targets | Strategic |

---

## Spawn Locations

EntitySpawner supports multiple spawn location types.

### Location Types

#### 1. Point (Specific Position)

```lua
location = {
    type = "point",
    position = Vector3.new(100, 10, 50)
}
```

#### 2. Area (Random Within Circle)

```lua
location = {
    type = "area",
    center = Vector3.new(0, 0, 0),
    radius = 100
}
```

#### 3. Perimeter (Ring Around Center)

```lua
location = {
    type = "perimeter",
    center = Vector3.new(0, 0, 0),
    minRadius = 150,
    maxRadius = 200
}
```
**Use Case**: Creature waves spawning around map edge

#### 4. Random (Random Ground Position)

```lua
location = { type = "random" }
```

#### 5. Points (Multiple Specific Points)

```lua
location = {
    type = "points",
    positions = {
        Vector3.new(100, 10, 50),
        Vector3.new(-50, 10, 100),
        Vector3.new(0, 10, -100),
    },
    randomize = true  -- Pick random point (default: true)
}
```

---

## Spawning Entities

### Using SpawnManager (Recommended)

**SpawnManager** handles population maintenance and wave spawning automatically.

```lua
local SpawnManager = _G.SpawnManager

-- Spawn single entity (simple)
SpawnManager.spawnEntity("Wolf", Vector3.new(100, 10, 50), 5)

-- Start night wave (creatures)
SpawnManager.startNightWave()

-- End night (clear creatures)
SpawnManager.endNight()

-- Clear all entities (testing)
SpawnManager.clearAllEntities()

-- Get current night
local night = SpawnManager.getCurrentNight()
```

### Using EntitySpawner (Advanced)

**EntitySpawner** provides full control over spawning.

```lua
local EntitySpawner = require(ReplicatedStorage.Shared.EntitySpawner)

-- Spawn single entity
local model = EntitySpawner.spawnEntity({
    entityType = "Wolf",
    location = { type = "random" },
    level = 5,
    spread = 10,  -- Random offset per spawn
})

-- Spawn wave
local models = EntitySpawner.spawnWave({
    {
        entityType = "Zombie",
        location = {
            type = "perimeter",
            center = Vector3.new(0, 0, 0),
            minRadius = 150,
            maxRadius = 200,
        },
        count = 10,
        level = 3,
        spread = 10,
    }
})

-- Despawn entity
EntitySpawner.despawnEntity(model)
```

---

## Examples

### Example 1: Passive Deer

```lua
Deer = {
    category = "Wildlife",
    health = 40,
    walkSpeed = 10,
    runSpeed = 18,
    primaryWeapon = "DeerHoof",
    baseStats = { strength = 1, magic = 0, stamina = 2, accuracy = 4 },
    drops = {"Meat", "Hide"},
    maxCount = 8,
    canTakeDamage = true,

    ai = {
        profile = "passive_wildlife",
        behaviors = {
            idle = "wander",
            onDamaged = "flee",      -- Future: Run away when hit
            onPlayerNear = "flee",   -- Future: Run from players
        },
        targetPriority = {},         -- Never attacks
        aggroRange = 20,             -- Detection range for fleeing
        wanderRadius = 60,
        returnToSpawn = true,
        returnSpeed = 0.7,
        retargetBehavior = "ignore",
    },
}
```

### Example 2: Territorial Bear

```lua
Bear = {
    category = "Wildlife",
    health = 100,
    walkSpeed = 5,
    runSpeed = 10,
    primaryWeapon = "BearClaw",
    baseStats = { strength = 6, magic = 0, stamina = 4, accuracy = 2 },
    drops = {"Meat", "Hide", "Bones"},
    maxCount = 3,
    canTakeDamage = true,

    ai = {
        profile = "territorial_wildlife",
        behaviors = {
            idle = "wander",
            onDamaged = "retaliate_locked",  -- Never switch target
            onPlayerNear = "chase",
        },
        targetPriority = {"Player"},
        aggroRange = 25,
        wanderRadius = 35,           -- Stays near spawn
        returnToSpawn = true,
        returnSpeed = 0.6,
        retargetBehavior = "locked", -- Focus on one target
    },
}
```

### Example 3: Zombie (Night Creature)

```lua
Zombie = {
    category = "Creature",
    health = 50,
    walkSpeed = 8,
    runSpeed = 12,
    primaryWeapon = "ZombieBite",
    baseStats = { strength = 4, magic = 0, stamina = 3, accuracy = 3 },
    drops = {"Cloth", "RottenMeat"},
    canTakeDamage = true,

    ai = {
        profile = "aggressive_creature",
        behaviors = {
            idle = "seek_target",        -- Always seeking
            onDamaged = "ignore",        -- Don't retarget
            onPlayerNear = "chase",
        },
        targetPriority = {"Player", "Structure"},  -- Attack both
        aggroRange = 25,
        seekRange = 100,                 -- Active seeking range
        wanderRadius = 20,               -- Patrol while seeking
        returnToSpawn = false,           -- Never return (attack mission)
        retargetBehavior = "priority",   -- Switch based on priority
    },
}
```

### Example 4: Elite Boss

```lua
ZombieKing = {
    category = "Creature",
    health = 500,
    walkSpeed = 10,
    runSpeed = 16,
    primaryWeapon = "ZombieKingAxe",
    baseStats = { strength = 12, magic = 0, stamina = 10, accuracy = 8 },
    drops = {"RareGem", "BossLoot"},
    canTakeDamage = true,

    ai = {
        profile = "boss_creature",
        behaviors = {
            idle = "seek_target",
            onDamaged = "retaliate_closest",  -- Smart switching
            onPlayerNear = "chase",
        },
        targetPriority = {"Player"},
        aggroRange = 50,                 -- Large detection range
        seekRange = 150,
        wanderRadius = 30,
        returnToSpawn = false,
        retargetBehavior = "closest",    -- Switch to closest threat
    },
}
```

---

## Advanced Usage

### Custom Spawn Patterns

```lua
-- Spawn entities in a circle
local function spawnCircle(entityType, center, radius, count)
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        local x = center.X + math.cos(angle) * radius
        local z = center.Z + math.sin(angle) * radius

        SpawnManager.spawnEntity(entityType, Vector3.new(x, center.Y, z), 1)
    end
end

spawnCircle("Wolf", Vector3.new(0, 10, 0), 100, 8)
```

### Spawn with Patrol Points (Future)

```lua
local model = EntitySpawner.spawnEntity({
    entityType = "Guard",
    location = { type = "point", position = Vector3.new(0, 10, 0) },
    patrolPoints = {
        Vector3.new(0, 10, 0),
        Vector3.new(50, 10, 0),
        Vector3.new(50, 10, 50),
        Vector3.new(0, 10, 50),
    },
})
```

### Accessing Active Entities

```lua
local EntityController = require(ReplicatedStorage.Shared.EntityController)

-- Get all active entities
for model, entity in EntityController.getActiveEntities() do
    print(`Entity: {entity.entityType}, Health: {entity.humanoid.Health}`)
end

-- Count entities by category
local function countByCategory(category)
    local count = 0
    for model, entity in EntityController.getActiveEntities() do
        if entity.config.category == category then
            count += 1
        end
    end
    return count
end

print(`Wildlife count: {countByCategory("Wildlife")}`)
print(`Creature count: {countByCategory("Creature")}`)
```

### Modifying Entity After Spawn

```lua
local model = SpawnManager.spawnEntity("Wolf", position, 10)

-- Get entity instance
local entity = EntityController.getEntity(model)

if entity then
    -- Force target a specific player
    EntityController.setTarget(model, player)

    -- Modify level
    EntityController.setEntityLevel(model, 20)
end
```

---

## Troubleshooting

### Entity Not Spawning

**Problem**: `SpawnManager.spawnEntity()` returns `nil`

**Solutions**:
1. Check entity exists in `EntitiesConfig.luau`
2. Verify model template exists in `ReplicatedStorage.Models`
3. Check console for error messages
4. Ensure model has `Humanoid` and `HumanoidRootPart`

```lua
-- Debug spawning
local model = SpawnManager.spawnEntity("Wolf", position, 1)
if not model then
    warn("Failed to spawn Wolf")
end
```

### Entity Not Moving

**Problem**: Entity spawns but doesn't move or attack

**Solutions**:
1. Check `ai.behaviors.idle` is set
2. Verify `targetPriority` array is not empty (unless passive)
3. Ensure `aggroRange` or `seekRange` is set
4. Check `walkSpeed` and `runSpeed` are > 0
5. Verify animations are loaded (check console)

### Entity Not Returning to Spawn

**Problem**: Entity wanders too far and doesn't return

**Solutions**:
1. Set `ai.returnToSpawn = true`
2. Increase `ai.wanderRadius` (return triggers at 1.5x radius)
3. Adjust `ai.returnSpeed` (higher = faster return)

```lua
ai = {
    returnToSpawn = true,
    wanderRadius = 50,       -- Returns when >75 studs from spawn
    returnSpeed = 0.8,       -- 80% of walk speed
}
```

### Entity Not Switching Targets

**Problem**: Entity locks onto one target and ignores others

**Solutions**:
1. Change `ai.retargetBehavior` to `"closest"` or `"priority"`
2. Check `behaviors.onDamaged` isn't set to `"ignore"`

```lua
ai = {
    retargetBehavior = "closest",  -- Switch to closest threat
    behaviors = {
        onDamaged = "retaliate_closest",  -- Not "ignore"
    },
}
```

### Too Many/Too Few Entities

**Problem**: Wildlife population incorrect

**Solutions**:
1. Check `maxCount` in entity config
2. Verify `SpawnManager` is running (check console for "SpawnManager initialized")
3. Wait 10 seconds (population check interval)

```lua
Wolf = {
    maxCount = 5,  -- Max 5 wolves active at once
}
```

### Creatures Not Spawning at Night

**Problem**: No creatures during night phase

**Solutions**:
1. Check `DayNightCycle` is calling `SpawnManager.startNightWave()`
2. Verify creature category is `"Creature"` not `"Wildlife"`
3. Check `GameConfig.nightWaves.baseZombieCount` is > 0

```lua
-- In DayNightCycle or manual trigger
_G.SpawnManager.startNightWave()
```

---

## Performance Tips

### Optimize Population Checks

```lua
-- In SpawnManager.server.luau
-- Adjust check interval (default: 10 seconds)
if currentTime - lastWildlifeCheck < 15 then  -- Changed to 15 seconds
    return
end
```

### Limit Active Entities

```lua
-- In EntitiesConfig.luau
Wolf = {
    maxCount = 3,  -- Reduced from 5
}
```

### Reduce Seek Range

```lua
ai = {
    seekRange = 50,  -- Reduced from 100 (less pathfinding)
}
```

---

## Testing Commands

Useful commands for testing spawning system:

```lua
-- Clear all entities
_G.SpawnManager.clearAllEntities()

-- Spawn multiple wolves
for i = 1, 10 do
    _G.SpawnManager.spawnEntity("Wolf", Vector3.new(i*10, 10, 0), 1)
end

-- Force night wave
_G.SpawnManager.startNightWave()

-- Count active entities
local EntityController = require(game.ReplicatedStorage.Shared.EntityController)
local count = 0
for _ in EntityController.getActiveEntities() do
    count += 1
end
print(`Active entities: {count}`)
```

---

## API Reference

### SpawnManager

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `spawnEntity` | `entityType: string, position: Vector3?, level: number?` | `Model?` | Spawn single entity |
| `startNightWave` | - | - | Start creature wave spawning |
| `endNight` | - | - | End night and clear creatures |
| `clearAllEntities` | - | - | Remove all entities |
| `getCurrentNight` | - | `number` | Get current night number |
| `isNightActive` | - | `boolean` | Check if night is active |

### EntitySpawner

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `spawnEntity` | `config: SpawnConfig` | `Model?` | Spawn with full config |
| `spawnWave` | `configs: {SpawnConfig}` | `{Model}` | Spawn multiple entities |
| `despawnEntity` | `model: Model` | - | Remove entity |
| `getDefaultSpawnConfig` | `entityType: string` | `SpawnConfig?` | Get default config |

### EntityController

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `initializeEntity` | `model: Model, entityType: string` | `EntityInstance?` | Initialize entity |
| `removeEntity` | `model: Model` | - | Remove from tracking |
| `getActiveEntities` | - | `{[Model]: EntityInstance}` | Get all entities |
| `getEntity` | `model: Model` | `EntityInstance?` | Get specific entity |
| `setTarget` | `model: Model, target: Player?` | - | Force target |
| `setEntityLevel` | `model: Model, level: number` | - | Set level |

---

## Summary

The unified spawning system provides:

✅ Clean, stateless architecture
✅ Flexible spawn configurations
✅ Custom AI behavior per entity
✅ Priority-based targeting
✅ Automatic population management
✅ Wave-based spawning for creatures

**Key Files**:
- Configuration: `src/shared/config/EntitiesConfig.luau`
- High-level API: `src/server/SpawnManager.server.luau`
- Spawning: `src/shared/EntitySpawner.luau`
- AI/Management: `src/shared/EntityController.luau`

**Next Steps**:
1. Configure entity AI profiles in `EntitiesConfig.luau`
2. Test spawning with `SpawnManager.spawnEntity()`
3. Customize behaviors for your game
4. Add new entity types by following examples

---

**Happy spawning! 🎮**

For questions or issues, check the [Troubleshooting](#troubleshooting) section or review the code examples above.
