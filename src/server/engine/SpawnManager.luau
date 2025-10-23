--!strict

--[[
	SpawnManager - High-level entity spawning management

	Responsibilities:
	- Maintain wildlife population levels
	- Spawn creature waves during night
	- Handle respawning logic
	- Interface between game systems and EntitySpawner

	This is the main entry point for spawning in the game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Engine = ServerScriptService:WaitForChild("Engine")

local GameConfig = require(Engine.Config.GameConfig)
local EntitySpawner = require(script.Parent.Entities.EntitySpawner)
local EntityController = require(script.Parent.Entities.EntityController)

local SpawnManager = {}

-- Track last spawn check times
local lastWildlifeCheck = 0
local isNightActive = false
local currentNight = 0
local nextWaveTime = 0

-- Initialization guard
local isInitialized = false

-- Maintain wildlife population (passive spawning)
local function maintainWildlifePopulation()
	local currentTime = tick()
	if currentTime - lastWildlifeCheck < 10 then -- Check every 10 seconds
		return
	end
	lastWildlifeCheck = currentTime

	-- Count entities by type
	local entityCounts: {[string]: number} = {}
	for model, entity in EntityController.getActiveEntities() do
		local entityType = entity.entityType
		entityCounts[entityType] = (entityCounts[entityType] or 0) + 1
	end

	-- Spawn missing wildlife
	for entityType, config in GameConfig.entities do
		if config.category ~= "Wildlife" then
			continue
		end

		local currentCount = entityCounts[entityType] or 0
		local maxCount = config.maxCount or 5
		local neededCount = maxCount - currentCount

		if neededCount > 0 then
			print(`Spawning {neededCount} {entityType}(s) to maintain population`)

			for i = 1, neededCount do
				local spawnConfig = EntitySpawner.getDefaultSpawnConfig(entityType)
				if spawnConfig then
					EntitySpawner.spawnEntity(spawnConfig)
				end

				-- Delay between spawns
				if i < neededCount then
					task.wait(0.5)
				end
			end
		end
	end
end

-- Calculate creature count for current night
local function calculateCreatureCount(): number
	local baseCount = GameConfig.nightWaves.baseZombieCount or 5
	local increase = GameConfig.nightWaves.difficultyIncrease or 0.2
	local nightMultiplier = 1 + (currentNight - 1) * increase
	return math.floor(baseCount * nightMultiplier)
end

-- Get current creature count
local function getCreatureCount(): number
	local count = 0
	for model, entity in EntityController.getActiveEntities() do
		if entity.config.category == "Creature" then
			count += 1
		end
	end
	return count
end

-- Spawn a wave of creatures (night attack)
local function spawnCreatureWave()
	-- Check if there are already too many creatures
	local currentCreatureCount = getCreatureCount()
	local maxCreaturesPerWave = calculateCreatureCount()
	local maxCreaturesTotal = maxCreaturesPerWave * 2 -- Allow up to 2 waves worth of creatures

	if currentCreatureCount >= maxCreaturesTotal then
		print(`Skipping wave spawn - too many creatures alive ({currentCreatureCount}/{maxCreaturesTotal})`)
		-- Schedule next wave check
		nextWaveTime = tick() + (GameConfig.nightWaves.waveInterval or 30)
		return
	end

	-- Spawn only enough to reach the max
	local creaturesToSpawn = math.min(maxCreaturesPerWave, maxCreaturesTotal - currentCreatureCount)
	print(`Spawning creature wave for night {currentNight}: {creaturesToSpawn} zombies (current alive: {currentCreatureCount})`)

	local mapSize = GameConfig.map.size
	local spawnConfig = {
		entityType = "Zombie",
		location = {
			type = "perimeter",
			center = Vector3.new(0, 0, 0),
			minRadius = mapSize / 2 - 50,
			maxRadius = mapSize / 2 - 20,
		},
		count = creaturesToSpawn,
		level = currentNight, -- Creatures scale with night number
		spread = 10, -- Spread out the spawns
	}

	EntitySpawner.spawnWave({spawnConfig})

	-- Schedule next wave
	nextWaveTime = tick() + (GameConfig.nightWaves.waveInterval or 30)
end

-- Main update loop
local function update()
	-- Maintain wildlife population
	-- maintainWildlifePopulation()

	-- Handle creature waves during night
	if isNightActive then
		-- local currentTime = tick()
		-- if currentTime >= nextWaveTime then
		-- 	spawnCreatureWave()
		-- end

		-- Optional: Check if all creatures are defeated (early night end)
		-- Uncomment this if you want night to end when all creatures are killed
		-- if getCreatureCount() == 0 and currentTime > nextWaveTime then
		-- 	print("All creatures defeated! Night ending early.")
		-- 	SpawnManager.endNight()
		-- end
	end
end

-- Public API
function SpawnManager.startNightWave()
	if isNightActive then
		print("Night already active")
		return
	end

	isNightActive = true
	currentNight += 1
	nextWaveTime = tick() + 5 -- First wave after 5 seconds

	print(`Starting night {currentNight} - first wave in 5 seconds`)
end

function SpawnManager.endNight()
	if not isNightActive then
		return
	end

	isNightActive = false
	nextWaveTime = 0

	-- Clear all creatures (not wildlife)
	for model, entity in EntityController.getActiveEntities() do
		if entity.config.category == "Creature" then
			EntitySpawner.despawnEntity(model)
		end
	end

	print(`Night {currentNight} ended - all creatures cleared`)
end

function SpawnManager.getCurrentNight(): number
	return currentNight
end

function SpawnManager.isNightActive(): boolean
	return isNightActive
end

-- Spawn specific entity (utility function)
function SpawnManager.spawnEntity(entityType: string, position: Vector3?, level: number?): Model?
	local config: EntitySpawner.SpawnConfig = {
		entityType = entityType,
		location = position and { type = "point", position = position } or { type = "random" },
		level = level or 1,
	}

	return EntitySpawner.spawnEntity(config)
end

-- Clear all entities (for testing/reset)
function SpawnManager.clearAllEntities()
	for model, entity in EntityController.getActiveEntities() do
		EntitySpawner.despawnEntity(model)
	end
	print("All entities cleared")
end

-- Initialize SpawnManager
function SpawnManager.initialize()
	if isInitialized then
		warn("[SpawnManager] Already initialized")
		return
	end

	isInitialized = true

	-- Initialize EntityController
	EntityController.initialize()

	-- Start update loop
	RunService.Heartbeat:Connect(update)

	-- Initial wildlife spawn (disabled for now)
	-- maintainWildlifePopulation()

	print("[SpawnManager] ✓ Initialized")
end

return SpawnManager
