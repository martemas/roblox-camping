--!strict

-- CLIENT-VISIBLE: Display information only
local Tools = {}

export type ToolCategory = "Axe" | "Pickaxe"

export type ToolDisplayData = {
	displayName: string,
	category: ToolCategory,
	description: string?,
	icon: string?,
}

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
