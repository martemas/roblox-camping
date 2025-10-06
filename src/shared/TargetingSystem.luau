--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent:WaitForChild("config"))
local Types = require(script.Parent:WaitForChild("Types"))

type TargetInfo = Types.TargetInfo

local TargetingSystem = {}

-- Track player targets and highlights
local playerTargets: {[Player]: Model?} = {}
local targetHighlights: {[Model]: {[Player]: Highlight}} = {}
local lastTargetCheck: {[Player]: number} = {}

-- Configuration
local CHECK_INTERVAL = 0.1 -- How often to check target validity (seconds)

-- Check if a model has targeting attributes and is valid
local function isTargetable(model: Model): boolean
	-- Check if it's a player character
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		-- Players are targetable if PvP is enabled
		return GameConfig.combat.pvpEnabled
	end

	-- Must have EntityType attribute for non-player entities
	local entityType = model:GetAttribute("EntityType")
	if not entityType then
		return false
	end

	-- Must have EntityCategory attribute
	local entityCategory = model:GetAttribute("EntityCategory")
	if not entityCategory then
		return false
	end

	-- Check if entity exists in GameConfig
	local config = GameConfig.entities[entityType] or GameConfig.resources[entityType] or GameConfig.buildings[entityType]

	return config ~= nil
end

-- Check if target is still valid (alive, exists, etc.)
local function isValidTarget(model: Model): boolean
	if not model or not model.Parent then
		return false
	end

	if not isTargetable(model) then
		return false
	end

	-- For entities with health, check if they're alive
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.Health > 0
	end

	-- For other types (resources, buildings), they're valid if they exist
	return true
end

-- Get detailed information about a targetable entity
local function getTargetInfo(model: Model, playerPosition: vector?): TargetInfo?
	if not isTargetable(model) then
		return nil
	end

	-- Check if it's a player character
	local targetPlayer = Players:GetPlayerFromCharacter(model)
	local entityType, entityCategory

	if targetPlayer then
		entityType = "Player"
		entityCategory = "player"
	else
		entityType = tostring(model:GetAttribute("EntityType"))
		entityCategory = tostring(model:GetAttribute("EntityCategory"))
	end

	-- Calculate distance if player position provided
	local distance = 0
	local modelPosition = nil
	local primaryPart = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
	if primaryPart and playerPosition then
		modelPosition = primaryPart.Position
		distance = (modelPosition - playerPosition).Magnitude
	end

	-- Get health information
	local health = 0
	local maxHealth = 0
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		health = humanoid.Health
		maxHealth = humanoid.MaxHealth
	end

	-- Get configuration-based stats
	local damage, walkSpeed, runSpeed = nil, nil, nil

	if entityCategory == ("player" :: Types.EntityCategory) then
		-- For players, damage depends on equipped weapon
		damage = nil -- Not static for players
		walkSpeed = GameConfig.player.walkSpeed
		runSpeed = GameConfig.player.sprintSpeed
	elseif entityCategory == ("resource" :: Types.EntityCategory) or entityCategory == ("building" :: Types.EntityCategory) then
		-- Resources and buildings have no damage or speed
		damage = nil
		walkSpeed = 0
		runSpeed = 0
	else
		local config = GameConfig.entities[entityType]
		local weaponConfig = GameConfig.weapons[config.primaryWeapon]
		damage = weaponConfig and weaponConfig.damage or nil
		walkSpeed = config.walkSpeed
		runSpeed = config.runSpeed
	end

	-- Get current state from model attribute (set by EntityController)
	local state = model:GetAttribute("EntityState") or "unknown"

	return {
		model = model,
		entityType = entityType,
		entityCategory = entityCategory,
		health = health,
		maxHealth = maxHealth,
		distance = distance,
		state = state,
		damage = damage,
		walkSpeed = walkSpeed,
		runSpeed = runSpeed,
	}
end

-- Create or update highlight for an entity
local function updateEntityHighlight(model: Model, player: Player, shouldHighlight: boolean)
	-- Initialize highlights table for this model if needed
	if not targetHighlights[model] then
		targetHighlights[model] = {}
	end

	local existingHighlight = targetHighlights[model][player]

	if shouldHighlight then
		if not existingHighlight then
			-- Create new highlight
			local highlight = Instance.new("Highlight")
			highlight.FillColor = GameConfig.targeting.ownTargetColor
			highlight.OutlineColor = GameConfig.targeting.ownTargetColor
			highlight.FillTransparency = 0.8
			highlight.OutlineTransparency = 0
			highlight.Parent = model
			targetHighlights[model][player] = highlight
		end
	else
		if existingHighlight then
			-- Remove highlight
			existingHighlight:Destroy()
			targetHighlights[model][player] = nil

			-- Clean up empty highlight table
			local hasHighlights = false
			for _ in pairs(targetHighlights[model]) do
				hasHighlights = true
				break
			end
			if not hasHighlights then
				targetHighlights[model] = nil
			end
		end
	end
