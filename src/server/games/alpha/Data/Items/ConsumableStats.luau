--!strict

-- GAME-SPECIFIC: Alpha game consumable stats
-- Type definitions are in server/engine/Data/ItemTypes.luau

local ServerScriptService = game:GetService("ServerScriptService")
local ItemTypes = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("ItemTypes"))

local ConsumableStats = {}

export type ConsumableSpec = ItemTypes.ConsumableSpec

ConsumableStats.Stats = {
	SmallMeat = {
		effects = {
			{ type = "heal", value = 25 },
		},
		cooldown = 1.0,
		soundEffect = "Eating",
	},

	BigMeat = {
		effects = {
			{ type = "heal", value = 50 },
		},
		cooldown = 1.0,
		soundEffect = "Eating",
	},

	RottenMeat = {
		effects = {
			{ type = "heal", value = 5 },
			{ type = "debuff", value = -2, duration = 10, stat = "stamina" },
		},
		cooldown = 1.0,
		soundEffect = "Eating",
	},
}

return ConsumableStats
