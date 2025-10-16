# Refactoring Plan: Item & Entity System Architecture

## Overview

This document outlines a comprehensive refactoring plan to restructure the game's item and entity system following industry best practices for game architecture. The goal is to create a scalable, maintainable, and designer-friendly codebase.

## Current Problems

### 1. **No Unified Item System**
- Inventory only tracks 4 resource types (Wood, Stone, Metal, Gem)
- Cannot track weapons, tools, armor, or consumables in inventory
- Drop items (SmallMeat, BigMeat, RottenMeat) have no configuration
- No way to know what category an item belongs to

### 2. **Scattered Configuration**
- Item data spread across multiple configs:
  - `ResourcesConfig.luau` - Resource types
  - `WeaponsConfig.luau` - Weapon stats
  - `ToolsConfig.luau` - Tool properties
  - `EntitiesConfig.luau` - Drop definitions
  - `ShopConfig.luau` - Shop items
- No single source of truth for "what items exist"

### 3. **Tight Coupling**
- `DropSystem` searches folders by name (Models/Items/, Models/Weapons/)
- No type-safe references between configs
- Logic mixed with data definitions

### 4. **Type System Issues**
```lua
-- Current: Limited to only resources
export type PlayerInventory = {
    [ResourcesConfig.ResourceType]: number
}

-- Problem: Can't store weapons, tools, consumables, etc.
```

## Proposed Solution: Clean Architecture

### Core Principles

1. **Data-Driven Design**: Separate data from logic
2. **Single Responsibility**: Each file has one clear purpose
3. **Dependency Direction**: Data ← Systems ← Services (one direction only)
4. **Type Safety**: Central registries with proper type definitions
5. **Designer-Friendly**: Game designers edit data files, not logic

## New File Structure

```
src/
├── shared/
│   ├── data/                    # Pure data definitions (WHAT things ARE)
│   │   ├── items/
│   │   │   ├── Items.luau              # Master item registry
│   │   │   ├── Weapons.luau            # Weapon specs (damage, range, type)
│   │   │   ├── Armor.luau              # Armor specs (defense, slots)
│   │   │   ├── Consumables.luau        # Consumable effects
│   │   │   ├── Tools.luau              # Tool specs (mining speed, etc)
│   │   │   └── Resources.luau          # Resource properties
│   │   │
│   │   ├── entities/
│   │   │   ├── Entities.luau           # Master entity registry
│   │   │   ├── Creatures.luau          # Hostile mobs (zombies, etc)
│   │   │   ├── Wildlife.luau           # Neutral/passive (wolves, bears)
│   │   │   ├── NPCs.luau               # Friendly NPCs (guards, merchants)
│   │   │   └── Structures.luau         # Buildings, defenses
│   │   │
│   │   ├── abilities/
│   │   │   ├── Abilities.luau          # Skill/spell definitions
│   │   │   └── StatusEffects.luau      # Buffs/debuffs
│   │   │
│   │   └── Types.luau                   # Shared type definitions
│   │
│   ├── systems/                 # Game logic (WHAT things DO)
│   │   ├── combat/
│   │   │   ├── Combat.luau             # Core combat calculations
│   │   │   ├── DamageTypes.luau        # Damage formulas
│   │   │   └── Stats.luau              # Stat system
│   │   │
│   │   ├── inventory/
│   │   │   ├── Inventory.luau          # Inventory logic (shared utils)
│   │   │   └── ItemValidator.luau      # Stackable/droppable checks
│   │   │
│   │   └── drops/
│   │       └── DropResolver.luau       # Drop chance calculations
│   │
│   └── config/                  # Tunable parameters (BALANCE/RULES)
│       ├── GameSettings.luau            # Global game rules
│       ├── Balance.luau                 # Damage/XP multipliers
│       ├── Economy.luau                 # Prices, costs
│       └── Spawning.luau                # Spawn rates/locations
│
├── server/
│   ├── services/                # Server-side game systems
│   │   ├── InventoryService.luau
│   │   ├── CombatService.luau
│   │   ├── DropService.luau
│   │   ├── SpawnService.luau
│   │   ├── ResourceService.luau
│   │   └── ShopService.luau
│   │
│   ├── managers/                # State management
│   │   ├── PlayerDataManager.luau
│   │   ├── EntityManager.luau
│   │   └── WorldManager.luau
│   │
│   └── init.server.luau
│
└── client/
    ├── controllers/             # Client-side logic
    │   ├── InventoryController.luau
    │   ├── CombatController.luau
    │   └── UIController.luau
    │
    ├── ui/                      # UI components
    │   ├── InventoryUI.luau
    │   ├── ShopUI.luau
    │   └── HUD.luau
    │
    └── init.client.luau
```

