--!strict

-- GAME-SPECIFIC: Alpha game consumable display data
-- Type definitions are in shared/engine/Data/ItemDisplayTypes.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDisplayTypes = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("ItemDisplayTypes"))

local Consumables = {}

export type ConsumableDisplayData = ItemDisplayTypes.ConsumableDisplayData

Consumables.Display = {
	SmallMeat = {
		displayName = "Small Meat",
		description = "Restores a small amount of health",
		useSound = "Eating",
	},

	BigMeat = {
		displayName = "Big Meat",
		description = "Restores a large amount of health",
		useSound = "Eating",
	},

	RottenMeat = {
		displayName = "Rotten Meat",
		description = "Spoiled meat, might make you sick",
		useSound = "Eating",
	},
}

return Consumables
