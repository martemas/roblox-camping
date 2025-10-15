--!strict

local WeaponsConfig = {
	-- Weapon System - defines all weapons for players and entities
	weapons = {
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
		-- PROJECTILE WEAPONS (Phase 2)
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
			damageTargetOnly = nil, -- Use combat.damageTargetOnly
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
			damageTargetOnly = false, -- Can hit entities along path
			penetratesEntities = false, -- Stops at first hit
			projectileConfig = {
				modelPath = "Web1",
				trailEnabled = true,
				trailColor = Color3.fromRGB(200, 200, 200),
				impactEffect = "WebSplat",
			},
		},

		-- ========================================
		-- HITSCAN WEAPONS (Phase 2)
		-- ========================================
		Crossbow = {
			type = "hitscan",
			name = "Crossbow",
			range = 100,
			damage = 40,
			visualEffect = "beam", -- Show beam visual
			requiresLineOfSight = true, -- Cannot shoot through walls
			castDuration = 0.3,
			cooldown = 2.0,
			-- spread = 2, -- TODO: Future accuracy variance
		},

		DirectHeal = {
			type = "hitscan",
			name = "Direct Heal",
			range = 50,
			damage = -30, -- Negative = healing
			visualEffect = "none", -- Silent/instant
			targetFilter = "allies",
			requiresTarget = true, -- Always requires target selection (even in free-aim mode)
			requiresLineOfSight = false, -- Can heal through walls (support spell)
			requireFacingForDamage = false, -- Don't need to face ally to heal
			castDuration = 0.2,
			cooldown = 3.0,
		},

		MagicMissile = {
			type = "hitscan",
			name = "Magic Missile",
			range = 80,
			damage = 25,
			visualEffect = "beam",
			requiresLineOfSight = true, -- Cannot shoot through walls
			castDuration = 0.4,
			cooldown = 1.0,
		},

		-- Hitscan with AOE on impact
		ExplosiveBolt = {
			type = "hitscan",
			name = "Explosive Bolt",
			range = 80,
			damage = 20, -- Direct hit damage
			visualEffect = "beam",
			requiresLineOfSight = true,

			aoeOnImpact = true,
			aoeDamage = 40, -- Explosion damage
			aoeRadius = 10,
			aoeFalloff = true,
			maxTargets = 5,

			castDuration = 0.4,
			cooldown = 4.0,
		},

		-- ========================================
		-- AOE WEAPONS (Phase 2)
		-- ========================================

		-- Instant self-centered AOE
		GroundSlam = {
			type = "aoe",
			name = "Ground Slam",
			range = 0, -- Self-centered
			aoeDamage = 35,
			aoeRadius = 20,
			aoeFalloff = true,
			maxTargets = 15,
			castDuration = 0.7,
			cooldown = 8.0,
		},

		-- Projectile AOE (explodes on impact)
		Fireball = {
			type = "projectile", -- Projectile that explodes on impact
			name = "Fireball",
			projectileSpeed = 40,
			damage = 30, -- Touch damage during flight
			aoeDamage = 50, -- Explosion damage
			range = 60,
			aoeRadius = 15,
			aoeFalloff = true,
			maxTargets = 10,
			aoeOnImpact = true, -- Trigger AOE explosion on impact
			damageTargetOnly = false, -- Can hit terrain/structures (important for AOE!)
			castDuration = 0.1,
			cooldown = 5.0,

			projectileConfig = {
				modelPath = "Fireball",
				trailEnabled = true,
				trailColor = Color3.fromRGB(255, 100, 0),
				impactEffect = "Explosion",
			},
		},

		-- Persistent healing zone
		HealingCircle = {
			type = "aoe",
			name = "Healing Circle",
			range = 40,
			aoeDamage = -20, -- Heal per tick
			aoeRadius = 12,
			aoeFalloff = false,
			maxTargets = 5,
			castDuration = 2.0,
			cooldown = 15.0,

			duration = 5.0, -- Lasts 5 seconds
			tickRate = 1.0, -- Heal every second (5 ticks)
			targetFilter = "allies",
		},

		-- Persistent damage zone
		PoisonCloud = {
			type = "aoe",
			name = "Poison Cloud",
			range = 40,
			aoeDamage = 10, -- Damage per tick
			aoeRadius = 12,
			aoeFalloff = false,
			maxTargets = 999,
			castDuration = 2.0,
			cooldown = 15.0,

			duration = 8.0,
			tickRate = 1.0,
			targetFilter = "enemies",
		},
	},
}

return WeaponsConfig
