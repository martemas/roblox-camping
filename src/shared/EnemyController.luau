--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

-- Entity runtime state
export type EntityState = "idle" | "wandering" | "chasing" | "attacking" | "jumping"

export type EntityInstance = {
	entityType: string,
	model: Model,
	humanoid: Humanoid,
	humanoidRootPart: BasePart,
	state: EntityState,
	target: Player?,
	lastAttackTime: number,
	lastJumpTime: number,
	lastWanderTime: number,
	isAggro: boolean,
	animationTracks: {[string]: AnimationTrack},
}

local EnemyController = {}
local activeEntities: {[Model]: EntityInstance} = {}
local isInitialized = false

-- Get entity configuration from GameConfig
local function getEntityConfig(entityType: string)
	-- First check wildlife
	if GameConfig.wildlife[entityType] then
		return GameConfig.wildlife[entityType]
	end

	-- Then check enemies
	if GameConfig.enemies[entityType] then
		return GameConfig.enemies[entityType]
	end

	return nil
end

-- Load animations for an entity from GameConfig
local function loadAnimations(entity: EntityInstance)
	local config = getEntityConfig(entity.entityType)
	if not config or not config.animations then
		return
	end

	local animator = entity.humanoid:FindFirstChild("Animator") :: Animator
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = entity.humanoid
	end

	entity.animationTracks = {}

	-- Load each animation defined in config
	for animName, animId in config.animations do
		if animId and animId ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = animId
			local track = animator:LoadAnimation(animation)
			entity.animationTracks[animName] = track
		end
	end
end

-- Play animation with proper cleanup
local function playAnimation(entity: EntityInstance, animName: string)
	local track = entity.animationTracks[animName]
	if not track then
		return
	end

	-- Stop other animations except the one we want to play
	for name, otherTrack in pairs(entity.animationTracks) do
		if name ~= animName and otherTrack.IsPlaying then
			otherTrack:Stop()
		end
	end

	-- Play the requested animation
	if not track.IsPlaying then
		track:Play()
	end
end

-- Play sound effect from model (sounds stay in model for easy modification)
local function playSound(entity: EntityInstance, soundName: string)
	local sound = entity.model:FindFirstChild("HumanoidRootPart"):FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = 1 + (math.random() * 0.2 - 0.1) -- Slight pitch variation
		sound:Play()
	end
end

-- Get closest player to entity
local function getClosestPlayer(entity: EntityInstance): Player?
	local config = getEntityConfig(entity.entityType)
	if not config then return nil end

	local position = entity.humanoidRootPart.Position
	local closest: Player? = nil
	local shortestDist = config.aggroDistance or config.aggroRange or 15

	for _, player in Players:GetPlayers() do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local playerHRP = player.Character.HumanoidRootPart :: BasePart
			local dist = (playerHRP.Position - position).Magnitude
			if dist <= shortestDist then
				closest = player
				shortestDist = dist
			end
		end
	end

	return closest
end

-- Calculate damage (centralized but configurable per entity)
function EnemyController.calculateDamage(entityType: string, targetHumanoid: Humanoid, attackType: string?): number
	local config = getEntityConfig(entityType)
	if not config then
		return 10 -- fallback damage
	end

	-- Support different attack types in future
	if attackType and config.attackTypes and config.attackTypes[attackType] then
		return config.attackTypes[attackType].damage
	end

	-- Default damage
	return config.damage or 10
end

