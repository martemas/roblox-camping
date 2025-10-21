--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Server-side imports
local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Items = require(script.Parent.Parent.Data.Items)
local CombatFeedback = require(ReplicatedStorage.Engine.VisualFX.CombatFeedback)
local ProjectileLOS = require(script.Parent.ProjectileLOS)
local HitscanEffects = require(ReplicatedStorage.Engine.VisualFX.HitscanEffects)

-- Server-side modules (in same directory)
local DamageCalculator = require(script.Parent.DamageCalculator)
local StatsProvider = require(script.Parent.StatsProvider)

-- Lazy-loaded server modules (avoid circular dependency)
local XPRewardManager

local function getXPRewardManager()
	if not XPRewardManager then
		local success, xpRewardModule = pcall(function()
			return script.Parent.Parent:WaitForChild("XPRewardManager", 5)
		end)

		if success and xpRewardModule then
			XPRewardManager = require(xpRewardModule)
		else
			warn("[CombatSystem] Failed to load XPRewardManager - module not found")
		end
	end
	return XPRewardManager
end

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

-- Get weapon config from Items module
function CombatSystem.getWeaponConfig(weaponId: string): WeaponConfig?
	local item = Items.getItem(weaponId)
	if not item or not item.Stats then
		warn(`Weapon config not found: {weaponId}`)
		return nil
	end
	return item.Stats
end

-- Get entity's weapon (for wildlife/enemies)
function CombatSystem.getEntityWeapon(entityType: string): string?
	local entityConfig = GameConfig.entities[entityType]
	if entityConfig and entityConfig.primaryWeapon then
		return entityConfig.primaryWeapon
	end

	return nil
end

-- Get player's equipped weapon (from tool)
function CombatSystem.getPlayerWeapon(player: Player): string?
	local character = player.Character
	if not character then
		return nil
	end

	-- Check for any equipped tool in character
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local toolName = child.Name
			-- Check Items for weapon reference
			local itemData = Items.getItem(toolName)
			if itemData and itemData.weaponData then
				-- Item has weapon data (e.g., BasicAxe → Axe)
				return itemData.weaponData
			else
				-- Pure weapon (e.g., Bow → Bow)
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
			local entityId = current:GetAttribute("EntityId")
			if entityId then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

-- Check if target is invulnerable to this weapon type
local function checkInvulnerability(targetModel: Model, weaponId: string): boolean
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	-- Check if invulnerability system is enabled
	if not GameConfig.combat.invulnerabilityFrames then
		return false
	end

	-- Check weapon-specific invulnerability
	local invulnAttr = `InvulnerableTo_{weaponId}`
	local isInvulnerable = humanoid:GetAttribute(invulnAttr)
	return isInvulnerable == true
end

-- Set invulnerability for a target to a specific weapon type
local function setInvulnerability(targetModel: Model, weaponId: string, duration: number)
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if not GameConfig.combat.invulnerabilityFrames then
		return
	end

	local invulnAttr = `InvulnerableTo_{weaponId}`
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

		-- Prevent friendly fire between same entity types
		if not entityPlayer and not attackerPlayer then
			local entityType = entity:GetAttribute("EntityType")
			local attackerType = attacker:GetAttribute("EntityType")

			-- Wildlife don't damage Wildlife, Creatures don't damage Creatures, etc.
			if entityType and attackerType and entityType == attackerType then
				return false
			end
		end

		return true
	end

	return true
end

