--[[
	SpawnConfig.luau
	Platform module defining spawn configuration types and interfaces.

	This module provides the contract between platform spawning logic and
	game-specific spawn configuration sources (workspace, JSON, database, etc.)
]]

-- Type definition for a single spawn point
export type SpawnPoint = {
	entityType: string, -- Entity type name (e.g., "Wolf", "Bear", "Zombie")
	position: Vector3, -- World position where entities should spawn
	count: number, -- Number of entities to spawn at this point
	spawnRadius: number?, -- Optional: radius around position for spawn distribution (default: 10)
	respawnTime: number?, -- Optional: seconds before entities respawn after death (default: 30)
	maxActive: number?, -- Optional: maximum concurrent entities from this spawn point
}

-- Default values for optional spawn point properties
local SpawnConfig = {}

SpawnConfig.DEFAULTS = {
	spawnRadius = 10, -- studs
	respawnTime = 30, -- seconds
	maxActive = nil, -- nil = unlimited
}

--[[
	Validates a spawn point configuration.
	Returns (isValid: boolean, errorMessage: string?)
]]
function SpawnConfig.validate(spawnPoint: SpawnPoint): (boolean, string?)
	if not spawnPoint.entityType or spawnPoint.entityType == "" then
		return false, "entityType is required and cannot be empty"
	end

	if not spawnPoint.position then
		return false, "position is required"
	end

	if not spawnPoint.count or spawnPoint.count < 1 then
		return false, "count must be at least 1"
	end

	if spawnPoint.spawnRadius and spawnPoint.spawnRadius < 0 then
		return false, "spawnRadius cannot be negative"
	end

	if spawnPoint.respawnTime and spawnPoint.respawnTime < 0 then
		return false, "respawnTime cannot be negative"
	end

	if spawnPoint.maxActive and spawnPoint.maxActive < 1 then
		return false, "maxActive must be at least 1"
	end

	return true, nil
end

--[[
	Applies default values to optional spawn point properties.
	Returns a new SpawnPoint with defaults applied.
]]
function SpawnConfig.applyDefaults(spawnPoint: SpawnPoint): SpawnPoint
	return {
		entityType = spawnPoint.entityType,
		position = spawnPoint.position,
		count = spawnPoint.count,
		spawnRadius = spawnPoint.spawnRadius or SpawnConfig.DEFAULTS.spawnRadius,
		respawnTime = spawnPoint.respawnTime or SpawnConfig.DEFAULTS.respawnTime,
		maxActive = spawnPoint.maxActive or SpawnConfig.DEFAULTS.maxActive,
	}
end

return SpawnConfig
