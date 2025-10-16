# Refactoring Plan v2: Pragmatic Engine/Game Separation

## Overview

This document provides a **practical, incremental approach** to separate reusable game engine code from game-specific camping game content. This builds on REFACTORING_0.md with clear engine/game boundaries and proper security.

**Key differences from REFACTORING_1.md:**
- REFACTORING_1.md = Ambitious full framework redesign (module system, complete rewrite)
- REFACTORING_2.md = **Pragmatic refactoring of existing code** (folder reorganization, security fixes)

## Design Principles

1. **Minimal Engine Touch** - Only modify engine when expanding capabilities for ALL future games
2. **Security First** - Only expose to client what's necessary; sensitive data stays server-side
3. **Multi-Game Support** - Structure supports multiple games: `games/camping/`, `games/survival/`, etc.
4. **Multi-Role Items** - Engine supports items with multiple capabilities (tool+weapon, armor+consumable)
5. **Incremental Migration** - Refactor existing code, not rewrite from scratch

## Final Structure

```
src/
├── shared/
│   ├── engine/                      # 🔒 REUSABLE ENGINE (rarely modified)
│   │   ├── systems/                 # Pure game logic (shared client+server)
│   │   │   ├── combat/
│   │   │   │   ├── CombatSystem.luau
│   │   │   │   ├── ProjectilePhysics.luau
│   │   │   │   ├── ProjectileLOS.luau
│   │   │   │   ├── Stats.luau
│   │   │   │   └── StatsProvider.luau
│   │   │   │
│   │   │   ├── inventory/
│   │   │   │   ├── Inventory.luau
│   │   │   │   └── ItemValidator.luau
│   │   │   │
│   │   │   ├── drops/
│   │   │   │   └── DropResolver.luau
│   │   │   │
│   │   │   └── entities/
│   │   │       └── EntityBehavior.luau
│   │   │
│   │   ├── visual-effects/
│   │   │   ├── AOETelegraph.luau
│   │   │   ├── HitscanEffects.luau
│   │   │   └── CombatFeedback.luau
│   │   │
│   │   ├── core/
│   │   │   ├── RemoteEvents.luau
│   │   │   ├── Types.luau
│   │   │   └── Utils.luau
│   │   │
│   │   └── player/
│   │       ├── TargetingSystem.luau
│   │       └── PlayerSettingsManager.luau
│   │
│   └── games/                       # 📝 GAME-SPECIFIC CODE
│       └── camping/                 # Camping survival game
│           ├── data/                # Item/entity definitions (CLIENT-VISIBLE)
│           │   ├── items/
│           │   │   ├── Items.luau               # Master item registry
│           │   │   ├── Weapons.luau             # Weapon display specs
│           │   │   ├── Tools.luau               # Tool display specs
│           │   │   ├── Consumables.luau         # Consumable display specs
│           │   │   ├── Resources.luau           # Resource display specs
│           │   │   ├── Armor.luau               # Armor display specs
│           │   │   └── Buildings.luau           # Building display specs
│           │   │
│           │   └── entities/
│           │       ├── Entities.luau            # Master entity registry
│           │       ├── Creatures.luau           # Creature definitions
│           │       ├── Wildlife.luau            # Wildlife definitions
│           │       └── NPCs.luau                # NPC definitions
│           │
│           └── config/
│               └── ClientSettings.luau          # UI/display settings ONLY
│
├── server/
│   ├── engine/                      # 🔒 REUSABLE ENGINE (rarely modified)
│   │   ├── services/                # Stateful game systems
│   │   │   ├── InventoryService.luau
│   │   │   ├── DropService.luau
│   │   │   ├── CombatService.luau
│   │   │   ├── EntityService.luau
│   │   │   └── XPService.luau
│   │   │
│   │   ├── managers/                # State management
│   │   │   ├── PlayerDataManager.luau
│   │   │   ├── EntityManager.luau
│   │   │   └── WorldManager.luau
│   │   │
│   │   ├── combat/                  # Server-side combat logic
│   │   │   ├── DamageCalculator.luau
│   │   │   ├── HitscanManager.luau
│   │   │   ├── ProjectileManager.luau
│   │   │   └── AOEZoneManager.luau
│   │   │
│   │   └── utilities/
│   │       ├── AnimationCache.luau
│   │       ├── AnimationManager.luau
│   │       ├── HealthBarManager.luau
│   │       └── ProfileStore.luau
│   │
│   └── games/                       # 📝 GAME-SPECIFIC CODE
│       └── camping/                 # Camping survival game
│           ├── data/                # Game data (SERVER-ONLY)
│           │   ├── items/
│           │   │   ├── WeaponStats.luau         # PRIVATE: Actual weapon stats
│           │   │   ├── ToolStats.luau           # PRIVATE: Actual tool stats
│           │   │   ├── ConsumableStats.luau     # PRIVATE: Actual consumable effects
│           │   │   ├── ResourceStats.luau       # PRIVATE: Gather rates, yields
│           │   │   └── ArmorStats.luau          # PRIVATE: Actual armor stats
│           │   │
│           │   └── entities/
│           │       ├── CreatureStats.luau       # PRIVATE: HP, damage, AI
│           │       ├── WildlifeStats.luau       # PRIVATE: Behavior, drops
│           │       └── NPCStats.luau            # PRIVATE: Stats, dialogue
│           │
│           ├── config/              # SECURITY-CRITICAL CONFIGS (SERVER-ONLY)
│           │   ├── GameConfig.luau              # Gameplay rules
│           │   ├── Balance.luau                 # Multipliers, rates
│           │   ├── Economy.luau                 # Prices, sell values
│           │   ├── SpawnConfig.luau             # Spawn locations/weights
│           │   └── DayNightCycleConfig.luau     # Day/night settings
│           │
│           ├── managers/            # Game-specific managers
│           │   ├── ResourceManager.luau
│           │   ├── ShopManager.luau
│           │   ├── SpawnManager.luau
│           │   ├── ToolManager.luau
│           │   └── TownhallManager.luau
│           │
│           └── loaders/
│               └── WorkspaceSpawnLoader.luau    # Map initialization
│
└── client/
    ├── engine/                      # 🔒 REUSABLE ENGINE (rarely modified)
    │   └── ui/
    │       └── UIComponent.luau
    │
    └── games/                       # 📝 GAME-SPECIFIC CODE
        └── camping/
            ├── ui/                  # Game-specific UI
            │   ├── Inventory.luau
            │   ├── Shop.luau
            │   ├── HealthBar.luau
            │   ├── StaminaBar.luau
            │   ├── XPBar.luau
            │   ├── StatsPanel.luau
            │   ├── TargetHUD.luau
            │   ├── TeamResources.luau
            │   ├── PhaseTimer.luau
            │   ├── Notification.luau
            │   └── LevelUpModal.luau
            │
            ├── controllers/         # Game-specific controllers
            │   ├── BuildingController.client.luau
            │   ├── MovementController.client.luau
            │   ├── EntityTargeting.client.luau
            │   ├── ToolClickHandler.client.luau
            │   └── TargetHUD.client.luau
            │
            └── config/
                ├── UIConfig.luau
                └── UIManager.luau
```

