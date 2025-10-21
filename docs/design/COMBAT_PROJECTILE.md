# Combat System - Projectile Line-of-Sight Implementation

## Overview

This document covers the implementation of projectile line-of-sight (LOS) validation, damage modes, and AI obstacle avoidance for the projectile weapon system.

**Key Features:**
- Server-authoritative LOS validation (client cannot manipulate)
- Reusable API for both players and AI entities
- Integration with existing facing requirements
- Support for target-only and multi-entity damage modes
- AI obstacle avoidance when blocked

---

## Architecture

### Security Model

**Critical: All validation happens SERVER-SIDE ONLY**

- Client sends attack request via RemoteEvent
- Server validates facing, LOS, cooldowns, weapon ownership
- Server spawns projectile and manages all damage calculations
- Client receives visual feedback only (cannot affect damage)

**Client Responsibilities (Visual Only):**
- Show HUD indicators (BLOCKED, NOT FACING, etc.)
- Request attacks via RemoteEvent
- Display visual effects

**Server Responsibilities (Authoritative):**
- Validate all attack preconditions
- Perform LOS raycasts
- Spawn and track projectiles
- Calculate and apply damage
- Enforce damage modes

---

## 1. Core API Module: ProjectileLOS

**File:** `src/shared/ProjectileLOS.luau`

### Type Definitions

```lua
--!strict

export type LOSResult = {
	hasLineOfSight: boolean,
	blockedBy: Instance?,
	blockedPosition: vector?,
}

local ProjectileLOS = {}
```

### Core Functions

```lua
-- Validate clear path from origin to target position
-- Filters out entities, checks only for physical obstacles
function ProjectileLOS.validatePath(
	origin: vector,
	targetPosition: vector,
	attacker: Model
): LOSResult
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Exclude attacker and all characters/entities
	local ignoreList = {attacker}

	-- Add all players' characters
	local Players = game:GetService("Players")
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignoreList, player.Character)
		end
	end

	-- Add all NPCs/entities (find models with Humanoid)
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Humanoid") and descendant.Parent ~= attacker then
			table.insert(ignoreList, descendant.Parent)
		end
	end

	raycastParams.FilterDescendantsInstances = ignoreList

	-- Raycast from origin to target
	local direction = targetPosition - origin
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)

	if raycastResult then
		-- Hit something (structure, resource, terrain)
		return {
			hasLineOfSight = false,
			blockedBy = raycastResult.Instance,
			blockedPosition = raycastResult.Position,
		}
	end

	-- Clear path
	return {
		hasLineOfSight = true,
		blockedBy = nil,
		blockedPosition = nil,
	}
end

-- Check if entity has clear shot to target entity
function ProjectileLOS.canTargetEntity(
	sourceEntity: Model,
	targetEntity: Model
): LOSResult
	local sourceRoot = sourceEntity:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = targetEntity:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not sourceRoot or not targetRoot then
		return {
			hasLineOfSight = false,
			blockedBy = nil,
			blockedPosition = nil,
		}
	end

	-- Shoot from slightly elevated position (chest height)
	local origin = sourceRoot.Position + vector.create(0, 1, 0)
	local targetPos = targetRoot.Position + vector.create(0, 1, 0)

	return ProjectileLOS.validatePath(origin, targetPos, sourceEntity)
end

return ProjectileLOS
```

**Key Security Features:**
- Runs on server only (shared module called by server scripts)
- No client input affects raycast results
- Filters all entities dynamically (cannot be spoofed)

---

## 2. Damage Mode System

**File:** `src/shared/CombatSystem.luau` (update existing)

### Damage Mode Helper

