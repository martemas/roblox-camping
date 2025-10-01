--!strict

--[[
	ProjectileManager - Projectile Spawning and Registry Management

	Public API for spawning projectiles and managing the active projectile registry.
	All projectile logic is server-authoritative.

	Integration:
	- Called by CombatSystem after attack validation
	- Delegates physics to ProjectilePhysics module
	- Tracks all active projectiles
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local ProjectilePhysics = require(script.Parent:WaitForChild("ProjectilePhysics"))

type ProjectileInstance = CombatSystem.ProjectileInstance

local ProjectileManager = {}

-- Active projectiles registry
local activeProjectiles: {ProjectileInstance} = {}
local isInitialized = false

--[[
	Get projectile configuration for a weapon

	@param weaponName - Name of weapon
	@return ProjectileConfig or nil
]]
local function getProjectileConfig(weaponName: string): CombatSystem.ProjectileConfig?
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if weaponConfig and weaponConfig.projectileConfig then
		return weaponConfig.projectileConfig
	end
	return nil
end

--[[
	Spawn a new projectile

	@param origin - Starting position
	@param direction - Unit direction vector
	@param weaponName - Name of weapon (e.g., "Bow")
	@param attacker - Entity firing the projectile
	@param attackingPlayer - Player if attacker is player character
	@param lockedTarget - Intended target (for damageTargetOnly mode)
	@return ProjectileInstance or nil if failed
]]
function ProjectileManager.spawnProjectile(
	origin: Vector3,
	direction: Vector3,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?
): ProjectileInstance?
	-- Validate attack via CombatSystem first
	local isValid = CombatSystem.performProjectileAttack(
		origin,
		direction,
		weaponName,
		attacker,
		attackingPlayer,
		lockedTarget
	)

	if not isValid then
		return nil
	end

	-- Get weapon config
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig or weaponConfig.type ~= "projectile" then
		warn(`Cannot spawn projectile for weapon {weaponName}`)
		return nil
	end

	-- Get damage mode
	local damageMode = CombatSystem.getEffectiveDamageMode(weaponConfig)

	-- Get projectile model configuration
	local projectileConfig = getProjectileConfig(weaponName)
	if not projectileConfig then
		warn(`No projectile config found for {weaponName}`)
		return nil
	end

	-- Navigate to projectile model
	-- Path: ReplicatedStorage.Models.Tools.Projectiles.[WeaponName].[ModelPath]
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("ReplicatedStorage.Models folder not found")
		return nil
	end

	local toolsFolder = modelsFolder:FindFirstChild("Tools")
	if not toolsFolder then
		warn("ReplicatedStorage.Models.Tools folder not found")
		return nil
	end

	local projectilesFolder = toolsFolder:FindFirstChild("Projectiles")
	if not projectilesFolder then
		warn("ReplicatedStorage.Models.Tools.Projectiles folder not found")
		return nil
	end

	local weaponFolder = projectilesFolder:FindFirstChild(weaponName)
	if not weaponFolder then
		warn(`No projectile folder found for {weaponName} in Tools.Projectiles`)
		return nil
	end

	local projectileModel = weaponFolder:FindFirstChild(projectileConfig.modelPath)
	if not projectileModel or not projectileModel:IsA("Model") then
		warn(`No projectile model found at Projectiles.{weaponName}.{projectileConfig.modelPath}`)
		return nil
	end

	-- Clone and setup model
	local clone = projectileModel:Clone()
	clone.Parent = workspace

	if not clone.PrimaryPart then
		warn(`Projectile model {projectileConfig.modelPath} has no PrimaryPart`)
		clone:Destroy()
		return nil
	end

	-- Ensure all parts are anchored and non-collidable for physics-free movement
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	-- Position projectile at origin, facing direction
	clone:PivotTo(CFrame.new(origin, origin + direction))

	-- Create projectile instance
	local projectile: ProjectileInstance = {
		model = clone,
		weapon = weaponName,
		attacker = attacker,
		attackingPlayer = attackingPlayer,
		lockedTarget = lockedTarget,
		damageMode = damageMode,
		spawnTime = tick(),
		distanceTraveled = 0,
		maxRange = weaponConfig.range,
		speed = weaponConfig.projectileSpeed or 50,
		direction = direction.Unit,
		lastPosition = origin,
		entitiesHit = {},
	}

	-- Add to registry
	table.insert(activeProjectiles, projectile)

	print(`Spawned projectile: {weaponName} from {attacker.Name}`)

	return projectile
end

--[[
	Destroy a projectile and clean up

	@param projectile - Projectile to destroy
]]
function ProjectileManager.destroyProjectile(projectile: ProjectileInstance)
	-- Play impact effect (future enhancement)
	-- showImpactEffect(projectile)

	-- Destroy model
	if projectile.model and projectile.model.Parent then
		projectile.model:Destroy()
	end

	print(`Destroyed projectile: {projectile.weapon}`)
end

--[[
	Update all active projectiles

	Called every frame by Heartbeat connection

	@param deltaTime - Time since last frame
]]
local function updateAllProjectiles(deltaTime: number)
	for i = #activeProjectiles, 1, -1 do
		local projectile = activeProjectiles[i]

		-- Check if model still exists
		if not projectile.model or not projectile.model.Parent then
			table.remove(activeProjectiles, i)
			continue
		end

		-- Update projectile physics
		local shouldDestroy = ProjectilePhysics.updateProjectile(projectile, deltaTime)

		if shouldDestroy then
			ProjectileManager.destroyProjectile(projectile)
			table.remove(activeProjectiles, i)
		end
	end
end

--[[
	Initialize the projectile manager

	Call this on server startup
]]
function ProjectileManager.initialize()
	if isInitialized then
		warn("ProjectileManager already initialized")
		return
	end

	isInitialized = true

	-- Connect to Heartbeat for updates
	RunService.Heartbeat:Connect(function(deltaTime)
		updateAllProjectiles(deltaTime)
	end)

	print("ProjectileManager initialized")
end

--[[
	Get count of active projectiles (for debugging)

	@return number - Count of active projectiles
]]
function ProjectileManager.getActiveCount(): number
	return #activeProjectiles
end

return ProjectileManager
