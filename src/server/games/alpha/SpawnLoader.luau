--[[
	WorkspaceSpawnLoader.luau
	Game-specific module for loading spawn configurations from workspace parts.

	This module reads parts in the workspace under the "Spawns" folder and converts
	them into standardized SpawnPoint configurations that the platform can use.

	Part Naming Convention: Spawn_<EntityType>
	Examples: Spawn_Wolf, Spawn_Bear, Spawn_Zombie

	Supported Attributes:
	- Entities (number): Number of entities to spawn at this point (default: 1)
	- SpawnRadius (number): Radius around part for spawn distribution (default: 10)
	- RespawnTime (number): Seconds before respawn after death (default: 30)
	- MaxActive (number): Maximum concurrent entities from this spawn point (optional)
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpawnConfig = require(ReplicatedStorage.Engine.Config.SpawnConfig)

type SpawnPoint = SpawnConfig.SpawnPoint

local WorkspaceSpawnLoader = {}

-- Prefix for spawn parts in workspace
local SPAWN_PART_PREFIX = "Spawn_"

-- Name of the folder containing spawn parts
local SPAWNS_FOLDER_NAME = "Spawns"

--[[
	Extracts the entity type from a spawn part name.
	Example: "Spawn_Wolf" -> "Wolf"
	Returns nil if the name doesn't follow the naming convention.
]]
local function extractEntityType(partName: string): string?
	if not string.find(partName, SPAWN_PART_PREFIX, 1, true) then
		return nil
	end

	local entityType = string.sub(partName, #SPAWN_PART_PREFIX + 1)

	if entityType == "" then
		return nil
	end

	return entityType
end

--[[
	Reads attributes from a spawn part and converts them to a SpawnPoint config.
	Returns nil if the part is invalid.
]]
local function parseSpawnPart(part: BasePart): SpawnPoint?
	local entityType = extractEntityType(part.Name)

	if not entityType then
		warn(
			string.format(
				"[WorkspaceSpawnLoader] Invalid spawn part name: '%s'. Expected format: 'Spawn_<EntityType>'",
				part.Name
			)
		)
		return nil
	end

	-- Read attributes with defaults
	local count = part:GetAttribute("Entities") or 1
	local spawnRadius = part:GetAttribute("SpawnRadius")
	local respawnTime = part:GetAttribute("RespawnTime")
	local maxActive = part:GetAttribute("MaxActive")

	-- Validate count
	if type(count) ~= "number" or count < 1 then
		warn(
			string.format(
				"[WorkspaceSpawnLoader] Invalid 'Entities' attribute on '%s'. Must be a number >= 1. Using default: 1",
				part.Name
			)
		)
		count = 1
	end

	-- Validate optional attributes
	if spawnRadius ~= nil and (type(spawnRadius) ~= "number" or spawnRadius < 0) then
		warn(
			string.format(
				"[WorkspaceSpawnLoader] Invalid 'SpawnRadius' attribute on '%s'. Must be a number >= 0. Using default.",
				part.Name
			)
		)
		spawnRadius = nil
	end

	if respawnTime ~= nil and (type(respawnTime) ~= "number" or respawnTime < 0) then
		warn(
			string.format(
				"[WorkspaceSpawnLoader] Invalid 'RespawnTime' attribute on '%s'. Must be a number >= 0. Using default.",
				part.Name
			)
		)
		respawnTime = nil
	end

	if maxActive ~= nil and (type(maxActive) ~= "number" or maxActive < 1) then
		warn(
			string.format(
				"[WorkspaceSpawnLoader] Invalid 'MaxActive' attribute on '%s'. Must be a number >= 1. Ignoring.",
				part.Name
			)
		)
		maxActive = nil
	end

	local spawnPoint: SpawnPoint = {
		entityType = entityType,
		position = part.Position,
		count = count,
		spawnRadius = spawnRadius,
		respawnTime = respawnTime,
		maxActive = maxActive,
	}

	-- Validate the spawn point
	local isValid, errorMessage = SpawnConfig.validate(spawnPoint)
	if not isValid then
		warn(
			string.format(
				"[WorkspaceSpawnLoader] Invalid spawn configuration for '%s': %s",
				part.Name,
				errorMessage or "unknown error"
			)
		)
		return nil
	end

	return spawnPoint
end

--[[
	Loads all spawn configurations from the workspace.
	Returns an array of SpawnPoint configurations.

	Returns an empty array if:
	- The Spawns folder doesn't exist
	- No valid spawn parts are found
	- All spawn parts are invalid
]]
function WorkspaceSpawnLoader.loadSpawnConfigs(): { SpawnPoint }
	local spawnsFolder = Workspace:FindFirstChild(SPAWNS_FOLDER_NAME)

	if not spawnsFolder then
		warn(
			string.format(
				"[WorkspaceSpawnLoader] Spawns folder '%s' not found in workspace. No spawn points will be loaded.",
				SPAWNS_FOLDER_NAME
			)
		)
		return {}
	end

	local spawnPoints: { SpawnPoint } = {}
	local validCount = 0
	local invalidCount = 0

	-- Iterate through all children in the Spawns folder
	for _, child in spawnsFolder:GetChildren() do
		-- Only process BaseParts
		if child:IsA("BasePart") then
			local spawnPoint = parseSpawnPart(child)

			if spawnPoint then
				-- Apply defaults
				spawnPoint = SpawnConfig.applyDefaults(spawnPoint)
				table.insert(spawnPoints, spawnPoint)
				validCount += 1
			else
				invalidCount += 1
			end
		end
	end

	-- print(
	-- 	string.format(
	-- 		"[WorkspaceSpawnLoader] Loaded %d spawn point(s) from workspace. (%d valid, %d invalid)",
	-- 		validCount,
	-- 		validCount,
	-- 		invalidCount
	-- 	)
	-- )

	return spawnPoints
end

return WorkspaceSpawnLoader