```lua
-- Type for damage mode configuration
export type DamageMode = {
	damageTargetOnly: boolean,
	penetratesEntities: boolean,
}

-- Get effective damage mode from weapon and combat config
local function getEffectiveDamageMode(weaponConfig: any): DamageMode
	local weaponDamageTargetOnly = weaponConfig.damageTargetOnly
	local combatDamageTargetOnly = GameConfig.combat.damageTargetOnly

	-- Rule: If EITHER weapon or combat is false, can hit entities along path
	-- Weapon false overrides combat true
	local effectiveDamageTargetOnly = true

	if weaponDamageTargetOnly == false then
		-- Weapon explicitly allows multi-target
		effectiveDamageTargetOnly = false
	elseif weaponDamageTargetOnly == nil and combatDamageTargetOnly == false then
		-- Weapon not set, combat allows multi-target
		effectiveDamageTargetOnly = false
	end

	-- Penetration only matters if damageTargetOnly is false
	local penetrates = if not effectiveDamageTargetOnly
		then (weaponConfig.penetratesEntities or false)
		else false

	return {
		damageTargetOnly = effectiveDamageTargetOnly,
		penetratesEntities = penetrates,
	}
end
```

### Update performProjectileAttack Stub

**Current stub in CombatSystem.luau needs full implementation:**

```lua
-- Perform projectile attack (called by server after validation)
function CombatSystem.performProjectileAttack(
	origin: vector,
	direction: vector,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model? -- The target player had locked when firing
): ProjectileInstance?
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig or weaponConfig.type ~= "projectile" then
		warn(`Weapon {weaponName} is not a projectile weapon`)
		return nil
	end

	-- Get damage mode
	local damageMode = getEffectiveDamageMode(weaponConfig)

	-- Validate LOS if required (server-side validation)
	if weaponConfig.requiresLineOfSight and lockedTarget then
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			local losResult = ProjectileLOS.validatePath(
				origin,
				targetRoot.Position,
				attacker
			)

			if not losResult.hasLineOfSight then
				warn(`Projectile blocked for {attacker.Name}`)
				return nil
			end
		end
	end

	-- Spawn projectile via ProjectileManager
	local projectile = ProjectileManager.spawnProjectile(
		origin,
		direction,
		weaponName,
		attacker,
		attackingPlayer,
		lockedTarget,
		damageMode
	)

	return projectile
end
```

---

## 3. ProjectileManager Updates

**File:** `src/shared/ProjectileManager.luau` (update existing)

### Update ProjectileInstance Type

```lua
export type ProjectileInstance = {
	model: Model,
	weapon: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?, -- NEW: The intended target
	damageMode: CombatSystem.DamageMode, -- NEW: Damage mode config
	spawnTime: number,
	distanceTraveled: number,
	maxRange: number,
	speed: number,
	direction: vector,
	lastPosition: vector,
	connection: RBXScriptConnection?,
	entitiesHit: {[Model]: boolean}, -- NEW: Track hit entities for penetration
}
```

### Update spawnProjectile Function

```lua
function ProjectileManager.spawnProjectile(
	origin: vector,
	direction: vector,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?,
	damageMode: CombatSystem.DamageMode
): ProjectileInstance?
	-- ... existing model cloning logic ...

	local projectile: ProjectileInstance = {
		model = projectileModel,
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
		connection = nil,
		entitiesHit = {},
	}

	-- ... rest of spawn logic ...
end
```

### Update updateProjectile Function

