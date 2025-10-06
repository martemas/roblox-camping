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

type WildlifeEntity = Types.WildlifeEntity
type WildlifeType = Types.WildlifeType

local WildlifeSpawner = {}
local activeWildlife: {[Model]: WildlifeEntity} = {}
local lastSpawnCheck: number = 0

-- Handle wildlife death and drops
local function onWildlifeDied(wildlife: WildlifeEntity)
	print(`{wildlife.wildlifeType} died`)

	-- TODO: Create drop items when item system is ready
	local config = GameConfig.entities[wildlife.wildlifeType]
	for _, dropType in pairs(config.drops) do
		print(`Would drop: {dropType}`)
		-- Create drop item at wildlife position
	end

	-- Clean up
	activeWildlife[wildlife.model] = nil

	-- Schedule respawn
	task.spawn(function()
		task.wait(config.respawnTime)
		-- Respawn at a random location
		spawnWildlifeAtRandomLocation(wildlife.wildlifeType)
	end)

	-- Remove model after a delay
	Debris:AddItem(wildlife.model, 5)
end

-- Create a wildlife entity
local function createWildlife(wildlifeType: WildlifeType, position: vector): WildlifeEntity?
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return nil
	end

	local wildlifeTemplate = modelsFolder:FindFirstChild(wildlifeType)
	if not wildlifeTemplate then
		warn(`Wildlife template '{wildlifeType}' not found in Models folder`)
		return nil
	end

	local wildlifeModel = wildlifeTemplate:Clone()
	wildlifeModel.Parent = workspace

	-- Position the model safely
	if wildlifeModel.PrimaryPart then
		wildlifeModel:SetPrimaryPartCFrame(CFrame.new(position))
	else
		-- Fallback: move the first BasePart found
		local firstPart = wildlifeModel:FindFirstChildOfClass("BasePart")
		if firstPart then
			firstPart.CFrame = CFrame.new(position)
		else
			warn(`No BasePart found in {wildlifeType} model for positioning`)
			wildlifeModel:Destroy()
			return nil
		end
	end

	local humanoid = wildlifeModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`No Humanoid found in {wildlifeType} model`)
		wildlifeModel:Destroy()
		return nil
	end

	local config = GameConfig.entities[wildlifeType]
	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.WalkSpeed = config.walkSpeed

	local wildlifeEntity: WildlifeEntity = {
		wildlifeType = wildlifeType,
		model = wildlifeModel,
		humanoid = humanoid,
		health = config.health,
		maxHealth = config.health,
		isAggro = false,
		target = nil,
		lastAttackTime = 0,
	}

	-- Handle death
	humanoid.Died:Connect(function()
		onWildlifeDied(wildlifeEntity)
	end)

	activeWildlife[wildlifeModel] = wildlifeEntity

	-- Set generic entity attributes for tool interaction system
	local entityConfig = GameConfig.entities[wildlifeType]
	if entityConfig then
		wildlifeModel:SetAttribute("EntityType", wildlifeType)
		wildlifeModel:SetAttribute("EntityCategory", entityConfig.category)
		wildlifeModel:SetAttribute("CanTakeDamage", entityConfig.canTakeDamage)
		wildlifeModel:SetAttribute("MaxHealth", entityConfig.health)
		wildlifeModel:SetAttribute("CurrentHealth", entityConfig.health)
	else
		warn(`No entity configuration found for {wildlifeType}`)
		-- Fallback to old system
		wildlifeModel:SetAttribute("MaxHealth", config.health)
		wildlifeModel:SetAttribute("CurrentHealth", config.health)
		wildlifeModel:SetAttribute("WildlifeType", wildlifeType)
	end

	-- Set Level attribute (default to 1, can be enhanced later)
	-- Health bar will be attached client-side by HealthBarAttacher
	wildlifeModel:SetAttribute("Level", 1)

	return wildlifeEntity
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

-- Update wildlife AI behavior
-- local function _updateWildlifeAI(wildlife: WildlifeEntity)
-- 	if not wildlife.model.Parent or wildlife.humanoid.Health <= 0 then
-- 		return
-- 	end

