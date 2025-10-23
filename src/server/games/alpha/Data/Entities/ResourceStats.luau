--!strict

-- GAME-SPECIFIC: Alpha game resource node stats, health, drops
-- Client only sees display data from shared/Data/Entities/Resources.luau
-- Type definitions are in server/engine/Data/EntityTypes.luau
-- Note: This is for resource NODES (entities), not resource ITEMS

local ServerScriptService = game:GetService("ServerScriptService")
local EntityTypes = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("EntityTypes"))

local ResourceStats = {}

export type ResourceStats = EntityTypes.ResourceStats

ResourceStats.Stats = {
	Tree = {
		health = 100,
		canTakeDamage = true,

		requiredToolCategory = "Axe",
		harvestTime = 2.0,
		hitsRequired = 6,
		respawnTime = 30,

		drops = {
			Wood = {
				chance = 1.0, -- 100% chance
				min = 3,
				max = 5,
				chanceModifiers = {
					luck = 0.01, -- +1% chance per luck point (for bonus drops)
				},
			},
		},
	},

	Rock = {
		health = 150,
		canTakeDamage = true,
		hitsRequired = 8,

		requiredToolCategory = "Pickaxe",
		harvestTime = 3.0,
		respawnTime = 45,

		drops = {
			Stone = {
				chance = 1.0,
				min = 2,
				max = 4,
			},
		},
	},

	RockMine = {
		health = 500,
		canTakeDamage = true,
		hitsRequired = 8,
		nodesCount = 20, -- Can be harvested 3 times before depletion
		requiredToolCategory = "Pickaxe",
		harvestTime = 3.0,
		respawnTime = 60,

		drops = {
			Stone = {
				chance = 1.0,
				min = 2,
				max = 4,
			},
		},
	},

	MetalVein = {
		health = 200,
		canTakeDamage = true,
		hitsRequired = 10,

		requiredToolCategory = "Pickaxe",
		harvestTime = 4.0,
		respawnTime = 60,

		drops = {
			Metal = {
				chance = 1.0,
				min = 1,
				max = 3,
				chanceModifiers = {
					luck = 0.02,
				},
			},
		},
	},

	GemNode = {
		health = 250,
		canTakeDamage = true,
		hitsRequired = 16,

		requiredToolCategory = "Pickaxe",
		harvestTime = 5.0,
		respawnTime = 90,

		drops = {
			Gem = {
				chance = 1.0,
				min = 1,
				max = 2,
				chanceModifiers = {
					luck = 0.05, -- Luck heavily affects gem drops
				},
			},
		},
	},

	GemMine = {
		health = 1000,
		canTakeDamage = true,
		hitsRequired = 16,

		requiredToolCategory = "Pickaxe",
		harvestTime = 5.0,
		nodesCount = 30, -- Can be harvested 10 times before depletion
		respawnTime = 120,

		drops = {
			Gem = {
				chance = 1.0,
				min = 1,
				max = 2,
				chanceModifiers = {
					luck = 0.05, -- Luck heavily affects gem drops
				},
			},
		},
	},
	
}

return ResourceStats
