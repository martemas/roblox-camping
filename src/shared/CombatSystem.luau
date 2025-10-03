--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameConfig = require(script.Parent:WaitForChild("GameConfig"))
local CombatFeedback = require(script.Parent:WaitForChild("CombatFeedback"))
local ProjectileLOS = require(script.Parent:WaitForChild("ProjectileLOS"))
local DamageCalculator = require(script.Parent:WaitForChild("DamageCalculator"))
local HitscanEffects = require(script.Parent:WaitForChild("HitscanEffects"))

-- Export types
export type WeaponType = "melee" | "projectile" | "hitscan" | "aoe"

export type WeaponConfig = {
	type: WeaponType,
	name: string,
	damage: number,
	range: number,
	cooldown: number,
	castDuration: number,

	-- Projectile-specific
	projectileSpeed: number?,
	projectileConfig: ProjectileConfig?,

	-- Hitscan-specific
	visualEffect: string?, -- "beam" or "none"

	-- AOE-specific
	aoeDamage: number?,
	aoeRadius: number?,
	aoeFalloff: boolean?,
	maxTargets: number?,
	duration: number?,
	tickRate: number?,
	targetFilter: string?,
	aoeOnImpact: boolean?, -- For projectile/hitscan with AOE explosion

	-- Combat validation properties (all weapon types)
	requiresTarget: boolean?, -- Weapon always requires target regardless of mode
	requiresLineOfSight: boolean?, -- Weapon requires line of sight to target
	requireFacingForDamage: boolean?, -- Override global requireFacingForDamage setting
}

export type AttackResult = {
	hit: boolean,           -- Was attack successful
	target: Model?,         -- Entity that was hit (nil for AOE/miss)
	damage: number?,        -- Damage dealt (nil if miss)
	wasInRange: boolean,    -- Was target in range after castDuration
	wasDodged: boolean,     -- Did target dodge (was in range, now isn't)
	blockedByInvulnerability: boolean?, -- Was attack blocked by invulnerability frames
}

export type AOEHitInfo = {
	entity: Model,
	damage: number,
	distance: number,       -- Distance from AOE center
}

export type DamageMode = {
	damageTargetOnly: boolean,
	penetratesEntities: boolean,
}

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

local CombatSystem = {}

-- Get weapon config from GameConfig
function CombatSystem.getWeaponConfig(weaponName: string): WeaponConfig?
	local weaponConfig = GameConfig.weapons[weaponName]
	if not weaponConfig then
		warn(`Weapon config not found: {weaponName}`)
		return nil
	end
	return weaponConfig
end

-- Get entity's weapon (for wildlife/enemies)
function CombatSystem.getEntityWeapon(entityType: string): string?
	-- Check wildlife
	local wildlifeConfig = GameConfig.wildlife[entityType]
	if wildlifeConfig and wildlifeConfig.primaryWeapon then
		return wildlifeConfig.primaryWeapon
	end

	-- Check enemies
	local enemyConfig = GameConfig.enemies[entityType]
	if enemyConfig and enemyConfig.primaryWeapon then
		return enemyConfig.primaryWeapon
	end

	return nil
end

-- Get player's equipped weapon (from tool)
function CombatSystem.getPlayerWeapon(player: Player): string?
	local character = player.Character
	if not character then
		return nil
	end

	-- Check for equipped tool
	for _, toolName in GameConfig.player.startingTools do
		local tool = character:FindFirstChild(toolName)
		if tool and tool:IsA("Tool") then
			-- Get weapon name: use weaponRef if available, otherwise use tool name directly
			local toolConfig = GameConfig.tools[toolName]
			if toolConfig and toolConfig.weaponRef then
				return toolConfig.weaponRef
			else
				-- Pure weapon tools (like Bow) use tool name as weapon name
				return toolName
			end
		end
	end

	return nil
end

-- Calculate distance between two positions
local function getDistance(pos1: vector, pos2: vector): number
	return (pos2 - pos1).Magnitude
end

-- Check if attacker is facing target (within configured angle)
local function isFacingTarget(
	attackerRoot: BasePart,
	targetRoot: BasePart,
	customAngleDegrees: number?
): boolean
	if not GameConfig.combat.requireFacingForDamage then
		return true -- Always allow damage if directional check is disabled
	end

	-- Get attacker's look vector (direction they're facing)
	local attackerLookVector = attackerRoot.CFrame.LookVector

	-- Get direction from attacker to target
	local directionToTarget = (targetRoot.Position - attackerRoot.Position).Unit

	-- Calculate dot product to determine angle
	local dotProduct = attackerLookVector:Dot(directionToTarget)

	-- Use custom angle if provided, otherwise use global config
	local angleDegrees = customAngleDegrees or GameConfig.combat.facingAngleDegrees or 180

	-- Convert configured angle to threshold
	-- facingAngleDegrees of 120° = 60° on each side of center = cos(60°) = 0.5
	local angleThreshold = math.cos(math.rad(angleDegrees / 2))

	-- If dot product >= threshold, attacker is facing target
	return dotProduct >= angleThreshold
