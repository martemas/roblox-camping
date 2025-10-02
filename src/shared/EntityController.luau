--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))
local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local CombatFeedback = require(script.Parent:WaitForChild("CombatFeedback"))
local ProjectileLOS = require(script.Parent:WaitForChild("ProjectileLOS"))
local DamageCalculator = require(script.Parent:WaitForChild("DamageCalculator"))

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

local EntityController = {}
local activeEntities: {[Model]: EntityInstance} = {}
local isInitialized = false

-- Helper function to update entity state and sync to model attribute
local function updateEntityState(entity: EntityInstance, newState: EntityState)
	entity.state = newState
	-- Update model attribute so clients can see the state
	entity.model:SetAttribute("EntityState", newState)
end

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
	local humanoidRootPart = entity.model:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		-- Fallback: look for sound directly in the model
		local sound = entity.model:FindFirstChild(soundName)
		if sound and sound:IsA("Sound") then
			sound.PlaybackSpeed = 1 + (math.random() * 0.2 - 0.1)
			sound:Play()
		end
		return
	end

	local sound = humanoidRootPart:FindFirstChild(soundName)
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
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
			local playerHumanoid = player.Character.Humanoid :: Humanoid
			local playerHRP = player.Character.HumanoidRootPart :: BasePart

			-- Only target players who are alive
			if playerHumanoid.Health > 0 then
				local dist = (playerHRP.Position - position).Magnitude
				if dist <= shortestDist then
					closest = player
					shortestDist = dist
				end
			end
		end
	end

	return closest
end

-- Move entity to avoid obstacles (simple sidestep)
local function repositionForClearShot(entity: EntityInstance, target: Player)
	if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local entityPos = entity.humanoidRootPart.Position
	local targetPos = target.Character.HumanoidRootPart.Position
	local toTarget = (targetPos - entityPos).Unit

	-- Calculate perpendicular directions (left and right)
	local leftDir = vector.create(-toTarget.Z, 0, toTarget.X)
	local rightDir = vector.create(toTarget.Z, 0, -toTarget.X)

	-- Test both sidestep positions
	local sideStepDist = 8
	local leftPos = entityPos + (leftDir * sideStepDist)
	local rightPos = entityPos + (rightDir * sideStepDist)

	-- Check which side gives clearer LOS
	local leftLOS = ProjectileLOS.validatePath(leftPos, targetPos, entity.model)
	local rightLOS = ProjectileLOS.validatePath(rightPos, targetPos, entity.model)

	-- Pick best direction
	local moveDir
	if leftLOS.hasLineOfSight then
		moveDir = leftDir
	elseif rightLOS.hasLineOfSight then
		moveDir = rightDir
	else
		-- Neither side clear, pick random
		moveDir = math.random() > 0.5 and leftDir or rightDir
	end

	-- Calculate new goal position
	local moveDistance = math.random(5, 10)
	local newGoal = entityPos + (moveDir * moveDistance)

	-- Move toward new position (simple approach, no pathfinding)
	entity.humanoid:MoveTo(newGoal)
	print(`*** {entity.entityType} repositioning to find clear shot`)

	-- Wait briefly for repositioning
	task.wait(0.5)
end

