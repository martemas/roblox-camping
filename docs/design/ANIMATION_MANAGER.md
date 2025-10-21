# Animation Manager System

## Overview

A secure, performant, and memory-safe system for managing custom per-tool animations in Roblox. Each tool can have multiple animations (anim1, anim2, anim3...) that play in sequence when the player activates the tool.

## Architecture

### Three-Tier System

1. **AnimationCache** (Server) - Pre-warmed cache of Animation objects
2. **AnimationManager** (Server) - Per-player AnimationTrack lifecycle management
3. **ToolManager Integration** - Plays animations on tool activation

---

## Directory Structure

```
ReplicatedStorage/
└── Models/
    └── Tools/              ← All tools stored here
        ├── Axe (Tool)
        │   ├── Handle (Part)
        │   ├── anim1 (Animation) → rbxassetid://...
        │   ├── anim2 (Animation) → rbxassetid://...
        │   └── anim3 (Animation) → rbxassetid://...
        └── Pickaxe (Tool)
            ├── Handle (Part)
            ├── anim1 (Animation) → rbxassetid://...
            └── anim2 (Animation) → rbxassetid://...
```

**Animation Naming Convention:**
- Must be named `anim1`, `anim2`, `anim3`, etc.
- Must be direct children of the Tool instance
- Must be Animation instances with valid AssetId
- Numbering starts at 1 and should be sequential

---

## Module 1: AnimationCache

**File:** `src/server/AnimationCache.luau`

### Purpose
Pre-loads all tool animations at server startup to prevent cache stampede and ensure O(1) lookups.

### API

```lua
AnimationCache.Initialize() → void
```
Called once at server startup. Scans `ReplicatedStorage.Models.Tools` and caches all animations.

```lua
AnimationCache.GetToolAnimations(toolType: ToolType) → {Animation}?
```
Returns cached animation array for the tool, or nil if no animations found.

```lua
AnimationCache.GetAnimationCount(toolType: ToolType) → number
```
Returns the number of animations available for this tool.

### Cache Structure

```lua
{
  ["Axe"] = {
    [1] = Animation (anim1),
    [2] = Animation (anim2),
    [3] = Animation (anim3)
  },
  ["Pickaxe"] = {
    [1] = Animation (anim1),
    [2] = Animation (anim2)
  }
}
```

### Pre-warming Algorithm

1. Find `ReplicatedStorage.Models.Tools` folder
2. Iterate all Tool instances
3. For each tool:
   - Find all children matching pattern `^anim%d+$`
   - Extract number from name (anim1 → 1, anim2 → 2)
   - Sort by number ascending
   - Validate Animation instance and AssetId
   - Store in cache array
4. Log results for debugging

### Error Handling

- Missing Tools folder → Log warning, return empty cache
- Invalid tool instance → Skip tool, log warning
- Missing animations → Tool excluded from cache
- Invalid Animation object → Skip animation, log warning

---

## Module 2: AnimationManager

**File:** `src/server/AnimationManager.luau`

### Purpose
Manages per-player AnimationTrack lifecycle, sequence tracking, and comprehensive cleanup.

### API

```lua
AnimationManager.PlayNextAnimation(player: Player, toolType: ToolType) → boolean
```
Plays the next animation in sequence for this player/tool combination. Returns true if successful, false if fallback needed.

```lua
AnimationManager.StopAllAnimations(player: Player, toolType: ToolType?) → void
```
Stops all playing animations. If toolType specified, stops only that tool. If nil, stops all tools.

```lua
AnimationManager.OnCharacterAdded(player: Player, character: Model) → void
```
Called when character spawns/respawns. Sets up character removal detection and clears old animation data.

```lua
AnimationManager.OnCharacterRemoving(player: Player) → void
```
Called when character dies/despawns. Stops and destroys all AnimationTracks.

```lua
AnimationManager.ClearPlayerData(player: Player) → void
```
Called when player leaves. Comprehensive cleanup of all player data and connections.

### Data Structures

```lua
-- Loaded AnimationTracks per player per tool
playerTracks = {
  [Player] = {
    ["Axe"] = {
      [1] = AnimationTrack,
      [2] = AnimationTrack,
      [3] = AnimationTrack
    },
    ["Pickaxe"] = {
      [1] = AnimationTrack,
      [2] = AnimationTrack
    }
  }
}

-- Current animation index per player per tool (1-based)
playerIndices = {
  [Player] = {
    ["Axe"] = 2,      -- Next activation plays anim2
    ["Pickaxe"] = 1   -- Next activation plays anim1
  }
}

-- Character connections for cleanup
characterConnections = {
  [Player] = {
    ancestryConnection = RBXScriptConnection
  }
}
```