end

-- Find entity model from a part (includes player characters and NPCs)
local function findEntityFromPart(part: BasePart): Model?
	local current = part.Parent
	while current and current ~= workspace do
		if current:IsA("Model") then
			-- Check if it's a player character
			local player = game:GetService("Players"):GetPlayerFromCharacter(current)
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

-- Check if target is invulnerable to this weapon type
local function checkInvulnerability(targetModel: Model, weaponName: string): boolean
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	-- Check if invulnerability system is enabled
	if not GameConfig.combat.invulnerabilityFrames then
		return false
	end

	-- Check weapon-specific invulnerability
	local invulnAttr = `InvulnerableTo_{weaponName}`
	local isInvulnerable = humanoid:GetAttribute(invulnAttr)
	return isInvulnerable == true
end

-- Set invulnerability for a target to a specific weapon type
local function setInvulnerability(targetModel: Model, weaponName: string, duration: number)
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if not GameConfig.combat.invulnerabilityFrames then
		return
	end

	local invulnAttr = `InvulnerableTo_{weaponName}`
	humanoid:SetAttribute(invulnAttr, true)

	-- Clear invulnerability after duration
	task.delay(duration, function()
		if humanoid and humanoid.Parent then
			humanoid:SetAttribute(invulnAttr, false)
		end
	end)
end

-- Check if PvP is allowed for this attack
local function isPvPAllowed(attacker: Model, target: Model): boolean
	-- Check if both are player characters
	local attackerPlayer = game:GetService("Players"):GetPlayerFromCharacter(attacker)
	local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(target)

	if not attackerPlayer or not targetPlayer then
		-- Not PvP if either is not a player
		return true
	end

	-- Check if PvP is enabled
	return GameConfig.combat.pvpEnabled
end

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

-- Find all entities within range of a position
local function findEntitiesInRange(
	origin: vector,
	range: number,
	excludeModel: Model?
): {Model}
	local entities: {Model} = {}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if excludeModel then {excludeModel} else {}

	local parts = workspace:GetPartBoundsInRadius(origin, range, params)

	-- Find unique entity models
	local seen: {[Model]: boolean} = {}
	for _, part in parts do
		local entity = findEntityFromPart(part)
		if entity and not seen[entity] and entity ~= excludeModel then
			seen[entity] = true
			table.insert(entities, entity)
		end
	end

	return entities
end

