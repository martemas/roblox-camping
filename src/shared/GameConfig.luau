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

		-- Starting Stats (accessible terminology)
		startingStats = {
			Power = 5,     -- Affects damage output (was Strength)
			Accuracy = 5,  -- Affects hit chance
			Health = 5,    -- Affects max health and health regen (was Vitality)
			Speed = 5,     -- Affects attack speed and movement (was Dexterity)
		},

		-- Stats per level
		statsPerLevel = 3, -- Stat points gained per level up
		maxStatValue = 50, -- Maximum value for any stat
	},

	-- Experience and Progression
	progression = {
		-- XP rewards for different activities
		xpRewards = {
			killWildlife = 10,
			killEnemy = 15,
			gatherResource = 2,
			craftItem = 5,
			surviveTillDawn = 50,
		},

		-- Level calculation: level = floor(sqrt(experience / 100))
		xpPerLevel = 100, -- Base XP needed for level calculation
		maxLevel = 50,    -- Maximum achievable level
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

	-- Tool Settings
	tools = {
		Axe = {
			damage = 20,
			miningEfficiency = 1.0,
			canMine = {"Wood"},
			swingCooldown = 0.5,
			-- Auto-targeting properties
			rangeType = "melee",
			effectiveRange = 8,
			autoTargetCompatible = true,
		},
		Pickaxe = {
			damage = 15,
			miningEfficiency = 1.0,
			canMine = {"Stone", "Metal"},
			swingCooldown = 0.5,
			-- Auto-targeting properties
			rangeType = "melee",
			effectiveRange = 8,
			autoTargetCompatible = true,
		},
	},

	-- Time Settings
	time = {
		dayDuration = 10, -- 5 minutes
		nightDuration = 180, -- 3 minutes
		transitionTime = 5, -- Seconds for dawn/dusk transition
	},

	-- Wildlife Settings
	wildlife = {
		Wolf = {
			maxCount = 5,
			health = 60,
			damage = 8,
			walkSpeed = 12,
			aggroRange = 15,
			respawnTime = 60,
			drops = {"Food", "Hide", "Bones"},
		},
		Bear = {
			maxCount = 3,
			health = 100,
			damage = 15,
			walkSpeed = 8,
			aggroRange = 20,
			respawnTime = 90,
			drops = {"Meat", "Hide", "Bones"},
		},
	},

	-- Enemy Settings
	enemies = {
		Zombie = {
			health = 50,
			damage = 15,
			walkSpeed = 8,
			attackRange = 6,
			attackCooldown = 2,
			spawnWeight = 1,
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
			-- Combat Stats
			stats = {
				Power = 8,     -- Damage output
				Accuracy = 75, -- Hit chance (out of 100)
				Health = 12,   -- Health multiplier
				Speed = 10,    -- Attack speed
			},
		},
		Bear = {
			category = "wildlife",
			health = 100,
			canTakeDamage = true,
			damageableBy = {"Axe", "Pickaxe"},
			manager = "WildlifeSpawner",
			-- Combat Stats
			stats = {
				Power = 15,    -- Higher damage
				Accuracy = 60, -- Lower accuracy than wolf
				Health = 20,   -- Much more health
				Speed = 6,     -- Slower attacks
			},
		},

		-- Enemies
		Zombie = {
			category = "enemy",
			health = 50,
			canTakeDamage = true,
			damageableBy = {"Axe", "Pickaxe"},
			manager = "EnemySpawner",
			-- Combat Stats
			stats = {
				Power = 10,    -- Moderate damage
				Accuracy = 65, -- Moderate accuracy
				Health = 10,   -- Moderate health
				Speed = 8,     -- Moderate speed
			},
		},

		-- Resources
		WoodNode = {
			category = "resource",
			health = 3, -- hits required
			canTakeDamage = true,
			damageableBy = {"Axe"},
			resourceType = "Wood",
			manager = "ResourceManager",
			-- No combat stats - resources don't fight back
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