-- 	local config = GameConfig.entities[wildlife.wildlifeType]
-- 	local primaryPart = wildlife.model.PrimaryPart
-- 	if not primaryPart then
-- 		return
-- 	end
-- 	local position = primaryPart.Position

-- 	-- Check for nearby players
-- 	local nearestPlayer = findNearestPlayer(position, config.aggroRange)

-- 	if nearestPlayer and nearestPlayer.Character then
-- 		-- Player in aggro range - become aggressive
-- 		if not wildlife.isAggro then
-- 			wildlife.isAggro = true
-- 			wildlife.target = nearestPlayer
-- 			print(`{wildlife.wildlifeType} is now aggressive toward {nearestPlayer.Name}`)
-- 		end

-- 		-- Attack if close enough and not on cooldown
-- 		local targetPrimaryPart = nearestPlayer.Character.PrimaryPart
-- 		if not targetPrimaryPart then
-- 			return
-- 		end
-- 		local targetPosition = targetPrimaryPart.Position
-- 		local distance = (position - targetPosition).Magnitude

-- 		if distance <= 8 and tick() - wildlife.lastAttackTime >= 2 then
-- 			-- Attack the player
-- 			local damage = config.damage
-- 			RemoteEvents.Events.TakeDamage:FireClient(nearestPlayer, damage, wildlife.wildlifeType)
-- 			wildlife.lastAttackTime = tick()

-- 			print(`{wildlife.wildlifeType} attacked {nearestPlayer.Name} for {damage} damage`)

-- 			-- TODO: Play attack animation when animation assets are ready
-- 			-- TODO: Play attack sound when sound assets are ready
-- 		else
-- 			-- Move toward the player
-- 			wildlife.humanoid:MoveTo(targetPosition)
-- 		end

-- 	else
-- 		-- No players nearby - return to wandering
-- 		if wildlife.isAggro then
-- 			wildlife.isAggro = false
-- 			wildlife.target = nil
-- 			print(`{wildlife.wildlifeType} is no longer aggressive`)
-- 		end

-- 		-- Random wandering behavior
-- 		if (wildlife.humanoid.MoveToFinished:Wait() or math.random() < 0.1) then
-- 			local wanderRange = 50
-- 			local randomX = position.X + math.random(-wanderRange, wanderRange)
-- 			local randomZ = position.Z + math.random(-wanderRange, wanderRange)
-- 			local wanderTarget = vector.create(randomX, position.Y, randomZ)

-- 			wildlife.humanoid:MoveTo(wanderTarget)
-- 		end
-- 	end
-- end

-- Spawn wildlife at a random location
function spawnWildlifeAtRandomLocation(wildlifeType: WildlifeType)
	local mapSize = GameConfig.map.size
	local centerPosition = vector.create(0, 0, 0)

	-- Generate random position away from camp center
	local minDistance = 100 -- Minimum distance from camp
	local maxDistance = mapSize / 2

	-- Use shared utility for ground-based random positioning
	local position = Utils.getRandomGroundPosition(centerPosition, minDistance, maxDistance)
	createWildlife(wildlifeType, position)
end

-- Check if we need to spawn more wildlife
local function checkWildlifeSpawning()
	local currentTime = tick()
	if currentTime - lastSpawnCheck < 5 then -- Check every 5 seconds
		return
	end
	lastSpawnCheck = currentTime

	for wildlifeType, config in pairs(GameConfig.entities) do
		local currentCount = 0
		if config.category ~= "wildlife" then
			continue
		end
		
		for _, wildlife in pairs(activeWildlife) do
			if wildlife.wildlifeType == wildlifeType then
				currentCount += 1
			end
		end

		-- Spawn more if below maximum
		local neededCount = GameConfig.wildlife.maxActive - currentCount
		for i = 1, neededCount do
			spawnWildlifeAtRandomLocation(wildlifeType :: WildlifeType)
		end
	end
end

-- Main update loop
local function updateWildlife()
	-- Update AI for all active wildlife
	for model, wildlife in pairs(activeWildlife) do
		if model.Parent then
			-- _updateWildlifeAI(wildlife)
		else
			-- Model was destroyed, clean up
			activeWildlife[model] = nil
		end
	end

	-- Check spawning needs
	checkWildlifeSpawning()
end

