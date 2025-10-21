# Drop System Guide

## Overview

The **DropSystem** is a stateless, generic system that handles item drops from any source in the game. It supports stat-influenced drop chances, conditional logic, and flexible spawning mechanics.

## Core Features

- ✅ **Stateless & Reusable** - Pure functions, no internal state
- ✅ **Generic** - Works with entities, chests, resources, quests, etc.
- ✅ **Stat Modifiers** - Player stats (like luck) influence drop chances
- ✅ **Conditional Logic** - Prevent or require certain drops based on other drops
- ✅ **Chance Caps** - Prevent over-stacking of bonuses
- ✅ **Server-Authoritative** - All RNG happens server-side for security

## Architecture

```
Drop Source → DropSystem.resolveDrops(config, stats) → Resolved Drops
                            ↓
            [Calculate Chances + Roll RNG + Apply Conditions]
                            ↓
              DropSystem.spawnDrops(drops, position) → Items in World
```

**Module Location:** `src/server/DropSystem.server.luau`

## Drop Configuration Structure

Drop configurations are defined alongside their owners (entities, chests, resources, etc.) in their respective config files.

### Basic Drop Configuration

```lua
drops = {
	["ItemName"] = {
		chance = 1.0,        -- Base chance (0.0 to 1.0, where 1.0 = 100%)
		min = 1,             -- Minimum quantity
		max = 1,             -- Maximum quantity
	}
}
```

### Advanced Drop Configuration

```lua
drops = {
	-- Guaranteed drop (100% chance)
	["BigMeat"] = {
		chance = 1.0,
		min = 1,
		max = 3,
		chanceModifiers = {
			luck = 0.0, -- No luck modifier for guaranteed drops
		}
	},

	-- Conditional drop (only if BigMeat didn't drop)
	["SmallMeat"] = {
		chance = 0.8, -- 80% base chance
		min = 1,
		max = 2,
		excludeIf = { "BigMeat" }, -- Don't drop if BigMeat already dropped
		chanceModifiers = {
			luck = 0.01, -- +1% per luck point
		}
	},

	-- Rare drop with stat modifiers and cap
	["LegendarySword"] = {
		chance = 0.01, -- 1% base chance
		min = 1,
		max = 1,
		chanceModifiers = {
			luck = 0.001,      -- +0.1% per luck point
			rarity_bonus = 0.005, -- +0.5% per rarity bonus point
		},
		maxChance = 0.15 -- Cap at 15% (prevents infinite stacking)
	},

	-- Conditional requirement (only drops if rare item dropped)
	["LegendarySheath"] = {
		chance = 1.0, -- 100% if condition met
		min = 1,
		max = 1,
		requireIf = { "LegendarySword" }, -- Only drop if LegendarySword dropped
	}
}
```

## Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `chance` | `number` | ✅ | Base drop chance (0.0 to 1.0) |
| `min` | `number` | ✅ | Minimum quantity to drop |
| `max` | `number` | ✅ | Maximum quantity to drop |
| `chanceModifiers` | `table` | ❌ | Stat modifiers `{statName = multiplier}` |
| `maxChance` | `number` | ❌ | Cap on final calculated chance |
| `excludeIf` | `array` | ❌ | Don't drop if these items already dropped |
| `requireIf` | `array` | ❌ | Only drop if these items already dropped |

### Chance Modifiers

Chance modifiers increase drop chance based on entity stats:

```lua
chanceModifiers = {
	luck = 0.01, -- +1% per luck point
	-- Formula: finalChance = baseChance + (luck * 0.01)
	-- Example: 10 luck = +10% drop chance
}
```

**Multiple modifiers stack additively:**
```lua
chanceModifiers = {
	luck = 0.01,           -- +1% per luck point
	rarity_bonus = 0.005,  -- +0.5% per rarity bonus
}
-- With 10 luck + 20 rarity: +10% + +10% = +20% total bonus
```

### Conditional Logic

**excludeIf** - Prevents drop if specified items already dropped:
```lua
["SmallMeat"] = {
	chance = 0.8,
	excludeIf = { "BigMeat" }, -- Don't drop if BigMeat dropped
}
```

**requireIf** - Only drops if specified items already dropped:
```lua
["BonusLoot"] = {
	chance = 1.0,
	requireIf = { "RareItem" }, -- Only drop if RareItem dropped
}
```

**Processing order matters:** Items are processed in the order they appear in the config table.

## API Reference

### DropSystem.resolveDrops()

Resolves which items should drop based on configuration and stats.

```lua
function DropSystem.resolveDrops(
	dropConfig: DropConfig,
	statsTable: StatsTable?
): { ResolvedDrop }
```

**Parameters:**
- `dropConfig` - Drop configuration table (from entity/chest/resource config)
- `statsTable` - Optional stats table `{luck = 5, strength = 10, ...}`

**Returns:** Array of resolved drops:
```lua
{
	{ itemId = "BigMeat", quantity = 2 },
	{ itemId = "BearPelt", quantity = 1 }
}
```

### DropSystem.spawnDrops()

Spawns physical drops in the world.