## Security: Client vs Server Split

### ✅ Client Gets (ReplicatedStorage)

**Purpose**: Display, UI, animations, tooltips

**Example**: `shared/games/camping/data/items/Weapons.luau`
```lua
-- CLIENT-VISIBLE: Display information only
local Weapons = {
    Axe = {
        displayName = "Axe",
        description = "Chop trees and defend yourself",
        icon = "rbxassetid://123",
        animationId = "rbxassetid://456",
        attackSound = "Swing",
        equipModel = "Weapons/Axe",
    },

    Sword = {
        displayName = "Iron Sword",
        description = "A sturdy blade for combat",
        icon = "rbxassetid://789",
        animationId = "rbxassetid://012",
        attackSound = "SwordSwing",
        equipModel = "Weapons/Sword",
    },
}

return Weapons
```

### 🔒 Server Owns (ServerScriptService)

**Purpose**: Gameplay mechanics, stats, formulas

**Example**: `server/games/camping/data/items/WeaponStats.luau`
```lua
-- SERVER-ONLY: Actual gameplay stats (NEVER sent to client)
local WeaponStats = {
    Axe = {
        damage = 20,              -- PRIVATE
        range = 8,                -- PRIVATE
        attackSpeed = 1.0,        -- PRIVATE
        cooldown = 0.5,           -- PRIVATE
        castDuration = 0.4,       -- PRIVATE
        damageType = "Physical",  -- PRIVATE
    },

    Sword = {
        damage = 25,              -- PRIVATE
        range = 10,               -- PRIVATE
        attackSpeed = 1.2,        -- PRIVATE
        cooldown = 0.4,           -- PRIVATE
        castDuration = 0.3,       -- PRIVATE
        damageType = "Physical",  -- PRIVATE
    },
}

return WeaponStats
```