```lua
function ProjectileManager.updateProjectile(projectile: ProjectileInstance, deltaTime: number)
	local weaponConfig = CombatSystem.getWeaponConfig(projectile.weapon)
	if not weaponConfig then
		return
	end

	-- Calculate new position
	local currentPosition = projectile.model.PrimaryPart.Position
	local movement = projectile.direction * (projectile.speed * deltaTime)

	-- Setup raycast
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local ignoreList = {projectile.attacker, projectile.model}

	-- If damageTargetOnly, ignore all entities except locked target
	if projectile.damageMode.damageTargetOnly then
		-- Add all entities except locked target to ignore list
		for _, player in game:GetService("Players"):GetPlayers() do
			if player.Character and player.Character ~= projectile.lockedTarget then
				table.insert(ignoreList, player.Character)
			end
		end

		-- Ignore all NPCs except locked target
		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("Humanoid") and descendant.Parent ~= projectile.lockedTarget then
				table.insert(ignoreList, descendant.Parent)
			end
		end
	end

	raycastParams.FilterDescendantsInstances = ignoreList

	-- Raycast from last position to current position
	local raycastResult = workspace:Raycast(
		projectile.lastPosition,
		movement,
		raycastParams
	)

	if raycastResult then
		local hitEntity = findEntityFromPart(raycastResult.Instance)

		if hitEntity then
			-- Check if already hit this entity
			if not projectile.entitiesHit[hitEntity] then
				projectile.entitiesHit[hitEntity] = true

				-- Determine if should damage this entity
				local shouldDamage = false

				if projectile.damageMode.damageTargetOnly then
					-- Only damage if this is the locked target
					shouldDamage = (hitEntity == projectile.lockedTarget)
				else
					-- Damage any entity hit
					shouldDamage = true
				end

				if shouldDamage then
					-- Apply damage
					local targetHumanoid = hitEntity:FindFirstChildOfClass("Humanoid")
					if targetHumanoid and targetHumanoid.Health > 0 then
						-- Check PvP rules
						if CombatSystem.isPvPAllowed(projectile.attacker, hitEntity) then
							-- Apply damage
							targetHumanoid:TakeDamage(weaponConfig.damage)

							-- Show feedback
							local damageType = if game:GetService("Players"):GetPlayerFromCharacter(hitEntity)
								then "incoming"
								else "self"

							CombatFeedback.showDamage(
								hitEntity,
								weaponConfig.damage,
								projectile.weapon,
								damageType,
								projectile.attackingPlayer
							)

							print(`Projectile hit {hitEntity.Name} for {weaponConfig.damage} damage`)
						end
					end
				end

				-- Check if should stop or penetrate
				if not projectile.damageMode.penetratesEntities then
					-- Stop at first entity hit
					destroyProjectile(projectile)
					return
				end
				-- Otherwise continue flying (penetration)
			end
		else
			-- Hit terrain/structure - always stop
			destroyProjectile(projectile)
			return
		end
	end

	-- Update position and distance
	projectile.lastPosition = currentPosition
	projectile.distanceTraveled = projectile.distanceTraveled + movement.Magnitude

	-- Check max range
	if projectile.distanceTraveled >= projectile.maxRange then
		destroyProjectile(projectile)
	end
end
```

**Security Notes:**
- All damage calculations on server
- Entity filtering happens server-side
- Client cannot influence raycast results or damage modes

---

## 4. ToolManager Integration

**File:** `src/server/ToolManager.luau` (update existing)

### Update performCombatAttack for Projectiles

```lua
-- In the projectile weapon branch
elseif weaponConfig.type == "projectile" then
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	-- Get locked target from TargetingSystem
	local lockedTarget = TargetingSystem.getTarget(player)

	-- Validate facing requirement (server-side)
	if GameConfig.combat.requireFacingForDamage and lockedTarget then
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			local isFacing = CombatSystem.isFacingTarget(
				humanoidRootPart,
				targetRoot,
				GameConfig.combat.facingAngleDegrees
			)

			if not isFacing then
				print(`{player.Name} not facing target, projectile blocked`)
				playToolSound(player, toolType, "swing") -- Miss sound
				return
			end
		end
	end

	-- Get aim direction
	local direction = humanoidRootPart.CFrame.LookVector
	local origin = humanoidRootPart.Position + (direction * 3) -- Spawn in front

	-- Wait for cast duration (draw/charge animation)
	task.wait(weaponConfig.castDuration)

	-- Spawn projectile (server validates LOS inside this function)
	local projectile = CombatSystem.performProjectileAttack(
		origin,
		direction,
		weaponName,
		character,
		player,
		lockedTarget
	)

	if projectile then
		playToolSound(player, toolType, "attack")
		print(`{player.Name} fired {weaponName}`)
	else
		playToolSound(player, toolType, "swing") -- Blocked sound
		print(`{player.Name} projectile blocked`)
	end
end
```

**Security:**
- Facing check done server-side
- Server validates before spawning projectile
- Client input only triggers validation, doesn't affect outcome

---

## 5. Client HUD Integration

**File:** `src/client/TargetingHUD.luau` (update existing)

### Add LOS Validation (Visual Feedback Only)