```lua
function DropSystem.spawnDrops(
	drops: { ResolvedDrop },
	position: Vector3,
	scatterRadius: number?
)
```

**Parameters:**
- `drops` - Array of resolved drops (from `resolveDrops()`)
- `position` - World position to spawn drops
- `scatterRadius` - Optional radius to scatter drops (default: 3 studs)

### DropSystem.processDrops()

Convenience method that resolves and spawns in one call.

```lua
function DropSystem.processDrops(
	dropConfig: DropConfig,
	statsTable: StatsTable?,
	position: Vector3,
	scatterRadius: number?
): { ResolvedDrop }
```

**Returns:** Array of resolved drops (for logging/debugging)

## Usage Examples

### Entity Death Drops

```lua
-- In EntityController when entity dies
local EntityController = require(ReplicatedStorage.Engine.EntityController)
local DropSystem = require(ServerScriptService.Server.DropSystem)
local StatsProvider = require(ReplicatedStorage.Engine.StatsProvider)

-- Entity died, get killer stats
local killerStats = StatsProvider.getStats(killerModel)

-- Get entity config
local entityConfig = EntitiesConfig.Entities.Bear

-- Process drops
local drops = DropSystem.processDrops(
	entityConfig.drops,     -- Drop configuration
	killerStats,            -- Killer's stats (for luck, etc.)
	entityPosition,         -- Spawn location
	5                       -- Scatter radius
)

print("Dropped items:", drops)
```

### Treasure Chest Drops

```lua
-- In ChestManager when chest is opened
local ChestsConfig = require(ReplicatedStorage.Engine.config.ChestsConfig)
local DropSystem = require(ServerScriptService.Server.DropSystem)
local StatsProvider = require(ReplicatedStorage.Engine.StatsProvider)

function ChestManager.openChest(chest, player)
	local chestConfig = ChestsConfig[chest.Name]
	local playerStats = StatsProvider.getStats(player.Character)

	-- Process drops (player stats can affect chest contents)
	DropSystem.processDrops(
		chestConfig.drops,
		playerStats,
		chest.Position
	)

	chest:Destroy()
end
```

### Resource Harvesting Drops

```lua
-- In ResourceManager when tree is chopped
local ResourcesConfig = require(ReplicatedStorage.Engine.config.ResourcesConfig)
local DropSystem = require(ServerScriptService.Server.DropSystem)

function ResourceManager.harvestResource(resource, player)
	local resourceConfig = ResourcesConfig[resource.Name]

	-- No stats influence (or pass nil)
	DropSystem.processDrops(
		resourceConfig.drops,
		nil,                 -- No stat modifiers
		resource.Position
	)

	resource:Destroy()
end
```

### Quest Reward Drops

```lua
-- In QuestManager when quest completes
local QuestConfig = require(ReplicatedStorage.Engine.config.QuestConfig)
local DropSystem = require(ServerScriptService.Server.DropSystem)

function QuestManager.completeQuest(questId, player)
	local questConfig = QuestConfig[questId]

	-- Spawn rewards at player's position
	DropSystem.processDrops(
		questConfig.rewardDrops,
		nil,                      -- No stat modifiers for quest rewards
		player.Character.HumanoidRootPart.Position,
		2                         -- Small scatter radius
	)
end
```

## Example Configurations

### Entity Drops (EntitiesConfig.luau)

```lua
Bear = {
	category = Categories.Wildlife,
	health = 100,
	-- ... other config ...
	drops = {
		["BigMeat"] = {
			chance = 1.0,
			min = 1,
			max = 3,
		},
		["SmallMeat"] = {
			chance = 0.8,
			min = 1,
			max = 2,
			excludeIf = { "BigMeat" },
			chanceModifiers = {
				luck = 0.01,
			}
		},
		["BearPelt"] = {
			chance = 0.01,
			min = 1,
			max = 1,
			chanceModifiers = {
				luck = 0.001,
			},
			maxChance = 0.15
		}
	}
}
```

### Treasure Chest Drops (ChestsConfig.luau)

```lua
ChestsConfig = {
	GoldenChest = {
		drops = {
			["Gold"] = {
				chance = 1.0,
				min = 50,
				max = 100,
			},
			["RareGem"] = {
				chance = 0.05, -- 5% chance
				min = 1,
				max = 3,
				chanceModifiers = {
					luck = 0.002, -- +0.2% per luck point
				},
				maxChance = 0.25 -- Cap at 25%
			},
			["LegendaryWeapon"] = {
				chance = 0.01, -- 1% chance
				min = 1,
				max = 1,
				requireIf = { "RareGem" }, -- Only if rare gem dropped
			}
		}
	}
}
```

### Resource Drops (ResourcesConfig.luau)

```lua
ResourcesConfig = {
	OakTree = {
		drops = {
			["Wood"] = {
				chance = 1.0,
				min = 3,
				max = 5,
			},
			["Acorn"] = {
				chance = 0.3, -- 30% chance
				min = 1,
				max = 2,
			}
		}
	}
}
```

## Stat System Integration

