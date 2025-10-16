--!strict

-- SERVER-ONLY: Actual tool stats (NEVER sent to client)
local ToolStats = {}

export type ToolCategory = "Axe" | "Pickaxe"

export type ToolSpec = {
	category: ToolCategory,
	miningSpeed: number, -- Multiplier for resource gathering
	swingCooldown: number,
	weaponRef: string, -- References WeaponStats for combat
}

ToolStats.Stats = {
	BasicAxe = {
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

	BasicPickaxe = {
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
