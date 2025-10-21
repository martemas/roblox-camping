--!strict

-- CLIENT-VISIBLE: Display information only for resource nodes
-- Actual stats, drops, health are in server/Data/Entities/ResourceStats.luau
-- Note: This is for resource NODES (entities), not resource ITEMS (see Items/Resources.luau)

local Resources = {}

export type ResourceDisplayData = {
	displayName: string,
	description: string?,
	icon: string?,
	harvestTool: string?, -- Tool type required (Axe, Pickaxe, etc.)
	sounds: {
		harvest: string?,
		destroyed: string?,
	}?,
}

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