-- Main attack function for melee weapons
function CombatSystem.attemptMeleeAttack(
	attacker: Model,
	target: Model?,
	weaponName: string,
	attackingPlayer: Player?
): AttackResult
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		return {
			hit = false,
			target = nil,
			damage = nil,
			wasInRange = false,
			wasDodged = false,
			blockedByInvulnerability = false
		}
	end

	-- Get attacker position
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not attackerRoot then
		return {
			hit = false,
			target = nil,
			damage = nil,
			wasInRange = false,
			wasDodged = false,
			blockedByInvulnerability = false
		}
	end

	local attackerPos = attackerRoot.Position

	-- Determine hit detection mode
	local damageTargetOnly = GameConfig.combat.damageTargetOnly

	local targetsToCheck: {Model} = {}

	if damageTargetOnly then
		-- Mode A: Only damage the specified target
		if target then
			table.insert(targetsToCheck, target)
		end
	else
		-- Mode B: Damage all entities in range
		targetsToCheck = findEntitiesInRange(attackerPos, weaponConfig.range, attacker)
	end

	-- Check each potential target
	local hitAny = false
	local firstHit: Model? = nil
	local totalDamage = 0

	for _, targetModel in targetsToCheck do
		local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not targetRoot then
			continue
		end

		-- Check if target is in range
		local distance = getDistance(attackerPos, targetRoot.Position)
		local inRange = distance <= weaponConfig.range

		if not inRange then
			-- Target out of range - dodged or miss
			if targetModel == target then
				-- Primary target dodged
				CombatFeedback.showDamage(targetModel, nil, weaponName, "dodge", attackingPlayer)
			end
			continue
		end

		-- Check facing requirement
		if not isFacingTarget(attackerRoot, targetRoot, nil) then
			-- Not facing target - blocked
			if targetModel == target then
				CombatFeedback.showDamage(targetModel, nil, weaponName, "blocked", attackingPlayer)
			end
			continue
		end

		-- Check PvP rules
		if not isPvPAllowed(attacker, targetModel) then
			print(`PvP blocked: {attacker.Name} cannot attack {targetModel.Name}`)
			continue
		end

		-- Check invulnerability
		if checkInvulnerability(targetModel, weaponName) then
			print(`{targetModel.Name} is invulnerable to {weaponName}`)
			if not hitAny and targetModel == target then
				-- Return blocked result for primary target
				return {
					hit = false,
					target = targetModel,
					damage = nil,
					wasInRange = true,
					wasDodged = false,
					blockedByInvulnerability = true
				}
			end
			continue
		end

		-- Target is in range and not invulnerable - calculate and apply damage
		local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
		if targetHumanoid and targetHumanoid.Health > 0 then
			-- Calculate damage using DamageCalculator
			local damageResult = DamageCalculator.calculateDamage({
				attacker = attacker,
				target = targetModel,
				weaponName = weaponName,
				hitPart = nil, -- Melee doesn't track specific part yet
			})

			if damageResult.wasHit then
				-- Apply damage
				targetHumanoid:TakeDamage(damageResult.finalDamage)

				-- Set invulnerability
				setInvulnerability(
					targetModel,
					weaponName,
					GameConfig.combat.invulnerabilityDuration or 0.5
				)

				-- Determine damage type for feedback
				local damageType: CombatFeedback.DamageType
				local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(targetModel)

				if targetPlayer then
					-- Damage to a player
					damageType = "incoming"
				else
					-- Damage to an NPC
					if attackingPlayer then
						damageType = "self"
					else
						damageType = "other_player"
					end
				end

				-- Show damage feedback
				CombatFeedback.showDamage(
					targetModel,
					damageResult.finalDamage,
					weaponName,
					damageType,
					attacker -- Changed from attackingPlayer to attacker model
				)

				-- Notify entity it was damaged (for aggro/retargeting) - lazy load to avoid circular dependency
				if not targetPlayer then
					local EntityController = require(script.Parent:WaitForChild("EntityController"))
					EntityController.onEntityDamaged(targetModel, attacker)
				end

				-- Play hit sound
				CombatFeedback.playHitSound(targetModel, "Hit")

				hitAny = true
				if not firstHit then
					firstHit = targetModel
				end
				totalDamage = totalDamage + damageResult.finalDamage

				print(`*** {attacker.Name} hit {targetModel.Name} for {damageResult.finalDamage} damage with {weaponName} (location: {damageResult.hitLocation}, multiplier: {damageResult.damageMultiplier}x)`)
			end
		end
	end

	if hitAny then
		return {
			hit = true,
			target = firstHit,
			damage = totalDamage,
			wasInRange = true,
			wasDodged = false,
			blockedByInvulnerability = false
		}
	else
		-- No hits - either out of range or all invulnerable
		return {
			hit = false,
			target = target,
			damage = nil,
			wasInRange = false,
			wasDodged = true,
			blockedByInvulnerability = false
		}
	end
end

-- Helper function to check if entity should be affected by AOE
local function shouldAffectEntity(entity: Model, attacker: Model, targetFilter: string?): boolean
	if not targetFilter or targetFilter == "all" then
		return true
	end

	local entityPlayer = Players:GetPlayerFromCharacter(entity)
	local attackerPlayer = Players:GetPlayerFromCharacter(attacker)

	if targetFilter == "allies" then
		-- Only affect allies (same player or self)
		if entity == attacker then
			return true
		end
		if entityPlayer and attackerPlayer and entityPlayer == attackerPlayer then
			return true
		end
		-- TODO: Team support
		return false

	elseif targetFilter == "enemies" then
		-- Only affect enemies (different player or NPCs)
		if entity == attacker then
			return false
		end
		if entityPlayer and attackerPlayer and entityPlayer == attackerPlayer then
			return false
		end
		return true
	end

	return true