-- Find all entities within range of a position
local function findEntitiesInRange(
	origin: vector,
	range: number,
	excludeModel: Model?,
	attacker: Model?,
	targetFilter: string?
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
			-- Apply target filtering if attacker is provided
			if attacker and targetFilter then
				if not shouldAffectEntity(entity, attacker, targetFilter) then
					continue
				end
			end

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
	weaponId: string,
	attackingPlayer: Player?,
	options: {
		attackerStats: any?,
		targetStats: any?,
		onDamageCallback: ((target: Model, attacker: Model) -> ())?
	}?
): AttackResult
	local opts = options or {}
	local weaponConfig = CombatSystem.getWeaponConfig(weaponId)
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
		-- Use weapon's targetFilter if specified, otherwise default to "enemies"
		local targetFilter = weaponConfig.targetFilter or "enemies"
		targetsToCheck = findEntitiesInRange(attackerPos, weaponConfig.range, attacker, attacker, targetFilter)
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
				CombatFeedback.showDamage(targetModel, nil, weaponId, "dodge", attackingPlayer)
			end
			continue
		end

		-- Check facing requirement
		if not isFacingTarget(attackerRoot, targetRoot, nil) then
			-- Not facing target - blocked
			if targetModel == target then
				CombatFeedback.showDamage(targetModel, nil, weaponId, "blocked", attackingPlayer)
			end
			continue
		end

		-- Use centralized damage system (handles PvP, invuln, calculation, damage, XP, feedback, aggro)
		local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
		if targetHumanoid and targetHumanoid.Health > 0 then
			local result = CombatSystem.applyDamageToEntity(attacker, targetModel, weaponId, {
				attackingPlayer = attackingPlayer,
				hitPart = nil, -- Melee doesn't track specific part yet
				attackerStats = opts.attackerStats,
				targetStats = opts.targetStats,
				onDamageCallback = opts.onDamageCallback,
			})

			if result.success then
				hitAny = true
				if not firstHit then
					firstHit = targetModel
				end
				totalDamage = totalDamage + (result.damage or 0)
			elseif targetModel == target then
				-- Primary target - handle special failure cases for return value
				if result.blockedByInvulnerability then
					return {
						hit = false,
						target = targetModel,
						damage = nil,
						wasInRange = true,
						wasDodged = false,
						blockedByInvulnerability = true
					}
				end
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

