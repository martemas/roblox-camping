--!strict

--[[
	TEST SCRIPT: Team System Testing

	This script helps you test the team system locally with 2 players in Roblox Studio.

	HOW TO USE:
	1. In Roblox Studio, go to Test tab
	2. Click the dropdown next to "Play" button
	3. Select "2 Players" (or more)
	4. Click "Start"
	5. Watch the output - players will be assigned to different teams

	WHAT IT DOES:
	- Assigns Player 1 to Red Team
	- Assigns Player 2 to Blue Team
	- Additional players alternate between teams
	- Spawns test NPCs on each team
	- Prints team information to console

	TO DISABLE:
	- Set ENABLED = false at the top of this script
	- Or delete this script when done testing
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- ═══════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════

local ENABLED = true  -- Set to false to disable test script

local TEST_CONFIG = {
	-- Team assignment for each player (cycles through this list)
	teams = {"red", "blue", "red", "blue"},  -- Player 1=red, Player 2=blue, etc.

	-- Spawn test NPCs?
	spawnTestNPCs = true,

	-- NPC spawn configuration
	npcConfig = {
		{entityType = "Wolf", teamId = "red", position = Vector3.new(-20, 10, 0)},
		{entityType = "Wolf", teamId = "blue", position = Vector3.new(20, 10, 0)},
	},

	-- Spawn locations for each team
	teamSpawns = {
		red = Vector3.new(-50, 10, 0),
		blue = Vector3.new(50, 10, 0),
		neutral = Vector3.new(0, 10, 0),
	},
}

-- ═══════════════════════════════════════════════════════
-- TEST SCRIPT
-- ═══════════════════════════════════════════════════════

if not ENABLED then
	print("[TestTeams] ⚠️ Test script disabled")
	return
end

print("═══════════════════════════════════════════════════════")
print("[TestTeams] 🧪 TEAM TESTING ENABLED")
print("[TestTeams] Players will be assigned to teams for testing")
print("═══════════════════════════════════════════════════════")

-- Wait for TeamManager to initialize
local TeamManager
task.wait(2)

local success, err = pcall(function()
	TeamManager = require(ServerScriptService.Engine.TeamManager)
end)

if not success or not TeamManager then
	warn("[TestTeams] ❌ Failed to load TeamManager:", err)
	return
end

-- Track player assignments
local playerIndex = 0
local assignedPlayers = {}

-- Function to assign player to team
local function assignPlayerToTeam(player: Player)
	-- Get team for this player
	playerIndex = playerIndex + 1
	local teamIndex = ((playerIndex - 1) % #TEST_CONFIG.teams) + 1
	local teamId = TEST_CONFIG.teams[teamIndex]

	-- Wait a moment for player to load
	task.wait(2)

	-- Assign team
	TeamManager.assignPlayerToTeam(player, teamId)
	assignedPlayers[player] = teamId

	print(`[TestTeams] ✓ Assigned {player.Name} to {teamId} team`)

	-- Print team info
	local teamMembers = TeamManager.getTeamMembers(teamId)
	print(`[TestTeams]   {teamId} team now has {#teamMembers} player(s)`)
end

-- Function to spawn player at team spawn
local function spawnPlayerAtTeamSpawn(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)  -- Wait for character to fully load

		local teamId = assignedPlayers[player]
		if not teamId then return end

		local spawnPos = TEST_CONFIG.teamSpawns[teamId] or TEST_CONFIG.teamSpawns.neutral
		local hrp = character:FindFirstChild("HumanoidRootPart")

		if hrp then
			hrp.CFrame = CFrame.new(spawnPos)
			print(`[TestTeams] 📍 Spawned {player.Name} at {teamId} spawn`)
		end
	end)
end

-- Function to spawn test NPCs
local function spawnTestNPCs()
	if not TEST_CONFIG.spawnTestNPCs then
		return
	end

	task.wait(3)  -- Wait for EntitySpawner to initialize

	local EntitySpawner
	local success, err = pcall(function()
		EntitySpawner = require(ServerScriptService.Engine.Entities.EntitySpawner)
	end)

	if not success or not EntitySpawner then
		warn("[TestTeams] ⚠️ Could not load EntitySpawner:", err)
		return
	end

	print("[TestTeams] 🐺 Spawning test NPCs...")

	for _, config in TEST_CONFIG.npcConfig do
		local npc = EntitySpawner.spawnEntity({
			entityType = config.entityType,
			location = {type = "point", position = config.position},
			level = 5,
			teamId = config.teamId,
		})

		if npc then
			print(`[TestTeams] ✓ Spawned {config.entityType} on {config.teamId} team at {config.position}`)
		end
	end
end

-- Function to print team status
local function printTeamStatus()
	task.wait(5)  -- Wait for all players to load

	print("\n═══════════════════════════════════════════════════════")
	print("[TestTeams] 📊 TEAM STATUS")
	print("═══════════════════════════════════════════════════════")

	local teams = {"red", "blue", "green", "neutral"}

	for _, teamId in teams do
		local members = TeamManager.getTeamMembers(teamId)
		local entities = TeamManager.getTeamEntities(teamId)

		if #members > 0 or #entities > 0 then
			print(`\n{teamId:upper()} TEAM:`)

			if #members > 0 then
				print(`  Players ({#members}):`)
				for _, player in members do
					print(`    - {player.Name}`)
				end
			end

			if #entities > 0 then
				print(`  NPCs ({#entities}):`)
				for _, entity in entities do
					print(`    - {entity.Name}`)
				end
			end
		end
	end

	print("\n═══════════════════════════════════════════════════════")
	print("[TestTeams] Test relationships:")

	local players = Players:GetPlayers()
	if #players >= 2 then
		local p1, p2 = players[1], players[2]
		local areAllies = TeamManager.areAllies(p1, p2)
		local areEnemies = TeamManager.areEnemies(p1, p2)

		print(`  {p1.Name} and {p2.Name}:`)
		print(`    - Allies: {areAllies}`)
		print(`    - Enemies: {areEnemies}`)

		if areAllies then
			print(`    ⚠️ They are on the same team - they should NOT attack each other`)
		elseif areEnemies then
			print(`    ⚔️ They are enemies - they CAN attack each other`)
		else
			print(`    🤝 They are neutral - no hostile actions`)
		end
	end

	print("═══════════════════════════════════════════════════════\n")
end

-- Connect to player events
Players.PlayerAdded:Connect(function(player)
	print(`\n[TestTeams] 👤 {player.Name} joined`)

	-- Assign to team
	assignPlayerToTeam(player)

	-- Set up spawn location
	spawnPlayerAtTeamSpawn(player)
end)

-- Handle players already in game (hot reload support)
for _, player in Players:GetPlayers() do
	assignPlayerToTeam(player)
	spawnPlayerAtTeamSpawn(player)
end

-- Spawn test NPCs
spawnTestNPCs()

-- Print status summary
printTeamStatus()

-- Periodic status updates (every 30 seconds)
task.spawn(function()
	while true do
		task.wait(30)
		printTeamStatus()
	end
end)

print("[TestTeams] ✓ Test script initialized")
print("[TestTeams] 💡 TIP: Check the Output window for team assignments")
