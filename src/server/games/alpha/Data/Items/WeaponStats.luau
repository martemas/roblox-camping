--!strict

-- GAME-SPECIFIC: Alpha game weapon stats
-- Type definitions are in server/engine/Data/ItemTypes.luau

local ServerScriptService = game:GetService("ServerScriptService")
local ItemTypes = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("ItemTypes"))

local WeaponStats = {}

export type WeaponSpec = ItemTypes.WeaponSpec

WeaponStats.Stats = {
	-- ========================================
	-- PLAYER WEAPONS (Tools as weapons)
	-- ========================================
	Axe = {
		type = "melee",
		name = "Axe",
		damage = 20,
		range = 8,
		cooldown = 0.5,
		castDuration = 0.4,
	},

	Pickaxe = {
		type = "melee",
		name = "Pickaxe",
		damage = 15,
		range = 10,
		cooldown = 0.5,
		castDuration = 0.3,
	},

	-- ========================================
	-- WILDLIFE WEAPONS
	-- ========================================
	WolfClaw = {
		type = "melee",
		name = "Wolf Claw",
		damage = 8,
		range = 10,
		cooldown = 2,
		castDuration = 0.5,
	},

	BearClaw = {
		type = "melee",
		name = "Bear Claw",
		damage = 25,
		range = 12,
		cooldown = 2,
		castDuration = 0.8,
	},

	-- ========================================
	-- ENEMY WEAPONS
	-- ========================================
	ZombieBite = {
		type = "melee",
		name = "Zombie Bite",
		damage = 15,
		range = 8,
		cooldown = 2,
		castDuration = 0.4,
	},

	-- ========================================
	-- PROJECTILE WEAPONS
	-- ========================================
	Bow = {
		type = "projectile",
		name = "Bow",
		damage = 30,
		range = 100,
		cooldown = 0.25,
		castDuration = 0.25,
		projectileSpeed = 80,
		requiresLineOfSight = true,
		damageTargetOnly = nil,
		penetratesEntities = false,
		projectileConfig = {
			modelPath = "Arrow1",
			trailEnabled = true,
			trailColor = Color3.fromRGB(255, 200, 100),
			impactEffect = "ArrowImpact",
		},
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
		damageTargetOnly = false,
		penetratesEntities = false,
		projectileConfig = {
			modelPath = "Web1",
			trailEnabled = true,
			trailColor = Color3.fromRGB(200, 200, 200),
			impactEffect = "WebSplat",
		},
	},

	-- ========================================
	-- HITSCAN WEAPONS
	-- ========================================
	Crossbow = {
		type = "hitscan",
		name = "Crossbow",
		range = 100,
		damage = 40,
		visualEffect = "beam",
		requiresLineOfSight = true,
		castDuration = 0.3,
		cooldown = 2.0,
	},

	DirectHeal = {
		type = "hitscan",
		name = "Direct Heal",
		range = 50,
		damage = -30,
		visualEffect = "none",
		targetFilter = "allies",
		requiresTarget = true,
		requiresLineOfSight = false,
		requireFacingForDamage = false,
		castDuration = 0.2,
		cooldown = 3.0,
	},

	MagicMissile = {
		type = "hitscan",
		name = "Magic Missile",
		range = 80,
		damage = 25,
		visualEffect = "beam",
		requiresLineOfSight = true,
		castDuration = 0.4,
		cooldown = 1.0,
	},

	ExplosiveBolt = {
		type = "hitscan",
		name = "Explosive Bolt",
		range = 80,
		damage = 20,
		visualEffect = "beam",
		requiresLineOfSight = true,
		aoeOnImpact = true,
		aoeDamage = 40,
		aoeRadius = 10,
		aoeFalloff = true,
		maxTargets = 5,
		castDuration = 0.4,
		cooldown = 4.0,
	},

	-- ========================================
	-- AOE WEAPONS
	-- ========================================
	GroundSlam = {
		type = "aoe",
		name = "Ground Slam",
		range = 0,
		aoeDamage = 35,
		aoeRadius = 20,
		aoeFalloff = true,
		maxTargets = 15,
		castDuration = 0.7,
		cooldown = 8.0,
		damage = 0,
	},

	Fireball = {
		type = "projectile",
		name = "Fireball",
		projectileSpeed = 40,
		damage = 30,
		aoeDamage = 50,
		range = 60,
		aoeRadius = 15,
		aoeFalloff = true,
		maxTargets = 10,
		aoeOnImpact = true,
		damageTargetOnly = false,
		castDuration = 0.1,
		cooldown = 5.0,
		projectileConfig = {
			modelPath = "Fireball",
			trailEnabled = true,
			trailColor = Color3.fromRGB(255, 100, 0),
			impactEffect = "Explosion",
		},
	},

	HealingCircle = {
		type = "aoe",
		name = "Healing Circle",
		range = 40,
		aoeDamage = -20,
		aoeRadius = 12,
		aoeFalloff = false,
		maxTargets = 5,
		castDuration = 2.0,
		cooldown = 15.0,
		duration = 5.0,
		tickRate = 1.0,
		targetFilter = "allies",
		damage = 0,
	},

	PoisonCloud = {
		type = "aoe",
		name = "Poison Cloud",
		range = 40,
		aoeDamage = 10,
		aoeRadius = 12,
		aoeFalloff = false,
		maxTargets = 999,
		castDuration = 2.0,
		cooldown = 15.0,
		duration = 8.0,
		tickRate = 1.0,
		targetFilter = "enemies",
		damage = 0,
	},
}

return WeaponStats
