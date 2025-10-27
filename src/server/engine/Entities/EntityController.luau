--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Engine = ServerScriptService:WaitForChild("Engine")
local EngineShared = ReplicatedStorage:WaitForChild("Engine")

local GameConfig = require(Engine.Config.GameConfig)
local CombatFeedback = require(EngineShared.VisualFX.CombatFeedback)
local ProjectileLOS = require(Engine.Combat.ProjectileLOS)
local Stats = require(Engine.Combat.Stats)
local StatsProvider = require(Engine.Combat.StatsProvider)
local Entities = require(script.Parent.Parent.Data.Entities)
local AOETelegraph = require(EngineShared.VisualFX.AOETelegraph)
local CombatSystem = require(Engine.Combat.CombatSystem)

-- Lazy-loaded modules to avoid circular dependencies
local XPRewardManager = require(Engine.XPRewardManager)

local function getXPRewardManager()
	if not XPRewardManager and RunService:IsServer() then
		-- Use WaitForChild with timeout (5 seconds)
		local success, xpRewardModule = pcall(function()
			return Engine:WaitForChild("XPRewardManager", 5)
		end)

		if success and xpRewardModule then
			XPRewardManager = require(xpRewardModule)
		else
			warn("[EntityController] Failed to load XPRewardManager - module not found in Engine")
		end
	end
	return XPRewardManager
end

-- DropSystem - Server-side only, no circular dependency
local DropSystem
if RunService:IsServer() then
	local engineFolder = ServerScriptService:FindFirstChild("Engine")
	if engineFolder then
		local dropSystemModule = engineFolder:FindFirstChild("DropSystem")
		if dropSystemModule then
			DropSystem = require(dropSystemModule)
		end
	end
end

-- Entity runtime state
export type EntityState = "idle" | "wandering" | "chasing" | "attacking" | "jumping"

