--!strict

--[[
	Stats - Centralized Stats System

	Provides centralized stat calculations, XP formulas, and derived stat bonuses.
	All combat formulas are here for easy balance adjustments.

	SECURITY: This module is shared but all modifications happen server-side.
	Client can read formulas but cannot manipulate stats.
]]

local GameConfig = require(script.Parent:WaitForChild("config"))

-- Export types
export type Stats = {
	strength: number,
	magic: number,
	stamina: number,
	accuracy: number,
	level: number,
	xp: number,
}

export type DerivedStats = {
	physicalDamageBonus: number,  -- Multiplier (1.0 = no bonus)
	defense: number,               -- Damage reduction (0.0 - 1.0)
	maxHealthBonus: number,        -- Additional HP from stamina
	magicDamageBonus: number,      -- Multiplier (future)
	magicResistance: number,       -- Damage reduction (future)
	hitChance: number,             -- Hit probability (0.05 - 0.99)
	dodgeChance: number,           -- Dodge probability (0.0 - 1.0)
	criticalChance: number,        -- Crit probability (0.0 - 1.0)
	critMultiplier: number,        -- Crit damage multiplier (1.5+)
}

local Stats = {}

--[[
	Calculate level from cumulative XP

	@param xp - Total XP accumulated
	@return Level (1+)
]]
function Stats.calculateLevelFromXP(xp: number): number
	if xp <= 0 then
		return 1
	end

	-- Iterate through levels until we find the right threshold
	local level = 1
	while true do
		local xpForNext = Stats.getXPForNextLevel(level)
		if xp < xpForNext then
			return level
		end
		level = level + 1

		-- Safety cap at level 100
		if level >= 100 then
			return 100
		end
	end
end

--[[
	Get cumulative XP required to reach a level
	Formula: floor(100 * level^1.5 / 100) * 100 (rounded to nearest 100)

	@param level - Target level (1+)
	@return Cumulative XP required
]]
function Stats.getXPForNextLevel(level: number): number
	if level <= 1 then
		return 0
	end

	-- XP formula: 100 * level^1.5, rounded to nearest 100
	local rawXP = 100 * math.pow(level, 1.5)
	return math.floor(rawXP / 100) * 100
end

--[[
	Get XP needed to go from one level to another

	@param fromLevel - Starting level
	@param toLevel - Target level
	@return XP difference
]]
function Stats.getXPNeededForLevel(fromLevel: number, toLevel: number): number
	return Stats.getXPForNextLevel(toLevel) - Stats.getXPForNextLevel(fromLevel)
end

--[[
	Validate stats against config caps

	@param stats - Stats to validate
	@param config - GameConfig.stats (optional, uses global if nil)
	@return true if valid
]]
function Stats.validateStats(stats: Stats, config: any?): boolean
	local statsConfig = config or GameConfig.stats
	if not statsConfig then
		return true
	end

	local maxValue = statsConfig.maxStatValue or 50

	-- Check each stat
	if stats.strength > maxValue then return false end
	if stats.magic > maxValue then return false end
	if stats.stamina > maxValue then return false end
	if stats.accuracy > maxValue then return false end

	return true
end

--[[
	Check if a stat can be allocated (not at cap)

	@param stats - Current stats
	@param statName - Name of stat to check ("strength", "magic", etc.)
	@param config - GameConfig.stats (optional)
	@return true if stat can be increased
]]
function Stats.canAllocateStat(stats: Stats, statName: string, config: any?): boolean
	local statsConfig = config or GameConfig.stats
	if not statsConfig then
		return true
	end

	local maxValue = statsConfig.maxStatValue or 50

	-- Get current value
	local currentValue = stats[statName]
	if type(currentValue) ~= "number" then
		return false  -- Invalid stat name
	end

	return currentValue < maxValue
end

--[[
	Scale entity stats by level (for NPCs)
	Formula: baseStats * (1 + scalingPerLevel * level)

	@param baseStats - Base stats (level 1)
	@param level - Current level
	@return Scaled stats
]]
function Stats.scaleStatsForLevel(baseStats: Stats, level: number): Stats
	local scalingFactor = 1 + ((level - 1) * (GameConfig.stats.entityStatScalingPerLevel or 0.1))

	return {
		strength = math.floor(baseStats.strength * scalingFactor),
		magic = math.floor(baseStats.magic * scalingFactor),
		stamina = math.floor(baseStats.stamina * scalingFactor),
		accuracy = math.floor(baseStats.accuracy * scalingFactor),
		level = level,
		xp = baseStats.xp or 0,
	}
end

--[[
	Calculate derived stats from base stats

	ALL COMBAT FORMULAS ARE HERE - easy to adjust for balance

	@param stats - Base stats
	@return Derived combat stats
]]
function Stats.getDerivedStats(stats: Stats): DerivedStats
	-- Physical Combat
	local physicalDamageBonus = 1.0 + (stats.strength * 0.02)  -- +2% per strength
	local defense = (stats.strength + stats.stamina) * 0.0075  -- Hybrid: -0.75% per combined STR+STA
	defense = math.clamp(defense, 0, 0.9)  -- Cap at 90% reduction

	local maxHealthBonus = stats.stamina * 10  -- +10 HP per stamina

	-- Magical Combat (future)
	local magicDamageBonus = 1.0 + (stats.magic * 0.02)  -- +2% per magic
	local magicResistance = stats.magic * 0.015  -- -1.5% per magic
	magicResistance = math.clamp(magicResistance, 0, 0.9)

	-- Accuracy System
	local hitChance = 0.95 + (stats.accuracy * 0.01)  -- Base 95% + 1% per accuracy
	hitChance = math.clamp(hitChance, 0.05, 0.99)  -- Clamp 5%-99%

	local dodgeChance = stats.accuracy * 0.01  -- +1% dodge per accuracy
	local criticalChance = 0.05 + (stats.accuracy * 0.005)  -- Base 5% + 0.5% per accuracy
	local critMultiplier = 1.5 + (stats.strength * 0.01)  -- Base 1.5x + strength scaling

	return {
		physicalDamageBonus = physicalDamageBonus,
		defense = defense,
		maxHealthBonus = maxHealthBonus,
		magicDamageBonus = magicDamageBonus,
		magicResistance = magicResistance,
		hitChance = hitChance,
		dodgeChance = dodgeChance,
		criticalChance = criticalChance,
		critMultiplier = critMultiplier,
	}
end

--[[
	Calculate XP reward for killing an entity
	Formula: baseXP * (1 + victimLevel * multiplier)

	@param victimType - Entity type ("Wolf", "Bear", etc.)
	@param victimLevel - Level of victim
	@return XP amount (rounded)
]]
function Stats.calculateXPReward(victimType: string, victimLevel: number): number
	local config = GameConfig.stats
	if not config or not config.xpRewards then
		return 10  -- Fallback
	end

	local baseXP = config.xpRewards[victimType] or 10
	local multiplier = config.xpLevelMultiplier or 1.5

	local scaledXP = baseXP * (1 + victimLevel * multiplier)
	return math.floor(scaledXP)
end

return Stats
