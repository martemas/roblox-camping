--!strict

--[[
	DamageCalculator - Centralized Damage Calculation System

	Provides server-authoritative damage calculations for all combat interactions.
	Supports body part multipliers, future stat-based combat, and extensibility.

	Security: All calculations server-side, client cannot manipulate results.
]]

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

local DamageCalculator = {}

-- Export types
export type DamageInput = {
	attacker: Model,           -- Attacker's character/NPC model
	target: Model,             -- Target's character/NPC model
	weaponName: string,        -- Weapon identifier (from GameConfig)
	hitPart: BasePart?,        -- Body part hit (optional, used for multipliers)

	-- Future: Stats system (Phase 2)
	attackerStats: Stats?,     -- Attacker's combat stats
	targetStats: Stats?,       -- Target's combat stats
}

export type DamageResult = {
	finalDamage: number,       -- Calculated damage to apply
	wasHit: boolean,           -- Did attack land (future: miss system)
	wasCritical: boolean,      -- Was it a critical hit (future)
	hitLocation: string,       -- Body part name: "head", "torso", "limb", "unknown"
	damageMultiplier: number,  -- Total multiplier applied (for feedback)
	baseDamage: number,        -- Original weapon damage (for debugging)
}

-- Future: Stats system (Phase 2)
export type Stats = {
	-- Offensive
	strength: number?,         -- Increases physical damage
	dexterity: number?,        -- Increases hit chance
	intelligence: number?,     -- Increases magical damage (future)

	-- Defensive
	defense: number?,          -- Reduces incoming physical damage
	resistance: number?,       -- Reduces incoming magical damage (future)
	evasion: number?,          -- Increases dodge chance

	-- Special
	critChance: number?,       -- Critical hit chance (0.0 - 1.0)
	critDamage: number?,       -- Critical damage multiplier (e.g., 1.5)
}

-- Debug logging
local DEBUG = false

--[[
	Get body part damage multiplier and location category

	@param hitPart - The body part that was hit (optional)
	@return multiplier (number), location (string)
]]
local function getBodyPartMultiplier(hitPart: BasePart?): (number, string)
	if not hitPart then
		return 1.0, "unknown"
	end

	-- Get multipliers config
	local multipliers = GameConfig.combat.bodyPartMultipliers
	if not multipliers then
		return 1.0, "unknown"
	end

	local partName = hitPart.Name
	local multiplier = multipliers[partName] or multipliers.default or 1.0

	-- Categorize body part
	local location = "unknown"
	if partName == "Head" then
		location = "head"
	elseif partName == "UpperTorso" or partName == "LowerTorso" or partName == "Torso" then
		location = "torso"
	elseif partName:find("Arm") or partName:find("Hand") or partName:find("Leg") or partName:find("Foot") then
		location = "limb"
	end

	return multiplier, location
end

--[[
	Apply stat modifiers to base damage (Future - Phase 2)

	@param baseDamage - Base weapon damage
	@param attackerStats - Attacker's combat stats
	@param targetStats - Target's combat stats
	@return Modified damage
]]
local function applyStatModifiers(
	baseDamage: number,
	attackerStats: Stats?,
	targetStats: Stats?
): number
	-- Phase 1: No stat modifiers yet, return base damage
	if not attackerStats and not targetStats then
		return baseDamage
	end

	-- Phase 2: Apply stat-based modifiers
	local damage = baseDamage

	-- Apply attacker strength bonus
	if attackerStats and attackerStats.strength then
		local strengthBonus = 1.0 + (attackerStats.strength * (GameConfig.combat.strengthDamageBonus or 0.02))
		damage = damage * strengthBonus
	end

	-- Apply defender defense reduction
	if targetStats and targetStats.defense then
		local defenseReduction = 1.0 - (targetStats.defense * (GameConfig.combat.defenseReduction or 0.015))
		defenseReduction = math.max(defenseReduction, 0.1) -- Minimum 10% damage gets through
		damage = damage * defenseReduction
	end

	return damage
end

--[[
	Roll for hit or miss (Future - Phase 2)

	@param attackerStats - Attacker's combat stats
	@param targetStats - Target's combat stats
	@return true if hit, false if miss
]]
local function rollHitChance(attackerStats: Stats?, targetStats: Stats?): boolean
	-- Phase 1: Always hit (no miss chance yet)
	if not attackerStats and not targetStats then
		return true
	end

	-- Phase 2: Calculate hit chance based on stats
	local baseHitChance = GameConfig.combat.baseHitChance or 0.95

	local attackerDex = (attackerStats and attackerStats.dexterity) or 0
	local targetEvasion = (targetStats and targetStats.evasion) or 0

	local hitChance = baseHitChance
		+ (attackerDex * (GameConfig.combat.dexterityHitBonus or 0.01))
		- (targetEvasion * (GameConfig.combat.evasionDodgeBonus or 0.01))

	-- Clamp between 5% and 95%
	hitChance = math.clamp(hitChance, 0.05, 0.95)

	return math.random() <= hitChance
