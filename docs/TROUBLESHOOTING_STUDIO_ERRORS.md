# Troubleshooting Studio Errors

Common errors you might see when testing the team system (or any Roblox game) in Studio.

## ✅ Safe to Ignore (Harmless Errors)

These errors are common in Roblox Studio and do not affect gameplay:

### Chat System Errors

```
Error calling SetCore CoreGuiChatConnections: SetCore: CoreGuiChatConnections has not been registered by the CoreScripts
```

**Cause:** Roblox's chat system tries to initialize before CoreGui is ready during local testing.

**Impact:** ❌ None - Chat still works fine

**Fix:** 🚫 Not needed - This is a Studio quirk, not present in published games

---

### WaitForChild Warnings

```
Infinite yield possible on 'Workspace:WaitForChild("Something")'
```

**Cause:** Script is waiting for an instance that might not exist yet.

**Impact:** ⚠️ Minor - Script may pause waiting for the instance

**Fix:**
```lua
-- Instead of:
local thing = workspace:WaitForChild("Something")

-- Use with timeout:
local thing = workspace:WaitForChild("Something", 5)
if not thing then
    warn("Thing not found!")
    return
end
```

---

## ⚠️ Team System Specific Errors

### TeamManager Not Found

```
[TestTeams] ❌ Failed to load TeamManager: attempt to call a nil value
```

**Cause:** TeamManager.luau not properly built into the project.

**Fix:**
1. Verify file exists: `src/server/engine/TeamManager.luau`
2. Rebuild: `rojo build -o "roblox-camping.rbxlx"`
3. Restart Studio and reopen the place file

---

### Teams Not Enabled Warning

```
[TeamManager] Team system disabled in GameConfig
```

**Cause:** Teams are disabled in configuration.

**Fix:**
Open `src/server/engine/Config/GameConfig.luau` and set:
```lua
teams = {
    enabled = true,  -- ← Change to true
}
```

Then rebuild: `rojo build -o "roblox-camping.rbxlx"`

---

### Invalid Team ID

```
[TeamManager] Invalid team: yellow, using default team: neutral
```

**Cause:** Trying to assign a player to a team that doesn't exist.

**Fix:**
Add the team to GameConfig.luau:
```lua
teams = {
    teams = {
        yellow = {
            name = "Yellow Team",
            color = Color3.fromRGB(255, 255, 0),
        },
    }
}
```

---

### Combat Not Team-Based

```
Players can damage teammates even though friendlyFire = false
```

**Cause:** `teamBased` setting is disabled.

**Fix:**
Open `src/server/engine/Config/GameConfig.luau`:
```lua
combat = {
    teamBased = true,  -- ← Must be true for team rules
    friendlyFire = false,
}
```

---

## 🔴 Critical Errors

### Script Error in TeamManager

```
ServerScriptService.Engine.TeamManager:XX: attempt to index nil with 'teams'
```

**Cause:** GameConfig is missing or corrupted.

**Fix:**
1. Check if `GameConfig.luau` exists in `src/server/engine/Config/`
2. Verify it has the `teams` table
3. Rebuild the project
4. If issue persists, compare with the template in the guide

---

### EntitySpawner Error

```
EntitySpawner:XX: attempt to call a nil value (method 'assignEntityToTeam')
```

**Cause:** TeamManager not loaded or initialized.

**Fix:**
1. Check GameInit.luau includes TeamManager initialization:
   ```lua
   local TeamManager = require(Engine.TeamManager)
   TeamManager.initialize()
   ```
2. Verify initialization order (TeamManager should init before EntitySpawner spawns)

---

## 🧪 Testing Errors

### Test Script Not Running

```
No output from [TestTeams] in console
```

**Cause:** Test script is disabled or not included in build.

**Check:**
1. Open `src/server/tests/TestTeams.server.luau`
2. Verify first line: `local ENABLED = true`
3. Rebuild: `rojo build -o "roblox-camping.rbxlx"`
4. Check ServerScriptService → Tests → TestTeams is present in Studio

---

### Players Not Assigned to Different Teams

```
[TestTeams] ✓ Assigned Player1 to neutral team
[TestTeams] ✓ Assigned Player2 to neutral team
```

**Cause:** Teams system not enabled or test script configuration issue.

**Fix:**
1. Enable teams in GameConfig.luau:
   ```lua
   teams = { enabled = true }
   ```
2. Check test script configuration:
   ```lua
   local TEST_CONFIG = {
       teams = {"red", "blue", "red", "blue"},  -- Must have valid team IDs
   }
   ```
3. Rebuild and restart Studio

---

### NPCs Not Spawning