The DropSystem integrates with the existing stats system via `StatsProvider`:

```lua
local StatsProvider = require(ReplicatedStorage.Engine.StatsProvider)

-- Get stats for any entity (player or NPC)
local stats = StatsProvider.getStats(model)
-- Returns: { strength = 10, magic = 5, luck = 3, ... } or nil

-- Pass to DropSystem
DropSystem.processDrops(dropConfig, stats, position)
```

**Stats are optional:** If `nil` is passed, only base drop chances are used (no modifiers).

## Drop Chance Calculation

The final drop chance is calculated as:

```
finalChance = baseChance + Σ(statValue × modifier)
finalChance = min(finalChance, maxChance) -- Apply cap if specified
finalChance = clamp(finalChance, 0, 1)     -- Ensure valid range
```

**Example:**
```lua
-- Configuration
chance = 0.01           -- 1% base
chanceModifiers = {
	luck = 0.001        -- +0.1% per luck point
}
maxChance = 0.15        -- 15% cap

-- Player stats
luck = 50

-- Calculation
finalChance = 0.01 + (50 × 0.001) = 0.01 + 0.05 = 0.06 (6%)
-- No cap needed (6% < 15%)

-- With 200 luck
finalChance = 0.01 + (200 × 0.001) = 0.21 (21%)
finalChance = min(0.21, 0.15) = 0.15 (15%) -- Capped!
```

## Best Practices

### 1. Use Chance Caps for Rare Items
Always set `maxChance` on rare drops to prevent over-stacking:
```lua
["LegendarySword"] = {
	chance = 0.01,
	chanceModifiers = { luck = 0.001 },
	maxChance = 0.15, -- ✅ Prevents >15% chance
}
```

### 2. Order Matters for Conditional Logic
Process high-priority drops first:
```lua
drops = {
	-- Process BigMeat first
	["BigMeat"] = { chance = 0.5 },

	-- Then SmallMeat (excluded if BigMeat dropped)
	["SmallMeat"] = {
		chance = 0.8,
		excludeIf = { "BigMeat" }
	}
}
```

### 3. Use Appropriate Modifiers
- **Guaranteed drops (chance = 1.0):** Set modifiers to 0
- **Common drops (chance > 0.5):** Use small modifiers (0.001 - 0.01)
- **Rare drops (chance < 0.05):** Use larger modifiers (0.01 - 0.1)

### 4. Scatter Radius Based on Context
- **Entity deaths:** Larger radius (5-10 studs) for natural feel
- **Chests:** Medium radius (3-5 studs)
- **Quest rewards:** Small radius (1-2 studs) near player

### 5. Log Drops for Debugging
```lua
local drops = DropSystem.processDrops(config, stats, position)
print("Dropped items:", drops) -- Shows what actually dropped
```

## Testing

### Manual Testing
```lua
-- Test with no stats (base chances only)
DropSystem.processDrops(config, nil, position)

-- Test with high luck
DropSystem.processDrops(config, { luck = 100 }, position)

-- Test conditional logic
local drops = DropSystem.resolveDrops(config, stats)
-- Verify excludeIf/requireIf working correctly
```

### Unit Testing Drop Chances
```lua
-- Run 1000 iterations to verify drop rates
local iterations = 1000
local dropCounts = {}

for i = 1, iterations do
	local drops = DropSystem.resolveDrops(config, stats)
	for _, drop in drops do
		dropCounts[drop.itemId] = (dropCounts[drop.itemId] or 0) + 1
	end
end

-- Verify rates match expected chances
for itemId, count in dropCounts do
	local rate = count / iterations
	print(itemId, "dropped", rate * 100, "% of the time")
end
```

## Future Enhancements

Potential extensions to the system:

1. **Drop Groups** - Weighted selection (one item from group)
2. **Dynamic Modifiers** - Time-based, event-based bonuses
3. **Drop History** - Track recent drops to prevent duplicates
4. **Guaranteed Pity System** - Ensure rare drop after N failures
5. **Visual Effects** - Different particles for rare vs common drops
6. **Drop Notifications** - UI feedback for rare drops

## Troubleshooting

### Drops Not Spawning
- ✅ Verify `spawnDrops()` implementation (currently placeholder)
- ✅ Check drop chances aren't too low
- ✅ Verify statsTable is formatted correctly

### Wrong Drop Rates
- ✅ Check `chanceModifiers` multipliers
- ✅ Verify stat values are correct
- ✅ Test with `nil` stats to isolate base chances

### Conditional Logic Not Working
- ✅ Verify processing order (items earlier in table process first)
- ✅ Check `excludeIf`/`requireIf` item IDs match exactly
- ✅ Test `resolveDrops()` separately to see what's rolling

## Related Systems

- **StatsProvider** - Fetches entity stats for drop calculations
- **EntityController** - Triggers drops on entity death
- **CombatSystem** - Provides damage/kill context
- **Config Files** - Define drop tables (EntitiesConfig, ChestsConfig, etc.)

---

**Module:** `src/server/DropSystem.server.luau`
**Last Updated:** October 2025
**Version:** 1.0