### Animation Sequence Logic

**Initialization:**
- When player first uses a tool, index starts at 1

**Progression:**
- Each activation: play current index, then increment
- Wrapping: If index > animation count, wrap to 1
- Example with 3 animations: 1→2→3→1→2→3→1...

**Per-Player Tracking:**
- Each player maintains their own sequence position
- Player A at index 2, Player B at index 1 (independent)

**Per-Tool Tracking:**
- Each tool has separate sequence for same player
- Player's Axe at index 2, Pickaxe at index 3 (independent)

### Cleanup Strategy

#### Trigger 1: Character Death/Removal
**Event:** `character.AncestryChanged` → parent == nil

**Actions:**
1. Stop all AnimationTracks for player (all tools)
2. Destroy all AnimationTrack instances
3. Clear `playerTracks[player]`
4. **Keep** `playerIndices[player]` (persist across respawns)
5. Disconnect character connections

**Reason:** Character's Humanoid/Animator destroyed, tracks become invalid.

#### Trigger 2: Player Leaving Server
**Event:** `Players.PlayerRemoving`

**Actions:**
1. Stop all AnimationTracks
2. Destroy all AnimationTrack instances
3. Clear `playerTracks[player]`
4. Clear `playerIndices[player]`
5. Disconnect all character connections
6. Remove player from all dictionaries

**Reason:** Player object will be garbage collected, must cleanup all references.

#### Trigger 3: Character Respawn
**Event:** `player.CharacterAdded`

**Actions:**
1. Call `OnCharacterRemoving(player)` to cleanup old character
2. Set up new character removal detection
3. Reset `playerTracks[player] = {}`
4. **Keep** `playerIndices[player]` (preserve sequence position)

**Reason:** New character has new Humanoid/Animator, old tracks incompatible.

#### Trigger 4: Tool Unequipped (Optional)
**Event:** `tool.Unequipped`

**Actions:**
1. Stop currently playing animation for this tool
2. **Keep** AnimationTracks cached (performance)
3. **Keep** animation index (preserve sequence)

**Reason:** Animation should stop visually, but cache remains for re-equip.

### Loading Strategy

**Lazy Loading:**
- AnimationTracks loaded on first tool activation per player
- Gets Animation objects from AnimationCache (pre-warmed)
- Loads all tracks for a tool at once (batch)

**Validation:**
- Check character exists
- Check Humanoid exists
- Check Animator exists
- Validate Animation objects from cache
- pcall LoadAnimation to catch errors

**Fallback:**
- If any step fails, return false
- ToolManager will use default animation

---

## Module 3: ToolManager Integration

**File:** `src/server/ToolManager.server.luau`

### Changes Required

#### 1. Add Imports
```lua
local AnimationCache = require(script.Parent:WaitForChild("AnimationCache"))
local AnimationManager = require(script.Parent:WaitForChild("AnimationManager"))
```

#### 2. Hook Character Lifecycle
```lua
local function onPlayerAdded(player: Player)
    playerCooldowns[player] = {}

    player.CharacterAdded:Connect(function(character)
        AnimationManager.OnCharacterAdded(player, character)
        task.wait(1)
        giveStartingTools(player)
    end)

    if player.Character then
        AnimationManager.OnCharacterAdded(player, player.Character)
        giveStartingTools(player)
    end
end
```

#### 3. Cleanup on Player Leave
```lua
local function onPlayerRemoving(player: Player)
    playerCooldowns[player] = nil
    swingHits[player] = nil
    AnimationManager.ClearPlayerData(player)
end
```

#### 4. Replace Animation Logic in onToolSwing
**Before (lines 275-307):**
```lua
-- Play swing animation using default Roblox character animation
local animateScript = character:FindFirstChild("Animate")
if animateScript then
    local toolSlashAnim = animateScript:FindFirstChild("toolslash")
    -- ... existing toolslash logic ...
end
```

**After:**
```lua
-- Play custom tool animation or fallback to default
local animationPlayed = AnimationManager.PlayNextAnimation(player, toolType)

if not animationPlayed then
    -- Fallback to default Roblox toolslash animation
    local animateScript = character:FindFirstChild("Animate")
    if animateScript then
        local toolSlashAnim = animateScript:FindFirstChild("toolslash")
        -- ... existing toolslash logic ...
    end
end
```

#### 5. Optional: Stop Animation on Unequip
```lua
local function createTool(toolType: ToolType): Tool?
    -- ... existing code ...

    local tool = toolTemplate:Clone()

    -- Stop animation when tool unequipped
    tool.Unequipped:Connect(function()
        local player = Players:GetPlayerFromCharacter(tool.Parent)
        if player then
            AnimationManager.StopAllAnimations(player, toolType)
        end
    end)

    return tool
end
```

