# Testing Teams Locally - Quick Reference

This is a quick reference for testing the team system with 2 players in Roblox Studio.

## 🚀 Quick Start (3 Steps)

### Step 1: Enable Teams

Open `src/server/engine/Config/GameConfig.luau` and set:

```lua
teams = {
    enabled = true,  -- ← Change this to true
    -- ...
}

combat = {
    teamBased = true,  -- ← Change this to true
    friendlyFire = false,
    -- ...
}
```

### Step 2: Enable Test Script

The test script is already included at `src/server/tests/TestTeams.server.luau`

Make sure the first line says:
```lua
local ENABLED = true  -- ← Should be true
```

### Step 3: Start 2-Player Test

In Roblox Studio:

1. Click **Test** tab in the ribbon
2. Click the dropdown arrow next to **Play** button
3. Select **2 Players**
4. Click **Start**

## ✅ What You Should See

### In the Output Window

```
═══════════════════════════════════════════════════════
[TestTeams] 🧪 TEAM TESTING ENABLED
[TestTeams] Players will be assigned to teams for testing
═══════════════════════════════════════════════════════

[TestTeams] 👤 Player1 joined
[TestTeams] ✓ Assigned Player1 to red team
[TestTeams]   red team now has 1 player(s)
[TestTeams] 📍 Spawned Player1 at red spawn

[TestTeams] 👤 Player2 joined
[TestTeams] ✓ Assigned Player2 to blue team
[TestTeams]   blue team now has 1 player(s)
[TestTeams] 📍 Spawned Player2 at blue spawn

[TestTeams] 🐺 Spawning test NPCs...
[TestTeams] ✓ Spawned Wolf on red team at -20, 10, 0
[TestTeams] ✓ Spawned Wolf on blue team at 20, 10, 0

═══════════════════════════════════════════════════════
[TestTeams] 📊 TEAM STATUS
═══════════════════════════════════════════════════════

RED TEAM:
  Players (1):
    - Player1
  NPCs (1):
    - Wolf

BLUE TEAM:
  Players (1):
    - Player2
  NPCs (1):
    - Wolf

═══════════════════════════════════════════════════════
[TestTeams] Test relationships:
  Player1 and Player2:
    - Allies: false
    - Enemies: true
    ⚔️ They are enemies - they CAN attack each other
═══════════════════════════════════════════════════════
```

### In the Game

**Player 1 (Red Team):**
- Spawns at position (-50, 10, 0) - left side of map
- Name tag appears in **red color**
- Has a red wolf NPC nearby (-20, 10, 0)
- Can attack Player 2 (blue team)
- Cannot attack red wolf (same team)

**Player 2 (Blue Team):**
- Spawns at position (50, 10, 0) - right side of map
- Name tag appears in **blue color**
- Has a blue wolf NPC nearby (20, 10, 0)
- Can attack Player 1 (red team)
- Cannot attack blue wolf (same team)

## 🧪 Testing Checklist

Try these tests to verify the team system works:

### ✅ Visual Tests
- [ ] Player 1's name tag is **red**
- [ ] Player 2's name tag is **blue**
- [ ] When targeting Player 2, their name shows in **blue** in the target HUD
- [ ] When targeting red wolf, name shows in **red**

### ✅ Combat Tests (Player 1)
- [ ] Can damage Player 2 (blue team) ✓
- [ ] Cannot damage red wolf (same team) ✗
- [ ] Red wolf does not attack Player 1 ✗
- [ ] Blue wolf attacks Player 1 ✓

### ✅ Combat Tests (Player 2)
- [ ] Can damage Player 1 (red team) ✓
- [ ] Cannot damage blue wolf (same team) ✗
- [ ] Blue wolf does not attack Player 2 ✗
- [ ] Red wolf attacks Player 2 ✓

### ✅ AI Tests
- [ ] Red wolf chases Player 2 (enemy)
- [ ] Red wolf ignores Player 1 (ally)
- [ ] Blue wolf chases Player 1 (enemy)
- [ ] Blue wolf ignores Player 2 (ally)