export type EntityInstance = {
	entityId: string,
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

	-- Stats system
	level: number,
	xp: number,
	baseStats: Stats.Stats,    -- Base stats from config
	scaledStats: Stats.Stats,  -- Scaled stats (baseStats * level scaling)
	config: any,  -- Store config reference for easy access

	-- AI system
	spawnPoint: Vector3,       -- Spawn location for return behavior
	patrolPoints: {Vector3}?,  -- Patrol points (if any)
	currentPatrolIndex: number, -- Current patrol point index
	attacker: Model?,          -- Last attacker (for retaliation)
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
local function getEntityConfig(entityId: string)
	-- First check wildlife
	return Entities.getEntity(entityId)
end

-- Load animations for an entity from GameConfig
local function loadAnimations(entity: EntityInstance)
	local config = Entities.getEntity(entity.entityId)

	if not config or not config.Display or not config.Display.animationIds then
		warn("No animations configured for entity type", entity.entityId)
		print(config)
		return
	end

	local animator = entity.humanoid:FindFirstChild("Animator") :: Animator
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = entity.humanoid
	end

	entity.animationTracks = {}

	-- Load each animation defined in config
	for animName, animId in config.Display.animationIds do
		-- print("Loading animation", animName)
		-- print("Anim ID", animId)
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
	local position = entity.humanoidRootPart.Position
	local closest: Player? = nil
	local shortestDist = entity.config.Stats.ai.aggroRange or 15

	for _, player in Players:GetPlayers() do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
			local playerHumanoid = player.Character.Humanoid :: Humanoid
			local playerHRP = player.Character.HumanoidRootPart :: BasePart

			-- Only target players who are alive
			if playerHumanoid.Health > 0 then
				-- Team filtering: Skip allies if team system enabled
				if GameConfig.combat.teamBased and GameConfig.teams and GameConfig.teams.enabled then
					local TeamManager = require(script.Parent.Parent.TeamManager)
					if TeamManager.areAllies(entity.model, player) then
						continue -- Skip team members
					end
				end

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
	local entityVector = vector.create(entityPos.X, entityPos.Y, entityPos.Z)
	
	local targetPos = target.Character.HumanoidRootPart.Position
	local targetVector = vector.create(targetPos.X, targetPos.Y, targetPos.Z)

	local toTarget = (targetPos - entityPos).Unit

	-- Calculate perpendicular directions (left and right)
	local leftDir = vector.create(-toTarget.Z, 0, toTarget.X)
	local rightDir = vector.create(toTarget.Z, 0, -toTarget.X)

	-- Test both sidestep positions
	local sideStepDist = 8
	local leftPos = entityVector + (leftDir * sideStepDist)
	local rightPos = entityVector + (rightDir * sideStepDist)

	-- Check which side gives clearer LOS
	local leftLOS = ProjectileLOS.validatePath(leftPos, targetVector, entity.model)
	local rightLOS = ProjectileLOS.validatePath(rightPos, targetVector, entity.model)

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
	local newGoal = entityVector + (moveDir * moveDistance)

	-- Move toward new position (simple approach, no pathfinding)
	entity.humanoid:MoveTo(newGoal)
	print(`*** {entity.entityId} repositioning to find clear shot`)

	-- Wait briefly for repositioning
	task.wait(0.5)
end

-- Perform attack on target using unified CombatSystem
local function performAttack(entity: EntityInstance, target: Player)
	if not target.Character or not target.Character:FindFirstChild("Humanoid") then
		return
	end

	local targetHumanoid = target.Character.Humanoid :: Humanoid
	local config = entity.config

	-- Don't attack if target is already dead
	if targetHumanoid.Health <= 0 then
		return
	end

	-- Get entity's weapon
	local weaponName = config.Stats.primaryWeapon
	if not weaponName then
		warn(`Entity {entity.entityId} has no primaryWeapon configured`)
		return
	end

	local CS = CombatSystem
	local weaponConfig = CS.getWeaponConfig(weaponName)
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

		-- Get stats for damage calculation
		local attackerStats = entity.scaledStats
		local targetStats = StatsProvider.getStats(target.Character)

		-- After castDuration: Check if target still in range using CombatSystem
		local result = CS.attemptMeleeAttack(
			entity.model,
			target.Character,
			weaponName,
			nil, -- No attacking player (this is an NPC)
			{
				attackerStats = attackerStats,
				targetStats = targetStats,
			}
		)

		if result.hit and result.damage then
			-- Target was in range - damage was applied by CombatSystem
			print(`*** {entity.entityId} hit {target.Name} for {result.damage} damage with {weaponName}`)
		elseif result.wasDodged then
			-- Target dodged!
			print(`*** {target.Name} dodged {entity.entityId} attack!`)
		elseif result.blockedByInvulnerability then
			-- Target is invulnerable
			print(`*** {target.Name} is invulnerable to {weaponName}`)
		end

	elseif weaponConfig.type == "projectile" then
		-- Check LOS before firing
		if weaponConfig.requiresLineOfSight then
			local losResult = ProjectileLOS.canTargetEntity(entity.model, target.Character)

			if not losResult.hasLineOfSight then
				print(`*** {entity.entityId} blocked by obstacle, repositioning`)
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
		local ProjectileManager = require(Engine.Combat.ProjectileManager)
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
			print(`*** {entity.entityId} fired {weaponName} at {target.Name}`)
		else
			print(`*** {entity.entityId} projectile attack failed`)
		end

	elseif weaponConfig.type == "hitscan" then
		-- Hitscan attack (uses HitscanManager like players)
		local HitscanManager = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("HitscanManager"))

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
			print(`*** {entity.entityId} hit {target.Name} with {weaponName}`)
		else
			print(`*** {entity.entityId} missed {target.Name} with {weaponName}`)
		end

	elseif weaponConfig.type == "aoe" then
		-- AOE attack
		local targetPos: Vector3

		if weaponConfig.range == 0 then
			-- Self-centered AOE
			targetPos = entity.humanoidRootPart.Position
		else
			-- Targeted at player position
			targetPos = target.Character.HumanoidRootPart.Position
		end

		-- Play attack animation
		playAnimation(entity, "attack")
		playSound(entity, "attack")
		updateEntityState(entity, "attacking")

		-- Show telegraph (warning for players to dodge)
		local telegraph = AOETelegraph.showCircleTelegraph(
			targetPos,
			weaponConfig.aoeRadius or 10,
			weaponConfig.castDuration,
			"damage"
		)

		-- Wait castDuration (players can dodge during this time)
		task.wait(weaponConfig.castDuration)

		-- Check if this is projectile AOE or instant AOE
		if weaponConfig.projectileSpeed then
			-- Projectile AOE: Spawn projectile that will explode on impact
			local ProjectileManager = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ProjectileManager"))
			local direction = (targetPos - entity.humanoidRootPart.Position).Unit
			local origin = entity.humanoidRootPart.Position + (direction * 2)

			local projectile = ProjectileManager.spawnProjectile(
				origin,
				direction,
				weaponName,
				entity.model,
				nil, -- No attacking player
				target.Character -- Locked target
			)

			if projectile then
				print(`*** {entity.entityId} fired AOE projectile {weaponName} at {target.Name}`)
			else
				print(`*** {entity.entityId} AOE projectile attack failed`)
			end
		else
			-- Instant AOE: Apply immediately at target position
			local attackerStats = entity.scaledStats
			local hits = CS.performAOEAttack(
				entity.model,
				targetPos,
				weaponName,
				nil, -- No attacking player (NPC)
				{
					attackerStats = attackerStats,
					onDamageCallback = function(target, attacker)
						EntityController.onEntityDamaged(target, attacker)
					end,
				}
			)

			print(`*** {entity.entityId} hit {#hits} entities with {weaponName} AOE`)
		end

	else
		-- Unknown weapon type
		warn(`Weapon type {weaponConfig.type} not yet implemented for NPCs`)
	end