---

## Module 4: Server Initialization

**File:** `src/server/init.server.luau`

### Initialization Order

```lua
-- 1. Pre-warm animation cache FIRST
local AnimationCache = require(script:WaitForChild("AnimationCache"))
AnimationCache.Initialize()

-- 2. Then initialize other systems
local ToolManager = require(script:WaitForChild("ToolManager"))
-- ... other systems ...
```

**Critical:** AnimationCache must initialize before ToolManager so animations are ready when players join.

---

## Security Model

### Server Authority
✅ All animation selection logic on server
✅ AnimationCache only reads from ReplicatedStorage (not client writable)
✅ AnimationManager tracks sequence indices server-side
✅ No client RemoteEvents for animation control

### Validation
✅ Tool ownership checked before playing animation
✅ Cooldowns enforced (existing system)
✅ Invalid tools return fallback
✅ Character validation before loading tracks

### Exploit Prevention
✅ Client cannot modify animation sequence (server-side index)
✅ Client cannot play animations for unequipped tools (validation)
✅ Client cannot bypass cooldowns (existing cooldown system)
✅ Client cannot inject custom animations (server caches from ReplicatedStorage only)

---

## Performance Optimization

### Zero Cache Stampede
- All animations pre-loaded at server start
- Players joining see instant O(1) lookups
- No race conditions or duplicate loads

### Minimal Latency
- First tool use: ~0.05s (load AnimationTracks only)
- Subsequent uses: <0.01s (tracks already loaded)

### Memory Efficient
- Animation objects shared across all players
- AnimationTracks only created per player (lightweight)
- Proper cleanup prevents memory leaks

### Network Efficient
- AnimationTracks replicate automatically (Roblox handles it)
- No custom RemoteEvents for animation sync

---

## Fallback Strategy

### If Custom Animations Missing

**Level 1: AnimationCache**
- Tool not in cache → returns nil
- Logs warning with tool name

**Level 2: AnimationManager**
- Receives nil from cache → returns false
- Signals fallback needed

**Level 3: ToolManager**
- Receives false → plays default `toolslash` animation
- Player experience unaffected

### Graceful Degradation
- Missing Tools folder → All tools use fallback
- Missing tool in folder → That tool uses fallback
- Missing animations in tool → That tool uses fallback
- Invalid Animation object → Skip, try next animation

---

## Testing Checklist

### Functionality
- [ ] Server starts without errors
- [ ] Animations pre-load with correct count logged
- [ ] Single player: animations cycle 1→2→3→1
- [ ] Multiple players: each tracks own sequence
- [ ] Different tools: separate sequences per tool
- [ ] Missing animations: fallback works correctly

### Cleanup & Memory
- [ ] Character death: animations stop and cleanup
- [ ] Player leaves: all data cleared
- [ ] Character respawn: new tracks load, old cleaned
- [ ] Tool unequip: animation stops (optional)
- [ ] 10+ players join/leave: no memory growth
- [ ] Rapid respawns: no memory accumulation

### Performance
- [ ] First tool use: <100ms load time
- [ ] Subsequent uses: <10ms
- [ ] 10+ simultaneous players: no lag
- [ ] Cache lookup: O(1) constant time

### Edge Cases
- [ ] Player leaves during animation → Clean cleanup
- [ ] Character dies mid-swing → Animation stops
- [ ] Tool equipped with no animations → Fallback works
- [ ] Invalid animator → Fallback works
- [ ] Multiple tools equipped rapidly → Correct sequence per tool

---

## Debug Logging

### AnimationCache
```
[AnimationCache] Scanning ReplicatedStorage.Models.Tools...
[AnimationCache] Found tool: Axe
[AnimationCache] Loaded 3 animations for Axe: anim1, anim2, anim3
[AnimationCache] Found tool: Pickaxe
[AnimationCache] Loaded 2 animations for Pickaxe: anim1, anim2
[AnimationCache] Pre-warming complete: 2 tools, 5 total animations
```

### AnimationManager
```
[AnimationManager] Loading tracks for Player1: Axe (3 animations)
[AnimationManager] Playing animation 2/3 for Player1: Axe
[AnimationManager] Character removing: Player1 (stopping all animations)
[AnimationManager] Player data cleared: Player1
```

### ToolManager
```
[ToolManager] Playing custom animation for Player1: Axe
[ToolManager] Fallback to default animation for Player2: Sword (no custom)
```

---

## Memory Management Summary

### What Gets Cached (Permanent)
- Animation objects from ReplicatedStorage (shared across all players)

