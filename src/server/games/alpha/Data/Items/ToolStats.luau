--!strict

-- GAME-SPECIFIC: Alpha game tool stats
-- Type definitions are in server/engine/Data/ItemTypes.luau

local ServerScriptService = game:GetService("ServerScriptService")
local ItemTypes = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("ItemTypes"))

local ToolStats = {}

export type ToolSpec = ItemTypes.ToolSpec

ToolStats.Stats = {
	Axe = {
		category = "Axe",
		miningSpeed = 1.0,
		swingCooldown = 0.2,
		weaponRef = "Axe",
	},

	SteelAxe = {
		category = "Axe",
		miningSpeed = 1.4,
		swingCooldown = 0.2,
		weaponRef = "Axe",
	},

	Pickaxe = {
		category = "Pickaxe",
		miningSpeed = 1.0,
		swingCooldown = 0.5,
		weaponRef = "Pickaxe",
	},

	SilverPickaxe = {
		category = "Pickaxe",
		miningSpeed = 1.3,
		swingCooldown = 0.4,
		weaponRef = "Pickaxe",
	},

	GoldenPickaxe = {
		category = "Pickaxe",
		miningSpeed = 1.5,
		swingCooldown = 0.3,
		weaponRef = "Pickaxe",
	},
}

return ToolStats