**Example**: `server/games/camping/config/Economy.luau`
```lua
-- SERVER-ONLY: Prices (exploit prevention)
local Economy = {
    itemPrices = {
        Wood = 10,           -- NEVER exposed to client
        Stone = 15,          -- NEVER exposed to client
        Metal = 50,          -- NEVER exposed to client
        Gem = 100,           -- NEVER exposed to client
        BasicAxe = 100,      -- NEVER exposed to client
        SteelAxe = 500,      -- NEVER exposed to client
    },

    itemSellValues = {
        Wood = 5,            -- NEVER exposed to client
        Stone = 7,           -- NEVER exposed to client
        Metal = 25,          -- NEVER exposed to client
        Gem = 50,            -- NEVER exposed to client
    },
}

return Economy
```

### Security Rules

| Data Type | Location | Reason |
|-----------|----------|--------|
| Item names, descriptions, icons | Client (ReplicatedStorage) | Needed for UI display |
| Weapon/tool animations | Client (ReplicatedStorage) | Needed for client-side animation |
| Entity models, visuals | Client (ReplicatedStorage) | Needed for rendering |
| Max inventory size | Client (ReplicatedStorage) | Needed for UI validation |
| **Weapon damage/stats** | **Server (ServerScriptService)** | **Prevent damage exploits** |
| **Drop rates/tables** | **Server (ServerScriptService)** | **Prevent farming exploits** |
| **Economy prices** | **Server (ServerScriptService)** | **Prevent price manipulation** |
| **Spawn rates/weights** | **Server (ServerScriptService)** | **Prevent spawn manipulation** |
| **Combat formulas** | **Server (ServerScriptService)** | **Prevent combat exploits** |
| **XP formulas** | **Server (ServerScriptService)** | **Prevent XP exploits** |

**Rule of Thumb**: If an exploiter knowing the value gives them an advantage → Server-only

## Multi-Role Item Support

The engine's item system supports items with multiple roles:

**Engine Types** (`shared/engine/core/Types.luau`):
```lua
export type ItemType = "Resource" | "Consumable" | "Weapon" | "Tool" | "Armor" | "Building"

export type ItemData = {
    id: string,
    name: string,
    type: ItemType,
    description: string?,

    -- Inventory properties
    stackable: boolean,
    maxStack: number?,
    droppable: boolean,
    dropModel: string?,

    -- Multi-role support (engine feature)
    weaponData: string?,      -- References WeaponStats
    armorData: string?,       -- References ArmorStats
    consumableData: string?,  -- References ConsumableStats
    toolData: string?,        -- References ToolStats
    buildingData: string?,    -- References BuildingStats
}
```

**Game Example** (`shared/games/camping/data/items/Items.luau`):
```lua
local Items = {}

Items.Database = {
    -- Dual-role: Tool + Weapon
    BasicAxe = {
        id = "BasicAxe",
        name = "Basic Axe",
        type = "Tool",
        description = "Chop trees and defend yourself",
        stackable = false,
        droppable = true,
        dropModel = "Items/BasicAxe",
        toolData = "BasicAxe",      -- ✅ Can mine trees
        weaponData = "Axe",         -- ✅ Can attack
    },

    -- Single-role: Weapon only
    IronSword = {
        id = "IronSword",
        name = "Iron Sword",
        type = "Weapon",
        description = "A sturdy blade for combat",
        stackable = false,
        droppable = true,
        dropModel = "Weapons/IronSword",
        weaponData = "Sword",       -- ✅ Can attack
        -- No toolData = Cannot mine
    },

    -- Single-role: Tool only
    BasicPickaxe = {
        id = "BasicPickaxe",
        name = "Basic Pickaxe",
        type = "Tool",
        description = "Mine stone and ore",
        stackable = false,
        droppable = true,
        dropModel = "Items/BasicPickaxe",
        toolData = "BasicPickaxe",  -- ✅ Can mine
        weaponData = "Pickaxe",     -- ✅ Can attack (weak)
    },

    -- Resource: No combat/tool use
    Wood = {
        id = "Wood",
        name = "Wood",
        type = "Resource",
        description = "Basic building material",
        stackable = true,
        maxStack = 999,
        droppable = true,
        dropModel = "Items/Wood",
        -- No weaponData or toolData
    },
}

return Items
```