## Detailed Layer Explanations

### 1. Data Layer (`shared/data/`)

**Purpose**: Pure data definitions - no logic, just properties

**Example**: `data/items/Items.luau` (Master Registry)
```lua
--!strict
local Items = {}

export type ItemType = "Resource" | "Consumable" | "Weapon" | "Tool" | "Material" | "Building" | "Armor"

export type ItemData = {
    id: string,
    name: string,
    type: ItemType,
    description: string?,

    -- Inventory properties
    stackable: boolean,
    maxStack: number?,

    -- World properties
    droppable: boolean,
    dropModel: string?,  -- Path relative to ReplicatedStorage.Models

    -- References to type-specific data
    weaponData: string?,      -- → data/items/Weapons.luau
    armorData: string?,       -- → data/items/Armor.luau
    consumableData: string?,  -- → data/items/Consumables.luau
    toolData: string?,        -- → data/items/Tools.luau
}

Items.Database = {
    -- Resources
    Wood = {
        id = "Wood",
        name = "Wood",
        type = "Resource",
        description = "Basic building material from trees",
        stackable = true,
        maxStack = 999,
        droppable = true,
        dropModel = "Items/Wood",
    },

    Stone = {
        id = "Stone",
        name = "Stone",
        type = "Resource",
        description = "Durable material for construction",
        stackable = true,
        maxStack = 999,
        droppable = true,
        dropModel = "Items/Stone",
    },

    Metal = {
        id = "Metal",
        name = "Metal Ore",
        type = "Resource",
        description = "Raw metal for crafting",
        stackable = true,
        maxStack = 999,
        droppable = true,
        dropModel = "Items/Metal",
    },

    Gem = {
        id = "Gem",
        name = "Gem",
        type = "Resource",
        description = "Precious gemstone",
        stackable = true,
        maxStack = 999,
        droppable = true,
        dropModel = "Items/Gem",
    },

    -- Consumables
    SmallMeat = {
        id = "SmallMeat",
        name = "Small Meat",
        type = "Consumable",
        description = "Restores 25 health",
        stackable = true,
        maxStack = 20,
        droppable = true,
        dropModel = "Items/SmallMeat",
        consumableData = "SmallMeat",  -- → data/items/Consumables.luau
    },

    BigMeat = {
        id = "BigMeat",
        name = "Big Meat",
        type = "Consumable",
        description = "Restores 50 health",
        stackable = true,
        maxStack = 20,
        droppable = true,
        dropModel = "Items/BigMeat",
        consumableData = "BigMeat",
    },

    RottenMeat = {
        id = "RottenMeat",
        name = "Rotten Meat",
        type = "Consumable",
        description = "Spoiled meat, might make you sick",
        stackable = true,
        maxStack = 20,
        droppable = true,
        dropModel = "Items/RottenMeat",
        consumableData = "RottenMeat",
    },

    -- Tools (inventory items that reference tools)
    BasicAxe = {
        id = "BasicAxe",
        name = "Basic Axe",
        type = "Tool",
        description = "Chop trees and defend yourself",
        stackable = false,
        droppable = true,
        dropModel = "Items/BasicAxe",
        toolData = "BasicAxe",      -- → data/items/Tools.luau
        weaponData = "Axe",         -- → data/items/Weapons.luau
    },

    SteelAxe = {
        id = "SteelAxe",
        name = "Steel Axe",
        type = "Tool",
        description = "Improved axe for faster gathering",
        stackable = false,
        droppable = true,
        dropModel = "Items/SteelAxe",
        toolData = "SteelAxe",
        weaponData = "Axe",
    },

    BasicPickaxe = {
        id = "BasicPickaxe",
        name = "Basic Pickaxe",
        type = "Tool",
        description = "Mine stone and ore",
        stackable = false,
        droppable = true,
        dropModel = "Items/BasicPickaxe",
        toolData = "BasicPickaxe",
        weaponData = "Pickaxe",
    },

    -- Weapons (standalone combat items)
    Bow = {
        id = "Bow",
        name = "Bow",
        type = "Weapon",
        description = "Ranged weapon for hunting",
        stackable = false,
        droppable = true,
        dropModel = "Items/Bow",
        weaponData = "Bow",  -- → data/items/Weapons.luau
    },

    -- Buildings
    WoodenWall = {
        id = "WoodenWall",
        name = "Wooden Wall",
        type = "Building",
        description = "A sturdy wooden wall for defense",
        stackable = true,
        maxStack = 50,
        droppable = false,  -- Buildings aren't dropped
        dropModel = nil,
    },
}

return Items
```

