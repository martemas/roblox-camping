# Combat System - Projectile Manager Implementation

## Overview

This document covers the implementation of the ProjectileManager system, which handles spawning, tracking, and physics simulation for all projectile weapons in the game.

**Architecture:**
- **ProjectileManager.luau** - Simple interface for spawning and registry management
- **ProjectilePhysics.luau** - Complex collision detection and damage calculation logic

**Security:** Server-authoritative only. All projectile logic runs on server.

---

## File Structure

### Module Organization

```
src/shared/
├── ProjectileManager.luau    (~100 LOC) - Public API, spawn, registry
└── ProjectilePhysics.luau     (~200 LOC) - Physics, collision, damage
```

### Model Organization

```
ReplicatedStorage.Models.Tools/
├── Bow/
│   └── Projectiles/
│       └── Arrow1/          (Model with PrimaryPart, Attachments, Trail)
└── [OtherWeapons]/
    └── Projectiles/
        └── [ProjectileName]/
```

---

## Type Definitions

### ProjectileInstance Type

**Location:** `src/shared/CombatSystem.luau` (exported type)

```lua
export type ProjectileInstance = {
	model: Model,               -- The visual projectile model
	weapon: string,             -- Weapon name (e.g., "Bow")
	attacker: Model,            -- Entity that fired the projectile
	attackingPlayer: Player?,   -- Player if attacker is player character
	lockedTarget: Model?,       -- The intended target (for damageTargetOnly mode)
	damageMode: DamageMode,     -- Damage calculation mode
	spawnTime: number,          -- Time projectile was spawned (tick())
	distanceTraveled: number,   -- Total distance traveled in studs
	maxRange: number,           -- Max range before despawn
	speed: number,              -- Speed in studs/second
	direction: Vector3,         -- Unit direction vector
	lastPosition: Vector3,      -- Last frame position (for raycast)
	entitiesHit: {[Model]: boolean}, -- Track hit entities for penetration
}

export type ProjectileConfig = {
	modelPath: string,          -- Path to projectile model in ReplicatedStorage
	speed: number,
	maxRange: number,
	trailEnabled: boolean,
	trailColor: Color3?,
	impactEffect: string?,      -- Name of impact effect model
}
```

---

## 1. ProjectileManager.luau

**Purpose:** Public API for spawning projectiles and managing the active projectile registry.

### Implementation

```lua
--!strict

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
	-- Get weapon config
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig or weaponConfig.type ~= "projectile" then
		warn(`Cannot spawn projectile for weapon {weaponName}`)
		return nil
	end

	-- Get damage mode
	local damageMode = CombatSystem.getEffectiveDamageMode(weaponConfig)

	-- Get projectile model path
	-- Pattern: ReplicatedStorage.Models.Tools.[WeaponName].Projectiles.[ProjectileName]
	local projectileConfig = getProjectileConfig(weaponName)
	if not projectileConfig then
		warn(`No projectile config found for {weaponName}`)
		return nil
	end

	-- Clone projectile model
	local projectileTemplate = ReplicatedStorage.Models.Tools:FindFirstChild(weaponName)
	if not projectileTemplate then
		warn(`No tool model found for {weaponName}`)
		return nil
	end

	local projectilesFolder = projectileTemplate:FindFirstChild("Projectiles")
	if not projectilesFolder then
		warn(`No Projectiles folder found in {weaponName}`)
		return nil
	end

	local projectileModel = projectilesFolder:FindFirstChild(projectileConfig.modelPath)
	if not projectileModel then
		warn(`No projectile model found at {projectileConfig.modelPath}`)
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

	-- Position projectile at origin
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
	Get projectile configuration for a weapon

	@param weaponName - Name of weapon
	@return ProjectileConfig or nil
]]
local function getProjectileConfig(weaponName: string): CombatSystem.ProjectileConfig?
	-- For now, hardcoded configs
	-- Future: Move to GameConfig.weapons[weaponName].projectileConfig
	local configs = {
		Bow = {
			modelPath = "Arrow1",
			speed = 80,
			maxRange = 100,
			trailEnabled = true,
			trailColor = Color3.fromRGB(255, 200, 100),
			impactEffect = "ArrowImpact",
		},
		SpiderWeb = {
			modelPath = "Web1",
			speed = 30,
			maxRange = 40,
			trailEnabled = true,
			trailColor = Color3.fromRGB(200, 200, 200),
			impactEffect = "WebSplat",
		},
	}

	return configs[weaponName]
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
]]
function ProjectileManager.getActiveCount(): number
	return #activeProjectiles
end

return ProjectileManager
```

