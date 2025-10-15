# Drop System - Container Mode Implementation Plan

## Overview

This document outlines the implementation plan for **Container Mode** (Mode 2) of the drop system. Container mode allows players to interact with entity corpses or treasure chests via a UI to selectively pick items, rather than having items scatter on the ground.

**Current Status:** Scatter mode (Mode 1) is implemented. Container mode is planned for future implementation.

## Container Mode Behavior

### User Experience Flow

1. **Entity Dies / Chest Spawns**
   - Entity corpse remains in world OR chest spawns
   - Loot is calculated based on killer's stats (or opener's stats)
   - Loot contents are "locked in" and stored on the container

2. **Player Approaches Container**
   - ProximityPrompt appears: "Press E to Loot"
   - Player activates prompt

3. **Loot UI Opens**
   - Shows all available items with quantities
   - Player can:
     - Click individual items to take
     - Use "Take All" button
     - Close UI to leave items

4. **Per-Player Loot Instances**
   - Each player sees their own loot (not shared)
   - Loot is resolved once when container is created
   - Multiple players can loot the same container
   - Each player gets the same items (based on killer's stats)

5. **Container Persistence**
   - Container stays in world for configurable time (5 minutes)
   - Auto-despawns after timeout
   - Can optionally despawn after first player loots (configurable)

## Configuration

### GameSettings.luau

```lua
drops = {
    mode = "container", -- "scatter" or "container"

    -- Scatter mode settings
    scatterRadius = 5,

    -- Container mode settings
    containerDespawnTime = 300,        -- 5 minutes (seconds)
    containerDespawnAfterLoot = false, -- Keep container after looting
    containerMaxDistance = 10,         -- Max distance to interact (studs)

    -- Both modes
    despawnTime = 300, -- Fallback despawn time
}
```

### EntitiesConfig.luau

No changes needed - drop tables remain the same:

```lua
Bear = {
    -- ... other config ...
    drops = {
        ["BigMeat"] = { chance = 1.0, min = 1, max = 3 },
        ["BearPelt"] = { chance = 0.01, min = 1, max = 1 }
    }
}
```

## Architecture

### Data Flow

```
Entity Dies
    ↓
DropSystem.resolveDrops(config, killerStats) → Resolved drops
    ↓
DropSystem.createLootContainer(drops, corpseModel, killerStats)
    ↓
[Store loot data on corpse + Add ProximityPrompt]
    ↓
Player activates prompt
    ↓
Server: Fire RemoteEvent → Client: Show LootUI
    ↓
Client: Player selects items → Server: Give items to player
    ↓
(Optional) Remove container if containerDespawnAfterLoot = true
```

### Container Data Structure

Loot data is stored on the container model using attributes:

```lua
-- Stored as JSON in StringValue or Attribute
containerModel:SetAttribute("IsLootContainer", true)
containerModel:SetAttribute("LootData", HttpService:JSONEncode({
    drops = {
        { itemId = "BigMeat", quantity = 3 },
        { itemId = "BearPelt", quantity = 1 }
    },
    killerUserId = 12345,              -- Who killed the entity
    killerStats = { luck = 50 },       -- Stats used for drop calculation
    createdTime = workspace:GetServerTimeNow(),
    despawnTime = 300,
    lootedPlayers = {}                 -- Track who looted (optional)
}))
```

**Why JSON encode?**
- Roblox attributes support limited types
- JSON allows complex nested tables
- Easy to serialize/deserialize

### Per-Player Loot Tracking

Since each player gets their own loot:

```lua
-- Option A: Track per-player (if limiting to one loot per player)
lootedPlayers = {
    [123456] = true, -- UserId → already looted
    [789012] = true
}

-- Option B: No tracking (unlimited looting)
-- Simply don't track, every player can loot
```

**Recommendation:** Start with Option B (unlimited looting) for simplicity. Add Option A later if needed for game balance.

## Implementation Details

### 1. DropSystem.createLootContainer()

**File:** `src/server/DropSystem.server.luau`

```lua
--[[
    Create loot container on entity corpse or chest
    @param drops - Resolved drops (from resolveDrops)
    @param containerModel - Entity corpse or chest model
    @param statsTable - Killer/opener stats (locked in)
]]
function DropSystem.createLootContainer(
    drops: { ResolvedDrop },
    containerModel: Model,
    statsTable: StatsTable?
)
    local HttpService = game:GetService("HttpService")

    -- Encode loot data
    local lootData = {
        drops = drops,
        killerStats = statsTable,
        createdTime = workspace:GetServerTimeNow(),
        despawnTime = GameConfig.drops.containerDespawnTime or 300,
        lootedPlayers = {} -- Track who looted (optional)
    }

    -- Store on container
    containerModel:SetAttribute("IsLootContainer", true)

    -- Store loot data (use StringValue for complex data)
    local lootDataValue = Instance.new("StringValue")
    lootDataValue.Name = "LootData"
    lootDataValue.Value = HttpService:JSONEncode(lootData)
    lootDataValue.Parent = containerModel

    -- Add ProximityPrompt for interaction
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "LootPrompt"
    prompt.ActionText = "Loot"
    prompt.ObjectText = containerModel.Name
    prompt.MaxActivationDistance = GameConfig.drops.containerMaxDistance or 10
    prompt.RequiresLineOfSight = true
    prompt.Parent = containerModel.PrimaryPart or containerModel:FindFirstChildWhichIsA("BasePart")

    -- Schedule auto-despawn
    task.delay(lootData.despawnTime, function()
        if containerModel and containerModel.Parent then
            containerModel:Destroy()
        end
    end)

    print(`[DropSystem] Created loot container at {containerModel:GetPivot().Position}`)
end
```

### 2. LootContainerManager.server.luau (New)

**File:** `src/server/LootContainerManager.server.luau`

Handles server-side container interactions.

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local LootContainerManager = {}

-- Parse loot data from container
local function getLootData(container: Model)
    local lootDataValue = container:FindFirstChild("LootData")
    if not lootDataValue or not lootDataValue:IsA("StringValue") then
        return nil
    end

    local success, lootData = pcall(function()
        return HttpService:JSONDecode(lootDataValue.Value)
    end)

    if not success then
        warn("[LootContainerManager] Failed to parse loot data")
        return nil
    end

    return lootData
end

-- Check if player has already looted this container
local function hasPlayerLooted(container: Model, player: Player): boolean
    local lootData = getLootData(container)
    if not lootData then
        return false
    end

    -- If tracking looted players
    if lootData.lootedPlayers then
        return lootData.lootedPlayers[tostring(player.UserId)] == true
    end

    return false
end

-- Mark player as having looted this container
local function markPlayerAsLooted(container: Model, player: Player)
    local lootDataValue = container:FindFirstChild("LootData")
    if not lootDataValue then
        return
    end

    local lootData = getLootData(container)
    if not lootData then
        return
    end

    lootData.lootedPlayers[tostring(player.UserId)] = true
    lootDataValue.Value = HttpService:JSONEncode(lootData)
end

-- Handle ProximityPrompt activation
function LootContainerManager.onPromptTriggered(prompt: ProximityPrompt, player: Player)
    local container = prompt.Parent.Parent
    if not container or not container:GetAttribute("IsLootContainer") then
        return
    end

    -- Check if already looted (optional)
    if hasPlayerLooted(container, player) then
        warn(`[LootContainerManager] {player.Name} already looted this container`)
        return
    end

    -- Get loot data
    local lootData = getLootData(container)
    if not lootData then
        warn("[LootContainerManager] Invalid loot data")
        return
    end

    -- Send loot data to client to show UI
    RemoteEvents.Events.OpenLootUI:FireClient(player, {
        containerId = container:GetAttribute("ContainerId") or tostring(container),
        drops = lootData.drops
    })

    print(`[LootContainerManager] Opened loot UI for {player.Name}`)
end

-- Handle player taking items from container
function LootContainerManager.onTakeItems(player: Player, containerId: string, itemIds: {string})
    -- Find container in workspace
    local container = findContainerById(containerId) -- TODO: Implement lookup
    if not container then
        warn("[LootContainerManager] Container not found")
        return
    end

    -- Verify loot is still valid
    local lootData = getLootData(container)
    if not lootData then
        return
    end

    -- Give items to player (TODO: integrate with inventory system)
    for _, itemId in itemIds do
        -- Find item in drops
        for _, drop in lootData.drops do
            if drop.itemId == itemId then
                print(`[LootContainerManager] Giving {player.Name} {drop.quantity}x {itemId}`)
                -- TODO: InventoryManager.AddItem(player, itemId, drop.quantity)
                break
            end
        end
    end

    -- Mark as looted (optional)
    markPlayerAsLooted(container, player)

    -- Despawn container if configured
    local GameConfig = require(ReplicatedStorage.Shared.config)
    if GameConfig.drops.containerDespawnAfterLoot then
        container:Destroy()
    end
end

-- Initialize manager
function LootContainerManager.initialize()
    -- Connect to all existing ProximityPrompts in workspace
    workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("ProximityPrompt") and descendant.Name == "LootPrompt" then
            descendant.Triggered:Connect(function(player)
                LootContainerManager.onPromptTriggered(descendant, player)
            end)
        end
    end)

    -- Connect RemoteEvents
    RemoteEvents.Events.TakeLootItems.OnServerEvent:Connect(function(player, containerId, itemIds)
        LootContainerManager.onTakeItems(player, containerId, itemIds)
    end)

    print("[LootContainerManager] Initialized")
