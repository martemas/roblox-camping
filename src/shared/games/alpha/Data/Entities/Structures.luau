--!strict

-- GAME-SPECIFIC: Alpha game structure display data
-- Type definitions are in shared/engine/Data/EntityDisplayTypes.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityDisplayTypes = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("EntityDisplayTypes"))

local Structures = {}

export type StructureCategory = EntityDisplayTypes.StructureCategory
export type StructureDisplayData = EntityDisplayTypes.StructureDisplayData

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