-- Perform AOE attack
function CombatSystem.performAOEAttack(
	attacker: Model,
	targetPosition: Vector3,
	weaponId: string,
	attackingPlayer: Player?,
	options: {
		damageOverride: number?,
		radius: number?,
		falloff: boolean?,
		maxTargets: number?,
		attackerStats: any?, -- Stats.Stats? (optional - fetched once for efficiency)
		onDamageCallback: ((target: Model, attacker: Model) -> ())?, -- Optional callback per target
	}?
): {AOEHitInfo}
	-- AOEZoneManager is in same directory (lazy load to avoid circular deps)
	local AOEZoneManager
	local success, aoeModule = pcall(function()
		return script.Parent:WaitForChild("AOEZoneManager", 5)
	end)
	if success and aoeModule then
		AOEZoneManager = require(aoeModule)
	end

	-- StatsProvider already imported at top
	local opts = options or {}

	local weaponConfig = CombatSystem.getWeaponConfig(weaponId)
	if not weaponConfig then
		warn(`performAOEAttack: Weapon {weaponId} not found`)
		return {}
	end

	-- Get effective values (options override config)
	local damage = opts.damageOverride or weaponConfig.aoeDamage or weaponConfig.damage or 10
	local radius = opts.radius or weaponConfig.aoeRadius or 10
	local falloff = if opts.falloff ~= nil then opts.falloff else (weaponConfig.aoeFalloff or false)
	local maxTargets = opts.maxTargets or weaponConfig.maxTargets or 999

	-- Get attacker stats ONCE (efficiency for multi-target)
	local attackerStats = opts.attackerStats or StatsProvider.getStats(attacker)

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
			if checkInvulnerability(entity, weaponId) then
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

				-- Get target stats (per target - necessary since each is different)
				local targetStats = StatsProvider.getStats(entity)

				-- Apply damage via central system
				local result = CombatSystem.applyDamageToEntity(attacker, entity, weaponId, {
					damageOverride = finalDamage,
					hitPosition = targetPosition,
					attackerStats = attackerStats, -- Reused attacker stats
					targetStats = targetStats, -- Per-target stats
					onDamageCallback = opts.onDamageCallback, -- Pass callback through
				})

				if result.success then
					table.insert(hits, {
						entity = entity,
						damage = result.damage or finalDamage,
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
			weaponId,
			attacker,
			attackingPlayer,
			weaponConfig.duration,
			weaponConfig.tickRate
		)
	end

	print(`AOE attack {weaponId} hit {#hits} entities at {targetPosition}`)
	return hits
end

-- Result type for damage application
export type DamageApplicationResult = {
	success: boolean,
	damage: number?,
	failureReason: string?, -- "no_humanoid" | "pvp_blocked" | "invulnerable" | "dodged" | "no_weapon_config"
	wasDodged: boolean,
	wasCritical: boolean,
	blockedByInvulnerability: boolean,
	blockedByPvP: boolean,
}

-- Apply damage to a single entity (low-level API for custom spells)
function CombatSystem.applyDamageToEntity(
	attacker: Model,
	target: Model,
	weaponId: string,
	options: {
		damageOverride: number?,
		hitPosition: Vector3?,
		bypassInvulnerability: boolean?,
		bypassPvP: boolean?,
		attackingPlayer: Player?,
		hitPart: BasePart?,
		attackerStats: any?, -- Stats.Stats? (optional - for damage calculation)
		targetStats: any?, -- Stats.Stats? (optional - for damage calculation)
		onDamageCallback: ((target: Model, attacker: Model) -> ())?, -- Optional callback after damage
	}?
): DamageApplicationResult
	local opts = options or {}

	-- Validate target has Humanoid
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return {
			success = false,
			damage = nil,
			failureReason = "no_humanoid",
			wasDodged = false,
			wasCritical = false,
			blockedByInvulnerability = false,
			blockedByPvP = false,
		}
	end

	-- Check PvP rules (unless bypassed)
	if not opts.bypassPvP and not isPvPAllowed(attacker, target) then
		print(`PvP blocked: {attacker.Name} cannot attack {target.Name}`)
		return {
			success = false,
			damage = nil,
			failureReason = "pvp_blocked",
			wasDodged = false,
			wasCritical = false,
			blockedByInvulnerability = false,
			blockedByPvP = true,
		}
	end

	-- Check invulnerability (unless bypassed)
	if not opts.bypassInvulnerability and checkInvulnerability(target, weaponId) then
		print(`{target.Name} is invulnerable to {weaponId}`)
		return {
			success = false,
			damage = nil,
			failureReason = "invulnerable",
			wasDodged = false,
			wasCritical = false,
			blockedByInvulnerability = true,
			blockedByPvP = false,
		}
	end

	-- Get weapon config
	local weaponConfig = CombatSystem.getWeaponConfig(weaponId)
	if not weaponConfig then
		return {
			success = false,
			damage = nil,
			failureReason = "no_weapon_config",
			wasDodged = false,
			wasCritical = false,
			blockedByInvulnerability = false,
			blockedByPvP = false,
		}
	end

	-- Use provided stats (from caller) for damage calculation
	local attackerStats = opts.attackerStats
	local targetStats = opts.targetStats

	-- Calculate damage via DamageCalculator (with stats)
	local damageResult = DamageCalculator.calculateDamage({
		attacker = attacker,
		target = target,
		weaponId = weaponId,
		hitPart = opts.hitPart or (opts.hitPosition and target:FindFirstChild("HumanoidRootPart") :: BasePart? or nil),
		attackerStats = attackerStats,
		targetStats = targetStats,
	})

	if not damageResult.wasHit then
		-- Show dodge feedback if target dodged
		if damageResult.wasDodged then
			CombatFeedback.showDamage(target, 0, weaponId, "dodge", attacker)
		end
		return {
			success = false,
			damage = nil,
			failureReason = "dodged",
			wasDodged = true,
			wasCritical = false,
			blockedByInvulnerability = false,
			blockedByPvP = false,
		}
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

		-- Track attacker for XP credit
		if finalDamage > 0 then
			local XPRewardModule = getXPRewardManager()
			if XPRewardModule then
				local attackerLevel = 1
				if attackerStats then
					attackerLevel = attackerStats.level or 1
				end
				print(`[CombatSystem] Tracking attacker {attacker.Name} (Level {attackerLevel}) for {target.Name}`)
				XPRewardModule.trackAttacker(target, attacker, attackerLevel)
			else
				warn(`[CombatSystem] XPRewardModule not loaded, cannot track attacker!`)
			end
		end
	end

	-- Set invulnerability (unless bypassed)
	if not opts.bypassInvulnerability then
		setInvulnerability(target, weaponId, GameConfig.combat.invulnerabilityDuration or 0.5)
	end

	-- Determine damage type for feedback
	local damageType: CombatFeedback.DamageType
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	local attackingPlayer = Players:GetPlayerFromCharacter(attacker)

	-- Check for critical hit
	if damageResult.wasCritical then
		damageType = "critical"
	elseif targetPlayer then
		damageType = "incoming"
	else
		if attackingPlayer then
			damageType = "self"
		else
			damageType = "other_player"
		end
	end

	-- Show damage feedback
	CombatFeedback.showDamage(target, math.abs(finalDamage), weaponId, damageType, attacker)

	-- Play hit sound
	CombatFeedback.playHitSound(target, "Hit")

	-- Call damage callback if provided (for aggro, events, etc.)
	if opts.onDamageCallback then
		opts.onDamageCallback(target, attacker)
	end

	return {
		success = true,
		damage = finalDamage,
		failureReason = nil,
		wasDodged = false,
		wasCritical = damageResult.wasCritical or false,
		blockedByInvulnerability = false,
		blockedByPvP = false,
	}
end

-- Perform hitscan attack
function CombatSystem.performHitscan(
	origin: Vector3,
	direction: Vector3,
	weaponId: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?
): AttackResult
	local weaponConfig = CombatSystem.getWeaponConfig(weaponId)
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
					weaponId,
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
				HitscanEffects.showBeam(origin, hitPosition, weaponId, 0.3, weaponConfig.damage and weaponConfig.damage < 0)
				HitscanEffects.showHitEffect(hitPosition, hitNormal, weaponId, weaponConfig.damage and weaponConfig.damage < 0)
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

		-- Validate range to hit entity (check distance from attacker to entity)
		local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
		if attackerRoot then
			local targetRoot = hitEntity:FindFirstChild("HumanoidRootPart") or hitEntity:FindFirstChild("Torso") :: BasePart?
			if targetRoot and targetRoot:IsA("BasePart") then
				local distance = getDistance(attackerRoot.Position, targetRoot.Position)
				if distance > weaponConfig.range then
					-- Hit entity is out of range
					if weaponConfig.visualEffect == "beam" then
						HitscanEffects.showBeam(origin, hitPosition, weaponId, 0.3, weaponConfig.damage and weaponConfig.damage < 0)
					end
					print(`Hitscan {weaponId} hit {hitEntity.Name} but target is out of range ({distance} > {weaponConfig.range})`)
					return {
						hit = false,
						target = hitEntity,
						damage = nil,
						wasInRange = false,
						wasDodged = true,
						blockedByInvulnerability = false
					}
				end
			end
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
					HitscanEffects.showBeam(origin, hitPosition, weaponId, 0.3, weaponConfig.damage and weaponConfig.damage < 0)
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
					HitscanEffects.showBeam(origin, hitPosition, weaponId, 0.3, weaponConfig.damage and weaponConfig.damage < 0)
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
	local result = CombatSystem.applyDamageToEntity(attacker, hitEntity, weaponId, {
		hitPosition = hitPosition,
	})

	-- Show visual effects (even if damage failed due to invuln/PvP)
	if weaponConfig.visualEffect == "beam" then
		-- Beam lingers for 0.3s to show the path
		HitscanEffects.showBeam(origin, hitPosition, weaponId, 0.3, weaponConfig.damage and weaponConfig.damage < 0)
		if result.success then
			HitscanEffects.showHitEffect(hitPosition, hitNormal, weaponId, weaponConfig.damage and weaponConfig.damage < 0)
		end
	end

	if result.success then
		-- AOE on impact (if configured)
		if weaponConfig.aoeOnImpact then
			-- Will be implemented in Phase 2
			warn("Hitscan AOE not yet implemented - Phase 2")
		end

		return {
			hit = true,
			target = hitEntity,
			damage = result.damage,
			wasInRange = true,
			wasDodged = result.wasDodged,
			blockedByInvulnerability = false
		}
	else
		-- Damage was blocked (invulnerability, PvP, or dodged)
		return {
			hit = false,
			target = hitEntity,
			damage = nil,
			wasInRange = true,
			wasDodged = result.wasDodged,
			blockedByInvulnerability = result.blockedByInvulnerability,
		}
	end
end

-- Perform projectile attack (validation only - spawning handled by caller)
function CombatSystem.performProjectileAttack(
	origin: Vector3,
	direction: Vector3,
	weaponId: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?
): boolean
	local weaponConfig = CombatSystem.getWeaponConfig(weaponId)
	if not weaponConfig or weaponConfig.type ~= "projectile" then
		warn(`Weapon {weaponId} is not a projectile weapon`)
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
	print(`Projectile attack validated for {attacker.Name} with {weaponId}`)
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