end

return LootContainerManager
```

### 3. LootContainerUI.client.luau (New)

**File:** `src/client/LootContainerUI.client.luau`

Handles client-side UI for looting containers.

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- TODO: Create UI elements
-- Structure:
-- ScreenGui
--   └── LootFrame (hidden by default)
--       ├── TitleLabel ("Loot Container")
--       ├── ItemsScrollFrame
--       │   └── [Item buttons generated dynamically]
--       ├── TakeAllButton
--       └── CloseButton

local lootFrame -- TODO: Reference to LootFrame
local currentContainerId = nil
local currentDrops = {}

-- Show loot UI with items
local function showLootUI(lootData)
    currentContainerId = lootData.containerId
    currentDrops = lootData.drops

    -- Clear existing item buttons
    -- TODO: Clear ItemsScrollFrame

    -- Create item buttons
    for _, drop in currentDrops do
        -- TODO: Create button for each item
        -- Button shows: [Item Icon] ItemName x Quantity
        -- OnClick: Select/deselect item
    end

    -- Show UI
    lootFrame.Visible = true
end

-- Hide loot UI
local function hideLootUI()
    lootFrame.Visible = false
    currentContainerId = nil
    currentDrops = {}
end

-- Handle "Take Selected" button
local function onTakeSelected()
    local selectedItemIds = {} -- TODO: Get selected items from UI

    if #selectedItemIds == 0 then
        warn("No items selected")
        return
    end

    -- Send to server
    RemoteEvents.Events.TakeLootItems:FireServer(currentContainerId, selectedItemIds)

    -- Close UI
    hideLootUI()
end

-- Handle "Take All" button
local function onTakeAll()
    local allItemIds = {}
    for _, drop in currentDrops do
        table.insert(allItemIds, drop.itemId)
    end

    -- Send to server
    RemoteEvents.Events.TakeLootItems:FireServer(currentContainerId, allItemIds)

    -- Close UI
    hideLootUI()
end

-- Handle "Close" button
local function onClose()
    hideLootUI()
end

-- Initialize
local function initialize()
    -- TODO: Create UI elements or reference existing UI

    -- Connect RemoteEvent
    RemoteEvents.Events.OpenLootUI.OnClientEvent:Connect(showLootUI)

    -- Connect button events
    -- TODO: Connect TakeSelectedButton, TakeAllButton, CloseButton

    print("[LootContainerUI] Initialized")
end

initialize()
```