**Engine automatically handles:**
- Checking if item can attack (has `weaponData?`)
- Checking if item can gather resources (has `toolData?`)
- Checking if item can be equipped (has `armorData?`)
- UI displays all available actions

## Config Split Example: GameSettings → ClientSettings + GameConfig

### Current (Insecure)
```lua
-- src/shared/config/GameSettings.luau (BAD: Everything exposed to client)
local GameSettings = {
    player = {
        inventorySize = 100,         -- ✅ Client needs for UI
        startingHealth = 100,        -- ⚠️ Client doesn't need
        startingStamina = 100,       -- ⚠️ Client doesn't need
    },

    drops = {
        mode = "scatter",            -- 🔒 Server-only gameplay rule
        scatterRadius = 5,           -- 🔒 Server-only
        despawnTime = 300,           -- 🔒 Server-only
    },

    combat = {
        damageTargetOnly = true,     -- 🔒 SECURITY RISK if client knows
        friendlyFire = false,        -- 🔒 SECURITY RISK
        pvpEnabled = false,          -- 🔒 SECURITY RISK
    },
}
```

### New (Secure)

**Client Settings** (`shared/games/camping/config/ClientSettings.luau`):
```lua
-- CLIENT-VISIBLE: UI/display settings only
local ClientSettings = {
    ui = {
        maxInventorySlots = 100,     -- For UI display/validation
        maxHealth = 100,             -- For health bar max
        maxStamina = 100,            -- For stamina bar max
        showDamageNumbers = true,    -- UI preference
        healthBarStyle = "modern",   -- UI style
    },
}

return ClientSettings
```

**Server Config** (`server/games/camping/config/GameConfig.luau`):
```lua
-- SERVER-ONLY: Gameplay rules (security-critical)
local GameConfig = {
    player = {
        startingHealth = 100,        -- Server authority
        startingStamina = 100,       -- Server authority
        healthRegen = 0.5,           -- Server-only mechanic
        staminaRegen = 1.0,          -- Server-only mechanic
    },

    drops = {
        mode = "scatter",            -- Drop behavior
        scatterRadius = 5,           -- Drop scatter distance
        despawnTime = 300,           -- Item lifetime
    },

    combat = {
        damageTargetOnly = true,     -- Prevent AOE exploits
        friendlyFire = false,        -- Team damage rules
        pvpEnabled = false,          -- PvP toggle
        damageMultiplier = 1.0,      -- Global damage scaling
    },

    spawning = {
        maxEntitiesPerPlayer = 10,   -- Spawn cap
        spawnInterval = 30,          -- Spawn frequency
        difficultyScaling = 1.2,     -- Difficulty multiplier
    },
}

return GameConfig
```

## Migration Path

### Phase 1: Create Folder Structure (Week 1)
1. Create `src/shared/engine/`, `src/server/engine/`, `src/client/engine/`
2. Create `src/shared/games/camping/`, `src/server/games/camping/`, `src/client/games/camping/`
3. Update `default.project.json` to reflect new structure

### Phase 2: Security Fix - Split Configs (Week 1)
**CRITICAL: Do this first to fix security issues**

1. Split `GameSettings.luau`:
   - → `shared/games/camping/config/ClientSettings.luau` (UI parts)
   - → `server/games/camping/config/GameConfig.luau` (gameplay rules)

2. Move all other configs to server:
   - `ResourcesConfig.luau` → `server/games/camping/config/ResourcesConfig.luau`
   - `WeaponsConfig.luau` → Split into display + stats (see above)
   - `ToolsConfig.luau` → Split into display + stats
   - `EntitiesConfig.luau` → Split into display + stats
   - `ShopConfig.luau` → `server/games/camping/config/Economy.luau`
   - `SpawnConfig.luau` → `server/games/camping/config/SpawnConfig.luau`
   - `DayNightCycleConfig.luau` → `server/games/camping/config/DayNightCycleConfig.luau`
   - `BuildingsConfig.luau` → Split into display + stats

3. Update all imports across codebase

### Phase 3: Move Engine Code (Week 2)
1. **Shared Engine**:
   - `src/shared/combat/*` → `src/shared/engine/systems/combat/`
   - `src/shared/visual-effects/*` → `src/shared/engine/visual-effects/`
   - `src/shared/core/*` → `src/shared/engine/core/`
   - `src/shared/player/TargetingSystem.luau` → `src/shared/engine/player/`

