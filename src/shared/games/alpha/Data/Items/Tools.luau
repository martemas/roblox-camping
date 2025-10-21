--!strict

-- GAME-SPECIFIC: Alpha game tool display data
-- Type definitions are in shared/engine/Data/ItemDisplayTypes.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDisplayTypes = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("ItemDisplayTypes"))

local Tools = {}

export type ToolCategory = ItemDisplayTypes.ToolCategory
export type ToolDisplayData = ItemDisplayTypes.ToolDisplayData

Tools.Display = {
	Axe = {
		displayName = "Basic Axe",
		category = "Axe",
		description = "Chops wood efficiently",
	},

	SteelAxe = {
		displayName = "Steel Axe",
		category = "Axe",
		description = "Faster wood chopping",
	},

	Pickaxe = {
		displayName = "Basic Pickaxe",
		category = "Pickaxe",
		description = "Mines stone and ore",
	},

	SilverPickaxe = {
		displayName = "Silver Pickaxe",
		category = "Pickaxe",
		description = "Faster mining",
	},

	GoldenPickaxe = {
		displayName = "Golden Pickaxe",
		category = "Pickaxe",
		description = "The fastest pickaxe",
	},
}

return Tools
