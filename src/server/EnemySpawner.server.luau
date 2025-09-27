--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local Utils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"))
local CombatCalculator = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatCalculator"))

type EnemyEntity = Types.EnemyEntity
type EnemyType = Types.EnemyType

local EnemySpawner = {}
local activeEnemies: {[Model]: EnemyEntity} = {}
local isNightActive: boolean = false
local currentNight: number = 0
local nextWaveTime: number = 0
local lastWaveTime: number = 0

-- References to other managers (will be set after initialization)
local TownhallManager = nil
local DayNightCycle = nil


-- Handle enemy death
local function onEnemyDied(enemy: EnemyEntity)
	print(`{enemy.enemyType} was defeated`)

	-- TODO: Create drop items when item system is ready
	-- Enemies might drop crafting materials or other resources

	-- Clean up
	activeEnemies[enemy.model] = nil

	-- Remove model after a delay
	Debris:AddItem(enemy.model, 3)

	-- Check if all enemies are defeated
	if isNightActive and next(activeEnemies) == nil then
		print("All enemies defeated! Night ending early.")
		-- Force day phase since all enemies are defeated
		if DayNightCycle then
			DayNightCycle.ForceDay()
		end
	end
end

-- Create an enemy entity
local function createEnemy(enemyType: EnemyType, position: vector): EnemyEntity?
	print(`DEBUG: Attempting to create {enemyType} at position {position}`) -- DEBUG

	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return nil
	end
	print(`DEBUG: Found Models folder`) -- DEBUG

	local enemyTemplate = modelsFolder:FindFirstChild(enemyType)
	if not enemyTemplate then
		warn(`Enemy template '{enemyType}' not found in Models folder`)
		print(`DEBUG: Available models in folder:`) -- DEBUG
		for _, child in pairs(modelsFolder:GetChildren()) do
			print(`  - {child.Name}`) -- DEBUG
		end
		return nil
	end
	print(`DEBUG: Found enemy template: {enemyTemplate.Name}`) -- DEBUG

	local enemyModel = enemyTemplate:Clone()
	enemyModel.Parent = workspace

	-- Position the model safely
	if enemyModel.PrimaryPart then
		enemyModel:SetPrimaryPartCFrame(CFrame.new(position))
	else
		-- Fallback: move the first BasePart found
		local firstPart = enemyModel:FindFirstChildOfClass("BasePart")
		if firstPart then
			firstPart.CFrame = CFrame.new(position)
		else
			warn(`No BasePart found in {enemyType} model for positioning`)
			enemyModel:Destroy()
			return nil
		end
	end

	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`No Humanoid found in {enemyType} model`)
		enemyModel:Destroy()
		return nil
	end

	local config = GameConfig.enemies[enemyType]
	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.WalkSpeed = config.walkSpeed

	-- Set generic entity attributes for tool interaction system
	local entityConfig = GameConfig.entities[enemyType]
	if entityConfig then
		enemyModel:SetAttribute("EntityType", enemyType)
		enemyModel:SetAttribute("EntityCategory", entityConfig.category)
		enemyModel:SetAttribute("CanTakeDamage", entityConfig.canTakeDamage)
		enemyModel:SetAttribute("MaxHealth", entityConfig.health)
		enemyModel:SetAttribute("CurrentHealth", entityConfig.health)
		print(`DEBUG: Set entity attributes for {enemyType}`) -- DEBUG
	else
		warn(`No entity configuration found for {enemyType}`)
	end

	-- Get warehouse as primary target
	local warehouse = nil
	if TownhallManager then
		warehouse = TownhallManager.GetTownhall()
	end
	local target = warehouse and warehouse.PrimaryPart

	local enemyEntity: EnemyEntity = {
		enemyType = enemyType,
		model = enemyModel,
		humanoid = humanoid,
		health = config.health,
		maxHealth = config.health,
		target = target,
		lastAttackTime = 0,
	}

	-- Handle death
	humanoid.Died:Connect(function()
		onEnemyDied(enemyEntity)
	end)

	activeEnemies[enemyModel] = enemyEntity
	return enemyEntity
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
local function createPathToTarget(enemy: EnemyEntity, targetPosition: vector)
	if not enemy.model.PrimaryPart then
		return
	end

	local humanoid = enemy.humanoid
	local currentPosition = enemy.model.PrimaryPart.Position

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