**Example**: `data/items/Weapons.luau`
```lua
--!strict

export type WeaponSpec = {
    damage: number,
    range: number,
    attackSpeed: number,
    damageType: "Physical" | "Magical" | "Fire" | "Ice",
    cooldown: number?,
    castDuration: number?,
}

local Weapons = {
    Axe = {
        damage = 20,
        range = 8,
        attackSpeed = 1.0,
        damageType = "Physical",
        cooldown = 0.5,
        castDuration = 0.4,
    },

    Pickaxe = {
        damage = 15,
        range = 10,
        attackSpeed = 1.0,
        damageType = "Physical",
        cooldown = 0.5,
        castDuration = 0.3,
    },

    Bow = {
        damage = 30,
        range = 100,
        attackSpeed = 0.8,
        damageType = "Physical",
        cooldown = 0.25,
        castDuration = 0.25,
    },
}

return Weapons
```

**Example**: `data/items/Consumables.luau`
```lua
--!strict

export type ConsumableEffect = {
    type: "heal" | "buff" | "debuff",
    value: number,
    duration: number?,
    stat: string?,
}

export type ConsumableSpec = {
    effects: {ConsumableEffect},
    cooldown: number?,
    soundEffect: string?,
}

local Consumables = {
    SmallMeat = {
        effects = {
            {type = "heal", value = 25}
        },
        cooldown = 1.0,
        soundEffect = "Eating",
    },

    BigMeat = {
        effects = {
            {type = "heal", value = 50}
        },
        cooldown = 1.0,
        soundEffect = "Eating",
    },

    RottenMeat = {
        effects = {
            {type = "heal", value = 5},
            {type = "debuff", value = -2, duration = 10, stat = "stamina"}
        },
        cooldown = 1.0,
        soundEffect = "Eating",
    },
}

return Consumables
```

**Example**: `data/items/Tools.luau`
```lua
--!strict

export type ToolCategory = "Axe" | "Pickaxe"

export type ToolSpec = {
    category: ToolCategory,
    miningSpeed: number,  -- Multiplier for resource gathering
    swingCooldown: number,
    durability: number?,
}

local Tools = {
    BasicAxe = {
        category = "Axe",
        miningSpeed = 1.0,  -- Base speed
        swingCooldown = 0.2,
    },

    SteelAxe = {
        category = "Axe",
        miningSpeed = 1.4,  -- 40% faster
        swingCooldown = 0.2,
    },

    BasicPickaxe = {
        category = "Pickaxe",
        miningSpeed = 1.0,
        swingCooldown = 0.5,
    },
}

return Tools
```

**Example**: `data/items/Armor.luau`
```lua
--!strict

export type ArmorSlot = "Head" | "Chest" | "Legs" | "Feet"

export type ArmorSpec = {
    slot: ArmorSlot,
    defense: number,
    durability: number?,
    statBonuses: {[string]: number}?,
}

local Armor = {
    LeatherChestplate = {
        slot = "Chest",
        defense = 10,
        durability = 100,
        statBonuses = {stamina = 2},
    },

    IronHelmet = {
        slot = "Head",
        defense = 15,
        durability = 150,
        statBonuses = {stamina = 1},
    },
}

return Armor
```

### 2. Systems Layer (`shared/systems/`)

**Purpose**: Pure functions that operate on data - no state, no side effects

