--!strict

-- Unified Entity Stats System
-- All entities (players, enemies, wildlife) use the same stat framework

-- Core RPG stats that all entities have
export type EntityStats = {
	-- Primary Stats
	strength: number,      -- Increases physical damage and carry capacity
	stamina: number,       -- Increases health and health regeneration
	agility: number,       -- Increases attack speed, movement speed, dodge, and crit chance
	iq: number,           -- Increases magical damage and mana

	-- Derived Stats (calculated from primary stats)
	maxHealth: number,      -- stamina * healthPerStamina + baseHealth
	health: number,         -- Current health
	mana: number,          -- iq * manaPerIQ + baseMana
	attackPower: number,   -- strength contribution to damage
	magicPower: number,    -- iq contribution to damage
	attackSpeed: number,   -- agility contribution to attack frequency
	critChance: number,    -- agility contribution to critical hit chance
	dodgeChance: number,   -- agility contribution to dodge chance
	moveSpeed: number,     -- agility contribution to movement speed

	-- Resistances
	physicalResistance: number,  -- Reduces physical damage taken
	magicalResistance: number,   -- Reduces magical damage taken
}

-- Weapon/Attack method stats (used by both tools and entity natural weapons)
export type WeaponStats = {
	name: string,
	baseDamage: number,
	damageType: "Physical" | "Magical" | "Hybrid",
	attackRange: number,        -- Distance in studs
	cooldown: number,          -- Time between attacks in seconds

	-- Stat scaling factors (how much each stat contributes to damage)
	strengthScaling: number,    -- Multiplier for strength contribution
	agilityScaling: number,     -- Multiplier for agility contribution
	iqScaling: number,         -- Multiplier for iq contribution

	-- Combat properties
	critMultiplier: number,     -- Damage multiplier on critical hit
	accuracy: number,           -- Base hit chance (0.0 to 1.0)

	-- Requirements (for tools only, entities always meet requirements)
	requirements: {
		strength: number?,
		agility: number?,
		iq: number?,
		level: number?,
	}?,
}

-- Configuration constants for stat calculations
local STAT_SCALING = {
	healthPerStamina = 10,         -- Each stamina point = +10 max health
	manaPerIQ = 5,                -- Each iq point = +5 max mana
	powerPerStrength = 2,          -- Each strength point = +2 attack power
	powerPerIQ = 2.5,             -- Each iq point = +2.5 magic power
	speedPerAgility = 0.02,        -- Each agility point = +2% attack speed
	critPerAgility = 0.5,          -- Each agility point = +0.5% crit chance
	dodgePerAgility = 0.3,         -- Each agility point = +0.3% dodge chance
	movePerAgility = 0.3,          -- Each agility point = +0.3 move speed
}

local BASE_STATS = {
	health = 100,
	mana = 50,
	attackSpeed = 1.0,
	critChance = 5.0,
	dodgeChance = 5.0,
	moveSpeed = 16,
	physicalResistance = 0,
	magicalResistance = 0,
}

local EntityStats = {}

-- Calculate derived stats from primary stats
function EntityStats.calculateDerivedStats(primaryStats: {strength: number, stamina: number, agility: number, iq: number}): EntityStats
	local derived: EntityStats = {
		-- Copy primary stats
		strength = primaryStats.strength,
		stamina = primaryStats.stamina,
		agility = primaryStats.agility,
		iq = primaryStats.iq,

		-- Calculate derived stats
		maxHealth = BASE_STATS.health + (primaryStats.stamina * STAT_SCALING.healthPerStamina),
		health = 0, -- Will be set to maxHealth after calculation
		mana = BASE_STATS.mana + (primaryStats.iq * STAT_SCALING.manaPerIQ),
		attackPower = primaryStats.strength * STAT_SCALING.powerPerStrength,
		magicPower = primaryStats.iq * STAT_SCALING.powerPerIQ,
		attackSpeed = BASE_STATS.attackSpeed + (primaryStats.agility * STAT_SCALING.speedPerAgility),
		critChance = BASE_STATS.critChance + (primaryStats.agility * STAT_SCALING.critPerAgility),
		dodgeChance = BASE_STATS.dodgeChance + (primaryStats.agility * STAT_SCALING.dodgePerAgility),
		moveSpeed = BASE_STATS.moveSpeed + (primaryStats.agility * STAT_SCALING.movePerAgility),

		-- Default resistances (can be modified by equipment/buffs)
		physicalResistance = BASE_STATS.physicalResistance,
		magicalResistance = BASE_STATS.magicalResistance,
	}

	-- Set current health to max health for new entities
	derived.health = derived.maxHealth

	return derived