```lua
-- Import ProjectileLOS
local ProjectileLOS = require(ReplicatedStorage.Engine.ProjectileLOS)

-- Update indicator logic
local function updateTargetIndicator()
	local target = TargetingSystem.getTarget(LocalPlayer)

	if not target then
		-- Show NO TARGET
		statusLabel.Text = "NO TARGET"
		statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		return
	end

	local character = LocalPlayer.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or not targetRoot then return end

	-- Check facing (if required)
	if GameConfig.combat.requireFacingForDamage then
		local isFacing = CombatSystem.isFacingTarget(
			humanoidRootPart,
			targetRoot,
			GameConfig.combat.facingAngleDegrees
		)

		if not isFacing then
			statusLabel.Text = "NOT FACING"
			statusLabel.TextColor3 = Color3.fromRGB(255, 150, 0) -- Orange
			return
		end
	end

	-- Check LOS (only for projectile weapons)
	local equippedTool = character:FindFirstChildOfClass("Tool")
	if equippedTool then
		local toolConfig = GameConfig.tools[equippedTool.Name]
		if toolConfig and toolConfig.weaponRef then
			local weaponConfig = GameConfig.weapons[toolConfig.weaponRef]
			if weaponConfig and weaponConfig.type == "projectile" and weaponConfig.requiresLineOfSight then
				local origin = humanoidRootPart.Position + vector.create(0, 1, 0)
				local targetPos = targetRoot.Position + vector.create(0, 1, 0)

				local losResult = ProjectileLOS.validatePath(origin, targetPos, character)

				if not losResult.hasLineOfSight then
					statusLabel.Text = "BLOCKED"
					statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50) -- Red
					return
				end
			end
		end
	end

	-- All checks passed
	statusLabel.Text = "READY"
	statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green
end

-- Update continuously or on weapon change
RunService.Heartbeat:Connect(updateTargetIndicator)
```

**Security:**
- Client check is VISUAL ONLY
- Server re-validates everything
- Client cannot bypass server validation

---

## 6. AI Obstacle Avoidance

**File:** `src/server/EntityController.luau` (update existing)

### Simple Sidestep Algorithm

```lua
-- Add at top
local ProjectileLOS = require(ReplicatedStorage.Engine.ProjectileLOS)

-- Update performAttack function for projectile weapons
elseif weaponConfig.type == "projectile" then
	-- Check LOS before firing
	if weaponConfig.requiresLineOfSight then
		local losResult = ProjectileLOS.canTargetEntity(entity.model, target.Character)

		if not losResult.hasLineOfSight then
			print(`*** {entity.entityType} blocked, attempting sidestep`)

			-- Attempt to sidestep obstacle
			local entityPos = entity.humanoidRootPart.Position
			local targetPos = target.Character.HumanoidRootPart.Position
			local toTarget = (targetPos - entityPos).Unit

			-- Calculate perpendicular directions (left and right)
			local leftDir = vector.create(-toTarget.Z, 0, toTarget.X)
			local rightDir = vector.create(toTarget.Z, 0, -toTarget.X)

			-- Try both directions, pick the one with clearer LOS
			local leftPos = entityPos + (leftDir * 8)
			local rightPos = entityPos + (rightDir * 8)

			-- Simple heuristic: check which side gets closer to clear LOS
			local leftLOS = ProjectileLOS.validatePath(leftPos, targetPos, entity.model)
			local rightLOS = ProjectileLOS.validatePath(rightPos, targetPos, entity.model)

			local moveDir
			if leftLOS.hasLineOfSight then
				moveDir = leftDir
			elseif rightLOS.hasLineOfSight then
				moveDir = rightDir
			else
				-- Neither side is clear, pick random
				moveDir = math.random() > 0.5 and leftDir or rightDir
			end

			-- Move to new position
			local moveDistance = math.random(5, 10)
			local newGoal = entityPos + (moveDir * moveDistance)

			-- Use existing pathfinding/movement system
			-- (Assuming you have a moveToPosition or similar function)
			entity.isRepositioning = true
			task.spawn(function()
				-- Simple movement towards goal
				local pathSuccess = moveToPosition(entity, newGoal)
				entity.isRepositioning = false

				if pathSuccess then
					print(`*** {entity.entityType} repositioned for clear shot`)
				end
			end)

			return -- Skip attack this cycle
		end
	end

	-- LOS is clear, proceed with projectile attack
	local targetPos = target.Character.HumanoidRootPart.Position
	local entityPos = entity.humanoidRootPart.Position

	-- Lead moving targets
	local targetVelocity = target.Character.HumanoidRootPart.AssemblyLinearVelocity
	local projectileSpeed = weaponConfig.projectileSpeed or 50
	local timeToImpact = (targetPos - entityPos).Magnitude / projectileSpeed
	local leadTarget = targetPos + (targetVelocity * timeToImpact)
	local direction = (leadTarget - entityPos).Unit

	-- Play animation
	playAnimation(entity, "attack")
	playSound(entity, "attack")
	updateEntityState(entity, "attacking")

	task.wait(weaponConfig.castDuration)

	-- Fire projectile
	local origin = entityPos + (direction * 2)
	CombatSystem.performProjectileAttack(
		origin,
		direction,
		weaponName,
		entity.model,
		nil,
		target.Character
	)

	print(`*** {entity.entityType} fired {weaponName} at {target.Name}`)
end
```