**Example**: `systems/drops/DropResolver.luau`
```lua
--!strict

-- This is the refactored version of current DropSystem.resolveDrops()
-- Pure function: same input = same output (deterministic with RNG seed)

local DropResolver = {}

export type DropItemConfig = {
    chance: number,
    min: number,
    max: number,
    chanceModifiers: { [string]: number }?,
    maxChance: number?,
    excludeIf: { string }?,
    requireIf: { string }?,
}

export type DropConfig = {
    [string]: DropItemConfig
}

export type ResolvedDrop = {
    itemId: string,
    quantity: number,
}

export type StatsTable = {
    [string]: number
}

-- Pure calculation functions
local function calculateDropChance(
    baseChance: number,
    statsTable: StatsTable?,
    modifiers: { [string]: number }?,
    maxChance: number?
): number
    local finalChance = baseChance

    if modifiers and statsTable then
        for statName, multiplier in modifiers do
            local statValue = statsTable[statName] or 0
            finalChance = finalChance + (statValue * multiplier)
        end
    end

    if maxChance then
        finalChance = math.min(finalChance, maxChance)
    end

    return math.clamp(finalChance, 0, 1)
end

function DropResolver.resolve(dropConfig: DropConfig, statsTable: StatsTable?): { ResolvedDrop }
    local resolvedDrops: { ResolvedDrop } = {}
    local droppedItems: { [string]: boolean } = {}

    for itemId, itemConfig in dropConfig do
        -- Skip if excluded
        if itemConfig.excludeIf then
            local shouldExclude = false
            for _, excludedId in itemConfig.excludeIf do
                if droppedItems[excludedId] then
                    shouldExclude = true
                    break
                end
            end
            if shouldExclude then
                continue
            end
        end

        -- Skip if requirements not met
        if itemConfig.requireIf then
            local meetsRequirements = true
            for _, requiredId in itemConfig.requireIf do
                if not droppedItems[requiredId] then
                    meetsRequirements = false
                    break
                end
            end
            if not meetsRequirements then
                continue
            end
        end

        -- Calculate drop chance
        local finalChance = calculateDropChance(
            itemConfig.chance,
            statsTable,
            itemConfig.chanceModifiers,
            itemConfig.maxChance
        )

        -- Roll for drop
        if math.random() <= finalChance then
            local quantity = math.random(itemConfig.min, itemConfig.max)
            table.insert(resolvedDrops, {
                itemId = itemId,
                quantity = quantity,
            })
            droppedItems[itemId] = true
        end
    end

    return resolvedDrops
end

return DropResolver
```

**Example**: `systems/inventory/ItemValidator.luau`
```lua
--!strict

local Items = require(script.Parent.Parent.Parent.data.items.Items)

local ItemValidator = {}

function ItemValidator.isStackable(itemId: string): boolean
    local itemData = Items.Database[itemId]
    return itemData and itemData.stackable or false
end

function ItemValidator.getMaxStack(itemId: string): number?
    local itemData = Items.Database[itemId]
    return itemData and itemData.maxStack
end

function ItemValidator.isDroppable(itemId: string): boolean
    local itemData = Items.Database[itemId]
    return itemData and itemData.droppable or false
end

function ItemValidator.canStack(itemId: string, currentStack: number, addAmount: number): boolean
    if not ItemValidator.isStackable(itemId) then
        return false
    end

    local maxStack = ItemValidator.getMaxStack(itemId)
    if not maxStack then
        return true  -- No stack limit
    end

    return currentStack + addAmount <= maxStack
end

return ItemValidator
```

### 3. Services Layer (`server/services/`)

**Purpose**: Stateful systems that manage game state and coordinate between systems

