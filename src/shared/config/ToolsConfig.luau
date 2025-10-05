--!strict

local ToolsConfig = {
	-- Tool Categories (for mining and combat)
	toolCategories = {
		Pickaxe = {"Pickaxe"},
		Axe = {"Axe"},
	},

	-- Tool Settings (for mining and resource gathering)
	tools = {
		-- Axes
		BasicAxe = {
			category = "Axe",
			miningSpeed = 1.0, -- Base mining speed
			swingCooldown = 0.2,
			weaponRef = "Axe", -- References weapons.Axe for combat
		},
		SteelAxe = {
			category = "Axe",
			miningSpeed = 1.4, -- 40% faster mining
			swingCooldown = 0.2,
			weaponRef = "Axe",
		},

		-- Pickaxes
		BasicPickaxe = {
			category = "Pickaxe",
			miningSpeed = 1.0, -- Base mining speed
			swingCooldown = 0.5,
			weaponRef = "Pickaxe", -- References weapons.Pickaxe for combat
		},
		SilverPickaxe = {
			category = "Pickaxe",
			miningSpeed = 1.3, -- 30% faster mining
			swingCooldown = 0.4,
			weaponRef = "Pickaxe",
		},
		GoldenPickaxe = {
			category = "Pickaxe",
			miningSpeed = 1.5, -- 50% faster mining
			swingCooldown = 0.3,
			weaponRef = "Pickaxe",
		},
	},
}

return ToolsConfig