-- Update enemy AI behavior
local function _updateEnemyAI(enemy: EnemyEntity)
	if not enemy.model.Parent or enemy.humanoid.Health <= 0 then
		return
	end

	local config = GameConfig.enemies[enemy.enemyType]
	local position = enemy.model.PrimaryPart.Position

	-- Check for nearby players first (higher priority than warehouse)
	local nearestPlayer = findNearestPlayer(position, 20) -- 20 stud detection range

	local targetPosition: vector?
	local attackTarget: any = nil

	if nearestPlayer and nearestPlayer.Character and nearestPlayer.Character.PrimaryPart then
		-- Player detected - prioritize attacking player
		targetPosition = nearestPlayer.Character.PrimaryPart.Position
		attackTarget = nearestPlayer
	elseif enemy.target then
		-- No player nearby - go to warehouse
		targetPosition = enemy.target.Position
		attackTarget = enemy.target
	end

	if targetPosition then
		local distance = (position - targetPosition).Magnitude

		-- Attack if close enough and not on cooldown
		if distance <= config.attackRange and tick() - enemy.lastAttackTime >= config.attackCooldown then
			if attackTarget == nearestPlayer and nearestPlayer then
				-- Use universal combat system for enemy attacking player
				local combatResult = CombatCalculator.CalculateCombat(enemy.model, nearestPlayer, nil)

				-- Print combat result for debugging
				CombatCalculator.PrintCombatResult(combatResult, enemy.enemyType, nearestPlayer.Name)

				-- Only apply damage if attack hit
				if combatResult.hit then
					RemoteEvents.Events.TakeDamage:FireClient(nearestPlayer, combatResult.damage, enemy.enemyType)
				end
			else
				-- Attack warehouse/structure - use fixed damage for now
				print(`{enemy.enemyType} attacked warehouse for {config.damage} damage`)
				-- TODO: Implement structure damage when building system is ready
			end

			enemy.lastAttackTime = tick()

			-- TODO: Play attack animation when animation assets are ready
			-- TODO: Play attack sound when sound assets are ready

		elseif distance > config.attackRange then
			-- Move toward target
			createPathToTarget(enemy, targetPosition)
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

-- Calculate enemies to spawn based on current night
local function calculateEnemyCount(): number
	local baseCount = GameConfig.nightWaves.baseZombieCount
	local increase = GameConfig.nightWaves.difficultyIncrease
	local nightMultiplier = 1 + (currentNight - 1) * increase
	local finalCount = math.floor(baseCount * nightMultiplier)

	print(`DEBUG: calculateEnemyCount - Night: {currentNight}, Base: {baseCount}, Increase: {increase}, Multiplier: {nightMultiplier}, Final: {finalCount}`) -- DEBUG
	return finalCount
end

-- Spawn a wave of enemies
local function spawnEnemyWave()
	local enemyCount = calculateEnemyCount()
	print(`DEBUG: Attempting to spawn {enemyCount} zombies for night {currentNight}`) -- DEBUG

	for i = 1, enemyCount do
		local spawnPosition = getRandomSpawnPosition()
		print(`DEBUG: Spawn position {i}: {spawnPosition}`) -- DEBUG
		local enemy = createEnemy("Zombie", spawnPosition)

		if enemy then
			print(`Spawned Zombie {i}/{enemyCount} at night {currentNight}`)
		else
			print(`DEBUG: Failed to create Zombie {i}/{enemyCount}`) -- DEBUG
		end

		-- Small delay between spawns for visual effect
		if i < enemyCount then
			task.wait(0.5)
		end
	end

	-- Schedule next wave
	nextWaveTime = tick() + GameConfig.nightWaves.waveInterval
end

-- Main update loop for enemies
local function updateEnemies()
	if not isNightActive then
		return
	end

	-- Update AI for all active enemies
	for model, enemy in pairs(activeEnemies) do
		if model.Parent then
			-- _updateEnemyAI(enemy)
		else
			-- Model was destroyed, clean up
			activeEnemies[model] = nil
		end
	end

	-- Check if it's time for next wave (with debounce to prevent rapid spawning)
	local currentTime = tick()
	if currentTime >= nextWaveTime and currentTime > lastWaveTime + 1 then
		print(`DEBUG: Spawning wave at time {currentTime}, was due at {nextWaveTime}`) -- DEBUG
		print("Spawning enemy wave...")
		lastWaveTime = currentTime
		spawnEnemyWave()
	end
end