end

-- Perform AOE attack
function CombatSystem.performAOEAttack(
	attacker: Model,
	targetPosition: Vector3,
	weaponName: string,
	attackingPlayer: Player?,
	options: {
		damageOverride: number?,
		radius: number?,
		falloff: boolean?,
		maxTargets: number?,
	}?
): {AOEHitInfo}
	local AOEZoneManager = require(script.Parent:WaitForChild("AOEZoneManager"))
	local opts = options or {}

	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		warn(`performAOEAttack: Weapon {weaponName} not found`)
		return {}
	end

	-- Get effective values (options override config)
	local damage = opts.damageOverride or weaponConfig.aoeDamage or weaponConfig.damage or 10
	local radius = opts.radius or weaponConfig.aoeRadius or 10
	local falloff = if opts.falloff ~= nil then opts.falloff else (weaponConfig.aoeFalloff or false)
	local maxTargets = opts.maxTargets or weaponConfig.maxTargets or 999

	local hits: {AOEHitInfo} = {}

	-- Find entities in radius
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {attacker}

	local parts = workspace:GetPartBoundsInRadius(targetPosition, radius, params)

	-- Find unique entities
	local hitEntities: {[Model]: boolean} = {}

	for _, part in parts do
		local entity = findEntityFromPart(part)
		if entity and not hitEntities[entity] then
			hitEntities[entity] = true

			-- Check target filter
			if not shouldAffectEntity(entity, attacker, weaponConfig.targetFilter) then
				continue
			end

			-- Check PvP
			if not isPvPAllowed(attacker, entity) then
				continue
			end

			-- Check invulnerability
			if checkInvulnerability(entity, weaponName) then
				continue
			end

			local entityRoot = entity:FindFirstChild("HumanoidRootPart") :: BasePart?
			if entityRoot then
				local distance = (targetPosition - entityRoot.Position).Magnitude

				-- Calculate damage with falloff
				local damageMultiplier = 1.0
				if falloff then
					damageMultiplier = 1 - (distance / radius)
					damageMultiplier = math.max(0, damageMultiplier)
				end

				local finalDamage = damage * damageMultiplier

				-- Apply damage via central system
				local success = CombatSystem.applyDamageToEntity(attacker, entity, weaponName, {
					damageOverride = finalDamage,
					hitPosition = targetPosition,
				})

				if success then
					table.insert(hits, {
						entity = entity,
						damage = finalDamage,
						distance = distance,
					})

					if #hits >= maxTargets then
						break
					end
				end
			end
		end
	end

	-- Create persistent zone if configured
	if weaponConfig.duration and weaponConfig.tickRate then
		AOEZoneManager.createZone(
			targetPosition,
			radius,
			weaponName,
			attacker,
			attackingPlayer,
			weaponConfig.duration,
			weaponConfig.tickRate
		)
	end

	print(`AOE attack {weaponName} hit {#hits} entities at {targetPosition}`)
	return hits
end

