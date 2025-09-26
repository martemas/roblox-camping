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

	-- Tool Settings
	tools = {
		Axe = {
			damage = 20,
			miningEfficiency = 1.0,
			canMine = {"Wood"},
			swingCooldown = 0.5,
		},
		Pickaxe = {
			damage = 15,
			miningEfficiency = 1.0,
			canMine = {"Stone", "Metal"},
			swingCooldown = 0.5,
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

	-- Shop Settings
	shop = {
		WoodenWall = {
			name = "Wooden Wall",
			description = "A sturdy wooden wall for defense",
			cost = { Wood = 3, Stone = 0, Metal = 0 },
			category = "Building",
			toolType = "WoodenWall", -- Will be the tool name
		},
	},
}

return GameConfig