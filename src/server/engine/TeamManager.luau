--!strict

--[[
	TeamManager - Team System for Players and Entities

	Manages team assignments for players and NPCs/entities.
	Supports team-based gameplay with ally/enemy relationships.

	Teams are session-based (not persistent) and can be set by:
	- External matchmaking place via TeleportData
	- Server-side team assignment for NPCs/pets/monsters

	Usage:
		TeamManager.assignPlayerToTeam(player, "red")
		TeamManager.assignEntityToTeam(wolfModel, "blue", ownerPlayer)
		TeamManager.areAllies(player1, player2) -- true/false
		TeamManager.areEnemies(player, npcModel) -- true/false
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(script.Parent.Config.GameConfig)
local RemoteEventsModule = require(ReplicatedStorage.Engine:WaitForChild("Core"):WaitForChild("RemoteEvents"))

local TeamManager = {}

-- Constants
local TEAM_ATTRIBUTE = "TeamId"
local OWNER_ATTRIBUTE = "OwnerId"
local DEFAULT_TEAM = "neutral"

-- Active teams tracking (for queries)
local playerTeams: {[Player]: string} = {} -- Cache for fast lookups
local entityTeams: {[Model]: string} = {} -- Cache for entity teams

--[[
	Get team configuration from GameConfig

	@param teamId - Team identifier
	@return Team config or nil
]]
local function getTeamConfig(teamId: string): any?
	if not GameConfig.teams or not GameConfig.teams.teams then
		return nil
	end
	return GameConfig.teams.teams[teamId]
end

--[[
	Assign player to a team

	@param player - Player to assign
	@param teamId - Team identifier (from GameConfig.teams.teams)
]]
function TeamManager.assignPlayerToTeam(player: Player, teamId: string)
	-- Validate team exists
	if not getTeamConfig(teamId) then
		warn(`[TeamManager] Invalid team: {teamId}, using default team: {DEFAULT_TEAM}`)
		teamId = DEFAULT_TEAM
	end

	-- Store in cache
	playerTeams[player] = teamId

	-- Set attribute on player (for replication)
	player:SetAttribute(TEAM_ATTRIBUTE, teamId)

	-- Set attribute on character if loaded
	if player.Character then
		player.Character:SetAttribute(TEAM_ATTRIBUTE, teamId)
	end

	-- Update on future character spawns
	player.CharacterAdded:Connect(function(character)
		character:SetAttribute(TEAM_ATTRIBUTE, teamId)
	end)

	print(`[TeamManager] {player.Name} assigned to team: {teamId}`)

	-- Fire event to client for UI updates
	local RemoteEvents = RemoteEventsModule.Events
	if RemoteEvents.TeamAssigned then
		RemoteEvents.TeamAssigned:FireClient(player, teamId)
	end
end

--[[
	Assign entity to a team (for NPCs, pets, monsters)

	@param model - Entity model
	@param teamId - Team identifier
	@param owner - Optional owning player (for pets/owned entities)
]]
function TeamManager.assignEntityToTeam(model: Model, teamId: string, owner: Player?)
	-- Validate team exists
	if not getTeamConfig(teamId) then
		warn(`[TeamManager] Invalid team: {teamId}, using default team: {DEFAULT_TEAM}`)
		teamId = DEFAULT_TEAM
	end

	-- Store in cache
	entityTeams[model] = teamId

	-- Set attributes on model
	model:SetAttribute(TEAM_ATTRIBUTE, teamId)

	if owner then
		model:SetAttribute(OWNER_ATTRIBUTE, owner.UserId)
	end

	print(`[TeamManager] Entity {model.Name} assigned to team: {teamId}`)
end

--[[
	Get team ID for a player or entity

	@param modelOrPlayer - Player or Model instance
	@return Team ID or nil
]]
function TeamManager.getTeamId(modelOrPlayer: Player | Model): string?
	-- Check if teams are enabled
	if not GameConfig.teams or not GameConfig.teams.enabled then
		return DEFAULT_TEAM
	end

	-- Handle Player
	if typeof(modelOrPlayer) == "Instance" and modelOrPlayer:IsA("Player") then
		local player = modelOrPlayer :: Player
		-- Check cache first
		if playerTeams[player] then
			return playerTeams[player]
		end
		-- Fallback to attribute
		return player:GetAttribute(TEAM_ATTRIBUTE) or DEFAULT_TEAM
	end

	-- Handle Model (Character or Entity)
	if typeof(modelOrPlayer) == "Instance" and modelOrPlayer:IsA("Model") then
		local model = modelOrPlayer :: Model

		-- Check if it's a player character
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			return TeamManager.getTeamId(player)
		end

		-- Check cache first
		if entityTeams[model] then
			return entityTeams[model]
		end

		-- Fallback to attribute
		return model:GetAttribute(TEAM_ATTRIBUTE) or DEFAULT_TEAM
	end

	return DEFAULT_TEAM
end

--[[
	Check if two entities are allies (same team)

	@param entity1 - Player or Model
	@param entity2 - Player or Model
	@return true if allies
]]
function TeamManager.areAllies(entity1: Player | Model, entity2: Player | Model): boolean
	-- If teams disabled, everyone is neutral (no allies/enemies)
	if not GameConfig.teams or not GameConfig.teams.enabled then
		return false
	end

	local team1 = TeamManager.getTeamId(entity1)
	local team2 = TeamManager.getTeamId(entity2)

	if not team1 or not team2 then
		return false
	end

	-- Same team = allies
	return team1 == team2
end

--[[
	Check if two entities are enemies (different teams)

	@param entity1 - Player or Model
	@param entity2 - Player or Model
	@return true if enemies

	Neutral team behavior:
	- Neutral entities can be attacked by any team (wildlife, resources)
	- Neutral entities don't attack other neutral entities (same team)
	- Useful for huntable wildlife, gatherable resources, ambient NPCs
]]
function TeamManager.areEnemies(entity1: Player | Model, entity2: Player | Model): boolean
	-- If teams disabled, use default PvP rules
	if not GameConfig.teams or not GameConfig.teams.enabled then
		return true -- Default: everything is potentially hostile
	end

	local team1 = TeamManager.getTeamId(entity1)
	local team2 = TeamManager.getTeamId(entity2)

	if not team1 or not team2 then
		return false
	end

	-- Same team = not enemies (includes neutral-to-neutral)
	if team1 == team2 then
		return false
	end

	-- Different teams = enemies (including neutral)
	-- This allows any team to attack neutral entities (wildlife, resources)
	-- But neutral entities won't attack each other (same team check above)
	return true
end

--[[
	Get all players on a team

	@param teamId - Team identifier
	@return Array of players
]]
function TeamManager.getTeamMembers(teamId: string): {Player}
	local members: {Player} = {}

	for _, player in Players:GetPlayers() do
		if TeamManager.getTeamId(player) == teamId then
			table.insert(members, player)
		end
	end

	return members
end

--[[
	Get all entities on a team

	@param teamId - Team identifier
	@return Array of entity models
]]
function TeamManager.getTeamEntities(teamId: string): {Model}
	local entities: {Model} = {}

	for model, team in entityTeams do
		if team == teamId and model.Parent then
			table.insert(entities, model)
		end
	end

	return entities
end

--[[
	Get team color for UI display

	@param teamId - Team identifier
	@return Color3
]]
function TeamManager.getTeamColor(teamId: string): Color3
	local teamConfig = getTeamConfig(teamId)
	if teamConfig and teamConfig.color then
		return teamConfig.color
	end

	-- Default: white/gray for neutral
	return Color3.fromRGB(200, 200, 200)
end

--[[
	Get team name for display

	@param teamId - Team identifier
	@return Team name
]]
function TeamManager.getTeamName(teamId: string): string
	local teamConfig = getTeamConfig(teamId)
	if teamConfig and teamConfig.name then
		return teamConfig.name
	end

	return teamId
end

--[[
	Remove player from team system (cleanup on leave)

	@param player - Player leaving
]]
function TeamManager.removePlayer(player: Player)
	playerTeams[player] = nil
end

--[[
	Remove entity from team system (cleanup on despawn)

	@param model - Entity model
]]
function TeamManager.removeEntity(model: Model)
	entityTeams[model] = nil
end

--[[
	Handle player join - assign team from TeleportData

	@param player - Player joining
]]
local function onPlayerAdded(player: Player)
	-- Check if teams are enabled
	if not GameConfig.teams or not GameConfig.teams.enabled then
		-- Assign to default team even if disabled (for consistency)
		TeamManager.assignPlayerToTeam(player, DEFAULT_TEAM)
		return
	end

	-- Try to read team from TeleportData (from external matchmaking place)
	local joinData = player:GetJoinData()
	local teamId = DEFAULT_TEAM

	if joinData and joinData.TeleportData then
		local teleportData = joinData.TeleportData
		if teleportData.TeamId and type(teleportData.TeamId) == "string" then
			teamId = teleportData.TeamId
			print(`[TeamManager] Player {player.Name} joined with team: {teamId} (from TeleportData)`)
		end
	else
		-- No teleport data - could be direct join (testing) or single-player
		print(`[TeamManager] Player {player.Name} joined without TeleportData, assigning to default team: {DEFAULT_TEAM}`)
	end

	-- Assign player to team
	TeamManager.assignPlayerToTeam(player, teamId)
end

--[[
	Initialize team system
]]
function TeamManager.initialize()
	print("[TeamManager] Initializing team system...")

	-- Check if teams are enabled
	if not GameConfig.teams or not GameConfig.teams.enabled then
		print("[TeamManager] Team system disabled in GameConfig")
	end

	-- Handle player join (assign team from TeleportData)
	Players.PlayerAdded:Connect(onPlayerAdded)

	-- Handle existing players (hot reload support)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		TeamManager.removePlayer(player)
	end)

	print("[TeamManager] ✓ Initialized")
end

return TeamManager