2. **Server Engine**:
   - `src/server/DropSystem.luau` → `src/server/engine/services/DropService.luau`
   - `src/server/InventoryManager.server.luau` → `src/server/engine/services/InventoryService.luau`
   - `src/server/PlayerStats.luau` → `src/server/engine/services/PlayerStatsService.luau`
   - `src/server/XPRewardManager.luau` → `src/server/engine/services/XPService.luau`
   - `src/server/combat/*` → `src/server/engine/combat/`
   - `src/server/entities/*` → `src/server/engine/managers/EntityManager.luau` (refactor)

3. **Client Engine**:
   - `src/client/ui/UIComponent.luau` → `src/client/engine/ui/UIComponent.luau`

### Phase 4: Move Game-Specific Code (Week 2)
1. **Server Game Code**:
   - `src/server/*Manager.server.luau` → `src/server/games/camping/managers/`
   - Keep game-specific managers in camping folder

2. **Client Game Code**:
   - `src/client/ui/*` → `src/client/games/camping/ui/`
   - `src/client/*Controller.client.luau` → `src/client/games/camping/controllers/`
   - `src/client/UIConfig.luau` → `src/client/games/camping/config/UIConfig.luau`

### Phase 5: Create Data Layer (Week 3)
1. Create `shared/games/camping/data/items/Items.luau` (master registry)
2. Create display-only definitions in shared
3. Create stats-only definitions in server
4. Migrate existing config data to new format
5. Create backward-compatibility adapters if needed

### Phase 6: Refactor Services (Week 3)
1. Update services to use new data structure
2. Update imports across codebase
3. Remove file system searches, use item database lookups
4. Test all functionality

### Phase 7: Update Client (Week 4)
1. Update UI to use client-safe definitions only
2. Remove any client-side game logic
3. Update all client requests to go through server validation
4. Security audit

### Phase 8: Clean Up (Week 4)
1. Remove old config files
2. Remove backward-compatibility adapters
3. Update documentation
4. Performance optimization
5. Final testing

## Creating a New Game

Once refactoring is complete, creating a new game is straightforward:

### Step 1: Create game folders
```
src/shared/games/survival/
src/server/games/survival/
src/client/games/survival/
```

### Step 2: Copy camping game structure
```bash
cp -r src/shared/games/camping/ src/shared/games/survival/
cp -r src/server/games/camping/ src/server/games/survival/
cp -r src/client/games/camping/ src/client/games/survival/
```

### Step 3: Edit game data
- Edit `survival/data/items/Items.luau` - Define new items
- Edit `survival/data/entities/Entities.luau` - Define new entities
- Edit `survival/config/*` - Configure gameplay rules

### Step 4: Update Rojo config
```json
{
  "tree": {
    "ReplicatedStorage": {
      "Engine": { "$path": "src/shared/engine" },
      "Games": {
        "Camping": { "$path": "src/shared/games/camping" },
        "Survival": { "$path": "src/shared/games/survival" }
      }
    },
    "ServerScriptService": {
      "Engine": { "$path": "src/server/engine" },
      "Games": {
        "Camping": { "$path": "src/server/games/camping" },
        "Survival": { "$path": "src/server/games/survival" }
      }
    }
  }
}
```

### Step 5: Test
Engine code remains unchanged - all modifications in `games/survival/`

## File Migration Checklist

### Shared → Shared Engine
- [ ] `combat/CombatSystem.luau`
- [ ] `combat/ProjectilePhysics.luau`
- [ ] `combat/ProjectileLOS.luau`
- [ ] `combat/Stats.luau`
- [ ] `combat/StatsProvider.luau`
- [ ] `visual-effects/AOETelegraph.luau`
- [ ] `visual-effects/HitscanEffects.luau`
- [ ] `visual-effects/CombatFeedback.luau`
- [ ] `core/RemoteEvents.luau`
- [ ] `core/Types.luau`
- [ ] `core/Utils.luau`
- [ ] `player/TargetingSystem.luau`
- [ ] `player/PlayerSettingsManager.luau`

### Shared Config → Server Game Config (SECURITY FIX)
- [ ] `config/GameSettings.luau` → Split to ClientSettings + GameConfig
- [ ] `config/ResourcesConfig.luau` → server game config
- [ ] `config/WeaponsConfig.luau` → Split display + stats
- [ ] `config/ToolsConfig.luau` → Split display + stats
- [ ] `config/EntitiesConfig.luau` → Split display + stats
- [ ] `config/ShopConfig.luau` → server/games/camping/config/Economy.luau
- [ ] `config/SpawnConfig.luau` → server game config
- [ ] `config/DayNightCycleConfig.luau` → server game config
- [ ] `config/BuildingsConfig.luau` → Split display + stats