---

## 2. ProjectilePhysics.luau

**Purpose:** Handle projectile physics simulation, collision detection, and damage application.

### Implementation

```lua
--!strict

local Players = game:GetService("Players")

local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local CombatFeedback = require(script.Parent:WaitForChild("CombatFeedback"))

type ProjectileInstance = CombatSystem.ProjectileInstance
type DamageMode = CombatSystem.DamageMode

local ProjectilePhysics = {}

--[[
	Update projectile physics for one frame

	@param projectile - Projectile to update
	@param deltaTime - Time since last frame
	@return boolean - True if projectile should be destroyed
]]
function ProjectilePhysics.updateProjectile(
	projectile: ProjectileInstance,
	deltaTime: number
): boolean
	-- Calculate movement
	local movement = projectile.direction * (projectile.speed * deltaTime)
	local currentPos = projectile.lastPosition
	local newPos = currentPos + movement

	-- Setup raycast parameters
	local raycastParams = buildRaycastParams(projectile)

	-- Perform raycast from last position to new position
	local raycastResult = workspace:Raycast(currentPos, movement, raycastParams)

	if raycastResult then
		-- Hit something
		return handleRaycastHit(projectile, raycastResult)
	end

	-- No hit - update position
	if projectile.model.PrimaryPart then
		projectile.model:PivotTo(CFrame.new(newPos, newPos + projectile.direction))
	end

	projectile.lastPosition = newPos
	projectile.distanceTraveled = projectile.distanceTraveled + movement.Magnitude

	-- Check max range
	if projectile.distanceTraveled >= projectile.maxRange then
		print(`Projectile {projectile.weapon} reached max range`)
		return true -- Destroy
	end

	return false -- Keep alive
end

--[[
	Build raycast parameters based on damage mode

	@param projectile - Projectile instance
	@return RaycastParams - Configured raycast parameters
]]
local function buildRaycastParams(projectile: ProjectileInstance): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local ignoreList: {Instance} = {projectile.attacker, projectile.model}

	if projectile.damageMode.damageTargetOnly then
		-- Ignore ALL entities except locked target
		addAllEntitiesExceptTarget(ignoreList, projectile.lockedTarget)
	else
		-- Only ignore already-hit entities (for penetration mode)
		for entity, _ in projectile.entitiesHit do
			table.insert(ignoreList, entity)
		end
	end

	params.FilterDescendantsInstances = ignoreList
	return params
end

--[[
	Handle raycast hit

	@param projectile - Projectile instance
	@param raycastResult - Raycast result
	@return boolean - True if projectile should be destroyed
]]
local function handleRaycastHit(
	projectile: ProjectileInstance,
	raycastResult: RaycastResult
): boolean
	-- Find entity from hit part
	local hitEntity = findEntityFromPart(raycastResult.Instance)

	if hitEntity then
		-- Hit an entity
		return handleEntityHit(projectile, hitEntity, raycastResult)
	else
		-- Hit terrain/structure - always destroy
		print(`Projectile {projectile.weapon} hit terrain/structure`)
		showImpactEffect(projectile, raycastResult.Position)
		return true
	end
end

--[[
	Handle entity collision

	@param projectile - Projectile instance
	@param entity - Entity that was hit
	@param raycastResult - Raycast result
	@return boolean - True if projectile should be destroyed
]]
local function handleEntityHit(
	projectile: ProjectileInstance,
	entity: Model,
	raycastResult: RaycastResult
): boolean
	-- Check if already hit this entity
	if projectile.entitiesHit[entity] then
		return false -- Already damaged, continue
	end

	-- Mark as hit
	projectile.entitiesHit[entity] = true

	-- Determine if should damage this entity
	local shouldDamage = false
	if projectile.damageMode.damageTargetOnly then
		-- Only damage if this is the locked target
		shouldDamage = (entity == projectile.lockedTarget)
	else
		-- Damage any entity hit
		shouldDamage = true
	end

	if shouldDamage then
		applyDamage(projectile, entity)
	end

	-- Check penetration
	if projectile.damageMode.penetratesEntities then
		-- Continue flying through entity
		return false
	else
		-- Stop at first entity hit
		print(`Projectile {projectile.weapon} hit entity {entity.Name}, stopping`)
		showImpactEffect(projectile, raycastResult.Position)
		return true
	end
end

--[[
	Apply damage to an entity

	@param projectile - Projectile instance
	@param entity - Entity to damage
]]
local function applyDamage(projectile: ProjectileInstance, entity: Model)
	local humanoid = entity:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Check PvP rules
	if not CombatSystem.isPvPAllowed(projectile.attacker, entity) then
		print(`PvP blocked: {projectile.attacker.Name} cannot damage {entity.Name}`)
		return
	end

	-- Get weapon config for damage value
	local weaponConfig = CombatSystem.getWeaponConfig(projectile.weapon)
	if not weaponConfig then
		return
	end

	-- Apply damage
	humanoid:TakeDamage(weaponConfig.damage)

	-- Determine damage type for feedback
	local damageType: CombatFeedback.DamageType
	local entityPlayer = Players:GetPlayerFromCharacter(entity)

	if entityPlayer then
		-- Damage to a player
		damageType = "incoming"
	else
		-- Damage to an NPC
		if projectile.attackingPlayer then
			damageType = "self"
		else
			damageType = "other_player"
		end
	end

	-- Show damage feedback
	CombatFeedback.showDamage(
		entity,
		weaponConfig.damage,
		projectile.weapon,
		damageType,
		projectile.attackingPlayer
	)

	print(`Projectile {projectile.weapon} hit {entity.Name} for {weaponConfig.damage} damage`)
end

--[[
	Find entity model from a part

	@param part - Part that was hit
	@return Model or nil
]]
local function findEntityFromPart(part: BasePart): Model?
	local current = part.Parent
	while current and current ~= workspace do
		if current:IsA("Model") then
			-- Check if it's a player character
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return current
			end

			-- Check if it's an NPC with EntityType attribute
			local entityType = current:GetAttribute("EntityType")
			if entityType then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

--[[
	Add all entities except target to ignore list

	@param ignoreList - List to append to
	@param target - Target entity to NOT ignore
]]
local function addAllEntitiesExceptTarget(ignoreList: {Instance}, target: Model?)
	-- Add all player characters except target
	for _, player in Players:GetPlayers() do
		if player.Character and player.Character ~= target then
			table.insert(ignoreList, player.Character)
		end
	end

	-- Add all NPCs except target
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Humanoid") and descendant.Parent ~= target then
			local model = descendant.Parent
			if model and model:IsA("Model") then
				table.insert(ignoreList, model)
			end
		end
	end
end

--[[
	Show impact effect at position (future enhancement)

	@param projectile - Projectile instance
	@param position - Impact position
]]
local function showImpactEffect(projectile: ProjectileInstance, position: Vector3)
	-- TODO: Spawn impact particle effect
	-- For now, just a placeholder
end

return ProjectilePhysics
```