## 🎨 Customizing the Test

Edit `src/server/tests/TestTeams.server.luau`:

```lua
local TEST_CONFIG = {
    -- Change team assignments
    teams = {"red", "blue", "red", "blue"},
    -- Player1=red, Player2=blue, Player3=red, Player4=blue

    -- Disable NPC spawning
    spawnTestNPCs = false,

    -- Change spawn locations
    teamSpawns = {
        red = Vector3.new(-100, 10, 0),   -- Move further apart
        blue = Vector3.new(100, 10, 0),
    },

    -- Add more NPCs
    npcConfig = {
        {entityType = "Wolf", teamId = "red", position = Vector3.new(-20, 10, 0)},
        {entityType = "Wolf", teamId = "blue", position = Vector3.new(20, 10, 0)},
        {entityType = "Bear", teamId = "red", position = Vector3.new(-30, 10, 0)},
        {entityType = "Bear", teamId = "blue", position = Vector3.new(30, 10, 0)},
    },
}
```

## 🐛 Troubleshooting

### Players not assigned to teams

**Check 1:** Is `ENABLED = true` in TestTeams.server.luau?
**Check 2:** Did you wait 2 seconds after starting? (TeamManager needs to initialize)
**Check 3:** Check Output window for errors

### Name tags not showing colors

**Check 1:** Is `teams.enabled = true` in GameConfig.luau?
**Check 2:** Did you rebuild the project? (`rojo build -o "roblox-camping.rbxlx"`)
**Check 3:** Check that GameConfig is in `ReplicatedStorage/Engine/Config`

### Players can still damage teammates

**Check 1:** Is `combat.teamBased = true` in GameConfig.luau?
**Check 2:** Is `combat.friendlyFire = false` in GameConfig.luau?
**Check 3:** Did you rebuild after changing config?

### NPCs attacking everyone

**Check 1:** Are NPCs assigned to teams? Check Output for spawn messages
**Check 2:** Is `combat.teamBased = true`?
**Check 3:** Check entity's team: `print(wolf:GetAttribute("TeamId"))`

## 🔧 Manual Testing (Without Test Script)

If you don't want to use the test script, add this to a new Script in ServerScriptService:

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local TeamManager = require(ServerScriptService.Engine.TeamManager)

local teams = {"red", "blue"}
local index = 1

Players.PlayerAdded:Connect(function(player)
    task.wait(2)  -- Wait for TeamManager

    local team = teams[index]
    TeamManager.assignPlayerToTeam(player, team)

    print(`Assigned {player.Name} to {team}`)

    index = index + 1
    if index > #teams then
        index = 1
    end
end)
```

## 📚 Next Steps

Once local testing works:

1. **Disable test script** - Set `ENABLED = false` in TestTeams.server.luau
2. **Implement matchmaking** - See [GUIDE_TEAM_SETUP.md](GUIDE_TEAM_SETUP.md#method-1-from-external-matchmaking-place-recommended)
3. **Deploy to production** - Publish your game!

## 🎯 Expected Results Summary

| Interaction | Result | Why |
|------------|--------|-----|
| Player 1 attacks Player 2 | ✓ Damage | Different teams (red vs blue) |
| Player 2 attacks Player 1 | ✓ Damage | Different teams (blue vs red) |
| Player 1 attacks Red Wolf | ✗ No damage | Same team (red) |
| Player 2 attacks Blue Wolf | ✗ No damage | Same team (blue) |
| Player 1 attacks Blue Wolf | ✓ Damage | Different teams |
| Player 2 attacks Red Wolf | ✓ Damage | Different teams |
| Red Wolf targets Player 1 | ✗ Ignores | Same team |
| Red Wolf targets Player 2 | ✓ Attacks | Enemy team |
| Blue Wolf targets Player 1 | ✓ Attacks | Enemy team |
| Blue Wolf targets Player 2 | ✗ Ignores | Same team |

---

**Need more help?** See the full guide: [GUIDE_TEAM_SETUP.md](GUIDE_TEAM_SETUP.md)