-- Apply damage to a single entity (low-level API for custom spells)
function CombatSystem.applyDamageToEntity(
	attacker: Model,
	target: Model,
	weaponName: string,
	options: {
		damageOverride: number?,
		hitPosition: Vector3?,
		bypassInvulnerability: boolean?,
	}?
): boolean
	local opts = options or {}

	-- Validate target has Humanoid
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end

	-- Check PvP rules (unless bypassed)
	if not isPvPAllowed(attacker, target) then
		print(`PvP blocked: {attacker.Name} cannot attack {target.Name}`)
		return false
	end

	-- Check invulnerability (unless bypassed)
	if not opts.bypassInvulnerability and checkInvulnerability(target, weaponName) then
		print(`{target.Name} is invulnerable to {weaponName}`)
		return false
	end

	-- Get weapon config
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		return false
	end

	-- Calculate damage via DamageCalculator
	local damageResult = DamageCalculator.calculateDamage({
		attacker = attacker,
		target = target,
		weaponName = weaponName,
		hitPart = opts.hitPosition and target:FindFirstChild("HumanoidRootPart") :: BasePart? or nil,
	})

	if not damageResult.wasHit then
		return false
	end

	-- Use override damage if provided, otherwise use calculated damage
	local finalDamage = opts.damageOverride or damageResult.finalDamage

	-- Apply damage/healing
	if finalDamage < 0 then
		-- Healing (negative damage)
		targetHumanoid.Health = math.min(targetHumanoid.Health - finalDamage, targetHumanoid.MaxHealth)
	else
		-- Damage
		targetHumanoid:TakeDamage(finalDamage)
	end

	-- Set invulnerability (unless bypassed)
	if not opts.bypassInvulnerability then
		setInvulnerability(target, weaponName, GameConfig.combat.invulnerabilityDuration or 0.5)
	end

	-- Determine damage type for feedback
	local damageType: CombatFeedback.DamageType
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	local attackingPlayer = Players:GetPlayerFromCharacter(attacker)

	if targetPlayer then
		damageType = "incoming"
	else
		if attackingPlayer then
			damageType = "self"
		else
			damageType = "other_player"
		end
	end

	-- Show damage feedback
	CombatFeedback.showDamage(target, math.abs(finalDamage), weaponName, damageType, attacker)

	-- Play hit sound
	CombatFeedback.playHitSound(target, "Hit")

	-- Notify entity it was damaged (for aggro) - lazy load to avoid circular dependency
	if not targetPlayer then
		local EntityController = require(script.Parent:WaitForChild("EntityController"))
		EntityController.onEntityDamaged(target, attacker)
	end

	return true
end

