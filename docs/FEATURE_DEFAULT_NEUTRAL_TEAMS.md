# Feature: Default Neutral Team Assignment

## Overview

All entities spawned in the game are now automatically assigned to a team. If no team is specified, entities default to the **"neutral"** team.

## Changes Made

### 1. EntitySpawner Always Assigns Teams

**File:** [EntitySpawner.luau](../src/server/engine/Entities/EntitySpawner.luau#L236-240)

**Before:**
```lua
-- Assign team if provided (for team-based gameplay)
if config.teamId then
    local TeamManager = require(script.Parent.Parent.TeamManager)
    TeamManager.assignEntityToTeam(model, config.teamId, config.ownerId)
end
```

**After:**
```lua
-- Always assign team (defaults to neutral if not specified)
-- This ensures all entities are properly registered in the team system
local TeamManager = require(script.Parent.Parent.TeamManager)
local teamId = config.teamId or "neutral"  -- Default to neutral
TeamManager.assignEntityToTeam(model, teamId, config.ownerId)
```

### 2. SpawnLoader Passes TeamId from Workspace

**File:** [SpawnLoader.luau](../src/server/games/alpha/SpawnLoader.luau#L118-126)

Spawn parts in the workspace can now have a `TeamId` attribute that gets passed through to the spawned entities.

**Added:**
```lua
local spawnPoint: SpawnPoint = {
    entityType = entityType,
    position = part.Position,
    count = count,
    spawnRadius = spawnRadius,
    respawnTime = respawnTime,
    maxActive = maxActive,
    teamId = teamId,  -- Pass through team ID from part attribute (optional)
}
```

### 3. SpawnManager Accepts TeamId Parameter

**File:** [SpawnManager.luau](../src/server/engine/SpawnManager.luau#L198-207)

**Updated signature:**
```lua
function SpawnManager.spawnEntity(
    entityType: string,
    position: Vector3?,
    level: number?,
    teamId: string?  -- NEW: Optional team parameter
): Model?
```

### 4. GameInit Passes TeamId

**File:** [GameInit.luau](../src/server/games/alpha/GameInit.luau#L165)

Now passes the `teamId` from spawn point configuration:

```lua
for i = 1, spawnPoint.count do
    SpawnManager.spawnEntity(spawnPoint.entityType, spawnPoint.position, 1, spawnPoint.teamId)
end
```

## Benefits

### ✅ Consistent Behavior
- Every entity always has a team assigned
- No "unknown" or "undefined" team states
- Entities are properly tracked in team queries

### ✅ Proper Registration
- All entities registered in TeamManager cache
- `TeamManager.getTeamEntities("neutral")` returns all neutral entities
- `entity:GetAttribute("TeamId")` always returns a valid team

### ✅ Backward Compatible
- Existing code that doesn't specify `teamId` continues to work
- Entities default to neutral team (non-hostile)
- No breaking changes to existing spawning code

### ✅ Level Designer Control
- Can set teams on spawn parts in Workspace
- Add `TeamId` attribute to spawn parts (e.g., "red", "blue")
- Entities spawn on the specified team automatically

## Usage Examples

### Example 1: Spawn Without TeamId (Defaults to Neutral)

```lua
-- Old code continues to work
local wolf = SpawnManager.spawnEntity("Wolf", Vector3.new(0, 10, 0), 5)

-- Wolf is automatically assigned to "neutral" team
print(wolf:GetAttribute("TeamId"))  -- "neutral"
```

### Example 2: Spawn with Specific Team

```lua
-- Spawn a red team wolf
local redWolf = SpawnManager.spawnEntity("Wolf", Vector3.new(0, 10, 0), 5, "red")

print(redWolf:GetAttribute("TeamId"))  -- "red"
```

### Example 3: Using EntitySpawner Directly

```lua
local EntitySpawner = require(ServerScriptService.Engine.Entities.EntitySpawner)

-- Without teamId - defaults to neutral
local neutralBear = EntitySpawner.spawnEntity({
    entityType = "Bear",
    location = { type = "point", position = Vector3.new(0, 10, 0) },
    level = 10,
})

-- With teamId
local blueBear = EntitySpawner.spawnEntity({
    entityType = "Bear",
    location = { type = "point", position = Vector3.new(0, 10, 0) },
    level = 10,
    teamId = "blue",
})
```

### Example 4: Workspace Spawn Parts

In Roblox Studio, select a spawn part and add attribute:

1. Select the spawn part (e.g., `Spawn_Wolf`)
2. Properties → Add Attribute
3. Name: `TeamId` (string)
4. Value: `"red"` or `"blue"` or `"green"`

All wolves spawned from that part will be on the specified team!

**Without TeamId attribute:** Spawns as neutral (default)
**With TeamId = "red":** Spawns on red team

## Testing

### Verify Neutral Default

```lua
-- Spawn entity without teamId
local entity = SpawnManager.spawnEntity("Wolf", Vector3.new(0, 10, 0), 1)

-- Check team assignment
local teamId = entity:GetAttribute("TeamId")
assert(teamId == "neutral", "Entity should default to neutral team")

-- Verify it's in team queries
local neutralEntities = TeamManager.getTeamEntities("neutral")
local found = false
for _, e in neutralEntities do
    if e == entity then
        found = true
        break
    end
end
assert(found, "Entity should be in neutral team list")
```

### Verify Specific Team

```lua
-- Spawn entity with red team
local entity = SpawnManager.spawnEntity("Wolf", Vector3.new(0, 10, 0), 1, "red")

-- Check team assignment
local teamId = entity:GetAttribute("TeamId")
assert(teamId == "red", "Entity should be on red team")

-- Verify team relationships
local player = game.Players:GetPlayers()[1]
TeamManager.assignPlayerToTeam(player, "blue")

assert(TeamManager.areEnemies(entity, player), "Red wolf should be enemy of blue player")
```

## Behavior Matrix

| Spawn Method | teamId Parameter | Result Team | Registered in System |
|--------------|------------------|-------------|---------------------|
| SpawnManager.spawnEntity("Wolf") | nil | neutral | ✅ Yes |
| SpawnManager.spawnEntity("Wolf", pos, lvl, "red") | "red" | red | ✅ Yes |
| EntitySpawner.spawnEntity({...}) | nil | neutral | ✅ Yes |
| EntitySpawner.spawnEntity({..., teamId="blue"}) | "blue" | blue | ✅ Yes |
| Workspace spawn part (no attribute) | nil | neutral | ✅ Yes |
| Workspace spawn part (TeamId="green") | "green" | green | ✅ Yes |

## Impact on Existing Systems

### Combat System
- Neutral entities don't attack other neutral entities (same team)
- Neutral entities can be attacked by non-neutral teams
- Works with existing `friendlyFire` and `teamBased` config

### AI Targeting
- Neutral NPCs won't target other neutral NPCs
- Neutral NPCs won't target neutral team players
- Consistent behavior across all entities

### Team Queries
- `TeamManager.getTeamEntities("neutral")` now returns ALL unassigned entities
- Previously missed entities with no team now properly tracked
- Team member counts accurate

## Migration Notes

### No Migration Required

This change is fully backward compatible. Existing code that spawns entities without specifying a team will continue to work exactly as before, with entities now properly registered as neutral.

### Optional: Update Existing Code

For clarity, you can optionally update spawn calls to explicitly specify "neutral":

```lua
-- Before (implicit neutral)
SpawnManager.spawnEntity("Wolf", position, level)

-- After (explicit neutral) - optional, not required
SpawnManager.spawnEntity("Wolf", position, level, "neutral")
```

## Related Documentation

- [Team System Setup Guide](GUIDE_TEAM_SETUP.md)
- [Testing Teams Locally](TESTING_TEAMS_LOCALLY.md)
- [TeamManager API Reference](GUIDE_TEAM_SETUP.md#api-reference)

## Technical Details

### Why Default to Neutral?

The neutral team represents entities that:
- **Can be attacked by any team** (huntable wildlife, resources)
- **Won't attack other neutral entities** (same team behavior)
- Don't participate in team-vs-team combat
- Useful for ambient/non-aligned entities

This is ideal for:
- **Wildlife that spawns naturally** (bears, wolves, deer)
- **Ambient creatures** (passive animals)
- **Resources** (trees, rocks, gatherable items)
- **Entities without explicit team assignment**

**Key Behavior:**
- ✅ Red team player **CAN** attack neutral bear
- ✅ Blue team player **CAN** attack neutral bear
- ❌ Neutral bear **CANNOT** attack other neutral entities
- ✅ Neutral entities are treated like hostile NPCs to all teams

### Team Attribute Storage

All entities store their team in the `TeamId` attribute:

```lua
entity:GetAttribute("TeamId")  -- Returns: "neutral", "red", "blue", "green", etc.
```

This attribute:
- Replicates to all clients
- Persists for the entity's lifetime
- Used by BillboardUI for name colors
- Used by targeting HUD for color display
- Used by combat system for ally/enemy checks

### Cache Management

TeamManager maintains a cache of entity teams:

```lua
local entityTeams: {[Model]: string} = {}
```

This cache:
- Provides fast lookups (no attribute queries)
- Automatically cleaned up when entities despawn
- Synchronized with entity attributes
- Used for team queries and relationship checks

## Future Enhancements

Possible future improvements:

1. **Dynamic Team Assignment**
   - Allow entities to switch teams during gameplay
   - Taming system could reassign wild animals to player's team

2. **Team-Specific Behaviors**
   - Different AI behaviors per team
   - Team-based objectives and goals

3. **Team Templates**
   - Preset team configurations
   - Easy team setup for different game modes

4. **Team Hierarchies**
   - Sub-teams or squads within main teams
   - Alliance systems between teams
