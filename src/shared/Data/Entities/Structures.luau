--!strict

-- CLIENT-VISIBLE: Display information only (names, icons, build UI info)
-- Actual stats, costs, production are in server/Data/Entities/StructureStats.luau

local Structures = {}

export type StructureCategory = "Defensive" | "Production" | "Utility" | "Emplacement"

export type StructureDisplayData = {
	displayName: string,
	description: string?,
	category: StructureCategory,
	icon: string?,
	buildPreviewModel: string?, -- Preview model shown during placement
	sounds: {
		build: string?,
		damaged: string?,
		destroyed: string?,
	}?,
}

Structures.Display = {
	WoodenWall = {
		displayName = "Wooden Wall",
		description = "Basic defensive wall",
		category = "Defensive",
		sounds = {
			build = "Construct",
			damaged = "WoodHit",
			destroyed = "WoodBreak",
		},
	},

	BarrackL1 = {
		displayName = "Barrack Level 1",
		description = "Trains basic melee units",
		category = "Production",
		sounds = {
			build = "Construct",
			damaged = "WoodHit",
			destroyed = "WoodBreak",
		},
	},
}

return Structures