end

-- Handle jumping logic
local function handleJumping(entity: EntityInstance)
	local config = entity.config
	local jumpCooldown = config.Stats.jumpCooldown or 3

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

-- Get closest entity of a specific category
local function getClosestEntityOfCategory(entity: EntityInstance, category: string): Model?
	if category == "Player" then
		-- Use existing player detection
		local player = getClosestPlayer(entity)
		return player and player.Character or nil

	elseif category == "Structure" then
		-- Find closest structure (building)
		-- TODO: Implement when building system is ready
		local townhall = _G.TownhallManager and _G.TownhallManager.GetTownhall()
		return townhall

	elseif category == "Wildlife" or category == "Creature" then
		-- Find closest entity of this category
		local position = entity.humanoidRootPart.Position
		local closest: Model? = nil

		local shortestDist = entity.config.Stats.ai.aggroRange or 30

		for model, otherEntity in activeEntities do
			if otherEntity.config.category == category and model ~= entity.model then
				-- Team filtering: Skip allies if team system enabled
				if GameConfig.combat.teamBased and GameConfig.teams and GameConfig.teams.enabled then
					local TeamManager = require(script.Parent.Parent.TeamManager)
					if TeamManager.areAllies(entity.model, model) then
						continue -- Skip team members
					end
				end

				local dist = (otherEntity.humanoidRootPart.Position - position).Magnitude
				if dist <= shortestDist then
					closest = model
					shortestDist = dist
				end
			end
		end

		return closest
	end

	return nil
end

-- Get target based on AI targetPriority array
local function getTarget(entity: EntityInstance): Model?
	-- local config = getEntityConfig(entity.entityId)
	-- if not config or not config.Stats or not config.Stats.ai or not config.Stats.ai.targetPriority then
	-- 	return nil
	-- end

	-- Check each priority in order
	for _, category in entity.config.Stats.ai.targetPriority do
		local target = getClosestEntityOfCategory(entity, category)
		if target then
			return target
		end
	end

	return nil
end

-- Wander behavior: Random wandering within radius from spawn point
local function behaviorWander(entity: EntityInstance)
	local currentTime = tick()
	local wanderCooldown = 3

	if currentTime - entity.lastWanderTime >= wanderCooldown then
		local wanderRadius = entity.config.Stats.ai.wanderRadius or 20
		local angle = math.random() * math.pi * 2
		local distance = math.random() * wanderRadius
		local offset = Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)
		local targetPos = entity.spawnPoint + offset
		entity.humanoid:MoveTo(targetPos)
		entity.lastWanderTime = currentTime
	end

	entity.humanoid.WalkSpeed = entity.config.Stats.walkSpeed or 12
	updateEntityState(entity, "wandering")
	playAnimation(entity, "walk")
end

