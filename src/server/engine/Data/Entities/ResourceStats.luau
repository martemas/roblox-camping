--!strict

-- SERVER-ONLY: Actual resource node stats, health, drops
-- Client only sees display data from shared/Data/Entities/Resources.luau
-- Note: This is for resource NODES (entities), not resource ITEMS

local ResourceStats = {}

export type DropConfig = {
	chance: number,
	min: number,
	max: number,
	chanceModifiers: { [string]: number }?,
	maxChance: number?,
	excludeIf: { string }?,
	requireIf: { string }?,
}

export type ResourceStats = {
	-- Health
	health: number,
	canTakeDamage: boolean?,
	-- spawnMode: string?,
	nodesCount: number?, -- Number of times this resource can be harvested before depletion

	-- Harvesting
	requiredToolCategory: string?, -- Tool category required (e.g., "Axe", "Pickaxe")
	hitsRequired: number?,
	miningDuration: number?, -- Base time to harvest (modified by tool stats)

	-- Drops (reference item IDs from Items.Database)
	drops: { [string]: DropConfig },
}

ResourceStats.Stats = {
	Tree = {
		health = 100,
		canTakeDamage = true,

		requiredToolCategory = "Axe",
		harvestTime = 2.0,
		hitsRequired = 6,

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
