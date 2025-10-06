--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local Utils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"))

type CreatureEntity = Types.CreatureEntity
type CreatureType = Types.CreatureType

local CreatureSpawner = {}
local activeEnemies: {[Model]: CreatureEntity} = {}
local isNightActive: boolean = false
local currentNight: number = 0
local nextWaveTime: number = 0
local lastWaveTime: number = 0

-- References to other managers (will be set after initialization)
local TownhallManager = nil
local DayNightCycle = nil


-- Handle creature death
local function onEnemyDied(creature: CreatureEntity)
	print(`{creature.creatureType} was defeated`)

	-- TODO: Create drop items when item system is ready
	-- Enemies might drop crafting materials or other resources

	-- Clean up
	activeEnemies[creature.model] = nil

	-- Remove model after a delay
	Debris:AddItem(creature.model, 3)

	-- Check if all creatures are defeated
	if isNightActive and next(activeEnemies) == nil then
		print("All creatures defeated! Night ending early.")
		-- Force day phase since all creatures are defeated
		if DayNightCycle then
			DayNightCycle.ForceDay()
		end
	end
end

-- Create an creature entity
local function createEnemy(creatureType: CreatureType, position: vector): CreatureEntity?
	print(`DEBUG: Attempting to create {creatureType} at position {position}`) -- DEBUG

	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return nil
	end
	print(`DEBUG: Found Models folder`) -- DEBUG

	local creatureTemplate = modelsFolder:FindFirstChild(creatureType)
	if not creatureTemplate then
		warn(`Enemy template '{creatureType}' not found in Models folder`)
		print(`DEBUG: Available models in folder:`) -- DEBUG
		for _, child in pairs(modelsFolder:GetChildren()) do
			print(`  - {child.Name}`) -- DEBUG
		end
		return nil
	end
	print(`DEBUG: Found creature template: {creatureTemplate.Name}`) -- DEBUG

	local creatureModel = creatureTemplate:Clone()
	creatureModel.Parent = workspace

	-- Position the model safely
	if creatureModel.PrimaryPart then
		creatureModel:SetPrimaryPartCFrame(CFrame.new(position))
	else
		-- Fallback: move the first BasePart found
		local firstPart = creatureModel:FindFirstChildOfClass("BasePart")
		if firstPart then
			firstPart.CFrame = CFrame.new(position)
		else
			warn(`No BasePart found in {creatureType} model for positioning`)
			creatureModel:Destroy()
			return nil
		end
	end

	local humanoid = creatureModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`No Humanoid found in {creatureType} model`)
		creatureModel:Destroy()
		return nil
	end

	local config = GameConfig.entities[creatureType]
	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.WalkSpeed = config.walkSpeed

	-- Set generic entity attributes for tool interaction system
	local entityConfig = GameConfig.entities[creatureType]
	if entityConfig then
		creatureModel:SetAttribute("EntityType", creatureType)
		creatureModel:SetAttribute("EntityCategory", entityConfig.category)
		creatureModel:SetAttribute("CanTakeDamage", entityConfig.canTakeDamage)
		creatureModel:SetAttribute("MaxHealth", entityConfig.health)
		creatureModel:SetAttribute("CurrentHealth", entityConfig.health)
		print(`DEBUG: Set entity attributes for {creatureType}`) -- DEBUG
	else
		warn(`No entity configuration found for {creatureType}`)
	end

	-- Set Level attribute (default to 1, can be enhanced later)
	-- Health bar will be attached client-side by HealthBarAttacher
	creatureModel:SetAttribute("Level", 1)

	-- Get warehouse as primary target
	local warehouse = nil
	if TownhallManager then
		warehouse = TownhallManager.GetTownhall()
	end
	local target = warehouse and warehouse.PrimaryPart

	local creatureEntity: CreatureEntity = {
		creatureType = creatureType,
		model = creatureModel,
		humanoid = humanoid,
		health = config.health,
		maxHealth = config.health,
		target = target,
		lastAttackTime = 0,
	}

	-- Handle death
	humanoid.Died:Connect(function()
		onEnemyDied(creatureEntity)
	end)

	activeEnemies[creatureModel] = creatureEntity
	return creatureEntity
end