-- Seek target behavior: Actively seek targets while wandering
local function behaviorSeekTarget(entity: EntityInstance)
	local seekRange = entity.config.Stats.ai.seekRange or 50
	local wanderRadius = entity.config.Stats.ai.wanderRadius or 20

	-- Look for target within seek range
	local target = getTarget(entity)

	if target then
		-- Found target - switch to chasing
		entity.isAggro = true
		entity.target = Players:GetPlayerFromCharacter(target) or target
		return
	end

	-- No target found - wander while seeking
	local currentTime = tick()
	local wanderCooldown = 3

	if currentTime - entity.lastWanderTime >= wanderCooldown then
		local angle = math.random() * math.pi * 2
		local distance = math.random() * wanderRadius
		local offset = Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)
		local targetPos = entity.spawnPoint + offset
		entity.humanoid:MoveTo(targetPos)
		entity.lastWanderTime = currentTime
	end

	entity.humanoid.WalkSpeed = entity.config.Stats.walkSpeed or 12
	updateEntityState(entity, "wandering")
	playAnimation(entity, "walk")
end

-- Return to spawn behavior: Walk back to spawn area
local function behaviorReturnToSpawn(entity: EntityInstance)
	local distanceToSpawn = (entity.humanoidRootPart.Position - entity.spawnPoint).Magnitude
	local returnThreshold = (entity.config.Stats.ai.wanderRadius or 20) * 1.5

	if distanceToSpawn > returnThreshold then
		-- Return to spawn
		entity.humanoid:MoveTo(entity.spawnPoint)
		entity.humanoid.WalkSpeed = (entity.config.Stats.walkSpeed or 12) * (entity.config.Stats.ai.returnSpeed or 0.5)
		updateEntityState(entity, "wandering")
		playAnimation(entity, "walk")
	else
		-- Close enough to spawn, resume idle behavior
		if entity.config.Stats.ai.behaviors.idle == "wander" then
			behaviorWander(entity)
		elseif entity.config.Stats.ai.behaviors.idle == "seek_target" then
			behaviorSeekTarget(entity)
		end
	end
end

-- Handle retargeting based on AI retargetBehavior setting
local function handleRetargeting(entity: EntityInstance): boolean
	local retargetBehavior = entity.config.Stats.ai.retargetBehavior or "locked"

	if retargetBehavior == "locked" then
		-- Never retarget
		return false

	elseif retargetBehavior == "closest" then
		-- Retarget to closest threat if current target out of range
		if entity.target then
			local currentTarget = entity.target
			local currentDist = math.huge

			if typeof(currentTarget) == "Instance" and currentTarget:IsA("Model") and currentTarget:FindFirstChild("HumanoidRootPart") then
				currentDist = (currentTarget.HumanoidRootPart.Position - entity.humanoidRootPart.Position).Magnitude
			end

			-- If current target is too far, find closest
			local chaseMultiplier = GameConfig.combat.chaseRangeMultiplier or 3
			local maxChaseRange = entity.config.Stats.ai.aggroRange * chaseMultiplier

			if currentDist > maxChaseRange then
				local newTarget = getTarget(entity)
				if newTarget then
					entity.target = Players:GetPlayerFromCharacter(newTarget) or newTarget
					return true
				else
					return false
				end
			end
		end

	elseif retargetBehavior == "priority" then
		-- Always check for higher priority targets
		local newTarget = getTarget(entity)
		if newTarget then
			entity.target = Players:GetPlayerFromCharacter(newTarget) or newTarget
			return true
		end
	end

	return false
end