**AI Strategy:**
1. Check LOS before firing
2. If blocked, calculate left/right sidestep positions
3. Test which direction gives clearer LOS
4. Move 5-10 studs in that direction
5. Skip attack this cycle, retry next attack cycle
6. If still blocked, repeat (will eventually path around or switch targets)

---

## 7. GameConfig Updates

**File:** `src/shared/GameConfig.luau`

### Add Projectile Weapon Configurations

```lua
weapons = {
	-- Existing weapons...

	-- Phase 2: Projectile Weapons
	Bow = {
		type = "projectile",
		name = "Bow",
		damage = 30,
		range = 100,
		cooldown = 1.5,
		castDuration = 0.5,
		projectileSpeed = 80,
		requiresLineOfSight = true,
		damageTargetOnly = nil, -- Use combat.damageTargetOnly
		penetratesEntities = false,
	},

	SpiderWeb = {
		type = "projectile",
		name = "Spider Web",
		damage = 5,
		range = 40,
		cooldown = 3,
		castDuration = 0.6,
		projectileSpeed = 30,
		requiresLineOfSight = true,
		damageTargetOnly = false, -- Can hit entities along path
		penetratesEntities = false, -- Stops at first hit
	},

	-- Example: Penetrating projectile
	MagicArrow = {
		type = "projectile",
		name = "Magic Arrow",
		damage = 20,
		range = 80,
		cooldown = 2.0,
		castDuration = 0.7,
		projectileSpeed = 100,
		requiresLineOfSight = true,
		damageTargetOnly = false, -- Hits all entities
		penetratesEntities = true, -- Passes through all entities
	},
},

tools = {
	-- Existing tools...

	Bow = {
		miningEfficiency = 0,
		canMine = {},
		swingCooldown = 1.5,
		weaponRef = "Bow",
	},
},
```

---

## 8. Testing Checklist

### Security Testing (CRITICAL)
- [ ] Client cannot modify damage values
- [ ] Client cannot bypass LOS validation
- [ ] Client cannot bypass facing requirements
- [ ] Client cannot spawn projectiles directly
- [ ] Server validates all weapon ownership
- [ ] Server enforces cooldowns
- [ ] Client disconnection doesn't break projectiles
- [ ] Exploiter cannot manipulate raycast results

### Functional Testing
- [ ] Projectile spawns at correct position
- [ ] LOS validation blocks shots through walls
- [ ] LOS validation blocks shots through resources (trees, rocks)
- [ ] LOS validation allows shots through gaps
- [ ] Facing requirement works (if enabled)
- [ ] HUD shows correct status (BLOCKED, NOT FACING, READY)
- [ ] damageTargetOnly = true: only target takes damage
- [ ] damageTargetOnly = false: entities along path take damage
- [ ] penetratesEntities = false: stops at first entity
- [ ] penetratesEntities = true: damages all entities along path
- [ ] AI sidesteps obstacles successfully
- [ ] AI repositions to find clear LOS
- [ ] AI doesn't get stuck in repositioning loop
- [ ] Works in multiplayer with 5+ players