```
[TestTeams] ⚠️ Could not load EntitySpawner
```

**Cause:** EntitySpawner not initialized yet or missing.

**Fix:**
1. Increase wait time in test script:
   ```lua
   task.wait(5)  -- Increase from 3 to 5 seconds
   ```
2. Check EntitySpawner exists in `src/server/engine/Entities/`
3. Verify GameInit initializes EntityAIManager (which loads EntityController)

---

## 🔧 General Studio Issues

### "Place file is from a newer version"

**Cause:** Roblox Studio is outdated.

**Fix:** Update Roblox Studio to the latest version.

---

### Scripts Not Running

**Cause:** Script disabled or FilteringEnabled issue.

**Check:**
1. Script is enabled (checkbox in properties)
2. Script is in the correct location (ServerScriptService for server scripts)
3. Script has `.server.luau` extension for server scripts

---

### Changes Not Appearing

**Cause:** Studio using old place file or changes not synced.

**Fix:**
1. **Always rebuild after code changes:**
   ```bash
   rojo build -o "roblox-camping.rbxlx"
   ```
2. Close the place file in Studio
3. Reopen `roblox-camping.rbxlx`
4. Start test again

---

## 🛠️ Debug Checklist

If team system isn't working, check in this order:

1. ✅ **Teams enabled in GameConfig?**
   - `teams.enabled = true`
   - `combat.teamBased = true`

2. ✅ **Project rebuilt?**
   - Run: `rojo build -o "roblox-camping.rbxlx"`
   - Reopen place file in Studio

3. ✅ **TeamManager initialized?**
   - Check Output for: `[TeamManager] ✓ Initialized`
   - Check GameInit.luau includes TeamManager

4. ✅ **Players assigned to teams?**
   - Check Output for: `[TeamManager] PlayerName assigned to team: red`
   - Or: `print(player:GetAttribute("TeamId"))`

5. ✅ **Test script enabled?**
   - `ENABLED = true` in TestTeams.server.luau
   - Script present in ServerScriptService → Tests

6. ✅ **Using multi-player test?**
   - Test → 2 Players → Start
   - Single player testing won't show team combat

---

## 📝 Getting Help

If you're still having issues:

1. **Check the Output window** - Most errors show here with stack traces
2. **Enable verbose logging** - Add print statements to track execution
3. **Test in isolation** - Disable other systems to find conflicts
4. **Compare with examples** - Check the guide for working code samples

### Useful Debug Commands

Add these to a test script to debug:

```lua
-- Check if TeamManager loaded
local TeamManager = require(ServerScriptService.Engine.TeamManager)
print("TeamManager loaded:", TeamManager ~= nil)

-- Check player's team
local player = game.Players:GetPlayers()[1]
print("Player team:", TeamManager.getTeamId(player))

-- Check team config
local GameConfig = require(ReplicatedStorage.Engine.Config)
print("Teams enabled:", GameConfig.teams.enabled)
print("Team based combat:", GameConfig.combat.teamBased)

-- Check entity team
local wolf = workspace.Entities:FindFirstChild("Wolf")
if wolf then
    print("Wolf team:", wolf:GetAttribute("TeamId"))
end

-- Check allies/enemies
local p1, p2 = game.Players:GetPlayers()[1], game.Players:GetPlayers()[2]
if p1 and p2 then
    print("P1 and P2 are allies:", TeamManager.areAllies(p1, p2))
    print("P1 and P2 are enemies:", TeamManager.areEnemies(p1, p2))
end
```

---

## 🔍 Common Studio Quirks

### Scripts Run Multiple Times

**Issue:** PlayerAdded fires for existing players during hot reload.

**Solution:** We handle this in TeamManager with:
```lua
-- Handle existing players (hot reload support)
for _, player in Players:GetPlayers() do
    onPlayerAdded(player)
end
```

### Attributes Not Replicating

**Issue:** Setting attributes on server but client doesn't see them.

**Cause:** Attribute set before instance replicated to client.

**Solution:** Always set attributes BEFORE adding instance to Workspace:
```lua
model:SetAttribute("TeamId", "red")  -- Set first
model.Parent = workspace  -- Then parent
```

### Memory Leaks

**Issue:** Old connections not cleaned up.

**Solution:** TeamManager handles cleanup automatically:
```lua
Players.PlayerRemoving:Connect(function(player)
    TeamManager.removePlayer(player)
end)
```

---

## 📚 Related Guides

- [GUIDE_TEAM_SETUP.md](GUIDE_TEAM_SETUP.md) - Full team system guide
- [TESTING_TEAMS_LOCALLY.md](TESTING_TEAMS_LOCALLY.md) - Quick testing reference