-- Perform hitscan attack
function CombatSystem.performHitscan(
	origin: Vector3,
	direction: Vector3,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?
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

	local hitEntity: Model? = nil
	local hitPosition: Vector3
	local hitNormal = Vector3.new(0, 1, 0)

	-- Determine target based on auto-aim mode
	if GameConfig.combat.autoAim and lockedTarget then
		-- Auto-aim mode: Check if locked target in range
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not targetRoot then
			return {
				hit = false,
				target = lockedTarget,
				damage = nil,
				wasInRange = false,
				wasDodged = false,
				blockedByInvulnerability = false
			}
		end

		local distance = getDistance(origin, targetRoot.Position)
		if distance > weaponConfig.range then
			-- Out of range
			return {
				hit = false,
				target = lockedTarget,
				damage = nil,
				wasInRange = false,
				wasDodged = true,
				blockedByInvulnerability = false
			}
		end

		hitEntity = lockedTarget
		hitPosition = targetRoot.Position

	else
		-- Free-aim mode: Raycast in direction
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {attacker}

		-- TODO: Add spread support for accuracy variance
		-- local spreadDirection = applySpread(direction, weaponConfig.spread or 0)

		local raycastResult = workspace:Raycast(origin, direction.Unit * weaponConfig.range, raycastParams)

		if not raycastResult then
			-- Complete miss - show beam to max range (shorter duration)
			if weaponConfig.visualEffect == "beam" then
				HitscanEffects.showBeam(
					origin,
					origin + (direction.Unit * weaponConfig.range),
					weaponName,
					0.15,
					weaponConfig.damage and weaponConfig.damage < 0
				)
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

		hitPosition = raycastResult.Position
		hitNormal = raycastResult.Normal
		hitEntity = findEntityFromPart(raycastResult.Instance)

		if not hitEntity then
			-- Hit terrain/wall
			if weaponConfig.visualEffect == "beam" then
				HitscanEffects.showBeam(origin, hitPosition, weaponName, 0.3, weaponConfig.damage and weaponConfig.damage < 0)
				HitscanEffects.showHitEffect(hitPosition, hitNormal, weaponName, weaponConfig.damage and weaponConfig.damage < 0)
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
	end

	-- Check target filter (allies/enemies)
	if weaponConfig.targetFilter then
		local targetPlayer = Players:GetPlayerFromCharacter(hitEntity)
		local attackerPlayer = Players:GetPlayerFromCharacter(attacker)

		if weaponConfig.targetFilter == "allies" then
			-- Can only target allies (same player or teammates)
			if targetPlayer ~= attackerPlayer then
				-- TODO: Add team support when teams are implemented
				if weaponConfig.visualEffect == "beam" then
					HitscanEffects.showBeam(origin, hitPosition, weaponName, 0.3, weaponConfig.damage and weaponConfig.damage < 0)
				end
				print(`Target filter blocked: {weaponConfig.name} can only target allies`)
				return {
					hit = false,
					target = hitEntity,
					damage = nil,
					wasInRange = true,
					wasDodged = false,
					blockedByInvulnerability = false
				}
			end
		elseif weaponConfig.targetFilter == "enemies" then
			-- Can only target enemies (different player or NPCs)
			if targetPlayer == attackerPlayer then
				if weaponConfig.visualEffect == "beam" then
					HitscanEffects.showBeam(origin, hitPosition, weaponName, 0.3, weaponConfig.damage and weaponConfig.damage < 0)
				end
				print(`Target filter blocked: {weaponConfig.name} can only target enemies`)
				return {
					hit = false,
					target = hitEntity,
					damage = nil,
					wasInRange = true,
					wasDodged = false,
					blockedByInvulnerability = false
				}
			end
		end
	end

	-- Apply damage via central function
	local success = CombatSystem.applyDamageToEntity(attacker, hitEntity, weaponName, {
		hitPosition = hitPosition,
	})

	-- Show visual effects (even if damage failed due to invuln/PvP)
	if weaponConfig.visualEffect == "beam" then
		-- Beam lingers for 0.3s to show the path
		HitscanEffects.showBeam(origin, hitPosition, weaponName, 0.3, weaponConfig.damage and weaponConfig.damage < 0)
		if success then
			HitscanEffects.showHitEffect(hitPosition, hitNormal, weaponName, weaponConfig.damage and weaponConfig.damage < 0)
		end
	end

	if success then
		-- AOE on impact (if configured)
		if weaponConfig.aoeOnImpact then
			-- Will be implemented in Phase 2
			warn("Hitscan AOE not yet implemented - Phase 2")
		end

		return {
			hit = true,
			target = hitEntity,
			damage = weaponConfig.damage,
			wasInRange = true,
			wasDodged = false,
			blockedByInvulnerability = false
		}
	else
		-- Damage was blocked (invulnerability or PvP)
		return {
			hit = false,
			target = hitEntity,
			damage = nil,
			wasInRange = true,
			wasDodged = false,
			blockedByInvulnerability = true,
		}
	end
end

-- Perform projectile attack (validation only - spawning handled by caller)
function CombatSystem.performProjectileAttack(
	origin: Vector3,
	direction: Vector3,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?
): boolean
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig or weaponConfig.type ~= "projectile" then
		warn(`Weapon {weaponName} is not a projectile weapon`)
		return false
	end

	-- Validate LOS if required (server-side validation)
	if weaponConfig.requiresLineOfSight and lockedTarget then
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			local targetPos = targetRoot.Position
			local losResult = ProjectileLOS.validatePath(
				origin,
				Vector3.new(targetPos.X, targetPos.Y, targetPos.Z),
				attacker
			)

			if not losResult.hasLineOfSight then
				warn(`Projectile blocked for {attacker.Name} - no line of sight to {lockedTarget.Name}`)
				return false
			end
		end
	end

	-- Return true - caller (ProjectileManager) will spawn projectile
	print(`Projectile attack validated for {attacker.Name} with {weaponName}`)
	return true
end

-- Export isPvPAllowed for use by other systems
function CombatSystem.isPvPAllowed(attacker: Model, target: Model): boolean
	return isPvPAllowed(attacker, target)
end

-- Export getEffectiveDamageMode for use by ProjectileManager
function CombatSystem.getEffectiveDamageMode(weaponConfig: any): DamageMode
	return getEffectiveDamageMode(weaponConfig)
end

-- Export isFacingTarget for client-side use (target HUD indicator)
function CombatSystem.isFacingTarget(
	attackerRoot: BasePart,
	targetRoot: BasePart,
	customAngleDegrees: number?
): boolean
	return isFacingTarget(attackerRoot, targetRoot, customAngleDegrees)
end

-- Export findEntityFromPart for use by AOE systems
function CombatSystem.findEntityFromPart(part: BasePart): Model?
	return findEntityFromPart(part)
end

return CombatSystem