-- Perform attack on target
local function performAttack(entity: EntityInstance, target: Player)
	if not target.Character or not target.Character:FindFirstChild("Humanoid") then
		return
	end

	local targetHumanoid = target.Character.Humanoid :: Humanoid
	local config = getEntityConfig(entity.entityType)

	-- Check recently hit attribute to prevent spam
	if targetHumanoid:GetAttribute("RecentlyBit") then
		return
	end

	-- Calculate and apply damage
	local damage = EnemyController.calculateDamage(entity.entityType, targetHumanoid)
	targetHumanoid:TakeDamage(damage)

	-- Play attack animation and sound
	playAnimation(entity, "attack")
	playSound(entity, "attack") -- Look for "attack" sound in model

	-- Set recently hit protection
	targetHumanoid:SetAttribute("RecentlyBit", true)
	print(`*** {entity.entityType} attacked {target.Name} for {damage} damage`)

	-- Clear protection after cooldown
	local attackCooldown = config.attackCooldown or 2
	task.delay(attackCooldown, function()
		if targetHumanoid then
			targetHumanoid:SetAttribute("RecentlyBit", false)
		end
	end)

	entity.lastAttackTime = tick()
end

-- Handle jumping logic
local function handleJumping(entity: EntityInstance)
	local config = getEntityConfig(entity.entityType)
	local jumpCooldown = config.jumpCooldown or 3

	local currentTime = tick()
	if currentTime - entity.lastJumpTime < jumpCooldown then
		return
	end

	local shouldJump = false

	-- Jump if stuck (not moving)
	if entity.humanoid:GetState() == Enum.HumanoidStateType.Seated or
		entity.humanoidRootPart.AssemblyLinearVelocity.Magnitude < 1 then
		shouldJump = true
	end

	-- Jump if target is jumping (for chasing)
	if entity.target and entity.target.Character and entity.target.Character:FindFirstChild("Humanoid") then
		local targetHumanoid = entity.target.Character.Humanoid :: Humanoid
		if targetHumanoid.Jump then
			shouldJump = true
		end
	end

	if shouldJump then
		entity.humanoid.Jump = true
		playAnimation(entity, "jump")
		entity.lastJumpTime = currentTime
		entity.state = "jumping"
	end
end

-- Get target based on priority (players first, then structures)
local function getTarget(entity: EntityInstance): Player?
	local config = getEntityConfig(entity.entityType)
	if not config then return nil end

	-- Always prioritize players first (as requested)
	local player = getClosestPlayer(entity)

	if player then
		return player
	end

	-- TODO: Add structure targeting when building system is ready
	-- This will check config.targetPriority to decide behavior

	return nil
end

-- Update entity AI behavior (main AI loop)
local function updateEntityAI(entity: EntityInstance)
	if not entity.model.Parent or entity.humanoid.Health <= 0 then
		return
	end

	local config = getEntityConfig(entity.entityType)
	if not config then return end

	local currentTime = tick()
	local target = getTarget(entity)

	-- Update aggro state
	if target then
		entity.isAggro = true
		entity.target = target
	else
		entity.isAggro = false
		entity.target = nil
	end

	-- Handle behavior based on aggro state
	if entity.isAggro and entity.target and entity.target.Character and entity.target.Character:FindFirstChild("HumanoidRootPart") then
		local targetHRP = entity.target.Character.HumanoidRootPart :: BasePart
		local targetPos = targetHRP.Position
		local distToTarget = (targetHRP.Position - entity.humanoidRootPart.Position).Magnitude

		-- Set running speed and animation
		entity.humanoid.WalkSpeed = config.runSpeed -- or config.walkSpeed or 12
		entity.state = "chasing"
		playAnimation(entity, "run")

		-- Attack if close enough
		local attackDistance = config.attackDistance or 5
		if distToTarget <= attackDistance then
			local attackCooldown = config.attackCooldown or 2
			if currentTime - entity.lastAttackTime >= attackCooldown then
				entity.state = "attacking"
				performAttack(entity, entity.target)
			end
		else
			-- Move toward target
			entity.humanoid:MoveTo(Vector3.new(targetPos.X, targetPos.Y, targetPos.Z))
		end

		-- Handle jumping
		if config.canJump then
			handleJumping(entity)
		end
	else
		-- Wandering behavior
		entity.humanoid.WalkSpeed = config.walkSpeed or 12
		entity.state = "wandering"
		playAnimation(entity, "walk")

		-- Simple wandering logic with cooldown to prevent rapid direction changes
		local wanderCooldown = 3 -- seconds between wander direction changes
		if currentTime - entity.lastWanderTime >= wanderCooldown then
			local wanderRange = config.wanderRange or 10
			local randomOffset = vector.create(
				math.random(-wanderRange, wanderRange),
				0,
				math.random(-wanderRange, wanderRange)
			)
			local currentPos = entity.humanoidRootPart.Position
			local targetPos = Vector3.new(
				currentPos.X + randomOffset.x,
				currentPos.Y + randomOffset.y,
				currentPos.Z + randomOffset.z
			)
			entity.humanoid:MoveTo(targetPos)
			entity.lastWanderTime = currentTime
		end
	end
