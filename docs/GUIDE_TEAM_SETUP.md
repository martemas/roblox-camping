# Team System Setup Guide

This guide explains how to set up and use the team system in your Roblox camping game.

## Overview

The team system allows you to:
- Assign players to teams (Red, Blue, Green, Neutral)
- Control PvP combat between teams
- Assign NPCs/monsters/pets to teams
- Display team colors on UI elements
- Integrate with external matchmaking places

## Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration](#configuration)
3. [Player Team Assignment](#player-team-assignment)
4. [NPC Team Assignment](#npc-team-assignment)
5. [Testing Teams Locally](#testing-teams-locally)
6. [Advanced Usage](#advanced-usage)

---

## Quick Start

### Enable the Team System

1. Open [GameConfig.luau](../src/server/engine/Config/GameConfig.luau)
2. Set `teams.enabled = true`:

```lua
teams = {
    enabled = true,  -- Enable team system
    defaultTeam = "neutral",
    teams = {
        red = { name = "Red Team", color = Color3.fromRGB(255, 50, 50) },
        blue = { name = "Blue Team", color = Color3.fromRGB(50, 100, 255) },
        green = { name = "Green Team", color = Color3.fromRGB(50, 255, 50) },
        neutral = { name = "Neutral", color = Color3.fromRGB(200, 200, 200) },
    },
}
```

3. Enable team-based combat:

```lua
combat = {
    teamBased = true,      -- Enable team-based combat rules
    friendlyFire = false,  -- Prevent teammates from damaging each other
    pvpEnabled = true,     -- Allow PvP between different teams
}
```

4. Rebuild your project: `rojo build -o "roblox-camping.rbxlx"`

---

## Configuration

### Team Definitions

Teams are defined in `GameConfig.teams.teams`. Each team has:

```lua
{
    name = "Team Display Name",  -- Shown in UI
    color = Color3.fromRGB(r, g, b)  -- Used for name tags and HUD
}
```

### Adding a New Team

```lua
teams = {
    enabled = true,
    defaultTeam = "neutral",
    teams = {
        -- Existing teams...
        yellow = {
            name = "Yellow Team",
            color = Color3.fromRGB(255, 255, 0),
        },
    },
}
```

### Combat Settings

```lua
combat = {
    teamBased = true,       -- Use team rules for combat
    friendlyFire = false,   -- true = teammates can damage each other
    pvpEnabled = true,      -- true = different teams can fight
}
```

**Behavior Matrix:**

| Setting | Result |
|---------|--------|
| `teamBased = false` | Classic FFA mode (ignore teams) |
| `teamBased = true, friendlyFire = false` | Teammates cannot damage each other |
| `teamBased = true, friendlyFire = true` | Teammates can damage each other |
| `pvpEnabled = false` | No player vs player combat |

---

## Player Team Assignment

### Method 1: From External Matchmaking Place (Recommended)

This is the intended workflow for production games with a lobby/matchmaking system.

#### Step 1: Matchmaking Place Setup

In your matchmaking/lobby place:

```lua
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local GAME_PLACE_ID = 123456789  -- Your main game place ID

-- Function to start a match
local function startMatch(redTeamPlayers, blueTeamPlayers)
    -- Teleport Red Team
    local redTeleportData = {
        TeamId = "red",
        MatchId = "match_" .. os.time(),
    }
    TeleportService:TeleportAsync(GAME_PLACE_ID, redTeamPlayers, {
        TeleportData = redTeleportData
    })

    -- Teleport Blue Team
    local blueTeleportData = {
        TeamId = "blue",
        MatchId = "match_" .. os.time(),
    }
    TeleportService:TeleportAsync(GAME_PLACE_ID, blueTeamPlayers, {
        TeleportData = blueTeleportData
    })
end

-- Example: 2v2 matchmaking
local function matchmakePlayers()
    local waitingPlayers = getWaitingPlayers()  -- Your matchmaking logic

    if #waitingPlayers >= 4 then
        local redTeam = {waitingPlayers[1], waitingPlayers[2]}
        local blueTeam = {waitingPlayers[3], waitingPlayers[4]}

        startMatch(redTeam, blueTeam)
    end
end
```

#### Step 2: Game Place Receives Teams

The game automatically reads `TeleportData.TeamId` and assigns teams on join. No additional code needed!

**How it works internally:**

```lua
-- In TeamManager.luau (already implemented)
local function onPlayerAdded(player: Player)
    local joinData = player:GetJoinData()
    local teamId = "neutral"  -- Default

    if joinData and joinData.TeleportData then
        local teleportData = joinData.TeleportData
        if teleportData.TeamId then
            teamId = teleportData.TeamId
        end
    end

    TeamManager.assignPlayerToTeam(player, teamId)
end
```

### Method 2: Manual Assignment (Testing/Custom Logic)

For testing or custom game modes, manually assign teams:

```lua
local TeamManager = require(ServerScriptService.Engine.TeamManager)

-- Assign a player to a team
TeamManager.assignPlayerToTeam(player, "red")

-- Assign based on player count (auto-balance)
Players.PlayerAdded:Connect(function(player)
    local redCount = #TeamManager.getTeamMembers("red")
    local blueCount = #TeamManager.getTeamMembers("blue")

    if redCount <= blueCount then
        TeamManager.assignPlayerToTeam(player, "red")
    else
        TeamManager.assignPlayerToTeam(player, "blue")
    end
end)
```

### Method 3: GUI-Based Team Selection

Allow players to choose their team:

```lua
-- Client: Send team selection to server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Engine.Core.RemoteEvents)

-- Create a RemoteEvent for team selection
local SelectTeamEvent = RemoteEvents.Events.SelectTeam  -- Add this to RemoteEvents.luau

-- Client script
redTeamButton.Activated:Connect(function()
    SelectTeamEvent:FireServer("red")
end)

blueTeamButton.Activated:Connect(function()
    SelectTeamEvent:FireServer("blue")
end)
```

```lua
-- Server: Handle team selection
local TeamManager = require(ServerScriptService.Engine.TeamManager)

SelectTeamEvent.OnServerEvent:Connect(function(player, teamId)
    -- Validate team exists
    if GameConfig.teams.teams[teamId] then
        -- Optional: Check if team switching is allowed
        local currentTeam = TeamManager.getTeamId(player)
        if currentTeam == "neutral" then
            TeamManager.assignPlayerToTeam(player, teamId)
            print(`{player.Name} joined {teamId} team`)
        else
            warn(`{player.Name} already on team {currentTeam}`)
        end
    end
end)
```

---

## NPC Team Assignment

### Spawning NPCs with Teams

```lua
local EntitySpawner = require(ServerScriptService.Engine.Entities.EntitySpawner)

-- Spawn a wolf on red team
EntitySpawner.spawnEntity({
    entityType = "Wolf",
    location = { type = "point", position = Vector3.new(0, 10, 0) },
    level = 5,
    teamId = "red",  -- Assign to red team
})

-- Spawn a pet owned by a player
EntitySpawner.spawnEntity({
    entityType = "Wolf",
    location = { type = "point", position = Vector3.new(0, 10, 0) },
    level = 5,
    teamId = TeamManager.getTeamId(player),  -- Same team as owner
    ownerId = player,  -- Mark as owned by player
})
```

### Dynamic Team Assignment

```lua
local TeamManager = require(ServerScriptService.Engine.TeamManager)

-- Assign existing entity to a team
local wolf = workspace.Entities.Wolf
TeamManager.assignEntityToTeam(wolf, "blue")

-- Assign entity to player's team
TeamManager.assignEntityToTeam(wolf, TeamManager.getTeamId(player), player)
```

### Wave Spawning with Teams

```lua
-- Spawn a wave of monsters for red team
local spawnConfigs = {
    {
        entityType = "Zombie",
        location = { type = "perimeter", center = Vector3.new(0, 0, 0), minRadius = 50, maxRadius = 100 },
        level = 10,
        count = 5,
        teamId = "red",
    },
}

EntitySpawner.spawnWave(spawnConfigs)
```

---

## Testing Teams Locally

### Quick Start: Using the Test Script (Recommended)

We've included a test script to make local testing easy!

**Steps:**

1. **Enable teams** in [GameConfig.luau](../src/server/engine/Config/GameConfig.luau):
   ```lua
   teams = { enabled = true }
   combat = { teamBased = true }
   ```

2. **Enable the test script** (already included):
   - Open [TestTeams.server.luau](../src/server/tests/TestTeams.server.luau)
   - Make sure `ENABLED = true` at the top

3. **Start multi-player test** in Roblox Studio:
   - Click **Test** tab
   - Click dropdown next to **Play** button
   - Select **2 Players** (or more)
   - Click **Start**

4. **Watch the output window** for team assignments:
   ```
   [TestTeams] ✓ Assigned Player1 to red team
   [TestTeams] ✓ Assigned Player2 to blue team
   [TestTeams] 📍 Spawned Player1 at red spawn
   [TestTeams] 📍 Spawned Player2 at blue spawn
   [TestTeams] 🐺 Spawning test NPCs...
   ```

**What the test script does:**
- ✅ Assigns Player 1 to Red Team, Player 2 to Blue Team
- ✅ Spawns players at team-specific locations (separated for easy testing)
- ✅ Spawns test NPCs on each team
- ✅ Prints team status and relationships
- ✅ Shows if players can attack each other

**To customize the test script:**
```lua
-- In TestTeams.server.luau
local TEST_CONFIG = {
    teams = {"red", "blue", "green", "neutral"},  -- Change team assignments
    spawnTestNPCs = true,  -- Set false to disable NPC spawning
    teamSpawns = {
        red = Vector3.new(-50, 10, 0),    -- Change spawn positions
        blue = Vector3.new(50, 10, 0),
    },
}
```

### Manual Testing (Alternative Method)

If you want to write your own test logic instead of using the test script:

**Single-Player Testing:**

```lua
-- Create a new script in ServerScriptService
local TeamManager = require(ServerScriptService.Engine.TeamManager)

game.Players.PlayerAdded:Connect(function(player)
    task.wait(2)  -- Wait for TeamManager to initialize

    -- Override team for testing
    TeamManager.assignPlayerToTeam(player, "red")
    print(`Assigned {player.Name} to red team for testing`)
end)
```

**Multi-Player Testing (Two Clients):**

```lua
local TeamManager = require(ServerScriptService.Engine.TeamManager)
local teams = {"red", "blue"}
local currentIndex = 1

game.Players.PlayerAdded:Connect(function(player)
    task.wait(2)

    local team = teams[currentIndex]
    TeamManager.assignPlayerToTeam(player, team)

    print(`Test: Assigned {player.Name} to {team} team`)

    currentIndex = currentIndex + 1
    if currentIndex > #teams then
        currentIndex = 1
    end
end)
```

### Verifying Team Assignment

```lua
-- Check player's team
local teamId = TeamManager.getTeamId(player)
print(`{player.Name} is on team: {teamId}`)

-- Check if two players are allies
if TeamManager.areAllies(player1, player2) then
    print("Players are teammates!")
else
    print("Players are enemies!")
end

-- Get all team members
local redTeamMembers = TeamManager.getTeamMembers("red")
print(`Red team has {#redTeamMembers} players`)
```

---

## Advanced Usage

### Custom Team Logic

```lua
local TeamManager = require(ServerScriptService.Engine.TeamManager)

-- Assign based on player data
game.Players.PlayerAdded:Connect(function(player)
    local profileStore = getPlayerProfile(player)
    local preferredTeam = profileStore.Data.preferredTeam

    if preferredTeam then
        TeamManager.assignPlayerToTeam(player, preferredTeam)
    end
end)
```

### Team Balancing

```lua
local function getSmallestTeam()
    local teams = {"red", "blue", "green"}
    local smallestTeam = teams[1]
    local smallestCount = #TeamManager.getTeamMembers(smallestTeam)

    for _, teamId in teams do
        local count = #TeamManager.getTeamMembers(teamId)
        if count < smallestCount then
            smallestTeam = teamId
            smallestCount = count
        end
    end

    return smallestTeam
end

game.Players.PlayerAdded:Connect(function(player)
    task.wait(2)
    local team = getSmallestTeam()
    TeamManager.assignPlayerToTeam(player, team)
end)
```

### Team Switching

```lua
local TEAM_SWITCH_COOLDOWN = 60  -- seconds
local lastSwitchTime = {}

local function canSwitchTeam(player)
    local lastSwitch = lastSwitchTime[player.UserId] or 0
    return (os.time() - lastSwitch) >= TEAM_SWITCH_COOLDOWN
end

SelectTeamEvent.OnServerEvent:Connect(function(player, newTeamId)
    if not canSwitchTeam(player) then
        warn(`{player.Name} must wait before switching teams`)
        return
    end

    TeamManager.assignPlayerToTeam(player, newTeamId)
    lastSwitchTime[player.UserId] = os.time()
end)
```

### Team-Specific Spawns

```lua
local TeamSpawns = {
    red = Vector3.new(-100, 10, 0),
    blue = Vector3.new(100, 10, 0),
    green = Vector3.new(0, 10, 100),
    neutral = Vector3.new(0, 10, 0),
}

game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        task.wait(0.1)

        local teamId = TeamManager.getTeamId(player)
        local spawnPos = TeamSpawns[teamId] or TeamSpawns.neutral

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(spawnPos)
        end
    end)
end)
```

### Team-Based Objectives

```lua
-- Capture the Flag example
local FlagManager = {}
FlagManager.flags = {
    red = workspace.RedFlag,
    blue = workspace.BlueFlag,
}

function FlagManager.canPickupFlag(player, flag)
    local playerTeam = TeamManager.getTeamId(player)
    local flagTeam = flag:GetAttribute("TeamId")

    -- Can only pick up enemy flags
    return TeamManager.areEnemies(player, flag)
end

function FlagManager.onFlagTouched(flag, otherPart)
    local player = game.Players:GetPlayerFromCharacter(otherPart.Parent)
    if not player then return end

    if FlagManager.canPickupFlag(player, flag) then
        -- Award points, etc.
        print(`{player.Name} captured the flag!`)
    end
end
```

---

## Troubleshooting

### Teams Not Working

**Check 1:** Is the system enabled?
```lua
-- In GameConfig.luau
teams = { enabled = true }
combat = { teamBased = true }
```

**Check 2:** Did TeamManager initialize?
- Check server output for: `[TeamManager] ✓ Initialized`

**Check 3:** Check player's team attribute:
```lua
print(player:GetAttribute("TeamId"))  -- Should print team name
```

### Players Assigned to Wrong Team

- Check `player:GetJoinData().TeleportData` in server console
- Verify TeleportService is passing `TeamId` correctly
- Check for multiple team assignment calls

### NPCs Not Respecting Teams

**Check 1:** Is the entity assigned to a team?
```lua
print(entity:GetAttribute("TeamId"))
```

**Check 2:** Verify combat settings:
```lua
combat = {
    teamBased = true,  -- Must be true
}
```

### Team Colors Not Showing

**Check 1:** Verify team config has colors:
```lua
teams = {
    teams = {
        red = { color = Color3.fromRGB(255, 50, 50) }  -- Must have color
    }
}
```

**Check 2:** Check GameConfig is accessible from client:
- GameConfig should be in `ReplicatedStorage.Engine.Config`

---

## API Reference

### TeamManager Functions

```lua
-- Assign player to team
TeamManager.assignPlayerToTeam(player: Player, teamId: string)

-- Assign entity/NPC to team
TeamManager.assignEntityToTeam(model: Model, teamId: string, owner: Player?)

-- Get team ID
TeamManager.getTeamId(modelOrPlayer: Player | Model): string?

-- Check relationships
TeamManager.areAllies(entity1: Player | Model, entity2: Player | Model): boolean
TeamManager.areEnemies(entity1: Player | Model, entity2: Player | Model): boolean

-- Get team members
TeamManager.getTeamMembers(teamId: string): {Player}
TeamManager.getTeamEntities(teamId: string): {Model}

-- Get team info
TeamManager.getTeamColor(teamId: string): Color3
TeamManager.getTeamName(teamId: string): string
```

---

## Examples

### Complete Matchmaking Example

**Lobby Place:**
```lua
local TeleportService = game:GetService("TeleportService")
local GAME_PLACE_ID = 123456789

local function teleportTeamsToGame(redPlayers, bluePlayers)
    -- Teleport red team
    TeleportService:TeleportAsync(GAME_PLACE_ID, redPlayers, {
        TeleportData = { TeamId = "red" }
    })

    -- Teleport blue team
    TeleportService:TeleportAsync(GAME_PLACE_ID, bluePlayers, {
        TeleportData = { TeamId = "blue" }
    })
end
```

**Game Place (Automatic):**
- Teams are automatically assigned from TeleportData
- No additional code needed!

### Complete Pet System Example

```lua
local PetManager = {}
local activePets = {}

function PetManager.spawnPet(player, petType)
    local TeamManager = require(ServerScriptService.Engine.TeamManager)
    local EntitySpawner = require(ServerScriptService.Engine.Entities.EntitySpawner)

    -- Get player's position and team
    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local position = hrp.Position + Vector3.new(3, 0, 0)

    -- Spawn pet on player's team
    local pet = EntitySpawner.spawnEntity({
        entityType = petType,
        location = { type = "point", position = position },
        level = 1,
        teamId = TeamManager.getTeamId(player),
        ownerId = player,
    })

    if pet then
        activePets[player] = pet
        print(`Spawned {petType} pet for {player.Name}`)
    end
end

return PetManager
```

---

## Best Practices

1. **Always enable `teamBased = true` when using teams**
   - Otherwise combat system ignores team relationships

2. **Use TeleportData for production**
   - Most reliable method for matchmaking
   - Prevents players from choosing their team

3. **Test with 2+ players**
   - Single-player testing can't verify team combat rules
   - Use Studio's multi-player test feature

4. **Assign teams early**
   - TeamManager auto-assigns during PlayerAdded
   - Don't reassign unless necessary (team switching)

5. **Clean up team data**
   - TeamManager handles cleanup automatically on PlayerRemoving
   - No manual cleanup needed

6. **Use neutral team for spectators**
   - Neutral team is not hostile to anyone
   - Perfect for non-combatants

---

## See Also

- [TeamManager.luau](../src/server/engine/TeamManager.luau) - Core implementation
- [GameConfig.luau](../src/server/engine/Config/GameConfig.luau) - Configuration
- [CombatSystem.luau](../src/server/engine/Combat/CombatSystem.luau) - Combat integration
- [EntityController.luau](../src/server/engine/Entities/EntityController.luau) - AI integration
