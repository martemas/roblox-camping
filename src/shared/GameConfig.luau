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
		dayDuration = 300, -- 5 minutes
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
		waveInterval = 20, -- Seconds between waves
		difficultyIncrease = 0.2, -- 20% more enemies per night survived
	},

	-- Map Settings
	map = {
		size = 1000, -- 1000x1000 studs
		campRadius = 50, -- Radius around camp center for building
		resourceSpawnRadius = 400, -- Max distance from center for resources
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
	},
}

return GameConfig