**Example**: `server/services/DropService.luau`
```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Items = require(ReplicatedStorage.Shared.data.items.Items)
local DropResolver = require(ReplicatedStorage.Shared.systems.drops.DropResolver)
local GameSettings = require(ReplicatedStorage.Shared.config.GameSettings)

local DropService = {}

-- Get item model from ReplicatedStorage using Items database
local function getItemModel(itemId: string): Model?
    local itemData = Items.Database[itemId]
    if not itemData or not itemData.dropModel then
        warn(`[DropService] No drop model for item: {itemId}`)
        return nil
    end

    local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
    if not modelsFolder then
        warn("[DropService] Models folder not found")
        return nil
    end

    local model = modelsFolder:FindFirstChild(itemData.dropModel)
    if not model or not model:IsA("Model") then
        warn(`[DropService] Model not found at: {itemData.dropModel}`)
        return nil
    end

    return model
end

-- Spawn drops in the world (stateful operation)
function DropService.spawnDrops(drops: {DropResolver.ResolvedDrop}, position: Vector3, scatterRadius: number?)
    local radius = scatterRadius or GameSettings.drops.scatterRadius or 5
    local despawnTime = GameSettings.drops.despawnTime or 300

    local droppedItemsFolder = workspace:FindFirstChild("DroppedItems")
    if not droppedItemsFolder then
        droppedItemsFolder = Instance.new("Folder")
        droppedItemsFolder.Name = "DroppedItems"
        droppedItemsFolder.Parent = workspace
    end

    for _, drop in drops do
        local itemTemplate = getItemModel(drop.itemId)
        if not itemTemplate then
            continue
        end

        -- Spawn each quantity individually
        for i = 1, drop.quantity do
            local itemModel = itemTemplate:Clone()

            -- Set collision group
            for _, descendant in itemModel:GetDescendants() do
                if descendant:IsA("BasePart") then
                    descendant.CollisionGroup = "Items"
                end
            end

            -- Calculate scatter position
            local angle = math.random() * math.pi * 2
            local distance = math.random() * radius
            local offset = Vector3.new(
                math.cos(angle) * distance,
                3,
                math.sin(angle) * distance
            )
            local spawnPosition = position + offset

            -- Position the model
            if itemModel.PrimaryPart then
                itemModel:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
            else
                itemModel:MoveTo(spawnPosition)
            end

            -- Add metadata
            itemModel:SetAttribute("IsDroppedItem", true)
            itemModel:SetAttribute("ItemId", drop.itemId)
            itemModel:SetAttribute("SpawnTime", workspace:GetServerTimeNow())
            itemModel:SetAttribute("DespawnTime", despawnTime)

            itemModel.Parent = droppedItemsFolder

            -- Schedule despawn
            task.delay(despawnTime, function()
                if itemModel and itemModel.Parent then
                    itemModel:Destroy()
                end
            end)
        end
    end
end

-- High-level API: Resolve and spawn drops
function DropService.processDrops(
    dropConfig: DropResolver.DropConfig,
    statsTable: DropResolver.StatsTable?,
    position: Vector3,
    scatterRadius: number?
): {DropResolver.ResolvedDrop}
    -- Use system to resolve drops (pure function)
    local drops = DropResolver.resolve(dropConfig, statsTable)

    -- Use service to spawn drops (stateful operation)
    DropService.spawnDrops(drops, position, scatterRadius)

    return drops
end

return DropService
```

