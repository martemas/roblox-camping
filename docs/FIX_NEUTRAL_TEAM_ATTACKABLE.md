# Fix: Neutral Team Entities are Now Attackable

## Problem

Red team players could not damage neutral team bears (or any neutral entities).

**Reported Issue:**
> "Player in red team cannot damage bear in neutral team"

## Root Cause

The `TeamManager.areEnemies()` function had special logic that prevented ANY interaction with neutral entities:

```lua
-- OLD CODE (PROBLEMATIC)
-- Neutral team is not hostile to anyone (unless configured otherwise)
if team1 == DEFAULT_TEAM or team2 == DEFAULT_TEAM then
    return false  -- ❌ Prevented attacking neutral entities
end
```

This made neutral entities **completely non-hostile** and **un-attackable**, which is not ideal for wildlife/hunting gameplay.

## Solution

Updated `TeamManager.areEnemies()` to treat neutral entities as attackable by all teams, while still preventing neutral-on-neutral attacks.

**File Changed:** [TeamManager.luau](../src/server/engine/TeamManager.luau#L196-218)

```lua
-- NEW CODE (FIXED)
-- Same team = not enemies (includes neutral-to-neutral)
if team1 == team2 then
    return false
end

-- Different teams = enemies (including neutral)
-- This allows any team to attack neutral entities (wildlife, resources)
-- But neutral entities won't attack each other (same team check above)
return true
```

## New Behavior

### ✅ Red Team vs Neutral Bear
```lua
local player = getRedTeamPlayer()
local bear = getNeutralBear()

TeamManager.areEnemies(player, bear)  -- ✅ true (can attack!)
```

### ✅ Blue Team vs Neutral Wolf
```lua
local player = getBlueTeamPlayer()
local wolf = getNeutralWolf()

TeamManager.areEnemies(player, wolf)  -- ✅ true (can attack!)
```

### ❌ Neutral Bear vs Neutral Wolf
```lua
local bear = getNeutralBear()
local wolf = getNeutralWolf()

TeamManager.areEnemies(bear, wolf)  -- ❌ false (same team, won't fight)
```

### ✅ Red Team vs Blue Team
```lua
local redPlayer = getRedTeamPlayer()
local bluePlayer = getBlueTeamPlayer()

TeamManager.areEnemies(redPlayer, bluePlayer)  -- ✅ true (enemies!)
```

## Behavior Matrix

| Attacker Team | Target Team | Can Attack? | Why |
|---------------|-------------|-------------|-----|
| Red | Neutral | ✅ Yes | Different teams |
| Blue | Neutral | ✅ Yes | Different teams |
| Green | Neutral | ✅ Yes | Different teams |
| Neutral | Neutral | ❌ No | Same team |
| Red | Blue | ✅ Yes | Different teams |
| Red | Red | ❌ No | Same team |
| Blue | Blue | ❌ No | Same team |

## Use Cases

### ✅ Wildlife Hunting (Perfect!)
```lua
-- Spawn neutral wildlife
local bear = SpawnManager.spawnEntity("Bear", position, 5)
-- bear is automatically neutral

-- Any team can hunt it
local redPlayer = getPlayerOnTeam("red")
local bluePlayer = getPlayerOnTeam("blue")

-- Both players can attack the bear
assert(TeamManager.areEnemies(redPlayer, bear) == true)
assert(TeamManager.areEnemies(bluePlayer, bear) == true)
```

### ✅ Resource Gathering
```lua
-- Spawn neutral trees/rocks
local tree = SpawnManager.spawnEntity("Tree", position, 1)
-- tree is neutral

-- Any team can chop it down
-- All teams compete for resources
```

### ✅ Ambient NPCs
```lua
-- Spawn neutral ambient creatures
local deer = SpawnManager.spawnEntity("Deer", position, 1)
-- deer is neutral and passive

-- Any team can hunt it if they want
-- Deer won't attack other neutral animals
```

## Impact on Gameplay

### Before Fix (Broken)
- ❌ Red team **cannot** attack neutral wildlife
- ❌ Blue team **cannot** attack neutral wildlife
- ❌ Wildlife feels "protected" and un-huntable
- ❌ No resource competition

### After Fix (Working!)
- ✅ Red team **can** hunt neutral wildlife
- ✅ Blue team **can** hunt neutral wildlife
- ✅ Teams compete for neutral resources
- ✅ Wildlife behaves like hostile NPCs
- ✅ Neutral entities don't attack each other

## AI Behavior

The fix also affects AI targeting:

### EntityController Targeting

```lua
-- In EntityController.getClosestPlayer()
if TeamManager.areAllies(entity, player) then
    continue  -- Skip allies
end

-- RED TEAM BEAR targeting:
-- ✅ Will target blue/green players (enemies)
-- ❌ Won't target red players (allies)
-- ❌ Won't target neutral players (now considered enemies but neutral AI doesn't target neutral)

-- NEUTRAL BEAR targeting:
-- ✅ Will target red/blue/green players (enemies)
-- ❌ Won't target other neutral entities (allies)
```

**Note:** Neutral entities can NOW be considered "enemies" to other teams, but the AI won't target them unless explicitly configured to do so.

## Testing

### Test 1: Red Player Attacks Neutral Bear
```lua
local player = game.Players:GetPlayers()[1]
TeamManager.assignPlayerToTeam(player, "red")

local bear = SpawnManager.spawnEntity("Bear", Vector3.new(0, 10, 0), 5)
-- bear is automatically neutral

-- Test combat
local canAttack = TeamManager.areEnemies(player, bear)
assert(canAttack == true, "Red player should be able to attack neutral bear")

-- Try to deal damage
local success = CombatSystem.dealDamage(player.Character, bear, 10)
assert(success, "Damage should succeed")
```

### Test 2: Neutral Entities Don't Fight Each Other
```lua
local bear = SpawnManager.spawnEntity("Bear", Vector3.new(0, 10, 0), 5)
local wolf = SpawnManager.spawnEntity("Wolf", Vector3.new(10, 10, 0), 5)
-- Both are neutral

local canFight = TeamManager.areEnemies(bear, wolf)
assert(canFight == false, "Neutral entities shouldn't fight each other")
```

### Test 3: Team Members Protected
```lua
local player1 = game.Players:GetPlayers()[1]
local player2 = game.Players:GetPlayers()[2]
TeamManager.assignPlayerToTeam(player1, "red")
TeamManager.assignPlayerToTeam(player2, "red")

local canAttack = TeamManager.areEnemies(player1, player2)
assert(canAttack == false, "Same team members can't attack each other")
```

## Configuration

No configuration changes needed! The fix applies to all neutral entities automatically.

However, if you wanted to create **truly non-hostile NPCs** (vendors, quest givers), you would need to:

1. **Option A:** Create a new team called "friendly"
   ```lua
   teams = {
       friendly = {
           name = "Friendly NPCs",
           color = Color3.fromRGB(100, 255, 100),
       }
   }
   ```
   Then modify `areEnemies()` to exclude "friendly" team.

2. **Option B:** Use entity attributes
   ```lua
   npc:SetAttribute("Invulnerable", true)
   ```
   Check in combat system before applying damage.

## Migration

No migration needed! This is a bug fix that makes the system work as expected.

### Existing Code Works
```lua
-- All existing spawn code works correctly
SpawnManager.spawnEntity("Bear", position, 5)
-- Bear is neutral and can now be hunted by all teams ✅
```

## Related Changes

This fix works in conjunction with:

1. **Default Neutral Team Assignment** - All entities without a team default to neutral
2. **Combat System** - Uses `areEnemies()` to check if damage is allowed
3. **AI Targeting** - Uses `areAllies()` to skip friendly targets

## Documentation Updated

- ✅ [FEATURE_DEFAULT_NEUTRAL_TEAMS.md](FEATURE_DEFAULT_NEUTRAL_TEAMS.md) - Updated neutral behavior description
- ✅ [TeamManager.luau](../src/server/engine/TeamManager.luau#L191-194) - Updated function comments

## Summary

**Before:** Neutral entities were un-attackable by any team (broken)
**After:** Neutral entities can be attacked by any team (working!)

This fix makes neutral entities behave correctly for wildlife/hunting gameplay while maintaining proper team-based combat rules.
