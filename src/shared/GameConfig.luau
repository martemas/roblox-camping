--!strict

-- Combat Mode Enum
export type CombatMode = "ACTION" | "TACTICAL"

local CombatMode = {
	ACTION = "ACTION" :: CombatMode, -- Can attack without target (shoots forward if no target)
	TACTICAL = "TACTICAL" :: CombatMode, -- Must select target to attack
}

local GameConfig = {
	-- Player Settings
	player = {
		maxHealth = 100,
		inventorySize = 5,
		startingTools = {"Axe", "Pickaxe", "Bow", "MagicMissile", "Fireball"},
		healthRegenRate = 5, -- Percentage per interval
		healthRegenInterval = 5, -- Seconds
		respawnTimeout = 10, -- Seconds

		-- Movement settings
		walkSpeed = 16,
		sprintSpeed = 24,
		maxStamina = 100,
		staminaDrainRate = 20, -- Per second while sprinting
		staminaRegenRate = 30, -- Per second while not sprinting
	},

	-- Resource Settings
	resources = {
		Wood = {
			nodesCount = 10,
			hitsRequired = 3,
			respawnTime = 30,
			yieldPerHit = 1,
			requiredTool = "Axe",
		},
		Stone = {
			nodesCount = 6,
			hitsRequired = 5,
			respawnTime = 45,
			yieldPerHit = 1,
			requiredTool = "Pickaxe",
		},
		Metal = {
			nodesCount = 3,
			hitsRequired = 8,
			respawnTime = 60,
			yieldPerHit = 1,
			requiredTool = "Pickaxe",
		},
	},

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
			cooldown = 1.5,
			castDuration = 0.5,
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

	-- Tool Settings (for mining and resource gathering)
	tools = {
		Axe = {
			miningEfficiency = 1.0,
			canMine = {"Wood"},
			swingCooldown = 0.2,
			weaponRef = "Axe", -- References weapons.Axe for combat
		},
		Pickaxe = {
			miningEfficiency = 1.0,
			canMine = {"Stone", "Metal"},
			swingCooldown = 0.5,
			weaponRef = "Pickaxe", -- References weapons.Pickaxe for combat
		}
	},

	-- Combat System Settings
	combat = {
		-- Combat Mode
		combatMode = CombatMode.TACTICAL, -- ACTION = can attack without target, TACTICAL = must select target

		-- Hit Detection Mode
		damageTargetOnly = true, -- false = hit all entities in range, true = only hit targeted entity

		-- Auto-Aim System (applies to projectile AND hitscan)
		autoAim = true, -- true = aim at locked target automatically, false = free-aim (aim direction)
		-- When true: projectiles/hitscans aim at target regardless of look direction (skill-based, combat action)
		-- When false: projectiles/hitscans go in aim direction (precision, FPS-style)

		-- Invulnerability Frames (prevent weapon spam)
		invulnerabilityFrames = false,
		invulnerabilityDuration = 0.5, -- Seconds of immunity per weapon type

		-- Directional Combat
		requireFacingForDamage = true, -- Must be facing target to deal damage
		facingAngleDegrees = 210, -- Total cone angle (180 = full front hemisphere, 120 = narrow cone)
		showFacingIndicator = true, -- Show visual feedback in target HUD

		-- Entity AI Aggro
		chaseRangeMultiplier = 3, -- How many times aggroRange before entity gives up chase

		-- Game Modes
		pvpEnabled = true, -- Enable player vs player damage
		teamBased = false, -- Enable team-based combat (future)
		friendlyFire = false, -- Can teammates damage each other (future)

		-- Body Part Damage Multipliers
		bodyPartMultipliers = {
			-- Head (R15)
			Head = 2.0,

			-- Torso (R15)
			UpperTorso = 1.0,
			LowerTorso = 1.0,

			-- Arms (R15)
			LeftUpperArm = 0.75,
			RightUpperArm = 0.75,
			LeftLowerArm = 0.75,
			RightLowerArm = 0.75,
			LeftHand = 0.75,
			RightHand = 0.75,

			-- Legs (R15)
			LeftUpperLeg = 0.8,
			RightUpperLeg = 0.8,
			LeftLowerLeg = 0.8,
			RightLowerLeg = 0.8,
			LeftFoot = 0.75,
			RightFoot = 0.75,

			-- R6 compatibility
			Torso = 1.0,
			["Left Arm"] = 0.75,
			["Right Arm"] = 0.75,
			["Left Leg"] = 0.8,
			["Right Leg"] = 0.8,

			-- Default for any unlisted parts
			default = 1.0,
		},

		-- Future: Stats-based combat (Phase 2)
		baseHitChance = 0.95,              -- 95% base hit chance
		dexterityHitBonus = 0.01,          -- +1% hit per dexterity point
		evasionDodgeBonus = 0.01,          -- +1% dodge per evasion point

		criticalHitChance = 0.05,          -- 5% base crit chance
		criticalDamageMultiplier = 1.5,    -- 1.5x damage on crit

		strengthDamageBonus = 0.02,        -- +2% damage per strength point
		defenseReduction = 0.015,          -- -1.5% damage taken per defense point
	},

	-- Time Settings
	time = {
		dayDuration = 60, -- 5 minutes
		nightDuration = 180, -- 3 minutes
		transitionTime = 5, -- Seconds for dawn/dusk transition

		-- Lighting Configuration
		dayBrightness = 2, -- Day ambient brightness (0-3)
		nightBrightness = 1.5, -- Night ambient brightness (0-3, higher = less dark)
		dayOutdoorAmbient = Color3.fromRGB(140, 140, 140), -- Day ambient color
		nightOutdoorAmbient = Color3.fromRGB(120, 120, 150), -- Night ambient color (bluish tint, brighter)
		dayColorShiftTop = Color3.fromRGB(0, 0, 0), -- Day color shift top
		dayColorShiftBottom = Color3.fromRGB(0, 0, 0), -- Day color shift bottom
		nightColorShiftTop = Color3.fromRGB(76, 76, 127), -- Night color shift top
		nightColorShiftBottom = Color3.fromRGB(0, 0, 0), -- Night color shift bottom
		dayClockTime = 12, -- Time of day during day (0-24)
		nightClockTime = 0, -- Time of day during night (0-24)
	},

	-- Wildlife Settings
	wildlife = {
		Wolf = {
			maxCount = 5,
			health = 60,
			walkSpeed = 12,
			runSpeed = 22,
			aggroRange = 30,
			wanderRange = 10,
			jumpCooldown = 3,
			respawnTime = 60,
			canJump = true,
			drops = {"Food", "Hide", "Bones"},
			targetPriority = "players", -- "players", "structures", "both"
			primaryWeapon = "WolfClaw", -- References weapons.WolfClaw
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
		},
		Bear = {
			maxCount = 3,
			health = 100,
			walkSpeed = 5,
			runSpeed = 10,
			aggroRange = 25,
			wanderRange = 35,
			jumpCooldown = 4,
			respawnTime = 90,
			canJump = false,
			drops = {"Meat", "Hide", "Bones"},
			targetPriority = "players",
			primaryWeapon = "BearClaw", -- References weapons.BearClaw
			animations = {
				walk = "rbxassetid://97593039109435",
				attack = "rbxassetid://97384715486637",
			},
		},
	},

	-- Enemy Settings
	enemies = {
		Zombie = {
			health = 50,
			walkSpeed = 8,
			runSpeed = 12,
			aggroRange = 25,
			wanderRange = 5,
			jumpCooldown = 4,
			spawnWeight = 1,
			canJump = false,
			targetPriority = "both", -- Attack both players and structures
			primaryWeapon = "ZombieBite", -- References weapons.ZombieBite
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
		},
	},

	-- Night Wave Settings
	nightWaves = {
		baseZombieCount = 5, 
		waveInterval = 60, -- Increased from 20 to 60 seconds between waves
		difficultyIncrease = 0.2, -- Reduced from 0.2 to 0.1 (10% increase per night)
	},

	-- Map Settings
	map = {
		size = 600, -- 1000x1000 studs
		campRadius = 50, -- Radius around camp center for building
		resourceSpawnRadius = 400, -- Max distance from center for resources
	},

	-- Entity System - defines all objects that can be interacted with
	entities = {
		-- Wildlife
		Wolf = {
			category = "wildlife",
			health = 60,
			canTakeDamage = true,
			damageableBy = {"Axe", "Pickaxe"}, -- Tools that can damage it
			manager = "WildlifeSpawner", -- Which manager handles this entity
		},
		Bear = {
			category = "wildlife",
			health = 100,
			canTakeDamage = true,
			damageableBy = {"Axe", "Pickaxe"},
			manager = "WildlifeSpawner",
		},

		-- Enemies
		Zombie = {
			category = "enemy",
			health = 50,
			canTakeDamage = true,
			damageableBy = {"Axe", "Pickaxe"},
			manager = "EnemySpawner",
		},

		-- Resources
		WoodNode = {
			category = "resource",
			health = 3, -- hits required
			canTakeDamage = true,
			damageableBy = {"Axe"},
			resourceType = "Wood",
			manager = "ResourceManager",
		},
		StoneNode = {
			category = "resource",
			health = 5,
			canTakeDamage = true,
			damageableBy = {"Pickaxe"},
			resourceType = "Stone",
			manager = "ResourceManager",
		},
		MetalNode = {
			category = "resource",
			health = 8,
			canTakeDamage = true,
			damageableBy = {"Pickaxe"},
			resourceType = "Metal",
			manager = "ResourceManager",
		},

		-- Buildings (for future expansion)
		WoodenWall = {
			category = "building",
			health = 100,
			canTakeDamage = false, -- Buildings can't be damaged by tools
			damageableBy = {},
			manager = nil,
		},
	},

	-- Targeting System Settings
	targeting = {
		selectionRange = 80, -- Maximum distance to select a target
		autoDeselectRange = 100, -- Auto-deselect if target moves this far
		showOtherPlayersTargets = false, -- Show other players' target highlights
		otherPlayerHighlightOpacity = 0.3, -- Opacity for other players' highlights
		ownTargetColor = Color3.fromRGB(255, 200, 0), -- Yellow for own target
		otherPlayerTargetColor = Color3.fromRGB(100, 150, 255), -- Blue for others
	},

	-- Shop Settings
	shop = {
		WoodenWall = {
			name = "Wooden Wall",
			description = "A sturdy wooden wall for defense",
			cost = { Wood = 0, Stone = 0, Metal = 0 },
			category = "Building",
			toolType = "WoodenWall", -- Will be the tool name
		},
		BarrackL1 = {
			name = "Barrack Level 1",
			description = "Trains basic melee units",
			cost = { Wood = 0, Stone = 0, Metal = 0 },
			category = "Building",
			toolType = "BarrackL1",
		},
	},

	-- Export CombatMode enum
	CombatMode = CombatMode,
}

return GameConfig