**Example**: `server/services/InventoryService.luau`
```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Items = require(ReplicatedStorage.Shared.data.items.Items)
local ItemValidator = require(ReplicatedStorage.Shared.systems.inventory.ItemValidator)
local RemoteEvents = require(ReplicatedStorage.Shared.core.RemoteEvents)
local GameSettings = require(ReplicatedStorage.Shared.config.GameSettings)

local InventoryService = {}

-- Player inventory storage
local playerInventories: {[Player]: {[string]: number}} = {}

-- Initialize empty inventory
local function createEmptyInventory(): {[string]: number}
    return {}
end

-- Get total item count
local function getInventoryCount(inventory: {[string]: number}): number
    local count = 0
    for _, amount in inventory do
        count += amount
    end
    return count
end

-- Add item to inventory
function InventoryService.addItem(player: Player, itemId: string, amount: number): boolean
    local inventory = playerInventories[player]
    if not inventory then
        return false
    end

    -- Validate item exists
    local itemData = Items.Database[itemId]
    if not itemData then
        warn(`[InventoryService] Unknown item: {itemId}`)
        return false
    end

    -- Check if stackable
    if not ItemValidator.isStackable(itemId) and amount > 1 then
        warn(`[InventoryService] Item {itemId} is not stackable`)
        return false
    end

    -- Check stack limit
    local currentAmount = inventory[itemId] or 0
    if not ItemValidator.canStack(itemId, currentAmount, amount) then
        warn(`[InventoryService] Stack limit exceeded for {itemId}`)
        return false
    end

    -- Check inventory space
    local currentCount = getInventoryCount(inventory)
    local maxSize = GameSettings.player.inventorySize or 100
    if currentCount + amount > maxSize then
        warn(`[InventoryService] Inventory full for {player.Name}`)
        return false
    end

    -- Add to inventory
    inventory[itemId] = currentAmount + amount
    RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)

    return true
end

-- Remove item from inventory
function InventoryService.removeItem(player: Player, itemId: string, amount: number): boolean
    local inventory = playerInventories[player]
    if not inventory then
        return false
    end

    local currentAmount = inventory[itemId] or 0
    if currentAmount < amount then
        return false
    end

    inventory[itemId] = currentAmount - amount
    if inventory[itemId] == 0 then
        inventory[itemId] = nil  -- Clean up empty slots
    end

    RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)
    return true
end

-- Get inventory
function InventoryService.getInventory(player: Player): {[string]: number}?
    return playerInventories[player]
end

-- Player lifecycle
local function onPlayerAdded(player: Player)
    playerInventories[player] = createEmptyInventory()
    RemoteEvents.Events.UpdateInventory:FireClient(player, playerInventories[player])
    print(`[InventoryService] Initialized inventory for {player.Name}`)
end

local function onPlayerRemoving(player: Player)
    playerInventories[player] = nil
    print(`[InventoryService] Cleaned up inventory for {player.Name}`)
end

-- Initialize
function InventoryService.initialize()
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    for _, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end

    print("[InventoryService] Initialized")
end

return InventoryService
```

### 4. Config Layer (`shared/config/`)

**Purpose**: Tunable parameters for game balance and global settings

**Example**: `config/GameSettings.luau`
```lua
--!strict

local GameSettings = {
    player = {
        inventorySize = 100,
        startingHealth = 100,
        startingStamina = 100,
    },

    drops = {
        mode = "scatter",  -- "scatter" | "container"
        scatterRadius = 5,
        despawnTime = 300,
    },

    combat = {
        damageTargetOnly = true,
        friendlyFire = false,
        pvpEnabled = false,
    },
}

return GameSettings
```

**Example**: `config/Balance.luau`
```lua
--!strict

local Balance = {
    -- Global multipliers
    damageMultiplier = 1.0,
    xpMultiplier = 1.0,
    dropRateMultiplier = 1.0,

    -- Stat scaling
    healthPerStamina = 10,
    damagePerStrength = 2,
    critChancePerLuck = 0.01,

    -- Economy
    sellValueMultiplier = 0.5,  -- Items sell for 50% of buy price
    shopPriceMultiplier = 1.0,
}

return Balance
```

**Example**: `config/Economy.luau`
```lua
--!strict

local Economy = {
    -- Item prices (for shop)
    itemPrices = {
        Wood = 10,
        Stone = 15,
        Metal = 50,
        Gem = 100,

        BasicAxe = 100,
        SteelAxe = 500,
        BasicPickaxe = 100,

        SmallMeat = 20,
        BigMeat = 50,
    },

    -- Sell values (what players get when selling)
    itemSellValues = {
        Wood = 5,
        Stone = 7,
        Metal = 25,
        Gem = 50,

        SmallMeat = 10,
        BigMeat = 25,
    },
}

return Economy
```

## Migration Path

### Phase 1: Create Data Layer
1. Create `src/shared/data/` folder structure
2. Create `data/items/Items.luau` - Master item registry
3. Create `data/items/Weapons.luau` - Migrate from WeaponsConfig
4. Create `data/items/Tools.luau` - Migrate from ToolsConfig
5. Create `data/items/Consumables.luau` - New file for food/potions
6. Create `data/items/Resources.luau` - Resource item properties

### Phase 2: Create Systems Layer
1. Create `src/shared/systems/` folder structure
2. Create `systems/drops/DropResolver.luau` - Extract pure functions from DropSystem
3. Create `systems/inventory/ItemValidator.luau` - Extraction validation logic
4. Move `src/shared/combat/` to `src/shared/systems/combat/`