-- Update entity AI behavior (main AI loop)
local function updateEntityAI(entity: EntityInstance)
	if not entity.model.Parent or entity.humanoid.Health <= 0 then
		return
	end

	local config = entity.config.Stats

	local currentTime = tick()

	-- Validate current target
	if entity.target then
		local targetModel = typeof(entity.target) == "Instance" and entity.target:IsA("Model") and entity.target or (typeof(entity.target) == "Instance" and entity.target.Character)

		if targetModel then
			local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
			local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")

			-- Clear target if dead or too far
			if not targetHumanoid or targetHumanoid.Health <= 0 then
				entity.target = nil
				entity.isAggro = false
			elseif targetRoot and targetRoot:IsA("BasePart") then
				local distance = (targetRoot.Position - entity.humanoidRootPart.Position).Magnitude
				local chaseMultiplier = GameConfig.combat.chaseRangeMultiplier or 3
				local maxChaseRange = config.ai.aggroRange * chaseMultiplier

				if distance > maxChaseRange then
					-- Try retargeting
					if not handleRetargeting(entity) then
						entity.target = nil
						entity.isAggro = false
						print(`{entity.entityId} gave up chase - target too far`)
					end
				end
			end
		else
			entity.target = nil
			entity.isAggro = false
		end
	end

	-- Look for new target if we don't have one
	if not entity.target then
		local target = getTarget(entity)
		if target then
			entity.isAggro = true
			entity.target = Players:GetPlayerFromCharacter(target) or target
		else
			entity.isAggro = false
		end
	end

	-- Handle behavior based on aggro state
	if entity.isAggro and entity.target then
		local targetModel = typeof(entity.target) == "Instance" and entity.target:IsA("Model") and entity.target or (typeof(entity.target) == "Instance" and entity.target.Character)

		if targetModel and targetModel:FindFirstChild("HumanoidRootPart") then
			local targetHRP = targetModel.HumanoidRootPart :: BasePart
			local targetPos = targetHRP.Position
			local distToTarget = (targetPos - entity.humanoidRootPart.Position).Magnitude

			-- Get weapon config for range/cooldown
			local weaponName = config.primaryWeapon
			local CS = CombatSystem
			local weaponConfig = CS.getWeaponConfig(weaponName)
			if not weaponConfig then
				warn(`Entity {entity.entityId} has no valid weapon config`)
				return
			end

			local attackDistance = weaponConfig.range
			local stoppingDistance = attackDistance * 0.8

			-- Adjust speed based on distance
			if entity.state ~= "attacking" then
				if distToTarget <= stoppingDistance then
					entity.humanoid.WalkSpeed = (config.walkSpeed or 12) * 0.6
					updateEntityState(entity, "chasing")
					playAnimation(entity, "walk")
				else
					entity.humanoid.WalkSpeed = config.runSpeed or 12
					updateEntityState(entity, "chasing")
					playAnimation(entity, "run")
				end
			end

			-- Attack if in range
			if distToTarget <= attackDistance then
				if currentTime - entity.lastAttackTime >= weaponConfig.cooldown then
					local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
					if targetPlayer then
						performAttack(entity, targetPlayer)
					end
				end
			end

			-- Movement
			if distToTarget > stoppingDistance then
				entity.humanoid:MoveTo(targetPos)
			else
				entity.humanoid:MoveTo(entity.humanoidRootPart.Position)
			end

			-- Jumping
			if config.canJump then
				handleJumping(entity)
			end
		end
	else
		-- Idle behavior (no target)
		local idleBehavior = config.ai.behaviors.idle

		if idleBehavior == "wander" then
			-- Check if we should return to spawn first
			if config.ai.returnToSpawn then
				local distanceToSpawn = (entity.humanoidRootPart.Position - entity.spawnPoint).Magnitude
				local returnThreshold = (config.ai.wanderRadius or 20) * 1.5

				if distanceToSpawn > returnThreshold then
					behaviorReturnToSpawn(entity)
				else
					behaviorWander(entity)
				end
			else
				behaviorWander(entity)
			end

		elseif idleBehavior == "seek_target" then
			behaviorSeekTarget(entity)

		else
			-- Default: stand idle
			entity.humanoid.WalkSpeed = config.walkSpeed or 12
			updateEntityState(entity, "idle")
			playAnimation(entity, "walk")
		end
	end
end