-- Perform attack on target using unified CombatSystem
local function performAttack(entity: EntityInstance, target: Player)
	if not target.Character or not target.Character:FindFirstChild("Humanoid") then
		return
	end

	local targetHumanoid = target.Character.Humanoid :: Humanoid
	local config = getEntityConfig(entity.entityType)

	-- Don't attack if target is already dead
	if targetHumanoid.Health <= 0 then
		return
	end

	-- Get entity's weapon
	local weaponName = config.primaryWeapon
	if not weaponName then
		warn(`Entity {entity.entityType} has no primaryWeapon configured`)
		return
	end

	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		return
	end

	-- Set attack time IMMEDIATELY to prevent multiple attacks during castDuration
	entity.lastAttackTime = tick()

	-- Handle different weapon types
	if weaponConfig.type == "melee" then
		-- Play attack animation and sound
		playAnimation(entity, "attack")
		playSound(entity, "attack")
		updateEntityState(entity, "attacking")

		-- Wait castDuration (telegraph window - player can dodge during this time)
		task.wait(weaponConfig.castDuration)

		-- After castDuration: Check if target still in range using CombatSystem
		local result = CombatSystem.attemptMeleeAttack(
			entity.model,
			target.Character,
			weaponName,
			nil -- No attacking player (this is an NPC)
		)

		if result.hit and result.damage then
			-- Target was in range - damage was applied by CombatSystem
			print(`*** {entity.entityType} hit {target.Name} for {result.damage} damage with {weaponName}`)
		elseif result.wasDodged then
			-- Target dodged!
			print(`*** {target.Name} dodged {entity.entityType} attack!`)
		elseif result.blockedByInvulnerability then
			-- Target is invulnerable
			print(`*** {target.Name} is invulnerable to {weaponName}`)
		end

	elseif weaponConfig.type == "projectile" then
		-- Check LOS before firing
		if weaponConfig.requiresLineOfSight then
			local losResult = ProjectileLOS.canTargetEntity(entity.model, target.Character)

			if not losResult.hasLineOfSight then
				print(`*** {entity.entityType} blocked by obstacle, repositioning`)
				-- Attempt to reposition for clear shot
				repositionForClearShot(entity, target)
				return -- Skip attack this cycle
			end
		end

		-- LOS is clear, proceed with projectile attack
		local targetPos = target.Character.HumanoidRootPart.Position
		local entityPos = entity.humanoidRootPart.Position

		-- Calculate direction with target leading (predict movement)
		local targetVelocity = target.Character.HumanoidRootPart.AssemblyLinearVelocity
		local projectileSpeed = weaponConfig.projectileSpeed or 50
		local timeToImpact = (targetPos - entityPos).Magnitude / projectileSpeed
		local leadTarget = targetPos + (targetVelocity * timeToImpact)
		local direction = (leadTarget - entityPos).Unit

		-- Play attack animation
		playAnimation(entity, "attack")
		playSound(entity, "attack")
		updateEntityState(entity, "attacking")

		-- Wait castDuration
		task.wait(weaponConfig.castDuration)

		-- Fire projectile via ProjectileManager
		local ProjectileManager = require(script.Parent:WaitForChild("ProjectileManager"))
		local origin = entityPos + (direction * 2) -- Slightly in front
		local projectile = ProjectileManager.spawnProjectile(
			origin,
			direction,
			weaponName,
			entity.model,
			nil, -- No attacking player
			target.Character -- Locked target
		)

		if projectile then
			print(`*** {entity.entityType} fired {weaponName} at {target.Name}`)
		else
			print(`*** {entity.entityType} projectile attack failed`)
		end

	elseif weaponConfig.type == "hitscan" then
		-- Hitscan attack (uses HitscanManager like players)
		local HitscanManager = require(script.Parent:WaitForChild("HitscanManager"))

		-- Play attack animation
		playAnimation(entity, "attack")
		playSound(entity, "attack")
		updateEntityState(entity, "attacking")

		-- Wait castDuration
		task.wait(weaponConfig.castDuration)

		-- Calculate origin and direction (auto-aim handles targeting)
		local origin = entity.humanoidRootPart.Position + vector.create(0, 1, 0) -- Chest height
		local direction = HitscanManager.calculateDirection(
			entity.humanoidRootPart,
			target.Character, -- Locked target
			origin
		)

		-- Perform hitscan via HitscanManager
		local result = HitscanManager.performHitscan(
			origin,
			direction,
			weaponName,
			entity.model,
			nil, -- No attacking player (NPC)
			target.Character -- Locked target
		)

		if result.hit then
			print(`*** {entity.entityType} hit {target.Name} with {weaponName}`)
		else
			print(`*** {entity.entityType} missed {target.Name} with {weaponName}`)
		end

	else
		-- Other weapon types (AOE) will be added in Phase 2
		warn(`Weapon type {weaponConfig.type} not yet implemented for NPCs`)
	end
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
		updateEntityState(entity, "jumping")
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

	-- If entity already has a target, check if we should maintain it
	if entity.target and entity.target.Character then
		local targetHumanoid = entity.target.Character:FindFirstChildOfClass("Humanoid")
		local targetRoot = entity.target.Character:FindFirstChild("HumanoidRootPart")

		-- Clear target if they died
		if not targetHumanoid or targetHumanoid.Health <= 0 then
			entity.target = nil
			entity.isAggro = false
		-- Clear target if they're beyond extended chase range
		elseif targetRoot and targetRoot:IsA("BasePart") then
			local distance = (targetRoot.Position - entity.humanoidRootPart.Position).Magnitude
			local chaseMultiplier = GameConfig.combat.chaseRangeMultiplier or 3
			local maxChaseRange = config.aggroRange * chaseMultiplier

			if distance > maxChaseRange then
				entity.target = nil
				entity.isAggro = false
				print(`{entity.entityType} gave up chase - target too far ({math.floor(distance)} > {maxChaseRange})`)
			end
		end
	end

	-- Only look for new target if we don't have one
	if not entity.target then
		local target = getTarget(entity)
		if target then
			entity.isAggro = true
			entity.target = target
		else
			entity.isAggro = false
		end
	end

	-- Handle behavior based on aggro state
	if entity.isAggro and entity.target and entity.target.Character and entity.target.Character:FindFirstChild("HumanoidRootPart") then
		local targetHRP = entity.target.Character.HumanoidRootPart :: BasePart
		local targetPos = targetHRP.Position
		local distToTarget = (targetHRP.Position - entity.humanoidRootPart.Position).Magnitude

		-- Get weapon config for range/cooldown
		local weaponName = config.primaryWeapon
		local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
		if not weaponConfig then
			warn(`Entity {entity.entityType} has no valid weapon config`)
			return
		end

		local attackDistance = weaponConfig.range
		local stoppingDistance = attackDistance * 0.8 -- Stop a bit before attack range

		-- Check if entity is currently attacking
		if entity.state ~= "attacking" then
			-- Adjust speed based on distance - slower when closer
			if distToTarget <= stoppingDistance then
				-- Within stopping distance: reduce speed for circling/strafing
				entity.humanoid.WalkSpeed = (config.walkSpeed or 12) * 0.6 -- 60% of walk speed
				updateEntityState(entity, "chasing")
				playAnimation(entity, "walk") -- use walk animation at lower speed
			else
				-- Outside stopping distance: full chase speed
				entity.humanoid.WalkSpeed = config.runSpeed or 12
				updateEntityState(entity, "chasing")
				playAnimation(entity, "run")
			end
		end

		if distToTarget <= attackDistance then
			if currentTime - entity.lastAttackTime >= weaponConfig.cooldown then
				-- Perform attack (performAttack now handles castDuration internally)
				performAttack(entity, entity.target)
			end
		end

		-- Movement behavior based on distance
		if distToTarget > stoppingDistance then
			-- Chase: move directly toward target
			entity.humanoid:MoveTo(targetPos)
		else
			-- Within stopping distance: stop moving and clear pathfinding target
			local currentPos = entity.humanoidRootPart.Position
			entity.humanoid:MoveTo(currentPos)
		end

		-- Handle jumping
		if config.canJump then
			handleJumping(entity)
		end
	else
		-- Wandering behavior
		entity.humanoid.WalkSpeed = config.walkSpeed or 12
		updateEntityState(entity, "wandering")
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
function EntityController.initializeEntity(model: Model, entityType: string): EntityInstance?
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

	-- Set initial state
	updateEntityState(entity, "idle")

	-- Handle death
	humanoid.Died:Connect(function()
		playSound(entity, "died") -- Play death sound if it exists
		EntityController.removeEntity(model)
	end)

	-- Register entity
	activeEntities[model] = entity

	print(`Initialized {entityType} entity with centralized controller`)
	return entity