---

## 3. Integration with Existing Systems

### CombatSystem.luau Updates

**Add ProjectileConfig type export:**

```lua
export type ProjectileConfig = {
	modelPath: string,
	speed: number,
	maxRange: number,
	trailEnabled: boolean,
	trailColor: Color3?,
	impactEffect: string?,
}

export type ProjectileInstance = {
	model: Model,
	weapon: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?,
	damageMode: DamageMode,
	spawnTime: number,
	distanceTraveled: number,
	maxRange: number,
	speed: number,
	direction: Vector3,
	lastPosition: Vector3,
	entitiesHit: {[Model]: boolean},
}
```

**Update performProjectileAttack to spawn projectile:**

```lua
function CombatSystem.performProjectileAttack(
	origin: vector,
	direction: vector,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?
): boolean
	-- Existing validation code...

	-- Import ProjectileManager
	local ProjectileManager = require(script.Parent:WaitForChild("ProjectileManager"))

	-- Spawn projectile
	local projectile = ProjectileManager.spawnProjectile(
		origin,
		direction,
		weaponName,
		attacker,
		attackingPlayer,
		lockedTarget
	)

	return projectile ~= nil
end
```

### Server Initialization

**Update `src/server/init.server.luau`:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectileManager = require(ReplicatedStorage.Shared.ProjectileManager)

