# Phase 0 - Core Mechanics Implementation

## Overview
Phase 0 focuses on testing fundamental game mechanics with minimal complexity. The goal is to establish the basic resource gathering → storage → defense loop that will serve as the foundation for all future phases.

## Asset Requirements

### Models to Create & Placement

#### Place in `ReplicatedStorage > Models`

**Resource Nodes** (with ClickDetector already added):
- `WoodNode` - Tree model with ClickDetector
- `StoneNode` - Rock formation with ClickDetector
- `MetalNode` - Metallic ore vein with ClickDetector

**Buildings**:
- `Warehouse` - Central storage building with ClickDetector for deposits

**Wildlife** (with Humanoid and basic animations):
- `Wolf` - Low-poly wolf model
- `Bear` - Low-poly bear model

**Enemies** (with Humanoid and animations):
- `Zombie` - Basic zombie model

**Tools** (as Tool objects):
- `Axe` - Tool with Handle part
- `Pickaxe` - Tool with Handle part

#### Place in `ReplicatedStorage > UI`

**Icons** (ImageLabel-ready):
- `WoodIcon` - 32x32px wood resource icon
- `StoneIcon` - 32x32px stone resource icon
- `MetalIcon` - 32x32px metal resource icon
- `AxeIcon` - 32x32px axe tool icon
- `PickaxeIcon` - 32x32px pickaxe tool icon

#### Place in `ReplicatedStorage > Effects`

**Particle Effects** (ParticleEmitter objects):
- `WoodParticles` - Wood chips effect
- `StoneParticles` - Stone dust effect
- `MetalParticles` - Metal sparks effect

#### Place in `ReplicatedStorage > Sounds`

**Sound Effects** (Sound objects):
- `AxeSwing` - Axe swinging sound
- `AxeHit` - Axe hitting wood sound
- `PickaxeSwing` - Pickaxe swinging sound
- `PickaxeHitStone` - Pickaxe hitting stone sound
- `PickaxeHitMetal` - Pickaxe hitting metal sound
- `DayTransition` - Day beginning sound
- `NightTransition` - Night beginning sound

## System Architecture

### 1. Resource Mining System (`src/server/ResourceManager.server.luau`)
**Resource Specifications**:
- **Wood**: 8-10 nodes, 3 hits with axe, 30s respawn
- **Stone**: 4-6 nodes, 5 hits with pickaxe, 45s respawn
- **Metal**: 2-3 nodes, 8 hits with pickaxe, 60s respawn

**Mining Mechanics**:
- ClickDetector on resource nodes
- Track hits per node server-side
- Visual feedback (particles on hit)
- Tool validation (axe for wood, pickaxe for stone/metal)
- HP indicator above nodes

### 2. Inventory System (`src/server/InventoryManager.server.luau`)
**Player Inventory**:
- 5-item limit per player initially
- Server-side storage (anti-exploit)
- UI updates via RemoteEvents
- Block mining when inventory full

### 3. Tool System (`src/server/ToolManager.server.luau`)
**Starting Tools**:
- **Axe**: 20 damage, mines wood only, swing animation
- **Pickaxe**: 15 damage, mines stone/metal, swing animation
- Auto-equip appropriate tool for resource type
- Tool switching validation

### 4. Warehouse System (`src/server/WarehouseManager.server.luau`)
**Central Storage**:
- Warehouse building at camp center
- Touch detection for auto-deposit
- Shared team resource pool
- UI shows total team resources
- Deposit sound effects

### 5. Wildlife System (`src/server/WildlifeSpawner.server.luau`)
**Random Spawning**:
- 3-5 wolves, 2-3 bears active at once
- Respawn 60s after death
- Random wandering when no players nearby
- 15-stud proximity aggro
- Drops: food, hide, bones