-- Handle player damage from wildlife
local function onPlayerTakeDamage(player: Player, damage: number, source: string)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = math.max(0, humanoid.Health - damage)
		print(`{player.Name} took {damage} damage from {source}`)
	end
end

-- Public API
function WildlifeSpawner.GetActiveWildlife(): {[Model]: WildlifeEntity}
	return activeWildlife
end

function WildlifeSpawner.GetWildlifeCount(wildlifeType: WildlifeType?): number
	local count = 0
	for _, wildlife in pairs(activeWildlife) do
		if not wildlifeType or wildlife.wildlifeType == wildlifeType then
			count += 1
		end
	end
	return count
end

function WildlifeSpawner.ClearAllWildlife()
	for model, wildlife in pairs(activeWildlife) do
		if model.Parent then
			model:Destroy()
		end
	end
	activeWildlife = {}
end

-- Handle tool hit on wildlife (called from ToolManager)
function WildlifeSpawner.HandleToolHit(player: Player, wildlifeModel: Model, damage: number, wildlifeType: string)
	print(`HandleToolHit called: {player.Name} hit {wildlifeType} for {damage} damage`) -- DEBUG
	print(`Looking for wildlife model: {wildlifeModel.Name}`) -- DEBUG

	local humanoid = wildlifeModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		print(`No Humanoid found in {wildlifeModel.Name}`) -- DEBUG
		return
	end

	-- Try to get tracked wildlife first
	local wildlife = activeWildlife[wildlifeModel]
	if wildlife then
		print(`Found tracked wildlife entity: {wildlife.wildlifeType}`) -- DEBUG
		print(`Current health: {wildlife.health}/{wildlife.maxHealth}`) -- DEBUG

		-- Apply damage to tracked entity
		wildlife.health -= damage
		wildlife.humanoid.Health = math.max(0, wildlife.health)

		-- Make aggressive
		if not wildlife.isAggro then
			wildlife.isAggro = true
			wildlife.target = player
			print(`{wildlifeType} is now aggressive toward {player.Name}`) -- DEBUG
		end

		print(`After damage - Custom health: {wildlife.health}, Humanoid health: {wildlife.humanoid.Health}`) -- DEBUG
	else
		-- Handle external models using attributes
		print(`No tracked entity found, using attribute system for external model`) -- DEBUG

		local currentHealthAttr = wildlifeModel:GetAttribute("CurrentHealth")
		local maxHealthAttr = wildlifeModel:GetAttribute("MaxHealth")

		local currentHealth: number
		local maxHealth: number

		-- Initialize attributes if not present
		if not currentHealthAttr then
			currentHealth = humanoid.Health
			maxHealth = humanoid.MaxHealth
			wildlifeModel:SetAttribute("CurrentHealth", currentHealth)
			wildlifeModel:SetAttribute("MaxHealth", maxHealth)
			print(`Initialized attributes - Health: {currentHealth}/{maxHealth}`) -- DEBUG
		else
			-- Cast attribute values to numbers for type safety
			currentHealth = tonumber(currentHealthAttr) or humanoid.Health
			maxHealth = tonumber(maxHealthAttr) or humanoid.MaxHealth
		end

		-- Apply damage using attributes
		currentHealth = math.max(0, currentHealth - damage)
		wildlifeModel:SetAttribute("CurrentHealth", currentHealth)
		humanoid.Health = math.max(0, currentHealth)

		print(`External model damage - Health: {currentHealth}/{maxHealth}, Humanoid: {humanoid.Health}`) -- DEBUG

		-- Check if died
		if currentHealth <= 0 then
			print(`{wildlifeType} (external) was killed by {player.Name}`) -- DEBUG
			-- Humanoid death will handle cleanup
		end
	end
end

-- Initialize the wildlife spawner
local function initialize()
	-- Connect damage handling
	RemoteEvents.Events.TakeDamage.OnServerEvent:Connect(onPlayerTakeDamage)

	-- Start the main update loop
	RunService.Heartbeat:Connect(updateWildlife)

	-- Initial spawn
	checkWildlifeSpawning()

	print("WildlifeSpawner initialized")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.WildlifeSpawner = WildlifeSpawner

return WildlifeSpawner