end

-- Calculate total damage from attacker stats and weapon
function EntityStats.calculateDamage(attackerStats: EntityStats, weapon: WeaponStats, isCritical: boolean?): number
	-- Base weapon damage
	local damage = weapon.baseDamage

	-- Add stat scaling bonuses
	local statBonus = (attackerStats.attackPower * weapon.strengthScaling) +
	                  (attackerStats.agility * weapon.agilityScaling) +
	                  (attackerStats.magicPower * weapon.iqScaling)

	damage = damage + statBonus

	-- Apply critical hit multiplier if applicable
	if isCritical then
		damage = damage * weapon.critMultiplier
	end

	return math.max(1, math.floor(damage)) -- Minimum 1 damage
end

-- Calculate damage reduction from target's resistances
function EntityStats.calculateDamageReduction(damage: number, targetStats: EntityStats, damageType: string): number
	local resistance = 0

	if damageType == "Physical" then
		resistance = targetStats.physicalResistance
	elseif damageType == "Magical" then
		resistance = targetStats.magicalResistance
	elseif damageType == "Hybrid" then
		-- Hybrid damage uses average of both resistances
		resistance = (targetStats.physicalResistance + targetStats.magicalResistance) / 2
	end

	-- Damage reduction formula: resistance / (resistance + 100)
	-- This gives diminishing returns (100 resistance = 50% reduction, 200 = 66.7%, etc.)
	local reductionPercent = resistance / (resistance + 100)
	local finalDamage = damage * (1 - reductionPercent)

	return math.max(1, math.floor(finalDamage)) -- Minimum 1 damage
end

-- Check if an attack hits based on attacker agility vs defender dodge chance
function EntityStats.calculateHitChance(attackerStats: EntityStats, defenderStats: EntityStats, weapon: WeaponStats): number
	-- Base accuracy from weapon
	local hitChance = weapon.accuracy

	-- Defender's dodge chance reduces hit chance
	local dodgeReduction = defenderStats.dodgeChance / 100
	hitChance = hitChance - dodgeReduction

	-- Attacker's agility can help overcome dodge
	local agilityBonus = (attackerStats.agility - defenderStats.agility) * 0.005 -- 0.5% per agility difference
	hitChance = hitChance + agilityBonus

	-- Clamp between 5% and 95% to always have some chance of missing/hitting
	return math.max(0.05, math.min(0.95, hitChance))
end

-- Check if an attack is dodged
function EntityStats.calculateDodge(defenderStats: EntityStats): boolean
	local dodgeChance = defenderStats.dodgeChance / 100 -- Convert percentage to decimal
	return math.random() <= dodgeChance
end

-- Check if an attack is a critical hit
function EntityStats.calculateCriticalHit(attackerStats: EntityStats, weapon: WeaponStats): boolean
	local critChance = attackerStats.critChance / 100 -- Convert percentage to decimal
	return math.random() <= critChance
end

-- Apply damage to an entity and return actual damage dealt
function EntityStats.applyDamage(targetStats: EntityStats, damage: number): number
	local actualDamage = math.min(damage, targetStats.health)
	targetStats.health = targetStats.health - actualDamage
	return actualDamage
end

-- Heal an entity (cannot exceed max health)
function EntityStats.applyHealing(targetStats: EntityStats, healing: number): number
	local actualHealing = math.min(healing, targetStats.maxHealth - targetStats.health)
	targetStats.health = targetStats.health + actualHealing
	return actualHealing
end

-- Check if entity is alive
function EntityStats.isAlive(stats: EntityStats): boolean
	return stats.health > 0
end

-- Get health percentage (useful for UI)
function EntityStats.getHealthPercent(stats: EntityStats): number
	if stats.maxHealth <= 0 then return 0 end
	return stats.health / stats.maxHealth
end

-- Validate stat requirements for weapon usage
function EntityStats.meetsRequirements(stats: EntityStats, weapon: WeaponStats, entityLevel: number?): boolean
	if not weapon.requirements then
		return true -- No requirements
	end

	local req = weapon.requirements

	if req.strength and stats.strength < req.strength then return false end
	if req.agility and stats.agility < req.agility then return false end
	if req.iq and stats.iq < req.iq then return false end
	if req.level and entityLevel and entityLevel < req.level then return false end

	return true
end

-- Get stat scaling configuration (useful for UI and balancing)
function EntityStats.getStatScaling(): typeof(STAT_SCALING)
	return STAT_SCALING
end

function EntityStats.getBaseStats(): typeof(BASE_STATS)
	return BASE_STATS
end

return EntityStats