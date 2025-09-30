--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))
local EntityStats = require(script.Parent:WaitForChild("EntityStats"))
local WeaponDefinitions = require(script.Parent:WaitForChild("WeaponDefinitions"))

-- Entity runtime state
export type EntityState = "idle" | "wandering" | "chasing" | "attacking" | "jumping"

export type EntityInstance = {
	entityType: string,
	entityCategory: string,
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

	-- New stats system
	stats: EntityStats.EntityStats,
	currentWeapon: EntityStats.WeaponStats,
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
local function getEntityConfig(entityType: string, entityCategory: string)
	if entityCategory == "wildlife" and GameConfig.wildlife[entityType] then
		return GameConfig.wildlife[entityType]
	elseif entityCategory == "enemy" and GameConfig.enemies[entityType] then
		return GameConfig.enemies[entityType]
	elseif entityCategory == "player" then
		return GameConfig.player
	end
	return nil
end

-- Load animations for an entity from GameConfig
local function loadAnimations(entity: EntityInstance)
	local config = getEntityConfig(entity.entityType, entity.entityCategory)
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

-- Play sound effect from model
local function playSound(entity: EntityInstance, soundName: string)
	local humanoidRootPart = entity.model:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		local sound = entity.model:FindFirstChild(soundName)
		if sound and sound:IsA("Sound") then
			sound.PlaybackSpeed = 1 + (math.random() * 0.2 - 0.1)
			sound:Play()
		end
		return
	end

	local sound = humanoidRootPart:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = 1 + (math.random() * 0.2 - 0.1)
		sound:Play()
	end
end

-- Create floating damage number above entity
local function createDamageDisplay(entity: EntityInstance, damage: number, damageSource: string?, damageType: string?)
	local humanoidRootPart = entity.humanoidRootPart

	-- Determine color based on damage type
	local textColor: Color3
	local displayText: string

	if damageType == "self" then
		textColor = Color3.fromRGB(255, 255, 100) -- Yellow
		displayText = "-" .. tostring(damage)
	elseif damageType == "other_player" then
		textColor = Color3.fromRGB(150, 150, 150) -- Gray
		displayText = "-" .. tostring(damage)
	elseif damageType == "incoming" then
		textColor = Color3.fromRGB(255, 100, 100) -- Red
		displayText = "-" .. tostring(damage)
	else
		textColor = Color3.fromRGB(255, 150, 150) -- Light red
		displayText = "-" .. tostring(damage)
	end

	-- Create BillboardGui for damage display
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 200, 0, 50)
	billboardGui.StudsOffset = Vector3.new(0, 2, 0)
	billboardGui.Parent = humanoidRootPart

	-- Create damage text label
	local damageLabel = Instance.new("TextLabel")
	damageLabel.Size = UDim2.new(1, 0, 1, 0)
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = displayText
	damageLabel.TextColor3 = textColor
	damageLabel.TextScaled = true
	damageLabel.Font = Enum.Font.SourceSansBold
	damageLabel.TextStrokeTransparency = 0
	damageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	damageLabel.Parent = billboardGui

	-- Animate the damage number
	local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(billboardGui, tweenInfo, {
		StudsOffset = Vector3.new(math.random(-1, 1), 4, math.random(-1, 1))
	})
	local fadeTween = TweenService:Create(damageLabel, tweenInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})

	tween:Play()
	fadeTween:Play()
	Debris:AddItem(billboardGui, 1.5)
end

-- Get closest player to entity
local function getClosestPlayer(entity: EntityInstance): Player?
	local config = getEntityConfig(entity.entityType, entity.entityCategory)
	if not config then return nil end

	local position = entity.humanoidRootPart.Position
	local closest: Player? = nil
	local shortestDist = config.aggroRange or 15

	for _, player in Players:GetPlayers() do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
			local playerHumanoid = player.Character.Humanoid :: Humanoid
			local playerHRP = player.Character.HumanoidRootPart :: BasePart

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

-- Perform attack on target using stats system
local function performAttack(entity: EntityInstance, target: Player)
	if not target.Character or not target.Character:FindFirstChild("Humanoid") then
		return
	end

	local targetHumanoid = target.Character.Humanoid :: Humanoid

	-- Don't attack if target is already dead
	if targetHumanoid.Health <= 0 then
		return
	end

	-- Check recently hit attribute to prevent spam
	if targetHumanoid:GetAttribute("RecentlyBit") then
		return
	end

	-- TODO: Get target player's stats for defense calculations
	-- For now, assume basic player stats
	local targetStats = EntityStats.calculateDerivedStats({
		strength = 10, stamina = 15, agility = 12, iq = 8
	})

	-- Calculate hit chance
	local hitChance = EntityStats.calculateHitChance(entity.stats, targetStats, entity.currentWeapon)
	local didHit = math.random() <= hitChance

	if not didHit then
		-- Miss - show miss indicator
		print(`{entity.entityType} missed {target.Name}`)
		return
	end

	-- Check for critical hit
	local isCritical = EntityStats.calculateCriticalHit(entity.stats, entity.currentWeapon)

	-- Calculate damage with stats
	local baseDamage = EntityStats.calculateDamage(entity.stats, entity.currentWeapon, isCritical)
	local finalDamage = EntityStats.calculateDamageReduction(baseDamage, targetStats, entity.currentWeapon.damageType)

	-- Apply damage
	targetHumanoid:TakeDamage(finalDamage)

	-- Show floating damage number above player
	if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
		local playerHRP = target.Character.HumanoidRootPart :: BasePart
		local tempEntity = {
			entityType = "Player",
			humanoidRootPart = playerHRP
		}
		createDamageDisplay(tempEntity :: any, finalDamage, entity.entityType, "incoming")
	end

	-- Play attack animation and sound
	playAnimation(entity, "attack")
	playSound(entity, "attack")

	-- Set recently hit protection
	targetHumanoid:SetAttribute("RecentlyBit", true)

	local critText = isCritical and " (CRITICAL!)" or ""
	print(`{entity.entityType} attacked {target.Name} for {finalDamage} damage{critText}`)

	-- Clear protection after cooldown
	task.delay(entity.currentWeapon.cooldown, function()
		if targetHumanoid then
			targetHumanoid:SetAttribute("RecentlyBit", false)
		end
	end)

	entity.lastAttackTime = tick()