-- Find nearest player to a position
local function findNearestPlayer(position: vector, maxDistance: number?): Player?
	local nearestPlayer: Player? = nil
	local nearestDistance = maxDistance or math.huge

	for _, player in pairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character.PrimaryPart then
			local distance = (character.PrimaryPart.Position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestPlayer = player
			end
		end
	end

	return nearestPlayer
end

-- Create pathfinding path to target
local function createPathToTarget(creature: CreatureEntity, targetPosition: vector)
	if not creature.model.PrimaryPart then
		return
	end

	local humanoid = creature.humanoid
	local currentPosition = creature.model.PrimaryPart.Position

	-- Use simple MoveTo for now - can be enhanced later with PathfindingService
	humanoid:MoveTo(targetPosition)

	-- TODO: Implement advanced pathfinding when needed
	-- local path = PathfindingService:CreatePath({
	--     AgentRadius = 3,
	--     AgentHeight = 6,
	--     AgentCanJump = true,
	--     WaypointSpacing = 4
	-- })
	-- local success, errorMessage = pcall(function()
	--     path:ComputeAsync(currentPosition, targetPosition)
	-- end)
	-- if success then
	--     local waypoints = path:GetWaypoints()
	--     for _, waypoint in pairs(waypoints) do
	--         humanoid:MoveTo(waypoint.Position)
	--         humanoid.MoveToFinished:Wait()
	--     end
	-- end
end

-- Update creature AI behavior
local function _updateEnemyAI(creature: CreatureEntity)
	if not creature.model.Parent or creature.humanoid.Health <= 0 then
		return
	end

	local config = GameConfig.entities[creature.creatureType]
	local position = creature.model.PrimaryPart.Position

	-- Check for nearby players first (higher priority than warehouse)
	local nearestPlayer = findNearestPlayer(position, 20) -- 20 stud detection range

	local targetPosition: vector?
	local attackTarget: any = nil

	if nearestPlayer and nearestPlayer.Character and nearestPlayer.Character.PrimaryPart then
		-- Player detected - prioritize attacking player
		targetPosition = nearestPlayer.Character.PrimaryPart.Position
		attackTarget = nearestPlayer
	elseif creature.target then
		-- No player nearby - go to warehouse
		targetPosition = creature.target.Position
		attackTarget = creature.target
	end

	if targetPosition then
		local distance = (position - targetPosition).Magnitude

		-- Attack if close enough and not on cooldown
		if distance <= config.attackRange and tick() - creature.lastAttackTime >= config.attackCooldown then
			if attackTarget == nearestPlayer then
				-- Attack player
				RemoteEvents.Events.TakeDamage:FireClient(nearestPlayer, config.damage, creature.creatureType)
				print(`{creature.creatureType} attacked {nearestPlayer.Name} for {config.damage} damage`)
			else
				-- Attack warehouse/structure
				-- TODO: Implement structure damage when building system is ready
				print(`{creature.creatureType} attacked warehouse for {config.damage} damage`)
			end

			creature.lastAttackTime = tick()

			-- TODO: Play attack animation when animation assets are ready
			-- TODO: Play attack sound when sound assets are ready

		elseif distance > config.attackRange then
			-- Move toward target
			createPathToTarget(creature, targetPosition)
		end
	end
end

-- Get spawn position around map perimeter
local function getRandomSpawnPosition(): vector
	local mapSize = GameConfig.map.size
	local spawnDistance = mapSize / 2 - 50 -- Spawn 50 studs inside map edge
	local centerPosition = vector.create(0, 0, 0)

	-- Use Utils ground detection for proper spawn positioning
	return Utils.getRandomGroundPosition(centerPosition, spawnDistance - 20, spawnDistance)
end

-- Calculate creatures to spawn based on current night
local function calculateEnemyCount(): number
	local baseCount = GameConfig.nightWaves.baseZombieCount
	local increase = GameConfig.nightWaves.difficultyIncrease
	local nightMultiplier = 1 + (currentNight - 1) * increase
	local finalCount = math.floor(baseCount * nightMultiplier)

	print(`DEBUG: calculateEnemyCount - Night: {currentNight}, Base: {baseCount}, Increase: {increase}, Multiplier: {nightMultiplier}, Final: {finalCount}`) -- DEBUG
	return finalCount
end

-- Spawn a wave of creatures
local function spawnEnemyWave()
	local creatureCount = calculateEnemyCount()
	print(`DEBUG: Attempting to spawn {creatureCount} zombies for night {currentNight}`) -- DEBUG

	for i = 1, creatureCount do
		local spawnPosition = getRandomSpawnPosition()
		print(`DEBUG: Spawn position {i}: {spawnPosition}`) -- DEBUG
		local creature = createEnemy("Zombie", spawnPosition)

		if creature then
			print(`Spawned Zombie {i}/{creatureCount} at night {currentNight}`)
		else
			print(`DEBUG: Failed to create Zombie {i}/{creatureCount}`) -- DEBUG
		end

		-- Small delay between spawns for visual effect
		if i < creatureCount then
			task.wait(0.5)
		end
	end

	-- Schedule next wave
	nextWaveTime = tick() + GameConfig.nightWaves.waveInterval
end

-- Main update loop for creatures
local function updateEnemies()
	if not isNightActive then
		return
	end

	-- Update AI for all active creatures
	for model, creature in pairs(activeEnemies) do
		if model.Parent then
			-- _updateEnemyAI(creature)
		else
			-- Model was destroyed, clean up
			activeEnemies[model] = nil
		end
	end

	-- Check if it's time for next wave (with debounce to prevent rapid spawning)
	local currentTime = tick()
	if currentTime >= nextWaveTime and currentTime > lastWaveTime + 1 then
		print(`DEBUG: Spawning wave at time {currentTime}, was due at {nextWaveTime}`) -- DEBUG
		print("Spawning creature wave...")
		lastWaveTime = currentTime
		spawnEnemyWave()
	end
end

-- Public API
function CreatureSpawner.StartNightWave()
	if isNightActive then
		print(`DEBUG: StartNightWave called but night is already active`) -- DEBUG
		return -- Already active
	end

	print(`DEBUG: StartNightWave called - beginning night {currentNight + 1}`) -- DEBUG
	isNightActive = true
	currentNight += 1
	nextWaveTime = tick() + 5 -- First wave starts after 5 seconds
	print(`DEBUG: nextWaveTime set to {nextWaveTime} (current time: {tick()})`) -- DEBUG

	print(`Starting night {currentNight} - creatures will spawn in 5 seconds`)
end

function CreatureSpawner.EndNight()
	isNightActive = false
	nextWaveTime = 0

	-- Clear all remaining creatures
	for model, creature in pairs(activeEnemies) do
		if model.Parent then
			model:Destroy()
		end
	end
	activeEnemies = {}

	print(`Night {currentNight} has ended - all creatures cleared`)
end

function CreatureSpawner.GetActiveEnemies(): {[Model]: CreatureEntity}
	return activeEnemies
end

function CreatureSpawner.GetEnemyCount(): number
	local count = 0
	for _ in pairs(activeEnemies) do
		count += 1
	end
	return count
end

function CreatureSpawner.GetCurrentNight(): number
	return currentNight
end

-- Handle tool hit on creature (called from ToolManager)
function CreatureSpawner.HandleToolHit(player: Player, creatureModel: Model, damage: number, creatureType: string)
	print(`HandleToolHit called: {player.Name} hit {creatureType} for {damage} damage`) -- DEBUG

	local humanoid = creatureModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		print(`No Humanoid found in {creatureModel.Name}`) -- DEBUG
		return
	end

	-- Try to get tracked creature first
	local creature = activeEnemies[creatureModel]
	if creature then
		print(`Found tracked creature entity: {creature.creatureType}`) -- DEBUG
		print(`Current health: {creature.health}/{creature.maxHealth}`) -- DEBUG

		-- Apply damage to tracked entity
		creature.health -= damage
		humanoid.Health = math.max(0, creature.health)

		-- Update attributes
		creatureModel:SetAttribute("CurrentHealth", creature.health)

		print(`After damage - Custom health: {creature.health}, Humanoid health: {humanoid.Health}`) -- DEBUG
	else
		-- Handle external models using attributes
		print(`No tracked entity found, using attribute system for external model`) -- DEBUG

		local currentHealthAttr = creatureModel:GetAttribute("CurrentHealth")
		local maxHealthAttr = creatureModel:GetAttribute("MaxHealth")

		local currentHealth: number
		local maxHealth: number

		-- Initialize attributes if not present
		if not currentHealthAttr then
			currentHealth = humanoid.Health
			maxHealth = humanoid.MaxHealth
			creatureModel:SetAttribute("CurrentHealth", currentHealth)
			creatureModel:SetAttribute("MaxHealth", maxHealth)
			print(`Initialized attributes - Health: {currentHealth}/{maxHealth}`) -- DEBUG
		else
			-- Cast attribute values to numbers for type safety
			currentHealth = tonumber(currentHealthAttr) or humanoid.Health
			maxHealth = tonumber(maxHealthAttr) or humanoid.MaxHealth
		end

		-- Apply damage using attributes
		currentHealth = math.max(0, currentHealth - damage)
		creatureModel:SetAttribute("CurrentHealth", currentHealth)
		humanoid.Health = math.max(0, currentHealth)

		print(`External model damage - Health: {currentHealth}/{maxHealth}, Humanoid: {humanoid.Health}`) -- DEBUG

		-- Check if died
		if currentHealth <= 0 then
			print(`{creatureType} (external) was killed by {player.Name}`) -- DEBUG
			-- Humanoid death will handle cleanup
		end
	end
end

-- Initialize the creature spawner
local function initialize()
	-- Get references to other managers
	task.spawn(function()
		-- Wait for other managers to be available in global scope
		while not _G.TownhallManager or not _G.DayNightCycle do
			task.wait(0.1)
		end
		TownhallManager = _G.TownhallManager
		DayNightCycle = _G.DayNightCycle
		print("CreatureSpawner connected to other managers")
	end)

	-- Start the main update loop
	RunService.Heartbeat:Connect(updateEnemies)

	-- Listen for day phase to end night
	local connection
	connection = RemoteEvents.Events.PhaseChanged.OnServerEvent:Connect(function(phase)
		if phase == "Day" and isNightActive then
			CreatureSpawner.EndNight()
		end
	end)

	print("CreatureSpawner initialized")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.CreatureSpawner = CreatureSpawner

return CreatureSpawner