end

-- Remove entity from tracking
function EntityController.removeEntity(model: Model)
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
function EntityController.getActiveEntities(): {[Model]: EntityInstance}
	return activeEntities
end

-- Get entity by model
function EntityController.getEntity(model: Model): EntityInstance?
	return activeEntities[model]
end

-- Force an entity to target a specific player (useful for testing/special events)
function EntityController.setTarget(model: Model, target: Player?)
	local entity = activeEntities[model]
	if entity then
		entity.target = target
		entity.isAggro = target ~= nil
	end
end

--[[
	Called when an entity takes damage - retargets to attacker ONLY if no current target

	@param entity - Entity that took damage
	@param attacker - The attacker (character model)
]]
function EntityController.onEntityDamaged(entity: Model, attacker: Model)
	local entityInstance = activeEntities[entity]
	if not entityInstance then
		return
	end

	-- ONLY retarget if entity has no current target
	if not entityInstance.target then
		local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
		if attackerPlayer then
			entityInstance.target = attackerPlayer
			entityInstance.isAggro = true
			print(`{entity.Name} now targeting {attackerPlayer.Name} after taking damage`)
		end
	end
end

-- Main update loop for all entities
local function updateAllEntities()
	for model, entity in activeEntities do
		if model.Parent then
			updateEntityAI(entity)
		else
			-- Model was destroyed, clean up
			EntityController.removeEntity(model)
		end
	end
end

-- Initialize the controller system
function EntityController.initialize()
	if isInitialized then
		return
	end

	-- Start the main update loop
	RunService.Heartbeat:Connect(updateAllEntities)

	isInitialized = true
	print("EntityController centralized system initialized")
end

-- Clean up all entities (useful for testing/resetting)
function EntityController.cleanup()
	for model, entity in pairs(activeEntities) do
		EntityController.removeEntity(model)
	end
	activeEntities = {}
end

-- Public API for external systems (like ToolManager hitting entities)
function EntityController.handleDamage(
	model: Model,
	damage: number,
	damageSource: string?,
	attackerModel: Model?,
	hitPart: BasePart?
)
	local entity = activeEntities[model]
	if entity then
		-- If attacker is provided, use DamageCalculator; otherwise use direct damage
		local finalDamage = damage
		local hitLocation = "unknown"

		if attackerModel and damageSource then
			-- Use DamageCalculator for proper damage calculation
			local damageResult = DamageCalculator.calculateDamage({
				attacker = attackerModel,
				target = model,
				weaponName = damageSource,
				hitPart = hitPart,
			})

			if damageResult.wasHit then
				finalDamage = damageResult.finalDamage
				hitLocation = damageResult.hitLocation
			else
				return -- Miss, no damage
			end
		end

		-- Apply damage
		entity.humanoid:TakeDamage(finalDamage)

		-- Determine damage type for feedback
		local attackingPlayer = if attackerModel
			then Players:GetPlayerFromCharacter(attackerModel)
			else nil
		local damageType: CombatFeedback.DamageType = if attackingPlayer then "self" else "other_player"

		-- Show floating damage number via CombatFeedback
		CombatFeedback.showDamage(model, finalDamage, damageSource, damageType, attackerModel)

		-- Play damage sound
		playSound(entity, "damage")

		print(`{entity.entityType} took {finalDamage} damage from {damageSource or "unknown"} (location: {hitLocation})`)
	end
end

return EntityController