end

-- Handle jumping logic
local function handleJumping(entity: EntityInstance)
	local config = getEntityConfig(entity.entityType, entity.entityCategory)
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

-- Get target based on priority
local function getTarget(entity: EntityInstance): Player?
	local config = getEntityConfig(entity.entityType, entity.entityCategory)
	if not config then return nil end

	-- Always prioritize players first
	local player = getClosestPlayer(entity)
	if player then
		return player
	end

	-- TODO: Add structure targeting when building system is ready
	return nil
end

-- Update entity AI behavior (main AI loop)
local function updateEntityAI(entity: EntityInstance)
	if not entity.model.Parent or entity.humanoid.Health <= 0 then
		return
	end

	local config = getEntityConfig(entity.entityType, entity.entityCategory)
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

		-- Set running speed based on stats
		entity.humanoid.WalkSpeed = entity.stats.moveSpeed * 1.5 -- Run speed
		updateEntityState(entity, "chasing")
		playAnimation(entity, "run")

		-- Attack if close enough
		if distToTarget <= entity.currentWeapon.attackRange then
			if currentTime - entity.lastAttackTime >= entity.currentWeapon.cooldown then
				updateEntityState(entity, "attacking")
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
		entity.humanoid.WalkSpeed = entity.stats.moveSpeed
		updateEntityState(entity, "wandering")
		playAnimation(entity, "walk")

		-- Simple wandering logic with cooldown
		local wanderCooldown = 3
		if currentTime - entity.lastWanderTime >= wanderCooldown then
			local wanderRange = config.wanderRange or 10
			local randomOffset = Vector3.new(
				math.random(-wanderRange, wanderRange),
				0,
				math.random(-wanderRange, wanderRange)
			)
			local currentPos = entity.humanoidRootPart.Position
			local targetPos = Vector3.new(
				currentPos.X + randomOffset.X,
				currentPos.Y + randomOffset.Y,
				currentPos.Z + randomOffset.Z
			)
			entity.humanoid:MoveTo(targetPos)
			entity.lastWanderTime = currentTime
		end
	end
end

-- Initialize an entity with the stats system
function EntityController.initializeEntity(model: Model, entityType: string, entityCategory: string): EntityInstance?
	local config = getEntityConfig(entityType, entityCategory)
	if not config then
		warn(`No configuration found for entity type: {entityType} ({entityCategory})`)
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart

	if not humanoid or not humanoidRootPart then
		warn(`Entity {entityType} missing Humanoid or HumanoidRootPart`)
		return nil
	end

	-- Calculate entity stats from config
	local entityStats = EntityStats.calculateDerivedStats(config.stats)

	-- Get default weapon
	local defaultWeapon = WeaponDefinitions.getDefaultWeapon(entityType)
	if not defaultWeapon then
		warn(`No default weapon found for entity type: {entityType}`)
		return nil
	end

	-- Set up humanoid properties from calculated stats
	humanoid.MaxHealth = entityStats.maxHealth
	humanoid.Health = entityStats.health
	humanoid.WalkSpeed = entityStats.moveSpeed

	-- Set model attributes for targeting system
	model:SetAttribute("EntityType", entityType)
	model:SetAttribute("EntityCategory", entityCategory)

	-- Create entity instance
	local entity: EntityInstance = {
		entityType = entityType,
		entityCategory = entityCategory,
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
		stats = entityStats,
		currentWeapon = defaultWeapon,
	}

	-- Load animations
	loadAnimations(entity)

	-- Set initial state
	updateEntityState(entity, "idle")

	-- Handle death
	humanoid.Died:Connect(function()
		playSound(entity, "died")
		EntityController.removeEntity(model)
	end)

	-- Register entity
	activeEntities[model] = entity

	print(`Initialized {entityType} ({entityCategory}) with stats: HP={entityStats.maxHealth}, ATK={entityStats.attackPower}, SPD={entityStats.moveSpeed}`)
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
		print(`Removed {entity.entityType} from EntityController`)
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

-- Force an entity to target a specific player
function EntityController.setTarget(model: Model, target: Player?)
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

-- Clean up all entities
function EntityController.cleanup()
	for model, entity in pairs(activeEntities) do
		EntityController.removeEntity(model)
	end
	activeEntities = {}
end

-- Public API for external systems (like ToolManager hitting entities)
function EntityController.handleDamage(model: Model, damage: number, damageSource: string?, attackingPlayer: Player?)
	local entity = activeEntities[model]
	if entity then
		-- Apply damage using stats system
		local actualDamage = EntityStats.applyDamage(entity.stats, damage)

		-- Update humanoid health to match entity stats
		entity.humanoid.Health = entity.stats.health

		-- Determine damage type for color coding
		local damageType = "self" -- Default to self damage

		-- Show floating damage number
		createDamageDisplay(entity, actualDamage, damageSource, damageType)

		-- Play damage sound
		playSound(entity, "damage")

		print(`{entity.entityType} took {actualDamage} damage from {damageSource or "unknown"}`)
	end
end

return EntityController