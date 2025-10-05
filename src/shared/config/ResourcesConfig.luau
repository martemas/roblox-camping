--!strict

local ResourcesConfig = {
	-- Resource Settings
	resources = {
		Wood = {
			spawnMode = "random", -- "random" or "manual"
			nodesCount = 10, -- Only used if spawnMode = "random"
			hitsRequired = 3, -- Total mines before depleted
			respawnTime = 30,
			yieldPerMine = 1, -- Items given per successful mine
			miningDuration = 3.0, -- Base seconds per auto-mine
			requiredToolCategory = "Axe", -- Any tool in Axe category works
		},
		Stone = {
			spawnMode = "random",
			nodesCount = 6,
			hitsRequired = 5,
			respawnTime = 45,
			yieldPerMine = 2,
			miningDuration = 4.0,
			requiredToolCategory = "Pickaxe",
		},
		Metal = {
			spawnMode = "random",
			nodesCount = 3,
			hitsRequired = 8,
			respawnTime = 60,
			yieldPerMine = 1,
			miningDuration = 5.0,
			requiredToolCategory = "Pickaxe",
		},
		RockyHill = {
			spawnMode = "manual", -- Must be placed manually in Studio
			nodesCount = 0, -- Not spawned randomly
			hitsRequired = 20,
			respawnTime = 120,
			yieldPerMine = 3,
			miningDuration = 6.0,
			requiredToolCategory = "Pickaxe",
		},
	},
}

return ResourcesConfig