-- Initialize an entity with the centralized system
function EntityController.initializeEntity(model: Model, entityId: string): EntityInstance?
	local config = getEntityConfig(entityId)
	if not config then
		warn(`No configuration found for entity type: {entityId}`)
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart

	if not humanoid or not humanoidRootPart then
		warn(`Entity {entityId} missing Humanoid or HumanoidRootPart`)
		return nil
	end

	-- Get level from model attribute (defaults to 1)
	local level = (model:GetAttribute("Level") :: number) or 1

	-- Get spawn point from model attribute (defaults to current position)
	local spawnPoint = model:GetAttribute("SpawnPoint") or humanoidRootPart.Position

	-- Get patrol points from model attribute (if any)
	local patrolPoints: {Vector3}? = nil
	local patrolPointsJson = model:GetAttribute("PatrolPoints")
	if patrolPointsJson then
		local success, decoded = pcall(function()
			return game:GetService("HttpService"):JSONDecode(patrolPointsJson)
		end)
		if success and decoded then
			patrolPoints = decoded
		end
	end

	-- Get base stats from config or use defaults
	local baseStats = config.Stats.baseStats or {
		strength = 3,
		magic = 0,
		stamina = 2,
		accuracy = 3,
		level = level,
		xp = 0,
	}

	-- Scale stats based on level
	local scaledStats = Stats.scaleStatsForLevel(baseStats, level)

	-- Calculate derived stats for HP bonus
	local derived = Stats.getDerivedStats(scaledStats)

	-- Set up humanoid properties from config + stats
	humanoid.MaxHealth = (config.Stats.health or 50) + derived.maxHealthBonus
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = config.Stats.walkSpeed or 12

	-- Store attributes for other systems (targeting, health bars, etc.)
	model:SetAttribute("Level", level)
	model:SetAttribute("EntityId", config.id)
	model:SetAttribute("EntityName", config.Display.DisplayName)
	model:SetAttribute("EntityType", config.type)
	model:SetAttribute("CanTakeDamage", config.Stats.canTakeDamage)
	model:SetAttribute("MaxHealth", humanoid.MaxHealth)
	model:SetAttribute("CurrentHealth", humanoid.Health)

	-- Create entity instance
	local entity: EntityInstance = {
		entityId = entityId,
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

		-- Stats system
		level = level,
		xp = 0,
		baseStats = baseStats,
		scaledStats = scaledStats,
		config = config,

		-- AI system
		spawnPoint = spawnPoint,
		patrolPoints = patrolPoints,
		currentPatrolIndex = 1,
		attacker = nil,
	}

	-- Load animations
	loadAnimations(entity)

	-- Set initial state
	updateEntityState(entity, "idle")

	-- Sync CurrentHealth attribute when health changes
	humanoid.HealthChanged:Connect(function(newHealth)
		model:SetAttribute("CurrentHealth", newHealth)
	end)

	-- Handle death
	humanoid.Died:Connect(function()
		playSound(entity, "died") -- Play death sound if it exists

		-- Server-side only actions
		if RunService:IsServer() then
			-- Award XP to last attacker
			local XPRewardModule = getXPRewardManager()
			if XPRewardModule then
				XPRewardModule.awardXPForKill(model)
			end

			-- Process drops
			if DropSystem and entity.config and entity.config.Stats.drops then

				-- Get killer stats from last attacker
				local killerStats = nil
				if entity.attacker then
					killerStats = StatsProvider.getStats(entity.attacker)
				end

				-- Process drops (mode determined by GameSettings)
				DropSystem.processDrops(
					entity.config.Stats.drops,
					killerStats,
					entity.humanoidRootPart.Position,
					nil, -- Use default scatter radius from config
					model -- Pass model for container mode (future)
				)
			end
		end

		EntityController.removeEntity(model)
	end)

	-- Register entity
	activeEntities[model] = entity

	print(`Initialized {entityId} entity (Level {level}) with centralized controller`)
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
		print(`Removed {entity.entityId} from centralized controller`)
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
	Called when an entity takes damage - handles retargeting based on AI behavior

	@param entity - Entity that took damage
	@param attacker - The attacker (character model)
]]
function EntityController.onEntityDamaged(entity: Model, attacker: Model)
	local entityInstance = activeEntities[entity]
	if not entityInstance then
		return
	end

	-- Store attacker reference
	entityInstance.attacker = attacker

	-- Handle retargeting based on AI onDamaged behavior
	local onDamagedBehavior = entityInstance.config.ai and entityInstance.config.ai.behaviors.onDamaged or "ignore"

	if onDamagedBehavior == "retaliate_locked" then
		-- Always attack attacker, never switch
		if not entityInstance.target then
			local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
			if attackerPlayer then
				entityInstance.target = attackerPlayer
				entityInstance.isAggro = true
				print(`{entity.Name} now targeting {attackerPlayer.Name} after taking damage (locked)`)
			else
				entityInstance.target = attacker
				entityInstance.isAggro = true
				print(`{entity.Name} now targeting attacker (locked)`)
			end
		end

	elseif onDamagedBehavior == "retaliate_closest" then
		-- Attack attacker, but can switch to closer threats
		local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
		if not entityInstance.target then
			if attackerPlayer then
				entityInstance.target = attackerPlayer
				entityInstance.isAggro = true
				print(`{entity.Name} now targeting {attackerPlayer.Name} after taking damage (can retarget)`)
			else
				entityInstance.target = attacker
				entityInstance.isAggro = true
				print(`{entity.Name} now targeting attacker (can retarget)`)
			end
		end

	elseif onDamagedBehavior == "ignore" then
		-- Don't retarget from damage, maintain current target
		-- This is useful for creatures with mission objectives (like attacking structures)
		print(`{entity.Name} ignored damage, maintaining current target`)

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
		warn("Entity Controller already initialized")
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
-- DEPRECATED: Use CombatSystem.applyDamageToEntity() instead for centralized damage handling
function EntityController.handleDamage(
	model: Model,
	damage: number,
	damageSource: string?,
	attackerModel: Model?,
	hitPart: BasePart?
)
	local entity = activeEntities[model]
	if not entity then
		return
	end

	-- Use centralized damage system for proper XP tracking and stats
	if attackerModel and damageSource then
		-- Delegate to CombatSystem for full damage handling (XP, stats, feedback, aggro)
		local CS = CombatSystem
		local attackerStats = StatsProvider.getStats(attackerModel)
		local targetStats = entity.scaledStats

		CS.applyDamageToEntity(attackerModel, model, damageSource, {
			hitPart = hitPart,
			attackerStats = attackerStats,
			targetStats = targetStats,
			onDamageCallback = function(target, attacker)
				EntityController.onEntityDamaged(target, attacker)
			end,
		})
	else
		-- Direct damage (environmental damage, no attacker)
		-- This bypasses XP system since there's no attacker
		entity.humanoid:TakeDamage(damage)

		-- Show feedback for environmental damage (already imported at top)
		CombatFeedback.showDamage(model, damage, damageSource or "environmental", "other_player", nil)

		-- Play damage sound
		playSound(entity, "damage")

		print(`{entity.entityId} took {damage} environmental damage`)
	end
