--!strict

local GameConfig = {
	-- Player Settings
	player = {
		-- Base stats for new players
		stats = {
			strength = 10,
			stamina = 15,
			agility = 12,
			iq = 8,
		},
		inventorySize = 5,
		startingTools = {"Axe", "Pickaxe"},
		healthRegenRate = 5, -- Percentage per interval
		healthRegenInterval = 5, -- Seconds
		respawnTimeout = 10, -- Seconds
		defaultWeapon = "Fists", -- When no tool equipped

		-- Movement settings (these will be overridden by agility stat)
		baseWalkSpeed = 16,
		sprintMultiplier = 1.5,
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
		dayDuration = 60, -- 5 minutes
		nightDuration = 180, -- 3 minutes
		transitionTime = 5, -- Seconds for dawn/dusk transition
	},

	-- Wildlife Settings
	wildlife = {
		Wolf = {
			-- Entity stats (determines health, damage, speed, etc.)
			stats = {
				strength = 2,  -- Moderate physical power
				stamina = 3,   -- Lower health pool
				agility = 5,   -- Fast and agile
				iq = 3,        -- Low intelligence
			},
			maxCount = 5,
			defaultWeapon = "WolfClaws",
			aggroRange = 30,
			wanderRange = 10,
			jumpCooldown = 3,
			respawnTime = 60,
			canJump = true,
			drops = {"Food", "Hide", "Bones"},
			targetPriority = "players", -- "players", "structures", "both"
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
		},
		Bear = {
			-- Entity stats (determines health, damage, speed, etc.)
			stats = {
				strength = 5,  -- High physical power
				stamina = 5,   -- Very high health
				agility = 2,    -- Slow but powerful
				iq = 5,        -- Low intelligence
			},
			maxCount = 3,
			defaultWeapon = "BearClaws",
			aggroRange = 25,
			wanderRange = 35,
			jumpCooldown = 4,
			respawnTime = 90,
			canJump = false,
			drops = {"Meat", "Hide", "Bones"},
			targetPriority = "players",
			animations = {
				walk = "rbxassetid://97593039109435", -- You can change these per entity
				attack = "rbxassetid://97384715486637",
			},
		},
	},

	-- Enemy Settings
	enemies = {
		Zombie = {
			-- Entity stats (determines health, damage, speed, etc.)
			stats = {
				strength = 12,  -- Moderate physical power
				stamina = 10,   -- Low health
				agility = 6,    -- Slow and shambling
				iq = 1,        -- Very low intelligence
			},
			defaultWeapon = "ZombieBite",
			aggroRange = 25,
			wanderRange = 5,
			jumpCooldown = 4,
			spawnWeight = 1,
			canJump = false,
			targetPriority = "both", -- Attack both players and structures
			animations = {
				walk = "rbxassetid://125448487250472", -- Change these to zombie-specific animations
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
			-- Future: Different attack types for weapons/abilities
			-- attackTypes = {
			--     bite = { damage = 15, cooldown = 2, animation = "bite" },
			--     claw = { damage = 12, cooldown = 1.5, animation = "claw" },
			-- }
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