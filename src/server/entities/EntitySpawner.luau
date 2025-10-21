--!strict

--[[
	EntitySpawner - Stateless entity spawning facade

	Responsibilities:
	- Create entity models from templates
	- Position entities based on spawn configuration
	- Initialize entities with EntityController
	- NO state management (EntityController handles that)

	Usage:
		EntitySpawner.spawnEntity({
			entityType = "Wolf",
			location = { type = "random" },
			level = 5,
		})
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("Utils"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EntityController = require(script.Parent:WaitForChild("EntityController"))
local Entities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Entities"))

-- Types
export type SpawnLocation =
	{ type: "point", position: Vector3 }
	| { type: "area", center: Vector3, radius: number }
	| { type: "perimeter", center: Vector3, minRadius: number, maxRadius: number }
	| { type: "random" }
	| { type: "points", positions: {Vector3}, randomize: boolean? }

export type SpawnConfig = {
	entityType: string,
	location: SpawnLocation,
	level: number?,
	count: number?,
	spread: number?,  -- Additional random offset per spawn (for spreading groups)
	spawnPoint: Vector3?,  -- Override spawn memory point (for patrol/wander behavior)
	patrolPoints: {Vector3}?,  -- Override patrol points from config
}

local EntitySpawner = {}

-- Get spawn position based on location config
local function getSpawnPosition(location: SpawnLocation, spread: number?): Vector3
	local position: Vector3

	if location.type == "point" then
		position = location.position

	elseif location.type == "area" then
		local angle = math.random() * math.pi * 2
		local distance = math.random() * location.radius
		local offset = Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)
		position = location.center + offset

	elseif location.type == "perimeter" then
		local angle = math.random() * math.pi * 2
		local distance = location.minRadius + math.random() * (location.maxRadius - location.minRadius)
		local offset = Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)
		position = location.center + offset

	elseif location.type == "random" then
		local mapSize = GameConfig.map.size
		local centerPosition = vector.create(0, 0, 0)
		local minDistance = 50
		local maxDistance = mapSize / 2
		position = Vector3.new(
			Utils.getRandomGroundPosition(centerPosition, minDistance, maxDistance).X,
			Utils.getRandomGroundPosition(centerPosition, minDistance, maxDistance).Y,
			Utils.getRandomGroundPosition(centerPosition, minDistance, maxDistance).Z
		)

	elseif location.type == "points" then
		local positions = location.positions
		local randomize = location.randomize ~= false  -- Default true
		local index = randomize and math.random(1, #positions) or 1
		position = positions[index]
	else
		warn(`Unknown spawn location type: {location.type}`)
		position = Vector3.new(0, 10, 0)
	end

	-- Apply spread if provided
	if spread and spread > 0 then
		local spreadOffset = Vector3.new(
			math.random(-spread, spread),
			0,
			math.random(-spread, spread)
		)
		position = position + spreadOffset
	end

	-- Ensure position is on ground
	local groundPosition = Utils.getRandomGroundPosition(
		vector.create(position.X, position.Y, position.Z),
		0,
		1
	)

	return Vector3.new(groundPosition.X, groundPosition.Y, groundPosition.Z)
end

-- Create entity model from template
local function createEntityModel(entityType: string, position: Vector3): Model?
	-- Get entity data from new Entities.Database
	local entityData = Entities.Database[entityType]

	if not entityData then
		warn(`Entity type '{entityType}' not found in Entities.Database`)
		return nil
	end

	if not entityData.spawnModel then
		warn(`No spawnModel defined for entity: {entityType}`)
		return nil
	end

	-- Parse spawn model path (e.g., "Wildlife/Wolf")
	local modelPath = entityData.spawnModel
	local pathParts = string.split(modelPath, "/")

	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return nil
	end

	local entitiesFolder = modelsFolder:FindFirstChild("Entities")
	if not entitiesFolder then
		warn("Entities folder not found in ReplicatedStorage.Models")
		return nil
	end

	-- Navigate through the path
	local currentFolder = entitiesFolder
	for i = 1, #pathParts - 1 do
		currentFolder = currentFolder:FindFirstChild(pathParts[i])
		if not currentFolder then
			warn(`Path '{pathParts[i]}' not found in model hierarchy for {entityType}`)
			return nil
		end
	end

	-- Get the actual model template
	local template = currentFolder:FindFirstChild(pathParts[#pathParts])
	if not template then
		warn(`Entity template '{pathParts[#pathParts]}' not found at path: {modelPath}`)
		return nil
	end

	local model = template:Clone()
	model.Parent = workspace

	-- Position the model
	if model.PrimaryPart then
		model:SetPrimaryPartCFrame(CFrame.new(position))

		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "Entities"
			end
		end
	else
		warn(`ERROR - Model '{entityType}' has no PrimaryPart, attempting to position manually`)
		-- Fallback: move the first BasePart found
		local firstPart = model:FindFirstChildOfClass("BasePart")
		if firstPart then
			firstPart.CFrame = CFrame.new(position)
		else
			warn(`ERROR - No BasePart found in {entityType} model for positioning`)
			model:Destroy()
			return nil
		end
	end

	return model
end

-- Spawn a single entity
function EntitySpawner.spawnEntity(config: SpawnConfig): Model?
	-- Validate entity type exists
	local entityConfig = Entities.Database[config.entityType]
	if not entityConfig then
		warn(`Entity type '{config.entityType}' not found in GameConfig.entities`)
		return nil
	end

	-- Get spawn position
	local position = getSpawnPosition(config.location, config.spread)

	-- Create model
	local model = createEntityModel(config.entityType, position)
	if not model then
		return nil
	end

	-- Set level if provided
	local level = config.level or 1
	model:SetAttribute("Level", level)

	-- Set spawn point for return behavior (use config override or actual spawn position)
	local spawnPoint = config.spawnPoint or position
	model:SetAttribute("SpawnPoint", spawnPoint)

	-- Set patrol points if provided
	if config.patrolPoints then
		-- Store patrol points as JSON string (Roblox attributes don't support arrays)
		local patrolPointsJson = game:GetService("HttpService"):JSONEncode(config.patrolPoints)
		model:SetAttribute("PatrolPoints", patrolPointsJson)
	end

	-- Initialize entity with EntityController (handles AI, stats, animations)
	local entity = EntityController.initializeEntity(model, config.entityType)
	if not entity then
		warn(`Failed to initialize entity: {config.entityType}`)
		model:Destroy()
		return nil
	end

	print(`Spawned {config.entityType} (Level {level}) at {position}`)
	return model
end

-- Spawn multiple entities (wave spawning)
function EntitySpawner.spawnWave(configs: {SpawnConfig}): {Model}
	local spawnedModels = {}

	for _, config in configs do
		local count = config.count or 1

		for i = 1, count do
			local model = EntitySpawner.spawnEntity(config)
			if model then
				table.insert(spawnedModels, model)
			end

			-- Small delay between spawns for visual effect
			if i < count then
				task.wait(0.5)
			end
		end
	end

	print(`Spawned wave: {#spawnedModels} entities`)
	return spawnedModels
end

-- Despawn entity (removes from EntityController and destroys model)
function EntitySpawner.despawnEntity(model: Model)
	EntityController.removeEntity(model)
	model:Destroy()
end

-- Get spawn configuration for entity type (helper for quick spawning)
function EntitySpawner.getDefaultSpawnConfig(entityType: string): SpawnConfig?
	local entityData = Entities.Database[entityType]
	if not entityData then
		return nil
	end

	-- Default spawn config based on entity category
	local category = entityData.type

	if category == "Wildlife" then
		-- Wildlife spawns randomly around map
		return {
			entityType = entityType,
			location = { type = "random" },
			level = 1,
		}
	elseif category == "Creature" then
		-- Creatures spawn at perimeter (for night attacks)
		local mapSize = GameConfig.map.size
		return {
			entityType = entityType,
			location = {
				type = "perimeter",
				center = Vector3.new(0, 0, 0),
				minRadius = mapSize / 2 - 50,
				maxRadius = mapSize / 2 - 20,
			},
			level = 1,
		}
	else
		-- Default: spawn at origin
		return {
			entityType = entityType,
			location = { type = "point", position = Vector3.new(0, 10, 0) },
			level = 1,
		}
	end
end

return EntitySpawner
