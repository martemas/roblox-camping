--!strict

-- GAME-SPECIFIC: Alpha game structure stats, costs, production
-- Client only sees display data from shared/Data/Entities/Structures.luau
-- Type definitions are in server/engine/Data/EntityTypes.luau

local ServerScriptService = game:GetService("ServerScriptService")
local EntityTypes = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("EntityTypes"))

local StructureStats = {}

export type StructureStats = EntityTypes.StructureStats

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