### 4. RemoteEvents.luau Updates

**File:** `src/shared/RemoteEvents.luau`

Add new RemoteEvents for container mode:

```lua
-- Add to Events table
Events = {
    -- ... existing events ...

    -- Container mode events
    OpenLootUI = createRemoteEvent("OpenLootUI"),     -- Server → Client: Show loot UI
    TakeLootItems = createRemoteEvent("TakeLootItems"), -- Client → Server: Take items
}
```

### 5. EntityController.luau Updates

**File:** `src/shared/EntityController.luau`

Update death handler to NOT remove entity if container mode:

```lua
humanoid.Died:Connect(function()
    playSound(entity, "died")

    if RunService:IsServer() then
        -- Award XP
        XPRewardManager.awardXPForKill(model)

        -- Process drops
        local DropSystemModule = getDropSystem()
        if DropSystemModule and entity.config.drops then
            local killerStats = StatsProvider.getStats(entity.attacker)

            DropSystemModule.processDrops(
                entity.config.drops,
                killerStats,
                entity.humanoidRootPart.Position,
                nil,
                model -- Pass model for container mode
            )
        end
    end

    -- Only remove entity if scatter mode
    local GameConfig = require(script.Parent.config)
    if GameConfig.drops.mode == "scatter" then
        EntityController.removeEntity(model)
    else
        -- Container mode: Keep corpse, just disable AI
        if entity.animationTracks then
            for _, track in entity.animationTracks do
                track:Stop()
            end
        end
        -- Disable humanoid but keep model
        entity.humanoid.Health = 0
        entity.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
end)
```