### What Gets Created Per Player
- AnimationTrack instances (one per animation per tool)
- Animation sequence indices (lightweight numbers)
- Character connections (one per player)

### What Gets Cleaned Up
- On character death: AnimationTracks destroyed, connections disconnected
- On player leave: All player data removed, all tracks destroyed, all connections disconnected
- On respawn: Old tracks destroyed before new ones created

### Memory Leak Prevention
✅ AnimationTracks explicitly destroyed with :Destroy()
✅ AnimationTracks stopped before destruction
✅ RBXScriptConnections disconnected
✅ Player references removed from all dictionaries
✅ No circular references
✅ No orphaned objects

---

## Implementation Status

- [x] AnimationCache.luau created
- [x] AnimationManager.luau created
- [x] ToolManager.server.luau updated
- [x] init.server.luau updated
- [x] Rojo build verified (compiles successfully)
- [ ] Testing with animations in Roblox Studio
- [ ] Documentation reviewed

---

## Troubleshooting

### Animation Stops Halfway / Gets Cut Off

**Problem:** Animation plays but stops before completing.

**Causes & Solutions:**

1. **Multiple swings too fast**
   - **Cause:** New animation interrupts old one
   - **Solution:** AnimationManager now stops previous animations before playing new ones (built-in)

2. **Animation Priority too low**
   - **Cause:** Other animations override tool animations
   - **Solution:** AnimationManager sets priority to `Action` (built-in)

3. **Tool unequip handler**
   - **Cause:** Tool.Unequipped event stops animation prematurely
   - **Solution:** Handler is now commented out by default in ToolManager

4. **Animation length vs cooldown mismatch**
   - **Cause:** Cooldown shorter than animation duration
   - **Solution:** Adjust weapon cooldown in GameConfig to match animation length
   - Example: If animation is 0.8s, set `cooldown = 0.8` or higher

5. **Animation not looped correctly**
   - **Cause:** Animation set to loop in Roblox
   - **Solution:** Ensure animations are NOT looped (looping should be false)

### Animation Not Playing at All

**Problem:** Default toolslash plays instead of custom animation.

**Causes & Solutions:**

1. **Animations not in Models/Tools folder**
   - Check server output for: `[AnimationCache] No valid animations found for ToolName`
   - Verify folder structure: `ReplicatedStorage/Models/Tools/ToolName/anim1`

2. **Animation naming incorrect**
   - Must be exactly: `anim1`, `anim2`, `anim3` (lowercase, sequential)
   - Check server output for loaded animation names

3. **AnimationId not set**
   - Each Animation instance must have valid `AnimationId` property
   - Format: `rbxassetid://123456789`

4. **Animator missing**
   - Character must have Humanoid with Animator
   - Check for warnings: `[AnimationManager] No animator for PlayerName`

### Animation Plays Same One Repeatedly

**Problem:** Always plays anim1, never progresses to anim2, anim3.

**Causes & Solutions:**

1. **Index not incrementing**
   - Should see in logs: `Playing animation 1/3`, then `2/3`, then `3/3`, then `1/3`...
   - If stuck at same number, check for errors in AnimationManager

2. **Only one animation loaded**
   - Check server output: `[AnimationCache] Loaded X animations for ToolName`
   - If X=1, add more animation instances (anim2, anim3)

### Memory Leak / Performance Degradation

**Problem:** Server gets slower over time with many players.

**Causes & Solutions:**

1. **AnimationTracks not cleaned up**
   - Verify logs show: `[AnimationManager] Player data cleared: PlayerName`
   - This should appear when players leave

2. **Character respawn not cleaning**
   - Verify logs show: `[AnimationManager] Character removing: PlayerName`
   - This should appear on death/respawn

3. **Use Roblox's memory profiler**
   - Check for growing AnimationTrack instances
   - Should stay constant or decrease over time

---

## Debug Commands

Add these to a server console for debugging:

```lua
-- Check animation cache
local AnimationCache = require(game.ServerScriptService.Server.AnimationCache)
print("Axe animations:", AnimationCache.GetAnimationCount("Axe"))
print("Pickaxe animations:", AnimationCache.GetAnimationCount("Pickaxe"))

-- Clear and reload cache
AnimationCache.ClearCache()
AnimationCache.Initialize()
```

---

## Future Enhancements

### Possible Features
- Animation priority customization per tool
- Animation blending/transitions
- Different animations for hit vs miss
- Animation speed modifiers
- Per-animation sound effects
- Animation events (hit detection timing)

### Not Recommended
- ❌ Client-side animation selection (security risk)
- ❌ Dynamic animation loading (cache stampede risk)
- ❌ Animation syncing between players (unnecessary, Roblox handles it)