end

--[[
	Roll for critical hit (Future - Phase 2)

	@param attackerStats - Attacker's combat stats
	@return true if critical, false if normal
]]
local function rollCriticalHit(attackerStats: Stats?): boolean
	-- Phase 1: No critical hits yet
	if not attackerStats then
		return false
	end

	-- Phase 2: Calculate crit chance based on stats
	local critChance = GameConfig.combat.criticalHitChance or 0.05

	if attackerStats.critChance then
		critChance = critChance + attackerStats.critChance
	end

	return math.random() <= critChance
end

--[[
	Create a miss result (for validation failures)

	@return DamageResult with 0 damage
]]
local function createMissResult(): DamageResult
	return {
		finalDamage = 0,
		wasHit = false,
		wasCritical = false,
		hitLocation = "unknown",
		damageMultiplier = 0,
		baseDamage = 0,
	}
end

--[[
	Main damage calculation function

	@param input - DamageInput with all parameters
	@return DamageResult with calculated damage
]]
function DamageCalculator.calculateDamage(input: DamageInput): DamageResult
	-- Validate attacker
	if not input.attacker or not input.attacker:IsA("Model") then
		warn("DamageCalculator: Invalid attacker model")
		return createMissResult()
	end

	-- Validate target
	if not input.target or not input.target:IsA("Model") then
		warn("DamageCalculator: Invalid target model")
		return createMissResult()
	end

	-- Validate weapon
	local weaponConfig = GameConfig.weapons[input.weaponName]
	if not weaponConfig then
		warn(`DamageCalculator: Invalid weapon: {input.weaponName}`)
		return createMissResult()
	end

	-- Validate hit part (if provided)
	if input.hitPart and not input.hitPart:IsDescendantOf(input.target) then
		warn("DamageCalculator: Hit part is not part of target, ignoring")
		input.hitPart = nil -- Ignore invalid hit part
	end

	-- Get base damage from weapon
	local baseDamage = weaponConfig.damage or 0

	-- Get body part multiplier
	local bodyMultiplier, hitLocation = getBodyPartMultiplier(input.hitPart)

	-- Roll for hit/miss (Phase 2 - currently always hits)
	local wasHit = rollHitChance(input.attackerStats, input.targetStats)
	if not wasHit then
		if DEBUG then
			print(`DamageCalculator: {input.attacker.Name} missed {input.target.Name}`)
		end
		return {
			finalDamage = 0,
			wasHit = false,
			wasCritical = false,
			hitLocation = hitLocation,
			damageMultiplier = 0,
			baseDamage = baseDamage,
		}
	end

	-- Roll for critical hit (Phase 2 - currently no crits)
	local wasCritical = rollCriticalHit(input.attackerStats)
	local critMultiplier = 1.0
	if wasCritical then
		critMultiplier = GameConfig.combat.criticalDamageMultiplier or 1.5
		if input.attackerStats and input.attackerStats.critDamage then
			critMultiplier = input.attackerStats.critDamage
		end
	end

	-- Calculate damage with all modifiers
	local damage = baseDamage
	damage = damage * bodyMultiplier
	damage = applyStatModifiers(damage, input.attackerStats, input.targetStats)
	damage = damage * critMultiplier

	-- Round to nearest integer
	local finalDamage = math.floor(damage + 0.5)

	-- Calculate total multiplier for feedback
	local totalMultiplier = bodyMultiplier * critMultiplier

	-- Debug logging
	if DEBUG then
		print(`=== DAMAGE CALCULATION ===`)
		print(`Attacker: {input.attacker.Name}`)
		print(`Target: {input.target.Name}`)
		print(`Weapon: {input.weaponName}`)
		print(`Base Damage: {baseDamage}`)
		print(`Hit Location: {hitLocation}`)
		print(`Body Part Multiplier: {bodyMultiplier}`)
		print(`Critical Hit: {wasCritical}`)
		print(`Critical Multiplier: {critMultiplier}`)
		print(`Final Damage: {finalDamage}`)
		print(`=========================`)
	end

	return {
		finalDamage = finalDamage,
		wasHit = true,
		wasCritical = wasCritical,
		hitLocation = hitLocation,
		damageMultiplier = totalMultiplier,
		baseDamage = baseDamage,
	}
end

return DamageCalculator