## UI Design Mockup

```
┌────────────────────────────────────┐
│  Bear Corpse                    [X]│
├────────────────────────────────────┤
│  ┌──────────────────────────────┐ │
│  │ [🥩] BigMeat         x3   [✓]│ │
│  │ [🧥] BearPelt        x1   [ ]│ │
│  │                              │ │
│  └──────────────────────────────┘ │
├────────────────────────────────────┤
│  [Take Selected] [Take All] [Close]│
└────────────────────────────────────┘
```

**UI Elements:**
- **Title:** Container name (e.g., "Bear Corpse", "Golden Chest")
- **Item List:** Scrollable list of items with:
  - Icon/image
  - Item name
  - Quantity
  - Checkbox to select
- **Buttons:**
  - Take Selected: Take only checked items
  - Take All: Take all items at once
  - Close: Close UI without taking anything

## Per-Player Loot Implementation

Since each player gets their own loot:

### Option A: Clone Container per Player (Simple)
- When player activates prompt, clone the container's loot data
- Player takes items from their own "instance"
- Original container remains for other players

### Option B: Virtual Instances (Efficient)
- Single container in world
- Server tracks per-player loot state
- Each player sees same items but takes independently

**Recommendation:** Use Option B for better performance.

```lua
-- Server-side tracking
local playerLootStates = {
    [player.UserId] = {
        containerId = "Bear_123",
        availableItems = {
            { itemId = "BigMeat", quantity = 3 },
            { itemId = "BearPelt", quantity = 1 }
        }
    }
}

-- When player takes items, only modify their state
-- Other players' states remain unchanged
```

## Testing Plan

### Test 1: Basic Container Creation
1. Set `GameConfig.drops.mode = "container"`
2. Kill Bear
3. Verify corpse remains in world
4. Verify ProximityPrompt appears
5. Verify loot data is stored correctly

### Test 2: UI Interaction
1. Activate ProximityPrompt
2. Verify UI opens with correct items
3. Select some items, click "Take Selected"
4. Verify items added to inventory
5. Close UI and reopen
6. Verify remaining items still available

### Test 3: Multi-Player Looting
1. Player A kills Bear
2. Player A loots container
3. Player B approaches same container
4. Verify Player B sees same items
5. Player B takes items
6. Verify both players got items

### Test 4: Auto-Despawn
1. Create container
2. Wait 5 minutes
3. Verify container auto-despawns

### Test 5: Despawn After Loot (Optional)
1. Set `GameConfig.drops.containerDespawnAfterLoot = true`
2. Loot container
3. Verify container despawns immediately

## Performance Considerations

### Container Tracking
- Store containers in dictionary for fast lookup: `containers[containerId] = model`
- Clean up on container destruction
- Limit max containers in world (e.g., 50)

### Per-Player Data
- Don't store per-player data on container model (bloat)
- Use server-side table: `playerLootStates[userId][containerId]`
- Clean up when player leaves or container despawns

### UI Performance
- Reuse UI elements (object pooling)
- Don't create new UI each time
- Update existing UI with new data

## Security Considerations

### Prevent Exploits
1. **Validate container exists** before giving items
2. **Verify loot data hasn't been tampered** (server authoritative)
3. **Check distance** - player must be near container
4. **Rate limiting** - prevent spam looting
5. **Sanity checks** - verify items are actually in loot table

