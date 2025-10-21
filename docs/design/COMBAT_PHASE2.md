# Combat System - Phase 2 Implementation Guide

## Table of Contents
1. [Overview](#overview)
2. [Projectile Weapons](#projectile-weapons)
3. [Hitscan Weapons](#hitscan-weapons)
4. [AOE Weapons](#aoe-weapons)
5. [Entity AI Updates](#entity-ai-updates)
6. [GameConfig Updates](#gameconfig-updates)
7. [Testing Checklist](#testing-checklist)
8. [Performance Considerations](#performance-considerations)

---

## Overview

Phase 2 expands the combat system to support advanced weapon types beyond basic melee:
- **Projectile Weapons** - Physical projectiles that travel through space (arrows, fireballs)
- **Hitscan Weapons** - Instant raycasts (crossbows, magic missiles, lasers)
- **AOE Weapons** - Area-of-effect attacks (ground slam, healing circles, explosions)

All weapon types use the unified combat system from Phase 1, ensuring consistent:
- Server-authoritative damage calculation
- CombatFeedback integration
- Invulnerability frames support
- PvP/PvE mode compatibility
- Telegraph systems for counterplay

---

## Projectile Weapons

### Weapon Examples
- **Bow** (player weapon) - Arrow projectile, medium speed
- **SpiderWeb** (enemy ranged attack) - Slow projectile, medium range

### Architecture

#### ProjectileManager Module
**File:** `src/shared/ProjectileManager.luau`

**Purpose:** Centralized system for spawning, tracking, and managing all projectiles.

**Type Definitions:**
```lua
export type ProjectileInstance = {
	model: Model,
	weapon: string,
	attacker: Model,
	attackingPlayer: Player?,
	spawnTime: number,
	distanceTraveled: number,
	maxRange: number,
	speed: number,
	direction: vector,
	lastPosition: vector,
	connection: RBXScriptConnection?,
}

export type ProjectileConfig = {
	modelTemplate: Model, -- Template to clone
	speed: number,
	maxRange: number,
	trailEnabled: boolean,
	trailColor: Color3?,
	hitEffect: string?, -- Particle effect on impact
}
```

**Core Functions:**

```lua
-- Spawn a new projectile
function ProjectileManager.spawnProjectile(
	origin: vector,
	direction: vector,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?
): ProjectileInstance?
	-- 1. Get weapon config
	-- 2. Clone projectile model from ReplicatedStorage.Models.Projectiles
	-- 3. Position at origin
	-- 4. Create BodyVelocity or LinearVelocity for movement
	-- 5. Set up collision detection
	-- 6. Add trail effects
	-- 7. Register in active projectiles table
	-- 8. Return ProjectileInstance
end

-- Update projectile position and check for hits
function ProjectileManager.updateProjectile(projectile: ProjectileInstance, deltaTime: number)
	-- 1. Calculate new position based on speed and direction
	-- 2. Perform raycast from lastPosition to currentPosition (prevent tunneling)
	-- 3. Check if raycast hit anything
	-- 4. If hit entity: apply damage via CombatSystem, destroy projectile
	-- 5. If hit terrain/wall: destroy projectile
	-- 6. Update distanceTraveled
	-- 7. If distanceTraveled > maxRange: destroy projectile
	-- 8. Update lastPosition
end

-- Destroy a projectile and clean up
function ProjectileManager.destroyProjectile(projectile: ProjectileInstance)
	-- 1. Disconnect update connection
	-- 2. Play impact effect if configured
	-- 3. Destroy model
	-- 4. Remove from active projectiles table
end

-- Main update loop for all active projectiles
function ProjectileManager.updateAllProjectiles(deltaTime: number)
	for id, projectile in activeProjectiles do
		if projectile.model.Parent then
			updateProjectile(projectile, deltaTime)
		else
			-- Projectile was destroyed externally, clean up
			destroyProjectile(projectile)
		end
	end
end

-- Initialize the projectile system
function ProjectileManager.initialize()
	-- Connect to RunService.Heartbeat for updates
	RunService.Heartbeat:Connect(function(deltaTime)
		updateAllProjectiles(deltaTime)
	end)
end
```

**Collision Detection Strategy:**

Use **continuous raycasting** to prevent tunneling:
```lua
-- Each frame, raycast from last position to current position
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = {projectile.attacker, projectile.model}

local raycastResult = workspace:Raycast(
	projectile.lastPosition,
	projectile.direction * (projectile.speed * deltaTime),
	raycastParams
)

if raycastResult then
	-- Check if hit an entity
	local hitEntity = findEntityFromPart(raycastResult.Instance)
	if hitEntity then
		-- Apply damage
		local weaponConfig = CombatSystem.getWeaponConfig(projectile.weapon)
		local targetHumanoid = hitEntity:FindFirstChildOfClass("Humanoid")
		if targetHumanoid then
			targetHumanoid:TakeDamage(weaponConfig.damage)
			CombatFeedback.showDamage(hitEntity, weaponConfig.damage, projectile.weapon, "self", projectile.attackingPlayer)
		end
		-- Destroy projectile
		destroyProjectile(projectile)
	else
		-- Hit terrain/wall - destroy projectile
		destroyProjectile(projectile)
	end
end
```

**Visual Effects:**

Trail effect using `Trail` instance:
```lua
local trail = Instance.new("Trail")
trail.Attachment0 = projectile.model:FindFirstChild("Attachment0")
trail.Attachment1 = projectile.model:FindFirstChild("Attachment1")
trail.Color = ColorSequence.new(weaponConfig.trailColor or Color3.fromRGB(255, 200, 0))
trail.Lifetime = 0.5
trail.Transparency = NumberSequence.new(0, 1)
trail.Parent = projectile.model
```

Impact effect:
```lua
local impactEffect = ReplicatedStorage.Effects:FindFirstChild(weaponConfig.hitEffect)
if impactEffect then
	local effect = impactEffect:Clone()
	effect.Position = raycastResult.Position
	effect.Parent = workspace
	Debris:AddItem(effect, 2)
end
```

### CombatSystem Integration

**Update `CombatSystem.luau`:**

Replace the stub function:
```lua
-- Perform projectile attack
function CombatSystem.performProjectileAttack(
	origin: vector,
	direction: vector,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?
): ProjectileInstance?
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig or weaponConfig.type ~= "projectile" then
		warn(`Weapon {weaponName} is not a projectile weapon`)
		return nil
	end

	-- Spawn projectile via ProjectileManager
	local projectile = ProjectileManager.spawnProjectile(
		origin,
		direction,
		weaponName,
		attacker,
		attackingPlayer
	)

	return projectile
end
```

### ToolManager Integration

**Update `performCombatAttack` function:**

```lua
-- In performCombatAttack function
local character = player.Character
if not character then
	return
end

local toolConfig = GameConfig.tools[toolType]
if not toolConfig or not toolConfig.weaponRef then
	return
end

local weaponName = toolConfig.weaponRef
local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
if not weaponConfig then
	return
end

-- Handle different weapon types
if weaponConfig.type == "melee" then
	-- Existing melee logic
	task.wait(weaponConfig.castDuration)
	local target = TargetingSystem.getTarget(player)
	local result = CombatSystem.attemptMeleeAttack(character, target, weaponName, player)
	-- ... existing melee handling

elseif weaponConfig.type == "projectile" then
	-- Get projectile origin (slightly in front of player)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	-- Get aim direction from camera
	local direction = getPlayerAimDirection(player)
	local origin = humanoidRootPart.Position + (direction * 3) -- 3 studs in front

	-- Wait for castDuration (draw/charge animation)
	task.wait(weaponConfig.castDuration)

	-- Spawn projectile
	local projectile = CombatSystem.performProjectileAttack(
		origin,
		direction,
		weaponName,
		character,
		player
	)

	if projectile then
		playToolSound(player, toolType, "attack")
		print(`{player.Name} fired {weaponName}`)
	else
		playToolSound(player, toolType, "swing")
	end
end
```

**Helper function for player aim direction:**

```lua
-- Get player's aim direction based on camera or mouse
local function getPlayerAimDirection(player: Player): vector
	-- Option 1: Use camera direction (first-person/third-person)
	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoidRootPart then
			-- Use character's look direction
			return humanoidRootPart.CFrame.LookVector
		end
	end

	-- Option 2: For client-side, could request from client via RemoteFunction
	-- This would allow more precise mouse-based aiming

	-- Fallback
	return vector.create(0, 0, -1)
end
```

### Projectile Models Setup

**Create projectile templates in workspace, then move to `ReplicatedStorage.Models.Projectiles`:**

**Arrow Model:**
- MeshPart or Model with arrow mesh
- Size: approximately 0.5 x 0.5 x 2 studs
- Add two Attachments: "Attachment0" (back) and "Attachment1" (front) for trail
- Add a Hitbox part (small sphere at tip)
- CollisionGroup: "Projectiles" (doesn't collide with itself)
- CanCollide = false (we use raycasts instead)

**WebBall Model:**
- Sphere part with web texture
- Size: 1 x 1 x 1 studs
- Add particle emitter for trail effect
- Semi-transparent material

### Entity AI for Projectiles

**Update `EntityController.luau` `performAttack` function:**

```lua
-- In performAttack function, after getting weaponConfig
if weaponConfig.type == "melee" then
	-- Existing melee attack logic
	-- ...

elseif weaponConfig.type == "projectile" then
	-- Get direction to target
	local targetPos = target.Character.HumanoidRootPart.Position
	local entityPos = entity.humanoidRootPart.Position
	local direction = (targetPos - entityPos).Unit

	-- Calculate lead for moving targets (basic prediction)
	local targetVelocity = target.Character.HumanoidRootPart.AssemblyLinearVelocity
	local projectileSpeed = weaponConfig.projectileSpeed or 50
	local timeToImpact = (targetPos - entityPos).Magnitude / projectileSpeed
	local leadTarget = targetPos + (targetVelocity * timeToImpact)
	local leadDirection = (leadTarget - entityPos).Unit

	-- Play attack animation
	playAnimation(entity, "attack")
	playSound(entity, "attack")
	updateEntityState(entity, "attacking")

	-- Wait castDuration
	task.wait(weaponConfig.castDuration)

	-- Fire projectile
	local origin = entityPos + (leadDirection * 2) -- Slightly in front
	CombatSystem.performProjectileAttack(
		origin,
		leadDirection,
		weaponName,
		entity.model,
		nil -- No attacking player (NPC)
	)

	print(`*** {entity.entityType} fired {weaponName} at {target.Name}`)
end

entity.lastAttackTime = tick()
```

### Testing Checklist

**Basic Functionality:**
- [ ] Projectile spawns at correct origin
- [ ] Travels in correct direction
- [ ] Moves at configured speed
- [ ] Trail effect visible
- [ ] Hits entities correctly
- [ ] Applies correct damage
- [ ] Despawns after max range
- [ ] Despawns on impact
- [ ] Respects weapon cooldown

**Edge Cases:**
- [ ] Projectile doesn't hit attacker
- [ ] Works through gaps/doorways
- [ ] Doesn't tunnel through thin walls (raycast works)
- [ ] Handles high-speed projectiles (>100 studs/sec)
- [ ] Handles slow projectiles (<20 studs/sec)
- [ ] Multiple projectiles can be in flight simultaneously
- [ ] Projectiles from different entities don't interfere

**Performance:**
- [ ] No lag with 10+ active projectiles
- [ ] No memory leaks
- [ ] Projectiles clean up properly
- [ ] RunService connection efficient

**Visual/Audio:**
- [ ] Launch sound plays
- [ ] Impact sound plays
- [ ] Impact effect spawns at hit location
- [ ] Trail follows projectile correctly

---

## Hitscan Weapons

### Weapon Examples
- **Crossbow** (player weapon) - Instant bolt, long range
- **MagicMissile** (magic weapon) - Instant beam, medium range

### Architecture

#### HitscanEffects Module
**File:** `src/shared/HitscanEffects.luau`

**Purpose:** Visual effects for instant-hit weapons (beams, impact particles).

```lua
local HitscanEffects = {}

-- Show a beam effect from origin to hit point
function HitscanEffects.showBeam(
	origin: vector,
	hitPoint: vector,
	weaponName: string,
	duration: number?
)
	-- Create beam using Beam instance or Part
	local beamPart = Instance.new("Part")
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.Size = vector.create(0.1, 0.1, (hitPoint - origin).Magnitude)
	beamPart.CFrame = CFrame.new(origin, hitPoint) * CFrame.new(0, 0, -beamPart.Size.Z / 2)
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = Color3.fromRGB(100, 200, 255)
	beamPart.Transparency = 0.5
	beamPart.Parent = workspace

	-- Fade out and destroy
	local tweenInfo = TweenInfo.new(duration or 0.1)
	local tween = TweenService:Create(beamPart, tweenInfo, {Transparency = 1})
	tween:Play()

	Debris:AddItem(beamPart, duration or 0.1)
end

-- Show hit effect at impact location
function HitscanEffects.showHitEffect(
	position: vector,
	normal: vector,
	weaponName: string
)
	-- Create impact particle effect
	local hitEffect = Instance.new("Part")
	hitEffect.Anchored = true
	hitEffect.CanCollide = false
	hitEffect.Size = vector.create(1, 1, 1)
	hitEffect.Position = position
	hitEffect.Transparency = 1
	hitEffect.Parent = workspace

	-- Add particle emitter
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 100
	particles.Lifetime = NumberRange.new(0.2, 0.5)
	particles.Speed = NumberRange.new(5, 10)
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200))
	particles.Transparency = NumberSequence.new(0, 1)
	particles.Size = NumberSequence.new(0.3, 0)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Parent = hitEffect

	-- Emit burst and destroy
	particles:Emit(20)
	Debris:AddItem(hitEffect, 1)

	-- Play hit sound
	local hitSound = Instance.new("Sound")
	hitSound.SoundId = "rbxassetid://12345" -- Replace with actual sound ID
	hitSound.Volume = 0.5
	hitSound.Parent = hitEffect
	hitSound:Play()
end

return HitscanEffects
```

### CombatSystem Integration

**Update `CombatSystem.luau`:**

Replace the stub function:
```lua
-- Perform hitscan attack
function CombatSystem.performHitscan(
	origin: vector,
	direction: vector,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?
): AttackResult
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig or weaponConfig.type ~= "hitscan" then
		return {
			hit = false,
			target = nil,
			damage = nil,
			wasInRange = false,
			wasDodged = false,
			blockedByInvulnerability = false
		}
	end

	-- Set up raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {attacker}

	-- Optional: Add spread/accuracy variance
	local spreadAngle = weaponConfig.spread or 0 -- degrees
	local spreadDirection = direction
	if spreadAngle > 0 then
		local randomX = (math.random() - 0.5) * math.rad(spreadAngle)
		local randomY = (math.random() - 0.5) * math.rad(spreadAngle)
		spreadDirection = CFrame.fromEulerAnglesXYZ(randomX, randomY, 0) * direction
	end

	-- Perform raycast
	local raycastResult = workspace:Raycast(
		origin,
		spreadDirection * weaponConfig.range,
		raycastParams
	)

	if raycastResult then
		-- Check if hit an entity
		local hitEntity = findEntityFromPart(raycastResult.Instance)

		if hitEntity then
			-- Check PvP rules
			if not isPvPAllowed(attacker, hitEntity) then
				print(`PvP blocked: {attacker.Name} cannot attack {hitEntity.Name}`)
				HitscanEffects.showBeam(origin, raycastResult.Position, weaponName)
				return {
					hit = false,
					target = hitEntity,
					damage = nil,
					wasInRange = true,
					wasDodged = false,
					blockedByInvulnerability = false
				}
			end

			-- Check invulnerability
			if checkInvulnerability(hitEntity, weaponName) then
				print(`{hitEntity.Name} is invulnerable to {weaponName}`)
				HitscanEffects.showBeam(origin, raycastResult.Position, weaponName)
				return {
					hit = false,
					target = hitEntity,
					damage = nil,
					wasInRange = true,
					wasDodged = false,
					blockedByInvulnerability = true
				}
			end

			-- Apply damage
			local targetHumanoid = hitEntity:FindFirstChildOfClass("Humanoid")
			if targetHumanoid and targetHumanoid.Health > 0 then
				targetHumanoid:TakeDamage(weaponConfig.damage)

				-- Set invulnerability
				setInvulnerability(
					hitEntity,
					weaponName,
					GameConfig.combat.invulnerabilityDuration or 0.5
				)

				-- Determine damage type
				local damageType: CombatFeedback.DamageType
				local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(hitEntity)

				if targetPlayer then
					damageType = "incoming"
				else
					damageType = if attackingPlayer then "self" else "other_player"
				end

				-- Show damage feedback
				CombatFeedback.showDamage(
					hitEntity,
					weaponConfig.damage,
					weaponName,
					damageType,
					attackingPlayer
				)

				-- Show visual effects
				HitscanEffects.showBeam(origin, raycastResult.Position, weaponName)
				HitscanEffects.showHitEffect(raycastResult.Position, raycastResult.Normal, weaponName)

				print(`*** {attacker.Name} hit {hitEntity.Name} with {weaponName} for {weaponConfig.damage} damage`)

				return {
					hit = true,
					target = hitEntity,
					damage = weaponConfig.damage,
					wasInRange = true,
					wasDodged = false,
					blockedByInvulnerability = false
				}
			end
		else
			-- Hit terrain/wall
			HitscanEffects.showBeam(origin, raycastResult.Position, weaponName)
			HitscanEffects.showHitEffect(raycastResult.Position, raycastResult.Normal, weaponName)
		end
	else
		-- Complete miss - show beam to max range
		local endPoint = origin + (spreadDirection * weaponConfig.range)
		HitscanEffects.showBeam(origin, endPoint, weaponName, 0.05)
	end

	return {
		hit = false,
		target = nil,
		damage = nil,
		wasInRange = false,
		wasDodged = false,
		blockedByInvulnerability = false
	}
end
```

### ToolManager Integration

**Update `performCombatAttack` function:**

```lua
elseif weaponConfig.type == "hitscan" then
	-- Get hitscan origin (eye level or weapon position)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	-- Get aim direction
	local direction = getPlayerAimDirection(player)
	local origin = humanoidRootPart.Position + vector.create(0, 2, 0) -- Eye level

	-- Wait for castDuration (aim/charge time)
	task.wait(weaponConfig.castDuration)

	-- Perform hitscan
	local result = CombatSystem.performHitscan(
		origin,
		direction,
		weaponName,
		character,
		player
	)

	if result.hit then
		playToolSound(player, toolType, "attack")
		print(`{player.Name} hit with {weaponName}`)
	else
		playToolSound(player, toolType, "swing")
		print(`{player.Name} missed with {weaponName}`)
	end
end
```

### Entity AI for Hitscan

**Update `EntityController.luau` `performAttack` function:**

```lua
elseif weaponConfig.type == "hitscan" then
	-- Get direction to target
	local targetPos = target.Character.HumanoidRootPart.Position
	local entityPos = entity.humanoidRootPart.Position

	-- Aim at target's center mass (head height)
	local aimTarget = targetPos + vector.create(0, 2, 0)
	local direction = (aimTarget - entityPos).Unit

	-- Play attack animation
	playAnimation(entity, "attack")
	playSound(entity, "attack")
	updateEntityState(entity, "attacking")

	-- Wait castDuration
	task.wait(weaponConfig.castDuration)

	-- Perform hitscan
	local origin = entityPos + vector.create(0, 1, 0) -- Chest height
	local result = CombatSystem.performHitscan(
		origin,
		direction,
		weaponName,
		entity.model,
		nil
	)

	if result.hit then
		print(`*** {entity.entityType} hit {target.Name} with {weaponName}`)
	else
		print(`*** {entity.entityType} missed {target.Name} with {weaponName}`)
	end
end
```

### Testing Checklist

**Basic Functionality:**
- [ ] Raycast fires instantly
- [ ] Detects entities correctly
- [ ] Respects max range
- [ ] Applies correct damage
- [ ] Beam effect visible
- [ ] Hit effect plays at impact
- [ ] Respects weapon cooldown

**Edge Cases:**
- [ ] Ignores attacker correctly
- [ ] Works through transparent parts (if configured)
- [ ] Hits closest entity first
- [ ] Handles very long ranges (>200 studs)
- [ ] Spread/accuracy variance works
- [ ] Multiple hitscans don't interfere

**Performance:**
- [ ] No lag with rapid fire
- [ ] Effects clean up properly
- [ ] No memory leaks

**Visual/Audio:**
- [ ] Fire sound plays
- [ ] Hit sound plays
- [ ] Beam visible for appropriate duration
- [ ] Impact effect matches weapon type

---

## AOE Weapons

### Weapon Examples
- **Fireball** (projectile AOE) - Travels then explodes
- **GroundSlam** (instant self-centered AOE) - Damages around caster
- **HealingCircle** (persistent AOE) - Heals allies over time
- **DragonBreath** (boss attack) - Large cone damage

### Architecture

#### AOETelegraph Module
**File:** `src/shared/AOETelegraph.luau`

**Purpose:** Show visual indicators for AOE attacks during castDuration.

```lua
local AOETelegraph = {}

-- Show ground telegraph for AOE attack
function AOETelegraph.showTelegraph(
	position: vector,
	radius: number,
	duration: number,
	color: Color3?,
	attackType: string? -- "damage" or "heal"
): Instance
	-- Create decal on ground showing AOE radius
	local telegraphPart = Instance.new("Part")
	telegraphPart.Name = "AOETelegraph"
	telegraphPart.Anchored = true
	telegraphPart.CanCollide = false
	telegraphPart.Size = vector.create(radius * 2, 0.1, radius * 2)
	telegraphPart.Position = position + vector.create(0, 0.05, 0) -- Slightly above ground
	telegraphPart.Transparency = 1
	telegraphPart.Parent = workspace

	-- Add cylinder mesh for circle shape
	local mesh = Instance.new("CylinderMesh")
	mesh.Parent = telegraphPart

	-- Add surface decal
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalFace.Top
	decal.Texture = "rbxassetid://12345" -- Circle texture with gradient
	decal.Color3 = color or (attackType == "heal" and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100))
	decal.Transparency = 0.3
	decal.Parent = telegraphPart

	-- Pulse animation
	local tweenInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- Infinite repeat
		true -- Reverse
	)
	local tween = TweenService:Create(decal, tweenInfo, {Transparency = 0.7})
	tween:Play()

	-- Add particle effects around perimeter
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 20
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Speed = NumberRange.new(2, 5)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Color = ColorSequence.new(decal.Color3)
	particles.Transparency = NumberSequence.new(0.5, 1)
	particles.Size = NumberSequence.new(0.5, 0)
	particles.Parent = telegraphPart

	-- Clean up after duration
	Debris:AddItem(telegraphPart, duration)

	return telegraphPart
end

-- Show directional cone telegraph (for breath attacks, etc.)
function AOETelegraph.showConeTelegraph(
	origin: vector,
	direction: vector,
	range: number,
	angle: number, -- degrees
	duration: number,
	color: Color3?
): Instance
	-- Create cone-shaped telegraph
	-- Similar to circular but with wedge shape
	-- Implementation details...
end

return AOETelegraph
```

#### AOEZoneManager Module
**File:** `src/shared/AOEZoneManager.luau`

**Purpose:** Manage persistent AOE zones that tick damage/healing over time.

```lua
export type AOEZone = {
	position: vector,
	radius: number,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	startTime: number,
	duration: number,
	tickRate: number,
	lastTickTime: number,
	visualEffect: Instance?,
}

local AOEZoneManager = {}
local activeZones: {AOEZone} = {}

-- Create a new AOE zone
function AOEZoneManager.createZone(
	position: vector,
	radius: number,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	duration: number,
	tickRate: number
): AOEZone
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		error(`Invalid weapon: {weaponName}`)
	end

	-- Create visual effect
	local visualPart = Instance.new("Part")
	visualPart.Name = "AOEZone_" .. weaponName
	visualPart.Anchored = true
	visualPart.CanCollide = false
	visualPart.Size = vector.create(radius * 2, 0.5, radius * 2)
	visualPart.Position = position
	visualPart.Transparency = 0.7
	visualPart.Material = Enum.Material.Neon
	visualPart.Color = weaponConfig.damage < 0 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
	visualPart.Parent = workspace

	-- Add cylinder mesh
	local mesh = Instance.new("CylinderMesh")
	mesh.Parent = visualPart

	-- Add particles
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 50
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Speed = NumberRange.new(0, 2)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Color = ColorSequence.new(visualPart.Color)
	particles.Transparency = NumberSequence.new(0.5, 1)
	particles.Size = NumberSequence.new(0.3, 0)
	particles.Parent = visualPart

	local zone: AOEZone = {
		position = position,
		radius = radius,
		weaponName = weaponName,
		attacker = attacker,
		attackingPlayer = attackingPlayer,
		startTime = tick(),
		duration = duration,
		tickRate = tickRate,
		lastTickTime = tick(),
		visualEffect = visualPart,
	}

	table.insert(activeZones, zone)
	print(`Created AOE zone: {weaponName} at {position}`)

	return zone
end

-- Tick a zone (apply damage/healing to entities in range)
function AOEZoneManager.tickZone(zone: AOEZone)
	local weaponConfig = CombatSystem.getWeaponConfig(zone.weaponName)
	if not weaponConfig then
		return
	end

	-- Find all entities in radius
	local entitiesInZone = findEntitiesInRange(zone.position, zone.radius, zone.attacker)

	for _, entity in entitiesInZone do
		-- Check if entity should be affected (targetFilter)
		local shouldAffect = true
		if weaponConfig.targetFilter == "allies" then
			-- Only affect allies (same team or self)
			local entityPlayer = game:GetService("Players"):GetPlayerFromCharacter(entity)
			if entityPlayer ~= zone.attackingPlayer then
				shouldAffect = false
			end
		elseif weaponConfig.targetFilter == "enemies" then
			-- Only affect enemies
			local entityPlayer = game:GetService("Players"):GetPlayerFromCharacter(entity)
			if entityPlayer == zone.attackingPlayer then
				shouldAffect = false
			end
		end

		if shouldAffect then
			-- Apply damage/healing
			local humanoid = entity:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				if weaponConfig.damage < 0 then
					-- Healing
					humanoid.Health = math.min(humanoid.Health - weaponConfig.damage, humanoid.MaxHealth)
					CombatFeedback.showDamage(entity, -weaponConfig.damage, zone.weaponName, "self", zone.attackingPlayer)
				else
					-- Damage
					humanoid:TakeDamage(weaponConfig.damage)

					local damageType: CombatFeedback.DamageType
					local entityPlayer = game:GetService("Players"):GetPlayerFromCharacter(entity)
					damageType = if entityPlayer then "incoming" else "self"

					CombatFeedback.showDamage(entity, weaponConfig.damage, zone.weaponName, damageType, zone.attackingPlayer)
				end
			end
		end
	end

	zone.lastTickTime = tick()
end

-- Update all active zones
function AOEZoneManager.updateZones()
	local currentTime = tick()

	for i = #activeZones, 1, -1 do
		local zone = activeZones[i]

		-- Check if zone has expired
		if currentTime - zone.startTime >= zone.duration then
			destroyZone(zone)
			table.remove(activeZones, i)
		else
			-- Check if it's time to tick
			if currentTime - zone.lastTickTime >= zone.tickRate then
				tickZone(zone)
			end
		end
	end
end

-- Destroy a zone and clean up
function AOEZoneManager.destroyZone(zone: AOEZone)
	if zone.visualEffect then
		zone.visualEffect:Destroy()
	end
	print(`Destroyed AOE zone: {zone.weaponName}`)
end

-- Initialize the zone manager
function AOEZoneManager.initialize()
	-- Connect to RunService for updates
	RunService.Heartbeat:Connect(function()
		updateZones()
	end)
end

return AOEZoneManager
```

### CombatSystem Integration

**Update `CombatSystem.luau`:**

Replace the stub function:
```lua
-- Perform AOE attack
function CombatSystem.performAOEAttack(
	attacker: Model,
	targetPosition: vector,
	weaponName: string,
	attackingPlayer: Player?
): {AOEHitInfo}
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig or weaponConfig.type ~= "aoe" then
		return {}
	end

	local hits: {AOEHitInfo} = {}

	-- If projectile AOE, it should have been spawned already and this is called on impact
	-- If instant AOE, apply immediately

	-- Get all parts in radius
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {attacker}

	local parts = workspace:GetPartBoundsInRadius(
		targetPosition,
		weaponConfig.aoeRadius or 10,
		params
	)

	-- Find unique entities
	local hitEntities: {[Model]: boolean} = {}
	local hitCount = 0

	for _, part in parts do
		local entity = findEntityFromPart(part)
		if entity and not hitEntities[entity] then
			hitEntities[entity] = true

			local entityRoot = entity:FindFirstChild("HumanoidRootPart") :: BasePart?
			if entityRoot then
				local distance = getDistance(targetPosition, entityRoot.Position)

				-- Check PvP rules
				if not isPvPAllowed(attacker, entity) then
					continue
				end

				-- Check invulnerability
				if checkInvulnerability(entity, weaponName) then
					continue
				end

				-- Calculate damage with falloff
				local damageMultiplier = 1.0
				if weaponConfig.aoeFalloff then
					damageMultiplier = 1 - (distance / (weaponConfig.aoeRadius or 10))
					damageMultiplier = math.max(0, damageMultiplier)
				end

				local finalDamage = weaponConfig.damage * damageMultiplier

				-- Apply damage or healing
				local humanoid = entity:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					if finalDamage < 0 then
						-- Healing
						humanoid.Health = math.min(humanoid.Health - finalDamage, humanoid.MaxHealth)
					else
						-- Damage
						humanoid:TakeDamage(finalDamage)

						-- Set invulnerability
						setInvulnerability(
							entity,
							weaponName,
							GameConfig.combat.invulnerabilityDuration or 0.5
						)
					end

					-- Show feedback
					local damageType: CombatFeedback.DamageType
					local entityPlayer = game:GetService("Players"):GetPlayerFromCharacter(entity)
					damageType = if entityPlayer then "incoming" else "self"

					CombatFeedback.showDamage(
						entity,
						math.abs(finalDamage),
						weaponName,
						damageType,
						attackingPlayer
					)

					table.insert(hits, {
						entity = entity,
						damage = finalDamage,
						distance = distance,
					})

					hitCount = hitCount + 1

					-- Check max targets
					if hitCount >= (weaponConfig.maxTargets or 999) then
						break
					end
				end
			end
		end
	end

	-- If persistent AOE (has duration), create zone
	if weaponConfig.duration and weaponConfig.tickRate then
		AOEZoneManager.createZone(
			targetPosition,
			weaponConfig.aoeRadius or 10,
			weaponName,
			attacker,
			attackingPlayer,
			weaponConfig.duration,
			weaponConfig.tickRate
		)
	end

	return hits
end
```

### ToolManager Integration

**Update `performCombatAttack` function:**

```lua
elseif weaponConfig.type == "aoe" then
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	-- Determine target position
	local targetPos: vector
	if weaponConfig.range == 0 then
		-- Self-centered AOE
		targetPos = humanoidRootPart.Position
	else
		-- Targeted AOE - get mouse position or use current target
		local target = TargetingSystem.getTarget(player)
		if target then
			local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
			targetPos = targetRoot and targetRoot.Position or humanoidRootPart.Position
		else
			-- Default to position in front of player
			targetPos = humanoidRootPart.Position + (humanoidRootPart.CFrame.LookVector * weaponConfig.range)
		end
	end

	-- Show telegraph during castDuration
	local telegraph = AOETelegraph.showTelegraph(
		targetPos,
		weaponConfig.aoeRadius or 10,
		weaponConfig.castDuration,
		nil,
		weaponConfig.damage < 0 and "heal" or "damage"
	)

	-- Wait for castDuration
	task.wait(weaponConfig.castDuration)

	-- If projectile AOE, spawn projectile that will explode on impact
	if weaponConfig.projectileSpeed then
		local direction = (targetPos - humanoidRootPart.Position).Unit
		local origin = humanoidRootPart.Position + vector.create(0, 2, 0)

		-- Spawn projectile (will trigger AOE on impact)
		local projectile = ProjectileManager.spawnProjectile(
			origin,
			direction,
			weaponName,
			character,
			player
		)

		playToolSound(player, toolType, "attack")
	else
		-- Instant AOE
		local hits = CombatSystem.performAOEAttack(
			character,
			targetPos,
			weaponName,
			player
		)

		if #hits > 0 then
			playToolSound(player, toolType, "attack")
			print(`{player.Name} hit {#hits} entities with {weaponName}`)
		else
			playToolSound(player, toolType, "swing")
			print(`{player.Name}'s {weaponName} hit nothing`)
		end
	end
end
```

**For Projectile AOE (like Fireball):**

Update `ProjectileManager.updateProjectile` to trigger AOE on impact:
```lua
-- When projectile hits something
if raycastResult then
	local hitEntity = findEntityFromPart(raycastResult.Instance)

	-- Check if this is an AOE projectile
	local weaponConfig = CombatSystem.getWeaponConfig(projectile.weapon)
	if weaponConfig and weaponConfig.type == "aoe" then
		-- Trigger AOE at impact position
		local hits = CombatSystem.performAOEAttack(
			projectile.attacker,
			raycastResult.Position,
			projectile.weapon,
			projectile.attackingPlayer
		)

		print(`Projectile AOE hit {#hits} entities`)
	elseif hitEntity then
		-- Normal projectile damage
		-- ... existing logic
	end

	-- Destroy projectile
	destroyProjectile(projectile)
end
```

### Entity AI for AOE

**Update `EntityController.luau` `performAttack` function:**

```lua
elseif weaponConfig.type == "aoe" then
	-- Determine target position
	local targetPos: vector
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

	-- Show telegraph
	AOETelegraph.showTelegraph(
		targetPos,
		weaponConfig.aoeRadius or 10,
		weaponConfig.castDuration,
		Color3.fromRGB(255, 50, 50),
		"damage"
	)

	-- Wait castDuration
	task.wait(weaponConfig.castDuration)

	-- Apply AOE
	local hits = CombatSystem.performAOEAttack(
		entity.model,
		targetPos,
		weaponName,
		nil
	)

	print(`*** {entity.entityType} hit {#hits} entities with {weaponName} AOE`)
end
```

### Testing Checklist

**Basic Functionality:**
- [ ] Telegraph shows during castDuration
- [ ] Telegraph shows correct radius
- [ ] AOE activates at target position
- [ ] All entities in radius are hit
- [ ] Damage falloff calculated correctly
- [ ] MaxTargets limit respected
- [ ] Healing (negative damage) works
- [ ] Respects weapon cooldown

**Projectile AOE:**
- [ ] Projectile spawns correctly
- [ ] Travels to target
- [ ] Explodes on impact
- [ ] AOE triggers at impact position
- [ ] Visual explosion effect

**Persistent Zones:**
- [ ] Zone creates visual effect
- [ ] Ticks at correct interval
- [ ] Affects entities entering zone
- [ ] Expires after duration
- [ ] Cleans up properly

**Edge Cases:**
- [ ] Multiple AOEs can overlap
- [ ] Self-centered AOE centers on caster
- [ ] Targeted AOE respects max range
- [ ] AOE doesn't hit caster (if configured)
- [ ] Works on moving targets
- [ ] PvP rules respected

**Performance:**
- [ ] No lag with large AOE radius
- [ ] No lag with multiple overlapping AOEs
- [ ] Zones clean up without memory leaks
- [ ] GetPartBoundsInRadius efficient

---

## Entity AI Updates

### Summary of Changes

Update `EntityController.luau` `performAttack` function to handle all weapon types:

```lua
local function performAttack(entity: EntityInstance, target: Player)
	if not target.Character or not target.Character:FindFirstChild("Humanoid") then
		return
	end

	local targetHumanoid = target.Character.Humanoid :: Humanoid
	local config = getEntityConfig(entity.entityType)

	if targetHumanoid.Health <= 0 then
		return
	end

	local weaponName = config.primaryWeapon
	if not weaponName then
		warn(`Entity {entity.entityType} has no primaryWeapon configured`)
		return
	end

	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		return
	end

	-- Set attack time IMMEDIATELY
	entity.lastAttackTime = tick()

	-- Play attack animation and sound
	playAnimation(entity, "attack")
	playSound(entity, "attack")
	updateEntityState(entity, "attacking")

	-- Get target position
	local targetPos = target.Character.HumanoidRootPart.Position
	local entityPos = entity.humanoidRootPart.Position

	-- Handle different weapon types
	if weaponConfig.type == "melee" then
		-- Existing melee logic
		task.wait(weaponConfig.castDuration)

		local result = CombatSystem.attemptMeleeAttack(
			entity.model,
			target.Character,
			weaponName,
			nil
		)

		if result.hit and result.damage then
			print(`*** {entity.entityType} hit {target.Name} for {result.damage} damage`)
		elseif result.wasDodged then
			print(`*** {target.Name} dodged {entity.entityType} attack!`)
		end

	elseif weaponConfig.type == "projectile" then
		-- Projectile attack with target leading
		local targetVelocity = target.Character.HumanoidRootPart.AssemblyLinearVelocity
		local projectileSpeed = weaponConfig.projectileSpeed or 50
		local timeToImpact = (targetPos - entityPos).Magnitude / projectileSpeed
		local leadTarget = targetPos + (targetVelocity * timeToImpact)
		local direction = (leadTarget - entityPos).Unit

		task.wait(weaponConfig.castDuration)

		local origin = entityPos + (direction * 2)
		CombatSystem.performProjectileAttack(
			origin,
			direction,
			weaponName,
			entity.model,
			nil
		)

		print(`*** {entity.entityType} fired {weaponName} at {target.Name}`)

	elseif weaponConfig.type == "hitscan" then
		-- Hitscan attack
		local aimTarget = targetPos + vector.create(0, 2, 0) -- Head height
		local direction = (aimTarget - entityPos).Unit

		task.wait(weaponConfig.castDuration)

		local origin = entityPos + vector.create(0, 1, 0)
		local result = CombatSystem.performHitscan(
			origin,
			direction,
			weaponName,
			entity.model,
			nil
		)

		if result.hit then
			print(`*** {entity.entityType} hit {target.Name} with {weaponName}`)
		else
			print(`*** {entity.entityType} missed with {weaponName}`)
		end

	elseif weaponConfig.type == "aoe" then
		-- AOE attack
		local aoeTargetPos = weaponConfig.range == 0 and entityPos or targetPos

		AOETelegraph.showTelegraph(
			aoeTargetPos,
			weaponConfig.aoeRadius or 10,
			weaponConfig.castDuration,
			Color3.fromRGB(255, 50, 50),
			"damage"
		)

		task.wait(weaponConfig.castDuration)

		local hits = CombatSystem.performAOEAttack(
			entity.model,
			aoeTargetPos,
			weaponName,
			nil
		)

		print(`*** {entity.entityType} hit {#hits} entities with {weaponName} AOE`)
	end
end
```

---

## GameConfig Updates

### Add Phase 2 Weapons

```lua
weapons = {
	-- Phase 1 weapons (existing)
	Axe = { ... },
	Pickaxe = { ... },
	WolfClaw = { ... },
	BearClaw = { ... },
	ZombieBite = { ... },

	-- Phase 2A: Projectile Weapons
	Bow = {
		type = "projectile",
		name = "Bow",
		damage = 30,
		range = 100,
		cooldown = 1.5,
		castDuration = 0.5, -- Draw time
		projectileSpeed = 80,
	},

	SpiderWeb = {
		type = "projectile",
		name = "Spider Web",
		damage = 5,
		range = 40,
		cooldown = 3,
		castDuration = 0.6,
		projectileSpeed = 30, -- Slow projectile
	},

	-- Phase 2B: Hitscan Weapons
	Crossbow = {
		type = "hitscan",
		name = "Crossbow",
		damage = 40,
		range = 120,
		cooldown = 2.0,
		castDuration = 0.3,
		spread = 2, -- degrees of accuracy variance
	},

	MagicMissile = {
		type = "hitscan",
		name = "Magic Missile",
		damage = 25,
		range = 80,
		cooldown = 1.0,
		castDuration = 0.4,
		spread = 0, -- Perfect accuracy
	},

	-- Phase 2C: AOE Weapons
	Fireball = {
		type = "aoe",
		name = "Fireball",
		damage = 50,
		range = 60,
		cooldown = 5.0,
		castDuration = 1.0,
		aoeRadius = 15,
		aoeFalloff = true,
		maxTargets = 10,
		projectileSpeed = 40, -- Travels as projectile then explodes
	},

	GroundSlam = {
		type = "aoe",
		name = "Ground Slam",
		damage = 35,
		range = 0, -- Self-centered
		cooldown = 8.0,
		castDuration = 0.7,
		aoeRadius = 20,
		aoeFalloff = true,
		maxTargets = 15,
	},

	HealingCircle = {
		type = "aoe",
		name = "Healing Circle",
		damage = -20, -- Negative = healing
		range = 40,
		cooldown = 15.0,
		castDuration = 2.0,
		aoeRadius = 12,
		aoeFalloff = false, -- Everyone gets full heal
		maxTargets = 5,
		duration = 5.0, -- Lasts 5 seconds
		tickRate = 1.0, -- Heal every second
		targetFilter = "allies",
	},

	DragonBreath = {
		type = "aoe",
		name = "Dragon Breath",
		damage = 60,
		range = 0, -- Self-centered
		cooldown = 10.0,
		castDuration = 1.5, -- Long telegraph
		aoeRadius = 30, -- Huge radius
		aoeFalloff = true,
		maxTargets = 20,
	},
},
```

### Add Tools for Phase 2 Weapons

```lua
tools = {
	-- Existing tools
	Axe = { ... },
	Pickaxe = { ... },

	-- Phase 2 tools
	Bow = {
		miningEfficiency = 0,
		canMine = {},
		swingCooldown = 1.5,
		weaponRef = "Bow",
	},

	Crossbow = {
		miningEfficiency = 0,
		canMine = {},
		swingCooldown = 2.0,
		weaponRef = "Crossbow",
	},
},
```

### Add Entities with Phase 2 Weapons

```lua
enemies = {
	Zombie = { ... },

	-- Spider enemy with projectile attack
	Spider = {
		health = 40,
		walkSpeed = 10,
		runSpeed = 15,
		aggroRange = 35,
		wanderRange = 8,
		jumpCooldown = 3,
		spawnWeight = 1,
		canJump = true,
		targetPriority = "players",
		primaryWeapon = "SpiderWeb",
		animations = {
			walk = "rbxassetid://...",
			run = "rbxassetid://...",
			attack = "rbxassetid://...",
		},
	},

	-- Mage enemy with hitscan
	DarkMage = {
		health = 60,
		walkSpeed = 8,
		runSpeed = 12,
		aggroRange = 40,
		wanderRange = 10,
		jumpCooldown = 5,
		spawnWeight = 0.5,
		canJump = false,
		targetPriority = "players",
		primaryWeapon = "MagicMissile",
		animations = {
			walk = "rbxassetid://...",
			attack = "rbxassetid://...",
		},
	},

	-- Boss with AOE
	Dragon = {
		health = 500,
		walkSpeed = 6,
		runSpeed = 10,
		aggroRange = 50,
		wanderRange = 20,
		jumpCooldown = 10,
		spawnWeight = 0.1,
		canJump = false,
		targetPriority = "both",
		primaryWeapon = "DragonBreath",
		animations = {
			walk = "rbxassetid://...",
			attack = "rbxassetid://...",
		},
	},
},
```

---

## Testing Checklist

### Projectile Weapons
- [ ] Arrow spawns and flies correctly
- [ ] Hits moving targets
- [ ] Despawns after max range
- [ ] Multiple projectiles don't interfere
- [ ] Trail effect visible
- [ ] Impact effects work
- [ ] Entity AI leads moving targets
- [ ] Works in multiplayer

### Hitscan Weapons
- [ ] Instant hit registration
- [ ] Beam effect visible
- [ ] Hit effects at impact point
- [ ] Respects max range
- [ ] Spread/accuracy works
- [ ] Entity AI aims correctly
- [ ] Works through transparent parts (if configured)

### AOE Weapons
- [ ] Telegraph shows clearly
- [ ] Correct radius
- [ ] All entities in range hit
- [ ] Damage falloff accurate
- [ ] MaxTargets respected
- [ ] Healing works
- [ ] Projectile AOE explodes correctly
- [ ] Persistent zones tick properly
- [ ] Zones clean up after duration
- [ ] Multiple zones can overlap
- [ ] Performance acceptable

### Integration
- [ ] All weapon types work for players
- [ ] All weapon types work for entities
- [ ] CombatFeedback works for all types
- [ ] Invulnerability frames work
- [ ] PvP modes work
- [ ] damageTargetOnly modes work
- [ ] No memory leaks
- [ ] No security exploits

### Balance
- [ ] Ranged weapons balanced vs melee
- [ ] AOE cooldowns appropriate
- [ ] Healing not overpowered
- [ ] Telegraph timing fair
- [ ] Damage values reasonable
- [ ] Entity AI not too accurate/inaccurate

---

## Performance Considerations

### Optimization Strategies

**Projectile Pooling:**
```lua
-- Reuse projectile instances instead of creating/destroying
local projectilePool: {Model} = {}

function ProjectileManager.getPooledProjectile(weaponName: string): Model
	for i, projectile in projectilePool do
		if not projectile.Parent then
			table.remove(projectilePool, i)
			return projectile
		end
	end

	-- Create new if pool empty
	local template = ReplicatedStorage.Models.Projectiles:FindFirstChild(weaponName)
	return template:Clone()
end

function ProjectileManager.returnToPool(projectile: Model)
	projectile.Parent = nil
	table.insert(projectilePool, projectile)
end
```

**Spatial Partitioning for AOE:**
```lua
-- Instead of checking ALL entities in workspace, use Region3 or spatial hash
-- This is especially important for large AOE radii

local function findEntitiesInRegion(position: vector, radius: number): {Model}
	-- Use Region3 or spatial hash grid
	-- More efficient than iterating all workspace descendants
end
```

**Limit Active Effects:**
```lua
-- Cap maximum concurrent projectiles/zones
local MAX_PROJECTILES = 50
local MAX_ZONES = 10

function ProjectileManager.spawnProjectile(...)
	if #activeProjectiles >= MAX_PROJECTILES then
		-- Remove oldest projectile
		local oldest = activeProjectiles[1]
		destroyProjectile(oldest)
	end
	-- ... spawn new projectile
end
```

**Throttle Raycast Checks:**
```lua
-- For slow-moving projectiles, don't raycast every frame
-- Update based on speed/deltaTime threshold

function ProjectileManager.updateProjectile(projectile, deltaTime)
	local distanceThisFrame = projectile.speed * deltaTime

	if distanceThisFrame < 0.5 then
		-- Skip raycast for very small movements
		-- Just update position
		return
	end

	-- Perform raycast
	-- ...
end
```

**Client-Side Prediction:**
```lua
-- Spawn projectile effects on client immediately for responsiveness
-- Server validates and corrects if needed
-- This reduces perceived lag

-- Client:
RemoteEvents.Events.FireProjectile:FireServer(origin, direction, weaponName)
-- Immediately spawn visual-only projectile on client

-- Server:
-- Validate, spawn authoritative projectile
-- Clients receive and reconcile
```

### Performance Targets

- **60 FPS** with 10+ active projectiles
- **60 FPS** with 5+ overlapping AOE zones
- **60 FPS** with 20+ entities using various weapon types
- **< 100ms** raycast time per frame total
- **< 50 instances** created per second
- **< 1MB** memory allocated per minute

---

## Security Considerations

### Server Validation

**All weapon usage must be validated server-side:**
```lua
-- In ToolManager, before performing attack
local function validateAttack(player: Player, weaponName: string): boolean
	-- Check cooldown
	if isOnCooldown(player, "attack") then
		return false
	end

	-- Check player has the weapon
	local character = player.Character
	if not character then
		return false
	end

	local tool = character:FindFirstChild(weaponName)
	if not tool then
		return false
	end

	-- Check weapon exists in config
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		return false
	end

	-- Set cooldown
	setCooldown(player, "attack", weaponConfig.cooldown)

	return true
end
```

**Projectile Spawn Validation:**
```lua
-- Prevent projectile spam exploits
local playerProjectileCount: {[Player]: number} = {}
local MAX_PROJECTILES_PER_PLAYER = 5

function ProjectileManager.spawnProjectile(...)
	if attackingPlayer then
		local count = playerProjectileCount[attackingPlayer] or 0
		if count >= MAX_PROJECTILES_PER_PLAYER then
			warn(`Player {attackingPlayer.Name} tried to spawn too many projectiles`)
			return nil
		end
		playerProjectileCount[attackingPlayer] = count + 1
	end

	-- ... spawn projectile
end

-- Decrement count when projectile destroyed
function ProjectileManager.destroyProjectile(projectile)
	if projectile.attackingPlayer then
		playerProjectileCount[projectile.attackingPlayer] =
			(playerProjectileCount[projectile.attackingPlayer] or 1) - 1
	end
	-- ... cleanup
end
```

**AOE Position Validation:**
```lua
-- Prevent invalid AOE positions (teleport exploits, etc.)
function CombatSystem.performAOEAttack(attacker, targetPosition, weaponName, attackingPlayer)
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)

	-- Check distance from attacker to target position
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart")
	if attackerRoot then
		local distance = (targetPosition - attackerRoot.Position).Magnitude
		if distance > weaponConfig.range * 1.5 then
			-- Position too far, reject
			warn(`Invalid AOE position for {weaponName}: too far from attacker`)
			return {}
		end
	end

	-- ... perform AOE
end
```

**Rate Limiting:**
```lua
-- Prevent rapid-fire exploits
local attackRateLimit: {[Player]: {timestamps: {number}}} = {}
local MAX_ATTACKS_PER_SECOND = 5

function validateAttackRate(player: Player): boolean
	local currentTime = tick()

	if not attackRateLimit[player] then
		attackRateLimit[player] = {timestamps = {}}
	end

	local timestamps = attackRateLimit[player].timestamps

	-- Remove old timestamps (>1 second ago)
	for i = #timestamps, 1, -1 do
		if currentTime - timestamps[i] > 1 then
			table.remove(timestamps, i)
		end
	end

	-- Check rate
	if #timestamps >= MAX_ATTACKS_PER_SECOND then
		warn(`Player {player.Name} is attacking too fast`)
		return false
	end

	-- Add current attack
	table.insert(timestamps, currentTime)
	return true
end
```

---

## Implementation Checklist

**Phase 2A - Projectiles:**
- [ ] Create ProjectileManager.luau
- [ ] Create projectile model templates (Arrow, WebBall)
- [ ] Update CombatSystem.performProjectileAttack
- [ ] Update ToolManager for projectile weapons
- [ ] Update EntityController for projectile attacks
- [ ] Add Bow to tools and player inventory
- [ ] Add Spider enemy with SpiderWeb weapon
- [ ] Test projectile functionality
- [ ] Balance projectile weapons

**Phase 2B - Hitscan:**
- [ ] Create HitscanEffects.luau
- [ ] Update CombatSystem.performHitscan
- [ ] Update ToolManager for hitscan weapons
- [ ] Update EntityController for hitscan attacks
- [ ] Add Crossbow to tools
- [ ] Add DarkMage enemy with MagicMissile
- [ ] Test hitscan functionality
- [ ] Balance hitscan weapons

**Phase 2C - AOE:**
- [ ] Create AOETelegraph.luau
- [ ] Create AOEZoneManager.luau
- [ ] Update CombatSystem.performAOEAttack
- [ ] Update ToolManager for AOE weapons
- [ ] Update EntityController for AOE attacks
- [ ] Add instant AOE weapon (GroundSlam)
- [ ] Add projectile AOE weapon (Fireball)
- [ ] Add persistent AOE (HealingCircle)
- [ ] Add Dragon boss with DragonBreath
- [ ] Test AOE functionality
- [ ] Balance AOE weapons

**Polish & Testing:**
- [ ] Performance optimization
- [ ] Security validation
- [ ] Visual effects polish
- [ ] Sound effects
- [ ] Balance testing with 5+ players
- [ ] Bug fixes
- [ ] Documentation updates

---

## Success Criteria

Phase 2 is complete when:
- ✅ All 4 weapon types functional (melee, projectile, hitscan, AOE)
- ✅ Players can use all weapon types effectively
- ✅ Entities/NPCs can use all weapon types
- ✅ Visual telegraphs clear and fair
- ✅ Performance targets met (60 FPS)
- ✅ No security exploits or vulnerabilities
- ✅ Balanced gameplay tested with multiple players
- ✅ All testing checklists passed
- ✅ Code documented and maintainable
