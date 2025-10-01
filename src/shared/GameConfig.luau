--!strict

local GameConfig = {
	-- Player Settings
	player = {
		maxHealth = 100,
		inventorySize = 5,
		startingTools = {"Axe", "Pickaxe"},
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
			castDuration = 0.3,
		},

		Pickaxe = {
			type = "melee",
			name = "Pickaxe",
			damage = 15,
			range = 7,
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
	},

	-- Tool Settings (for mining and resource gathering)
	tools = {
		Axe = {
			miningEfficiency = 1.0,
			canMine = {"Wood"},
			swingCooldown = 0.5,
			weaponRef = "Axe", -- References weapons.Axe for combat
		},
		Pickaxe = {
			miningEfficiency = 1.0,
			canMine = {"Stone", "Metal"},
			swingCooldown = 0.5,
			weaponRef = "Pickaxe", -- References weapons.Pickaxe for combat
		},
	},

	-- Combat System Settings
	combat = {
		-- Hit Detection Mode
		damageTargetOnly = true, -- false = hit all entities in range, true = only hit targeted entity

		-- Invulnerability Frames (prevent weapon spam)
		invulnerabilityFrames = false,
		invulnerabilityDuration = 0.5, -- Seconds of immunity per weapon type

		-- Directional Combat
		requireFacingForDamage = true, -- Must be facing target to deal damage
		facingAngleDegrees = 180, -- Total cone angle (180 = full front hemisphere, 120 = narrow cone)
		showFacingIndicator = true, -- Show visual feedback in target HUD

		-- Game Modes
		pvpEnabled = true, -- Enable player vs player damage
		teamBased = false, -- Enable team-based combat (future)
		friendlyFire = false, -- Can teammates damage each other (future)
	},

	-- Time Settings
	time = {
		dayDuration = 60, -- 5 minutes
		nightDuration = 180, -- 3 minutes
		transitionTime = 5, -- Seconds for dawn/dusk transition
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
}

return GameConfig