```lua
-- Example validation
function LootContainerManager.onTakeItems(player, containerId, itemIds)
    -- Validate container exists
    local container = findContainerById(containerId)
    if not container then return end

    -- Validate distance
    local distance = (player.Character.HumanoidRootPart.Position - container:GetPivot().Position).Magnitude
    if distance > GameConfig.drops.containerMaxDistance + 5 then -- +5 buffer
        warn(`{player.Name} too far from container`)
        return
    end

    -- Validate items are in loot table
    local lootData = getLootData(container)
    for _, itemId in itemIds do
        local found = false
        for _, drop in lootData.drops do
            if drop.itemId == itemId then
                found = true
                break
            end
        end
        if not found then
            warn(`{player.Name} requested invalid item: {itemId}`)
            return
        end
    end

    -- All checks passed, give items
    -- ...
end
```

## Integration with Existing Systems

### Inventory System
Container mode needs to integrate with inventory system to give items to players:

```lua
-- Current: InventoryManager only supports resources
InventoryManager.AddItem(player, "Wood", 5)

-- Needed: Support for items/weapons
-- Option A: Extend InventoryManager
InventoryManager.AddItem(player, "BigMeat", 3)

-- Option B: Create ItemManager
ItemManager.AddItem(player, "BigMeat", 3)

-- Option C: Unified system
PlayerInventory.AddItem(player, "BigMeat", 3) -- Works for resources AND items
```

**Recommendation:** Extend existing InventoryManager to support all item types (not just resources).

### Treasure Chests
Container mode works perfectly for treasure chests:

```lua
-- ChestManager.luau
function ChestManager.onChestOpened(chest, player)
    local chestConfig = ChestsConfig[chest.Name]
    local playerStats = StatsProvider.getStats(player.Character)

    -- Create loot container on chest
    DropSystem.processDrops(
        chestConfig.drops,
        playerStats,
        chest.Position,
        nil,
        chest -- Pass chest as container
    )
end
```

### Quest Rewards
Can also use container mode for quest reward chests:

```lua
-- QuestManager.luau
function QuestManager.completeQuest(questId, player)
    local questConfig = QuestConfig[questId]

    -- Spawn reward chest near player
    local rewardChest = spawnRewardChest(player.Character.HumanoidRootPart.Position)

    -- Create loot container
    DropSystem.processDrops(
        questConfig.rewardDrops,
        nil, -- No stat modifiers for quest rewards
        rewardChest.Position,
        nil,
        rewardChest
    )
end
```

## Future Enhancements

### Advanced Features
1. **Loot Sharing** - Party/team loot distribution
2. **Loot History** - Track what players looted
3. **Loot Filters** - Auto-loot by rarity/type
4. **Visual Effects** - Rare item glow, particles
5. **Sound Effects** - Loot open/close sounds
6. **Loot Notifications** - "You received BigMeat x3"
7. **Quick Loot** - Hold key to auto-take all
8. **Loot Preview** - Hover to see items before opening

### Balancing Tools
1. **Loot Cooldowns** - Prevent farming same container
2. **Diminishing Returns** - Less loot if looted recently
3. **Loot Tables by Time** - Different loot day vs night
4. **Seasonal Loot** - Event-specific drops

## Implementation Priority

1. **Phase 1: Core Container Logic** (High Priority)
   - DropSystem.createLootContainer()
   - LootContainerManager server setup
   - ProximityPrompt handling
   - Per-player loot tracking

2. **Phase 2: UI Implementation** (High Priority)
   - Create LootContainerUI
   - Item display and selection
   - Take/Cancel buttons
   - RemoteEvents integration

3. **Phase 3: Inventory Integration** (High Priority)
   - Extend InventoryManager for items
   - Connect loot → inventory
   - Validate inventory space

4. **Phase 4: Polish** (Medium Priority)
   - Visual effects
   - Sound effects
   - Notifications
   - Error handling

5. **Phase 5: Advanced Features** (Low Priority)
   - Quick loot
   - Loot filters
   - Loot history
   - Balancing tools

## Related Documentation

- [GUIDE_DROP_SYSTEM.md](./GUIDE_DROP_SYSTEM.md) - Main drop system documentation
- `src/server/DropSystem.server.luau` - Drop system implementation
- `src/shared/config/GameSettings.luau` - Drop configuration
- `src/shared/config/EntitiesConfig.luau` - Entity drop tables

---

**Status:** Planning Complete - Ready for Implementation
**Last Updated:** October 2025
**Version:** 1.0