### Server → Server Engine
- [ ] `DropSystem.luau` → `services/DropService.luau`
- [ ] `InventoryManager.server.luau` → `services/InventoryService.luau`
- [ ] `PlayerStats.luau` → `services/PlayerStatsService.luau`
- [ ] `XPRewardManager.luau` → `services/XPService.luau`
- [ ] `combat/DamageCalculator.luau`
- [ ] `combat/HitscanManager.luau`
- [ ] `combat/ProjectileManager.luau`
- [ ] `combat/AOEZoneManager.luau`
- [ ] `entities/EntityController.luau` → `managers/EntityManager.luau`
- [ ] `entities/EntitySpawner.luau` → merged into EntityManager
- [ ] `AnimationCache.luau` → `utilities/`
- [ ] `AnimationManager.luau` → `utilities/`
- [ ] `HealthBarManager.luau` → `utilities/`
- [ ] `ProfileStore.luau` → `utilities/`

### Server → Server Game Managers
- [ ] `ResourceManager.server.luau` → `games/camping/managers/`
- [ ] `ShopManager.server.luau` → `games/camping/managers/`
- [ ] `SpawnManager.server.luau` → `games/camping/managers/`
- [ ] `ToolManager.server.luau` → `games/camping/managers/`
- [ ] `TownhallManager.server.luau` → `games/camping/managers/`
- [ ] `game-specific/WorkspaceSpawnLoader.luau` → `games/camping/loaders/`

### Client → Client Engine
- [ ] `ui/UIComponent.luau`

### Client → Client Game
- [ ] `ui/*.luau` → `games/camping/ui/`
- [ ] `*Controller.client.luau` → `games/camping/controllers/`
- [ ] `UIConfig.luau` → `games/camping/config/`
- [ ] `UIManager.luau` → `games/camping/config/`

## Benefits Summary

| Benefit | Impact |
|---------|--------|
| **Security** | Sensitive data no longer exposed to client (exploit prevention) |
| **Multi-Game Support** | Can build new games by editing data files only |
| **Engine Reusability** | Engine improvements benefit all games automatically |
| **Clear Boundaries** | Obvious separation between engine and game code |
| **Rapid Development** | New games created in days, not months |
| **Maintainability** | Clear file organization makes debugging easier |
| **Team Collaboration** | Designers edit game data, engineers edit engine |

## Key Differences from REFACTORING_0 & REFACTORING_1

| Aspect | REFACTORING_0 | REFACTORING_1 | REFACTORING_2 (This) |
|--------|---------------|---------------|----------------------|
| **Scope** | Data layer refactoring | Full framework redesign | Pragmatic folder reorganization |
| **Security** | Not addressed | Comprehensive | **Critical security fixes first** |
| **Engine/Game** | Not separated | Fully separated with modules | **Pragmatically separated** |
| **Migration** | Incremental | Requires rewrite | **Refactor existing code** |
| **Timeline** | 6 phases | 6 weeks | 4 weeks |
| **Risk** | Medium | High (big rewrite) | **Low (incremental)** |

## Next Steps

1. ✅ Review this plan with team
2. ✅ Get approval for security fixes
3. Begin Phase 1: Create folder structure
4. **PRIORITY: Execute Phase 2 (security fix) immediately**
5. Continue with remaining phases
6. Test thoroughly at each phase
7. Document migration issues/learnings

## Questions & Answers

### Q: Why not do full REFACTORING_1 approach?
**A**: REFACTORING_1 is ideal long-term but requires rewriting significant code. REFACTORING_2 achieves 80% of benefits with 20% of effort by refactoring existing code instead of rewriting.

### Q: Can we upgrade to REFACTORING_1 later?
**A**: Yes! REFACTORING_2 sets up the folder structure and security boundaries. Once stable, can incrementally add module system from REFACTORING_1.

### Q: What's the most critical part?
**A**: **Phase 2 (Security Fix)**. Current code exposes gameplay rules to client, allowing exploits. This must be fixed immediately.

### Q: How do we test during migration?
**A**: After each phase, run full game test. Keep backward compatibility adapters until fully migrated.

### Q: What if we find issues with engine code during migration?
**A**: If it's a bug fix, fix in engine. If it's camping-specific logic, move to game folder.