### Phase 3: Refactor Services
1. Rename `server/DropSystem.luau` → `server/services/DropService.luau`
2. Rename `server/InventoryManager.server.luau` → `server/services/InventoryService.luau`
3. Update services to use data layer and systems layer
4. Remove direct file system searches, use Items database instead

### Phase 4: Update Types
1. Update `shared/core/Types.luau`:
   - Change `PlayerInventory` from ResourceType-based to itemId-based
   - Add new types for item system
2. Re-export types from data layer

### Phase 5: Update Configs
1. Simplify `config/ResourcesConfig.luau` - Keep only node spawning logic
2. Simplify `config/EntitiesConfig.luau` - Reference Items database for drops
3. Simplify `config/ShopConfig.luau` - Reference Items database for shop items
4. Create `config/Balance.luau` - Extract tunable parameters
5. Create `config/Economy.luau` - Extract prices

### Phase 6: Update Client
1. Update inventory UI to use Items database
2. Update shop UI to use Items database
3. Update tooltips/info displays

## Benefits Summary

| Benefit | How It Helps |
|---------|-------------|
| **Scalability** | Easy to add new items/entities without touching game logic |
| **Maintainability** | Clear separation makes debugging and updates easier |
| **Type Safety** | Centralized registries enable better type checking |
| **Testability** | Pure functions in systems layer are easy to unit test |
| **Designer-Friendly** | Non-programmers can edit data files safely |
| **Performance** | No more folder searching, direct lookups via database |
| **Flexibility** | Easy to add new item types or systems |
| **Collaboration** | Clear structure makes team development easier |

## Key Architectural Principles

### 1. Separation of Concerns
- **Data** (what things are) is separate from **Systems** (what things do)
- **Systems** (pure logic) is separate from **Services** (stateful operations)
- **Config** (tunable parameters) is separate from **Data** (definitions)

### 2. Dependency Direction
```
Services
   ↓
Systems
   ↓
Data
   ↓
Types
```
Dependencies flow in one direction. Data never depends on systems, systems never depend on services.

### 3. Single Source of Truth
- `Items.Database` is the ONLY place that defines what items exist
- All other systems reference this database
- No duplicate definitions scattered across files

### 4. Type-Safe References
Instead of string-based searches:
```lua
-- OLD (brittle)
local model = workspace:FindFirstChild("Items"):FindFirstChild(itemName)

-- NEW (type-safe)
local itemData = Items.Database[itemId]  -- Type-checked
local modelPath = itemData.dropModel     -- Known to exist
```

### 5. Pure Functions Where Possible
Systems layer uses pure functions (same input = same output) making them:
- Easy to test
- Easy to reason about
- Cacheable/memoizable
- Parallelizable