-- Public API
function EnemySpawner.StartNightWave()
	if isNightActive then
		print(`DEBUG: StartNightWave called but night is already active`) -- DEBUG
		return -- Already active
	end

	print(`DEBUG: StartNightWave called - beginning night {currentNight + 1}`) -- DEBUG
	isNightActive = true
	currentNight += 1
	nextWaveTime = tick() + 5 -- First wave starts after 5 seconds
	print(`DEBUG: nextWaveTime set to {nextWaveTime} (current time: {tick()})`) -- DEBUG

	print(`Starting night {currentNight} - enemies will spawn in 5 seconds`)
end

function EnemySpawner.EndNight()
	isNightActive = false
	nextWaveTime = 0

	-- Clear all remaining enemies
	for model, enemy in pairs(activeEnemies) do
		if model.Parent then
			model:Destroy()
		end
	end
	activeEnemies = {}

	print(`Night {currentNight} has ended - all enemies cleared`)
end

function EnemySpawner.GetActiveEnemies(): {[Model]: EnemyEntity}
	return activeEnemies
end

function EnemySpawner.GetEnemyCount(): number
	local count = 0
	for _ in pairs(activeEnemies) do
		count += 1
	end
	return count
end

function EnemySpawner.GetCurrentNight(): number
	return currentNight
end

-- Handle tool hit on enemy (called from ToolManager)
function EnemySpawner.HandleToolHit(player: Player, enemyModel: Model, damage: number, enemyType: string)
	print(`HandleToolHit called: {player.Name} hit {enemyType} for {damage} damage`) -- DEBUG

	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		print(`No Humanoid found in {enemyModel.Name}`) -- DEBUG
		return
	end

	-- Try to get tracked enemy first
	local enemy = activeEnemies[enemyModel]
	if enemy then
		print(`Found tracked enemy entity: {enemy.enemyType}`) -- DEBUG
		print(`Current health: {enemy.health}/{enemy.maxHealth}`) -- DEBUG

		-- Apply damage to tracked entity
		enemy.health -= damage
		humanoid.Health = math.max(0, enemy.health)

		-- Update attributes
		enemyModel:SetAttribute("CurrentHealth", enemy.health)

		print(`After damage - Custom health: {enemy.health}, Humanoid health: {humanoid.Health}`) -- DEBUG
	else
		-- Handle external models using attributes
		print(`No tracked entity found, using attribute system for external model`) -- DEBUG

		local currentHealthAttr = enemyModel:GetAttribute("CurrentHealth")
		local maxHealthAttr = enemyModel:GetAttribute("MaxHealth")

		local currentHealth: number
		local maxHealth: number

		-- Initialize attributes if not present
		if not currentHealthAttr then
			currentHealth = humanoid.Health
			maxHealth = humanoid.MaxHealth
			enemyModel:SetAttribute("CurrentHealth", currentHealth)
			enemyModel:SetAttribute("MaxHealth", maxHealth)
			print(`Initialized attributes - Health: {currentHealth}/{maxHealth}`) -- DEBUG
		else
			-- Cast attribute values to numbers for type safety
			currentHealth = tonumber(currentHealthAttr) or humanoid.Health
			maxHealth = tonumber(maxHealthAttr) or humanoid.MaxHealth
		end

		-- Apply damage using attributes
		currentHealth = math.max(0, currentHealth - damage)
		enemyModel:SetAttribute("CurrentHealth", currentHealth)
		humanoid.Health = math.max(0, currentHealth)

		print(`External model damage - Health: {currentHealth}/{maxHealth}, Humanoid: {humanoid.Health}`) -- DEBUG

		-- Check if died
		if currentHealth <= 0 then
			print(`{enemyType} (external) was killed by {player.Name}`) -- DEBUG
			-- Humanoid death will handle cleanup
		end
	end
end

-- Initialize the enemy spawner
local function initialize()
	-- Get references to other managers
	task.spawn(function()
		-- Wait for other managers to be available in global scope
		while not _G.TownhallManager or not _G.DayNightCycle do
			task.wait(0.1)
		end
		TownhallManager = _G.TownhallManager
		DayNightCycle = _G.DayNightCycle
		print("EnemySpawner connected to other managers")
	end)

	-- Start the main update loop
	RunService.Heartbeat:Connect(updateEnemies)

	-- Listen for day phase to end night
	local connection
	connection = RemoteEvents.Events.PhaseChanged.OnServerEvent:Connect(function(phase)
		if phase == "Day" and isNightActive then
			EnemySpawner.EndNight()
		end
	end)

	print("EnemySpawner initialized")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.EnemySpawner = EnemySpawner

return EnemySpawner