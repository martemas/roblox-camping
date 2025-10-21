--!strict

-- GAME-SPECIFIC: Alpha game resource display data
-- Type definitions are in shared/engine/Data/EntityDisplayTypes.luau
-- Note: This is for resource NODES (entities), not resource ITEMS (see Items/Resources.luau)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityDisplayTypes = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("EntityDisplayTypes"))

local Resources = {}

export type ResourceDisplayData = EntityDisplayTypes.ResourceDisplayData

Resources.Display = {
	Tree = {
		displayName = "Tree",
		description = "Harvestable wood source",
		harvestTool = "Axe",
		sounds = {
			harvest = "ChopWood",
			destroyed = "TreeFall",
		},
	},

	Rock = {
		displayName = "Rock",
		description = "Harvestable stone source",
		harvestTool = "Pickaxe",
		sounds = {
			harvest = "MineRock",
			destroyed = "RockBreak",
		},
	},

	RockMine = {
		displayName = "Rock Mine",
		description = "Harvestable stone source",
		harvestTool = "Pickaxe",
		sounds = {
			harvest = "MineRock",
			destroyed = "RockBreak",
		},
	},

	MetalVein = {
		displayName = "Metal Vein",
		description = "Rich metal ore deposit",
		harvestTool = "Pickaxe",
		sounds = {
			harvest = "MineOre",
			destroyed = "OreBreak",
		},
	},

	GemNode = {
		displayName = "Gem Node",
		description = "Rare gemstone deposit",
		harvestTool = "Pickaxe",
		sounds = {
			harvest = "MineGem",
			destroyed = "GemBreak",
		},
	},

	GemMine = {
		displayName = "Gem Mine",
		description = "Rare gemstone mine",
		harvestTool = "Pickaxe",
		sounds = {
			harvest = "MineGem",
			destroyed = "GemBreak",
		},
	},
}

return Resources
