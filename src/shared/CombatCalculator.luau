--!strict

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))
local Types = require(script.Parent:WaitForChild("Types"))

type PlayerStats = Types.PlayerStats
type CombatResult = Types.CombatResult

local CombatCalculator = {}

-- Calculate if an attack hits based on attacker accuracy vs target evasion
local function calculateHitChance(attackerStats: PlayerStats, targetStats: PlayerStats?): boolean
	local attackerAccuracy = attackerStats.Accuracy
	local targetEvasion = targetStats and targetStats.Speed or 0 -- Speed affects evasion

	-- Base hit chance from accuracy, reduced by target's speed/evasion
	local hitChance = math.max(5, attackerAccuracy - (targetEvasion * 0.5)) -- Minimum 5% hit chance

	-- Cap hit chance at 95%
	hitChance = math.min(95, hitChance)

	local roll = math.random(1, 100)
	return roll <= hitChance
end

-- Calculate damage based on attacker power and optional weapon modifiers
local function calculateDamage(attackerStats: PlayerStats, weaponDamage: number?, criticalHit: boolean?): number
	local baseDamage = attackerStats.Power
	local weaponBonus = weaponDamage or 0

	-- Total damage = base power + weapon damage
	local totalDamage = baseDamage + weaponBonus

	-- Add some variance (80-120% of base damage)
	local variance = math.random(80, 120) / 100
	totalDamage = totalDamage * variance

	-- Critical hit doubles damage
	if criticalHit then
		totalDamage = totalDamage * 2
	end

	return math.max(1, math.floor(totalDamage)) -- Minimum 1 damage
end

-- Calculate if attack is a critical hit based on attacker speed
local function calculateCriticalHit(attackerStats: PlayerStats): boolean
	local critChance = attackerStats.Speed * 0.5 -- Speed affects crit chance
	critChance = math.min(25, critChance) -- Cap at 25% crit chance

	local roll = math.random(1, 100)
	return roll <= critChance
end

-- Get stats from entity (either player progression or entity config)
local function getEntityStats(entity: Model | Player): PlayerStats?
	if entity:IsA("Player") then
		-- Player stats from progression system (TODO: implement PlayerStatsManager)
		-- For now, use starting stats + level scaling
		return GameConfig.player.startingStats
	else
		-- Entity stats from config
		local entityType = entity:GetAttribute("EntityType")
		if entityType then
			local entityConfig = GameConfig.entities[entityType]
			if entityConfig and entityConfig.stats then
				return entityConfig.stats
			end
		end
	end

	return nil
end

-- Get weapon damage bonus from tool
local function getWeaponDamage(tool: Tool?): number
	if not tool then return 0 end

	local toolConfig = GameConfig.tools[tool.Name]
	return toolConfig and toolConfig.damage or 0
end

-- Main combat calculation function
function CombatCalculator.CalculateCombat(
	attacker: Model | Player,
	target: Model | Player,
	weapon: Tool?
): CombatResult
	local attackerStats = getEntityStats(attacker)
	local targetStats = getEntityStats(target)

	if not attackerStats then
		-- Default stats if none found
		attackerStats = {Power = 5, Accuracy = 50, Health = 5, Speed = 5}
	end

	-- Calculate hit/miss
	local hit = calculateHitChance(attackerStats, targetStats)

	local damage = 0
	local critical = false
	local xpGained = 0

	if hit then
		-- Calculate critical hit
		critical = calculateCriticalHit(attackerStats)

		-- Calculate damage
		local weaponDamage = getWeaponDamage(weapon)
		damage = calculateDamage(attackerStats, weaponDamage, critical)

		-- Calculate XP for players
		if attacker:IsA("Player") and target:IsA("Model") then
			local targetType = target:GetAttribute("EntityCategory")
			if targetType == "wildlife" then
				xpGained = GameConfig.progression.xpRewards.killWildlife
			elseif targetType == "enemy" then
				xpGained = GameConfig.progression.xpRewards.killEnemy
			end
		end
	end

	return {
		hit = hit,
		damage = damage,
		critical = critical,
		xpGained = xpGained,
	}
end

-- Calculate health from Health stat
function CombatCalculator.CalculateMaxHealth(healthStat: number): number
	-- Base health + (Health stat * multiplier)
	return GameConfig.player.maxHealth + (healthStat * 10)
end

-- Calculate attack speed from Speed stat (cooldown reduction)
function CombatCalculator.CalculateAttackSpeed(speedStat: number, baseCooldown: number): number
	-- Each point of speed reduces cooldown by 2%
	local speedBonus = speedStat * 0.02
	local newCooldown = baseCooldown * (1 - speedBonus)
	return math.max(0.1, newCooldown) -- Minimum 0.1 second cooldown
end

-- Utility function to print combat result for debugging
function CombatCalculator.PrintCombatResult(result: CombatResult, attackerName: string, targetName: string)
	if result.hit then
		local critText = result.critical and " (CRITICAL!)" or ""
		print(`{attackerName} hit {targetName} for {result.damage} damage{critText}`)
		if result.xpGained > 0 then
			print(`{attackerName} gained {result.xpGained} XP`)
		end
	else
		print(`{attackerName} missed {targetName}`)
	end
end

return CombatCalculator