-- Initialize projectile system
ProjectileManager.initialize()
```

---

## 4. Projectile Model Setup

### Model Structure

**Path:** `ReplicatedStorage.Models.Tools.Bow.Projectiles.Arrow1`

**Hierarchy:**
```
Arrow1 (Model)
├── PrimaryPart (Part) - Main arrow body
│   ├── Attachment0 (Attachment) - Trail start (back)
│   ├── Attachment1 (Attachment) - Trail end (front)
│   └── Trail (Trail) - Visual trail effect
│       • Color = ColorSequence (yellow/orange)
│       • Lifetime = 0.5
│       • Transparency = NumberSequence (0 → 1)
├── ArrowHead (MeshPart) - Optional tip mesh
└── ArrowFletch (MeshPart) - Optional feather mesh
```

### Model Properties

**All Parts:**
- `CanCollide = false` (using raycasts instead)
- `Anchored = false`
- `Massless = true`

**Model:**
- `PrimaryPart = PrimaryPart` (must be set)

**Collision Setup:**
- Create CollisionGroup "Projectiles"
- Set projectiles to NOT collide with themselves
- Configure via PhysicsService

---

## 5. Testing Checklist

### Basic Functionality
- [ ] Projectile spawns at correct origin
- [ ] Travels in correct direction
- [ ] Moves at configured speed
- [ ] Trail effect visible
- [ ] Despawns after max range
- [ ] Despawns on terrain hit
- [ ] Despawns on entity hit (non-penetrating)

### Damage Modes
- [ ] `damageTargetOnly = true`: Only locked target takes damage
- [ ] `damageTargetOnly = false`: Any entity in path takes damage
- [ ] `penetratesEntities = true`: Projectile passes through entities
- [ ] `penetratesEntities = false`: Projectile stops at first entity
- [ ] Entities can only be hit once per projectile

### Security
- [ ] Server spawns all projectiles
- [ ] Client cannot manipulate projectile damage
- [ ] Client cannot bypass LOS validation
- [ ] PvP rules enforced
- [ ] No client-side spawning possible

### Performance
- [ ] No lag with 10+ active projectiles
- [ ] Raycast filtering efficient
- [ ] No memory leaks
- [ ] Update loop performs well

### Edge Cases
- [ ] Projectile attacker dies mid-flight (projectile continues)
- [ ] Target dies mid-flight (projectile continues)
- [ ] Multiple projectiles from same attacker
- [ ] Projectile at max range boundary
- [ ] Very fast projectiles don't tunnel (raycast catches)
- [ ] Very slow projectiles still update correctly

---

## 6. Future Enhancements

### Visual Effects
- Impact particle effects on hit
- Different effects for entity vs terrain hits
- Weapon-specific trail colors/styles

### Audio
- Launch sound (play on spawn)
- Impact sound (play on hit)
- Whoosh sound for fast projectiles

### Projectile Pooling
- Object pool for frequently spawned projectiles
- Reduce Instance creation overhead
- Reuse instead of Clone/Destroy

### Advanced Physics
- Gravity simulation for arcing projectiles
- Wind effects
- Projectile drop over distance
- Spin/rotation effects

### Projectile Types
- Homing projectiles (seek target)
- Explosive projectiles (trigger AOE on impact)
- Bouncing projectiles (ricochet off surfaces)
- Chained projectiles (lightning between targets)

---

## Success Criteria

Implementation complete when:
- ✅ Both ProjectileManager and ProjectilePhysics modules implemented
- ✅ Projectiles spawn and move correctly
- ✅ Collision detection works with all damage modes
- ✅ Server-authoritative security maintained
- ✅ Integration with CombatSystem complete
- ✅ Bow weapon functional with Arrow1 projectile
- ✅ All tests passed
- ✅ No performance issues
- ✅ Rojo build succeeds

---

## Performance Targets

- **60 FPS** with 20+ active projectiles
- **< 5ms** per frame for all projectile updates
- **< 50 instances** created per second
- **< 1MB** memory allocated per minute
- **Zero** memory leaks

---

## Security Notes

**Critical: All projectile logic is server-side only**

- Client never spawns projectiles
- Client never updates projectile positions
- Client never calculates damage
- Server validates all attacks before spawning
- Server enforces all damage modes and rules
- Client only sees visual representation

**Rate Limiting:**
Weapon cooldowns prevent projectile spam (handled by ToolManager).

**Exploit Prevention:**
- Server validates weapon ownership
- Server validates LOS before spawn
- Server validates facing requirements
- Server enforces max projectiles per player (future)