### Performance Testing
- [ ] No lag with multiple projectiles in flight
- [ ] LOS checks don't cause framerate drops
- [ ] AI pathfinding efficient
- [ ] No memory leaks from projectile pooling

### Edge Cases
- [ ] Target moves behind obstacle mid-flight (projectile continues)
- [ ] Attacker dies mid-flight (projectile continues)
- [ ] Target dies mid-flight (projectile continues/despawns)
- [ ] Multiple AI entities blocked simultaneously
- [ ] Projectile at max range edge cases
- [ ] Penetrating projectile hits max targets

---

## 9. Implementation Order

1. ✅ Create `ProjectileLOS.luau` module
2. ✅ Add `getEffectiveDamageMode()` to `CombatSystem.luau`
3. ✅ Update `performProjectileAttack()` in `CombatSystem.luau`
4. ✅ Update `ProjectileManager.luau` types and logic
5. ✅ Update `ToolManager.luau` projectile attack validation
6. ✅ Update `TargetingHUD.luau` visual indicators
7. ✅ Update `EntityController.luau` AI obstacle avoidance
8. ✅ Update `GameConfig.luau` weapon definitions
9. ✅ Test all functionality
10. ✅ Security audit and testing

---

## 10. Security Considerations Summary

### Server-Side Validation Checklist

**All of these MUST happen on server:**
- ✅ Weapon ownership validation
- ✅ Cooldown enforcement
- ✅ Facing requirement check
- ✅ LOS validation raycast
- ✅ Damage mode determination
- ✅ Target validity check
- ✅ Projectile spawn
- ✅ Damage calculation
- ✅ Damage application

**Client can only:**
- ❌ Request attack via RemoteEvent
- ❌ Display visual feedback (HUD, effects)
- ❌ Show predicted projectile path (cosmetic only)

### Exploit Prevention

**Rate Limiting:**
```lua
-- In ToolManager
local attackRateLimit = {}
local MAX_ATTACKS_PER_SECOND = 10

local function validateAttackRate(player: Player): boolean
	local currentTime = tick()
	if not attackRateLimit[player] then
		attackRateLimit[player] = {timestamps = {}}
	end

	local timestamps = attackRateLimit[player].timestamps

	-- Remove old timestamps
	for i = #timestamps, 1, -1 do
		if currentTime - timestamps[i] > 1 then
			table.remove(timestamps, i)
		end
	end

	if #timestamps >= MAX_ATTACKS_PER_SECOND then
		warn(`Player {player.Name} attacking too fast - possible exploit`)
		return false
	end

	table.insert(timestamps, currentTime)
	return true
end
```

**Projectile Count Limiting:**
```lua
-- In ProjectileManager
local playerProjectileCount: {[Player]: number} = {}
local MAX_PROJECTILES_PER_PLAYER = 5

local function canSpawnProjectile(player: Player?): boolean
	if not player then return true end -- NPCs unlimited

	local count = playerProjectileCount[player] or 0
	return count < MAX_PROJECTILES_PER_PLAYER
end
```

---

## Success Criteria

Implementation complete when:
- ✅ All server-side validation in place
- ✅ Client cannot manipulate any damage/validation
- ✅ LOS system works for players and AI
- ✅ All damage modes function correctly
- ✅ AI obstacle avoidance functional
- ✅ HUD indicators accurate
- ✅ No security exploits found
- ✅ Performance targets met (60 FPS)
- ✅ All tests passed

---

## Future Enhancements

**Advanced AI Pathfinding:**
- Use `PathfindingService` with custom cost modifiers
- Prefer paths with clear LOS to target
- Use cover when health low

**Projectile Prediction:**
- Client-side cosmetic prediction for responsiveness
- Server reconciliation if prediction wrong

**Ballistic Trajectory:**
- Add gravity to projectiles
- Arc calculation for long-range shots
- Lead calculation with gravity compensation