### 6. Day/Night Cycle (`src/server/DayNightCycle.server.luau`)
**Cycle Management**:
- **Day**: 5 minutes (mining/building phase)
- **Night**: 3 minutes (defense phase)
- Smooth Lighting.TimeOfDay transitions
- Phase change notifications with sound
- UI countdown timer

### 7. Enemy Spawning (`src/server/EnemySpawner.server.luau`)
**Level 1 Enemies (Night Only)**:
- 5 zombies per wave
- Spawn at map perimeter (random locations)
- Basic pathfinding to warehouse using PathfindingService
- 50 HP, 15 damage, 8 walkspeed

### 8. Client UI (`src/client/GameUI.client.luau`)
**HUD Elements**:
- **Inventory Display**: 5 slots with item icons (bottom-left)
- **Team Resources**: Wood/stone/metal counters (top-middle)
- **Phase Timer**: Day/night countdown (top-right)
- **Health Bar**: Player health (top-left)

## Configuration System

### Game Settings (`src/shared/GameConfig.luau`)
```lua
local GameConfig = {
    -- Player Settings
    player = {
        maxHealth = 100,
        inventorySize = 5,
        startingTools = {"Axe", "Pickaxe"}
    },

    -- Resource Settings
    resources = {
        Wood = { nodesCount = 10, hitsRequired = 3, respawnTime = 30 },
        Stone = { nodesCount = 6, hitsRequired = 5, respawnTime = 45 },
        Metal = { nodesCount = 3, hitsRequired = 8, respawnTime = 60 }
    },

    -- Time Settings
    dayDuration = 300, -- 5 minutes
    nightDuration = 180, -- 3 minutes

    -- Wildlife Settings
    wildlife = {
        maxWolves = 5,
        maxBears = 3,
        aggroRange = 15,
        respawnTime = 60
    },

    -- Enemy Settings
    enemies = {
        zombiesPerWave = 5,
        zombieHealth = 50,
        zombieDamage = 15,
        zombieSpeed = 8
    }
}
```

## File Structure
```
src/
├── server/
│   ├── init.server.luau
│   ├── ResourceManager.server.luau
│   ├── InventoryManager.server.luau
│   ├── ToolManager.server.luau
│   ├── WarehouseManager.server.luau
│   ├── WildlifeSpawner.server.luau
│   ├── DayNightCycle.server.luau
│   └── EnemySpawner.server.luau
├── client/
│   ├── init.client.luau
│   └── GameUI.client.luau
└── shared/
    ├── GameConfig.luau
    ├── RemoteEvents.luau
    └── Types.luau
```

## Core Gameplay Loop
1. **Day Phase**: Players mine resources (wood/stone/metal) with appropriate tools
2. **Resource Management**: Limited to 5 items, must return to warehouse to deposit
3. **Wildlife Encounters**: Random bears/wolves attack when players venture far from camp
4. **Night Phase**: Zombies spawn and attack the warehouse
5. **Defense**: Players use tools as weapons to defend the camp
6. **Repeat**: Cycle continues with increasing difficulty

## Testing Priorities
1. **Resource Mining**: Tool validation, hit detection, HP tracking
2. **Inventory System**: 5-item limit enforcement, UI updates
3. **Warehouse Deposits**: Touch detection, shared storage
4. **Wildlife AI**: Random wandering, proximity aggro, combat
5. **Day/Night Cycle**: Visual transitions, timer accuracy
6. **Enemy Pathfinding**: Zombie navigation to warehouse
7. **Tool Combat**: Weapon damage against wildlife/enemies
8. **UI Integration**: All HUD elements updating correctly

## Success Criteria
- Players can successfully mine all 3 resource types
- Inventory management forces strategic trips to warehouse
- Wildlife provides environmental challenge during resource gathering
- Day/night cycle creates distinct gameplay phases
- Basic combat system works for both tools and enemies
- UI clearly communicates game state to players

This phase establishes the foundation mechanics that will be expanded in future phases with building systems, camp upgrades, and more complex enemy waves.