end

-- Set a player's target
function TargetingSystem.setTarget(player: Player, targetModel: Model?): boolean
	-- Clear previous target
	local previousTarget = playerTargets[player]
	if previousTarget then
		updateEntityHighlight(previousTarget, player, false)
	end

	-- Validate new target
	if targetModel then
		if not isValidTarget(targetModel) then
			warn(`Cannot target {targetModel.Name}: not a valid target`)
			playerTargets[player] = nil
			return false
		end

		-- Check distance if player has a character
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local playerPos = player.Character.HumanoidRootPart.Position
			local targetPos = (targetModel.PrimaryPart or targetModel:FindFirstChildOfClass("BasePart"))
			if targetPos then
				local distance = (targetPos.Position - playerPos).Magnitude
				if distance > GameConfig.targeting.selectionRange then
					warn(`Cannot target {targetModel.Name}: too far away ({math.floor(distance * 10) / 10} > {GameConfig.targeting.selectionRange})`)
					playerTargets[player] = nil
					return false
				end
			end
		end

		-- Set new target
		playerTargets[player] = targetModel
		updateEntityHighlight(targetModel, player, true)
		return true
	else
		-- Clear target
		playerTargets[player] = nil
		print(`{player.Name} cleared target`)
		return true
	end
end

-- Get a player's current target
function TargetingSystem.getTarget(player: Player): Model?
	return playerTargets[player]
end

-- Get detailed info about a player's current target
function TargetingSystem.getTargetInfo(player: Player): TargetInfo?
	local target = playerTargets[player]
	if not target then
		return nil
	end

	local playerPos = nil
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		playerPos = player.Character.HumanoidRootPart.Position
	end

	return getTargetInfo(target, playerPos)
end

-- Find closest targetable entity to a player
function TargetingSystem.findClosestTarget(player: Player): Model?
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	local playerPos = player.Character.HumanoidRootPart.Position
	local closest: Model? = nil
	local shortestDist = GameConfig.targeting.selectionRange

	-- Search through all models in workspace
	for _, model in pairs(workspace:GetChildren()) do
		if model:IsA("Model") and isValidTarget(model) then
			local targetPos = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
			if targetPos then
				local distance = (targetPos.Position - playerPos).Magnitude
				if distance <= shortestDist then
					closest = model
					shortestDist = distance
				end
			end
		end
	end

	return closest
end

-- Check if player's target is still valid and within range
local function validatePlayerTarget(player: Player)
	local target = playerTargets[player]
	if not target then
		return
	end

	-- Check if target is still valid
	if not isValidTarget(target) then
		print(`Auto-deselecting {target.Name} for {player.Name}: no longer valid`)
		TargetingSystem.setTarget(player, nil)
		return
	end

	-- Check distance
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local playerPos = player.Character.HumanoidRootPart.Position
		local targetPos = target.PrimaryPart or target:FindFirstChildOfClass("BasePart")
		if targetPos then
			local distance = (targetPos.Position - playerPos).Magnitude
			if distance > GameConfig.targeting.autoDeselectRange then
				print(`Auto-deselecting {target.Name} for {player.Name}: too far away ({math.floor(distance * 10) / 10} > {GameConfig.targeting.autoDeselectRange})`)
				TargetingSystem.setTarget(player, nil)
				return
			end
		end
	end
end

-- Main update loop for target validation
local function updateTargets()
	local currentTime = tick()

	for player, _ in pairs(playerTargets) do
		-- Throttle checks per player
		local lastCheck = lastTargetCheck[player] or 0
		if currentTime - lastCheck >= CHECK_INTERVAL then
			validatePlayerTarget(player)
			lastTargetCheck[player] = currentTime
		end
	end
end

-- Clean up when player leaves
local function onPlayerRemoving(player: Player)
	-- Clear target and highlights
	TargetingSystem.setTarget(player, nil)
	playerTargets[player] = nil
	lastTargetCheck[player] = nil
end

-- Initialize the targeting system
function TargetingSystem.initialize()
	-- Start update loop
	RunService.Heartbeat:Connect(updateTargets)

	-- Handle player cleanup
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	print("TargetingSystem initialized")
end

-- Public API for external systems
function TargetingSystem.isTargetable(model: Model): boolean
	return isTargetable(model)
end

function TargetingSystem.isValidTarget(model: Model): boolean
	return isValidTarget(model)
end

function TargetingSystem.getEntityInfo(model: Model, playerPosition: vector?): TargetInfo?
	return getTargetInfo(model, playerPosition)
end

return TargetingSystem