### 6. Location-Based vs. ReplicatedStorage
All data and systems are in ReplicatedStorage because:
- Client needs item info for UI
- Client needs for local validation (better UX)
- Server still validates all operations
- No security risk (exploiters can't force-add items by knowing configs)

For truly sensitive data (spawn weights, exact economy values), split into:
- `shared/data/` - Public data (client-visible)
- `server/data/` - Private data (server-only)

## Comparison: Current vs. Clean Architecture

### Current Structure
```
src/shared/config/
├── WeaponsConfig.luau      # Weapon stats
├── ToolsConfig.luau        # Tool properties
├── ResourcesConfig.luau    # Resource types
├── EntitiesConfig.luau     # Entity definitions + drops
└── ShopConfig.luau         # Shop items

src/server/
├── DropSystem.luau         # Drop logic + spawning (mixed)
├── InventoryManager.server.luau  # Inventory (ResourceType only)
└── ...

Problems:
❌ No central item registry
❌ Can't track weapons/tools in inventory
❌ Drop items (SmallMeat) have no config
❌ Logic mixed with data
❌ Folder-based searches (brittle)
```

### Clean Architecture
```
src/shared/
├── data/                   # Pure data definitions
│   ├── items/
│   │   ├── Items.luau      # Master registry (source of truth)
│   │   ├── Weapons.luau    # Weapon specs
│   │   ├── Tools.luau      # Tool specs
│   │   ├── Consumables.luau # Consumable specs
│   │   └── Resources.luau  # Resource specs
│   └── entities/
│       └── ...
├── systems/                # Pure logic (no state)
│   ├── drops/
│   │   └── DropResolver.luau  # Drop calculations
│   └── inventory/
│       └── ItemValidator.luau # Validation logic
└── config/                 # Tunable parameters
    ├── GameSettings.luau
    ├── Balance.luau
    └── Economy.luau

src/server/
├── services/               # Stateful operations
│   ├── DropService.luau    # Drop spawning
│   ├── InventoryService.luau # Inventory management
│   └── ...
└── managers/               # State management
    └── ...

Benefits:
✅ Single source of truth (Items.Database)
✅ All item types supported in inventory
✅ Every item has config
✅ Clear separation of concerns
✅ Type-safe lookups (no searches)
✅ Easy to test
✅ Easy to extend
```

## Example Usage After Refactoring

### Adding a New Item
```lua
-- 1. Add to Items.Database (data/items/Items.luau)
BreadLoaf = {
    id = "BreadLoaf",
    name = "Bread Loaf",
    type = "Consumable",
    description = "Restores 35 health",
    stackable = true,
    maxStack = 20,
    droppable = true,
    dropModel = "Items/BreadLoaf",
    consumableData = "BreadLoaf",
},

-- 2. Add consumable specs (data/items/Consumables.luau)
BreadLoaf = {
    effects = {
        {type = "heal", value = 35}
    },
    cooldown = 1.5,
    soundEffect = "Eating",
},

-- 3. Done! Item now works with:
-- - Inventory system (automatic)
-- - Drop system (automatic)
-- - Shop system (automatic)
-- - UI systems (automatic)
```

### Using Items in Code
```lua
-- Get item info
local itemData = Items.Database["Wood"]
print(itemData.name)  -- "Wood"
print(itemData.type)  -- "Resource"

-- Check if stackable
local canStack = ItemValidator.isStackable("Wood")  -- true

-- Add to inventory
InventoryService.addItem(player, "Wood", 50)

-- Process drops
local drops = DropResolver.resolve({
    ["SmallMeat"] = {chance = 1.0, min = 1, max = 1}
}, killerStats)

DropService.spawnDrops(drops, position)
```

## Questions & Answers

### Q: Should ItemsConfig be in ReplicatedStorage or ServerScriptService?
**A**: ReplicatedStorage (shared). The client needs item data for UI, tooltips, and local validation. The server still validates all operations, so there's no security risk.

### Q: Why separate Items.luau from Weapons.luau/Tools.luau?
**A**:
- `Items.luau` = Master registry (what items exist)
- `Weapons.luau` = Weapon-specific specs (how weapons work)
- This prevents duplication and keeps files focused
- A sword is an "item" (can be in inventory, dropped, etc.) AND has "weapon properties" (damage, range)

### Q: Why have both Systems and Services?
**A**:
- **Systems** = Pure functions (easy to test, no state)
- **Services** = Stateful operations (manage game state)
- Example: `DropResolver.resolve()` (system) calculates drops, `DropService.spawnDrops()` (service) creates models in world

### Q: Do we need to migrate everything at once?
**A**: No! Migrate in phases:
1. Phase 1: Create data layer, keep old code working
2. Phase 2: Create systems layer, gradually refactor
3. Phase 3: Update services one at a time
4. Phase 4: Remove old code once fully migrated

### Q: What about backward compatibility?
**A**: Create adapter/facade during migration:
```lua
-- Old code uses:
local item = ResourcesConfig.Types.Wood

-- Adapter provides:
ResourcesConfig.Types = {
    Wood = Items.Database.Wood.id,
    Stone = Items.Database.Stone.id,
    -- ...
}

-- Eventually remove adapter once all code migrated
```

## Next Steps

1. Review this document with team
2. Get alignment on architecture
3. Create Phase 1 tasks
4. Begin migration with data layer
5. Incrementally refactor systems
6. Remove old code when fully migrated

## References

- Current codebase structure
- Industry best practices (Unity, Unreal, Godot)
- Clean Architecture principles
- Data-Driven Design patterns
- ECS (Entity Component System) inspiration