end

--[[
	Stats System Public API
	Used by CombatSystem and XPRewardManager
]]

-- Get entity stats (scaled for current level)
function EntityController.getEntityStats(model: Model): Stats.Stats?
	local entity = activeEntities[model]
	if not entity then
		return nil
	end

	return entity.scaledStats
end

-- Get entity level
function EntityController.getEntityLevel(model: Model): number
	local entity = activeEntities[model]
	if not entity then
		return 1
	end

	return entity.level
end

-- Set entity level and scale stats
function EntityController.setEntityLevel(model: Model, level: number)
	local entity = activeEntities[model]
	if not entity then
		return
	end

	entity.level = level
	entity.scaledStats = Stats.scaleStatsForLevel(entity.baseStats, level)

	-- Update HP based on new stamina
	local derived = Stats.getDerivedStats(entity.scaledStats)
	entity.humanoid.MaxHealth = entity.config.Stats.health + derived.maxHealthBonus

	-- Store level on model
	model:SetAttribute("Level", level)

	print(`{entity.entityId} leveled up to {level}!`)
end

-- Award XP to entity (uses centralized Stats.calculateXPReward)
function EntityController.awardEntityXP(model: Model, victimType: string, victimLevel: number)
	local entity = activeEntities[model]
	if not entity then
		return
	end

	-- Check if this entity type can earn XP
	if not GameConfig.stats.entityCanEarnXP[entity.entityId] then
		return
	end

	-- SECURITY: Use centralized calculation
	local xpAmount = Stats.calculateXPReward(victimType, victimLevel)

	entity.xp = entity.xp + xpAmount

	-- Check for level-up
	local newLevel = Stats.calculateLevelFromXP(entity.xp)
	if newLevel > entity.level then
		-- Auto-allocate stat points evenly (0.5 per stat for 2 points total)
		local pointsGained = (newLevel - entity.level) * GameConfig.stats.statPointsPerLevel
		local perStat = pointsGained / 4

		entity.baseStats.strength = entity.baseStats.strength + perStat
		entity.baseStats.magic = entity.baseStats.magic + perStat
		entity.baseStats.stamina = entity.baseStats.stamina + perStat
		entity.baseStats.accuracy = entity.baseStats.accuracy + perStat

		-- Apply scaling
		EntityController.setEntityLevel(model, newLevel)

		print(`{entity.entityId} earned {xpAmount} XP and leveled up to {newLevel}!`)
	else
		print(`{entity.entityId} earned {xpAmount} XP ({entity.xp} total)`)
	end
end

return EntityController