end

-- Initialize an entity with the centralized system
function EnemyController.initializeEntity(model: Model, entityType: string): EntityInstance?
	local config = getEntityConfig(entityType)
	if not config then
		warn(`No configuration found for entity type: {entityType}`)
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart

	if not humanoid or not humanoidRootPart then
		warn(`Entity {entityType} missing Humanoid or HumanoidRootPart`)
		return nil
	end

	-- Set up humanoid properties from config
	humanoid.MaxHealth = config.health or 50
	humanoid.Health = config.health or 50
	humanoid.WalkSpeed = config.walkSpeed or 12

	-- Create entity instance
	local entity: EntityInstance = {
		entityType = entityType,
		model = model,
		humanoid = humanoid,
		humanoidRootPart = humanoidRootPart,
		state = "idle",
		target = nil,
		lastAttackTime = 0,
		lastJumpTime = 0,
		lastWanderTime = 0,
		isAggro = false,
		animationTracks = {},
	}

	-- Load animations
	loadAnimations(entity)

	-- Handle death
	humanoid.Died:Connect(function()
		playSound(entity, "died") -- Play death sound if it exists
		EnemyController.removeEntity(model)
	end)

	-- Register entity
	activeEntities[model] = entity

	print(`Initialized {entityType} entity with centralized controller`)
	return entity
end

-- Remove entity from tracking
function EnemyController.removeEntity(model: Model)
	local entity = activeEntities[model]
	if entity then
		-- Clean up animation tracks
		for _, track in pairs(entity.animationTracks) do
			if track then
				track:Stop()
				track:Destroy()
			end
		end

		activeEntities[model] = nil
		print(`Removed {entity.entityType} from centralized controller`)
	end
end

-- Get all active entities
function EnemyController.getActiveEntities(): {[Model]: EntityInstance}
	return activeEntities
end

-- Get entity by model
function EnemyController.getEntity(model: Model): EntityInstance?
	return activeEntities[model]
end

-- Force an entity to target a specific player (useful for testing/special events)
function EnemyController.setTarget(model: Model, target: Player?)
	local entity = activeEntities[model]
	if entity then
		entity.target = target
		entity.isAggro = target ~= nil
	end
end

-- Main update loop for all entities
local function updateAllEntities()
	for model, entity in activeEntities do
		if model.Parent then
			updateEntityAI(entity)
		else
			-- Model was destroyed, clean up
			EnemyController.removeEntity(model)
		end
	end
end

-- Initialize the controller system
function EnemyController.initialize()
	if isInitialized then
		return
	end

	-- Start the main update loop
	RunService.Heartbeat:Connect(updateAllEntities)

	isInitialized = true
	print("EnemyController centralized system initialized")
end

-- Clean up all entities (useful for testing/resetting)
function EnemyController.cleanup()
	for model, entity in pairs(activeEntities) do
		EnemyController.removeEntity(model)
	end
	activeEntities = {}
end

-- Public API for external systems (like ToolManager hitting entities)
function EnemyController.handleDamage(model: Model, damage: number, damageSource: string?)
	local entity = activeEntities[model]
	if entity then
		entity.humanoid:TakeDamage(damage)
		playSound(entity, "damage")
		print(`{entity.entityType} took {damage} damage from {damageSource or "unknown"}`)
	end
end

return EnemyController