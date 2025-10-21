--!strict

-- SERVER-ONLY: Actual structure stats, costs, production
-- Client only sees display data from shared/Data/Entities/Structures.luau

local StructureStats = {}

export type StructureStats = {
	-- Health & Defense
	health: number,
	armor: number?,
	canTakeDamage: boolean?,

	-- Building
	buildCost: { [string]: number }?, -- Item costs (reference Items.Database)
	buildTime: number?, -- Seconds to construct

	-- Production (for production structures)
	production: {
		itemId: string, -- Reference to Items.Database
		quantity: number,
		time: number, -- Seconds per production cycle
	}?,

	-- Storage (for storage structures)
	capacity: number?,

	-- Combat (for defensive structures)
	attackRange: number?,
	attackCooldown: number?,
	damage: number?,
	projectileType: string?,
	projectileSpeed: number?,
	projectileArc: number?,
	targetType: string?, -- "Ground" | "Air" | "Both"
	weaponRef: string?, -- Reference to weapon system

	-- Healing/Repair (for support structures)
	healRate: number?,
	repairRate: number?,

	-- Buffs/Effects (for buff structures)
	effectRadius: number?,
	effectStrength: number?,
	effectDuration: number?,
}

StructureStats.Stats = {
	WoodenWall = {
		health = 100,
		armor = 0,
		canTakeDamage = true,

		buildCost = {
			Wood = 10,
		},
		buildTime = 5,
	},

	BarrackL1 = {
		health = 200,
		armor = 5,
		canTakeDamage = true,

		buildCost = {
			Wood = 50,
			Stone = 20,
		},
		buildTime = 30,

		production = {
			itemId = "Soldier", -- Future: Unit spawning
			quantity = 1,
			time = 60,
		},

		capacity = 10, -- Can train/hold 10 units
	},
}

return StructureStats
