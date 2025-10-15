--!strict

--[[
	DamageCalculator - Centralized Damage Calculation System

	Provides server-authoritative damage calculations for all combat interactions.
	Supports body part multipliers, stat-based combat, and extensibility.

	Security: All calculations server-side, client cannot manipulate results.
	All stat formulas are centralized in Stats module for easy balance adjustments.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config"))
local Stats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("combat"):WaitForChild("Stats"))

local DamageCalculator = {}

-- Export types (use centralized Stats type)
export type Stats = Stats.Stats

export type DamageInput = {
	attacker: Model,           -- Attacker's character/NPC model
	target: Model,             -- Target's character/NPC model
	weaponName: string,        -- Weapon identifier (from GameConfig)
	hitPart: BasePart?,        -- Body part hit (optional, used for multipliers)

	-- Stats system
	attackerStats: Stats?,     -- Attacker's combat stats
	targetStats: Stats?,       -- Target's combat stats
}

export type DamageResult = {
	finalDamage: number,       -- Calculated damage to apply
	wasHit: boolean,           -- Did attack land (considers dodge)
	wasCritical: boolean,      -- Was it a critical hit
	wasDodged: boolean,        -- Did target dodge the attack
	hitLocation: string,       -- Body part name: "head", "torso", "limb", "unknown"
	damageMultiplier: number,  -- Total multiplier applied (for feedback)
	baseDamage: number,        -- Original weapon damage (for debugging)
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
	Apply stat modifiers to base damage
	Uses centralized Stats.getDerivedStats() for all calculations

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
	if not attackerStats and not targetStats then
		return baseDamage
	end

	local damage = baseDamage

	-- Apply attacker's physical damage bonus (centralized calculation)
	if attackerStats then
		local derived = Stats.getDerivedStats(attackerStats)
		damage = damage * derived.physicalDamageBonus
	end

	-- Apply target's defense reduction (centralized calculation)
	if targetStats then
		local derived = Stats.getDerivedStats(targetStats)
		local damageReduction = 1.0 - derived.defense
		damage = damage * math.max(damageReduction, 0.1)  -- Min 10% damage gets through
	end

	return damage
end

--[[
	Roll for hit or miss (considers accuracy vs dodge)
	Uses centralized Stats.getDerivedStats() for all calculations

	@param attackerStats - Attacker's combat stats
	@param targetStats - Target's combat stats
	@return wasHit (boolean), wasDodged (boolean)
]]
local function rollHitChance(attackerStats: Stats?, targetStats: Stats?): (boolean, boolean)
	if not attackerStats and not targetStats then
		return true, false  -- Always hit if no stats
	end

	-- Get hit chance from attacker (centralized calculation)
	local hitChance = 0.95  -- Default
	if attackerStats then
		local derived = Stats.getDerivedStats(attackerStats)
		hitChance = derived.hitChance
	end

	-- Subtract target's dodge chance (centralized calculation)
	if targetStats then
		local derived = Stats.getDerivedStats(targetStats)
		hitChance = hitChance - derived.dodgeChance
	end

	-- Clamp between 5% and 99%
	hitChance = math.clamp(hitChance, 0.05, 0.99)

	local wasHit = math.random() <= hitChance
	local wasDodged = not wasHit and targetStats ~= nil  -- Only count as dodge if target has stats

	return wasHit, wasDodged
end

--[[
	Roll for critical hit
	Uses centralized Stats.getDerivedStats() for all calculations

	@param attackerStats - Attacker's combat stats
	@return wasCritical (boolean), critMultiplier (number)
]]
local function rollCriticalHit(attackerStats: Stats?): (boolean, number)
	if not attackerStats then
		return false, 1.0
	end

	-- Get crit chance and multiplier (centralized calculation)
	local derived = Stats.getDerivedStats(attackerStats)
	local wasCritical = math.random() <= derived.criticalChance

	return wasCritical, derived.critMultiplier
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
		wasDodged = false,
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

	-- Roll for hit/miss (considers accuracy vs dodge)
	local wasHit, wasDodged = rollHitChance(input.attackerStats, input.targetStats)
	if not wasHit then
		if DEBUG then
			print(`DamageCalculator: {input.attacker.Name} missed {input.target.Name} (dodged={wasDodged})`)
		end
		return {
			finalDamage = 0,
			wasHit = false,
			wasCritical = false,
			wasDodged = wasDodged,
			hitLocation = hitLocation,
			damageMultiplier = 0,
			baseDamage = baseDamage,
		}
	end

	-- Roll for critical hit (uses centralized crit calculation)
	local wasCritical, critMultiplier = rollCriticalHit(input.attackerStats)

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
		wasDodged = false,  -- Not dodged if we got here
		hitLocation = hitLocation,
		damageMultiplier = totalMultiplier,
		baseDamage = baseDamage,
	}
end

return DamageCalculator
