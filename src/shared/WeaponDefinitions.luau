--!strict

-- Weapon Definitions for All Entities
-- Includes both natural weapons (claws, fangs) and player tools

local EntityStats = require(script.Parent:WaitForChild("EntityStats"))

type WeaponStats = EntityStats.WeaponStats

local WeaponDefinitions = {}

-- Natural weapons for wildlife and enemies
WeaponDefinitions.naturalWeapons = {
	-- Wolf natural weapon
	WolfClaws = {
		name = "Wolf Claws",
		baseDamage = 15,
		damageType = "Physical",
		attackRange = 4,
		cooldown = 1.2,
		strengthScaling = 0.8,
		agilityScaling = 0.6,
		iqScaling = 0.0,
		critMultiplier = 1.5,
		accuracy = 0.85,
	} :: WeaponStats,

	-- Bear natural weapon
	BearClaws = {
		name = "Bear Claws",
		baseDamage = 25,
		damageType = "Physical",
		attackRange = 5,
		cooldown = 2.0,
		strengthScaling = 1.2,
		agilityScaling = 0.2,
		iqScaling = 0.0,
		critMultiplier = 1.8,
		accuracy = 0.75,
	} :: WeaponStats,

	-- Zombie natural weapon
	ZombieBite = {
		name = "Zombie Bite",
		baseDamage = 12,
		damageType = "Physical",
		attackRange = 3,
		cooldown = 1.5,
		strengthScaling = 0.7,
		agilityScaling = 0.3,
		iqScaling = 0.0,
		critMultiplier = 1.3,
		accuracy = 0.70,
	} :: WeaponStats,

	-- Player default weapon (unarmed)
	Fists = {
		name = "Fists",
		baseDamage = 8,
		damageType = "Physical",
		attackRange = 2,
		cooldown = 1.0,
		strengthScaling = 0.5,
		agilityScaling = 0.3,
		iqScaling = 0.0,
		critMultiplier = 1.2,
		accuracy = 0.90,
	} :: WeaponStats,
}

-- Player tools as weapons
WeaponDefinitions.playerTools = {
	-- Axe - High strength scaling, good for chopping and combat
	Axe = {
		name = "Axe",
		baseDamage = 20,
		damageType = "Physical",
		attackRange = 3,
		cooldown = 1.8,
		strengthScaling = 1.0,
		agilityScaling = 0.2,
		iqScaling = 0.0,
		critMultiplier = 1.6,
		accuracy = 0.80,
		requirements = {
			strength = 5,
		},
	} :: WeaponStats,

	-- Pickaxe - Moderate damage, good for mining and combat
	Pickaxe = {
		name = "Pickaxe",
		baseDamage = 18,
		damageType = "Physical",
		attackRange = 3,
		cooldown = 1.6,
		strengthScaling = 0.8,
		agilityScaling = 0.4,
		iqScaling = 0.0,
		critMultiplier = 1.4,
		accuracy = 0.82,
		requirements = {
			strength = 3,
		},
	} :: WeaponStats,

	-- Future weapons can be added here
	-- Bow = { ... },
	-- Sword = { ... },
	-- Staff = { ... },
}

-- Get weapon stats by name (checks both natural and tool weapons)
function WeaponDefinitions.getWeapon(weaponName: string): WeaponStats?
	-- Check natural weapons first
	local naturalWeapon = WeaponDefinitions.naturalWeapons[weaponName]
	if naturalWeapon then
		return naturalWeapon
	end

	-- Check player tools
	local toolWeapon = WeaponDefinitions.playerTools[weaponName]
	if toolWeapon then
		return toolWeapon
	end

	return nil
end

-- Get default weapon for an entity type
function WeaponDefinitions.getDefaultWeapon(entityType: string): WeaponStats?
	if entityType == "Wolf" then
		return WeaponDefinitions.naturalWeapons.WolfClaws
	elseif entityType == "Bear" then
		return WeaponDefinitions.naturalWeapons.BearClaws
	elseif entityType == "Zombie" then
		return WeaponDefinitions.naturalWeapons.ZombieBite
	elseif entityType == "Player" then
		return WeaponDefinitions.naturalWeapons.Fists
	end

	return nil
end

-- Get all available weapons for an entity type
function WeaponDefinitions.getAvailableWeapons(entityType: string): {WeaponStats}
	local weapons = {}

	if entityType == "Player" then
		-- Players can use fists and all tools they qualify for
		table.insert(weapons, WeaponDefinitions.naturalWeapons.Fists)

		for _, weapon in pairs(WeaponDefinitions.playerTools) do
			table.insert(weapons, weapon)
		end
	else
		-- Non-player entities only use their natural weapon
		local defaultWeapon = WeaponDefinitions.getDefaultWeapon(entityType)
		if defaultWeapon then
			table.insert(weapons, defaultWeapon)
		end
	end

	return weapons
end

-- Check if an entity can use a specific weapon
function WeaponDefinitions.canUseWeapon(entityType: string, weaponName: string, entityStats: EntityStats.EntityStats?, entityLevel: number?): boolean
	local weapon = WeaponDefinitions.getWeapon(weaponName)
	if not weapon then
		return false
	end

	-- Non-player entities can only use their default weapon
	if entityType ~= "Player" then
		local defaultWeapon = WeaponDefinitions.getDefaultWeapon(entityType)
		return defaultWeapon and defaultWeapon.name == weaponName
	end

	-- Players can use any weapon they meet requirements for
	if entityStats and not EntityStats.meetsRequirements(entityStats, weapon, entityLevel) then
		return false
	end

	return true
end

-- Get weapon categories for UI organization
function WeaponDefinitions.getWeaponCategories(): {[string]: {string}}
	return {
		Natural = {"WolfClaws", "BearClaws", "ZombieBite", "Fists"},
		Tools = {"Axe", "Pickaxe"},
		-- Future categories: Ranged = {"Bow"}, Magic = {"Staff"}, etc.
	}
end

-- Get weapon scaling information for UI tooltips
function WeaponDefinitions.getWeaponTooltip(weaponName: string): string?
	local weapon = WeaponDefinitions.getWeapon(weaponName)
	if not weapon then
		return nil
	end

	local tooltip = `{weapon.name}\n`
	tooltip = tooltip .. `Damage: {weapon.baseDamage} ({weapon.damageType})\n`
	tooltip = tooltip .. `Range: {weapon.attackRange} studs\n`
	tooltip = tooltip .. `Speed: {math.floor(10 / weapon.cooldown) / 10} attacks/sec\n`
	tooltip = tooltip .. `Accuracy: {weapon.accuracy * 100}%\n`
	tooltip = tooltip .. `Crit Multiplier: {weapon.critMultiplier}x\n`

	if weapon.strengthScaling > 0 then
		tooltip = tooltip .. `Strength Scaling: {weapon.strengthScaling * 100}%\n`
	end
	if weapon.agilityScaling > 0 then
		tooltip = tooltip .. `Agility Scaling: {weapon.agilityScaling * 100}%\n`
	end
	if weapon.iqScaling > 0 then
		tooltip = tooltip .. `IQ Scaling: {weapon.iqScaling * 100}%\n`
	end

	if weapon.requirements then
		tooltip = tooltip .. `Requirements:\n`
		for stat, value in pairs(weapon.requirements) do
			tooltip = tooltip .. `  {stat}: {value}\n`
		end
	end

	return tooltip
end

return WeaponDefinitions