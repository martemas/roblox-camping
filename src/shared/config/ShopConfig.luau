--!strict

local ShopConfig = {
	-- Shop Settings
	shop = {
		WoodenWall = {
			name = "Wooden Wall",
			description = "A sturdy wooden wall for defense",
			cost = { Wood = 0, Stone = 0, Metal = 0 },
			category = "Building",
			toolType = "WoodenWall", -- Will be the tool name
		},
		BarrackL1 = {
			name = "Barrack Level 1",
			description = "Trains basic melee units",
			cost = { Wood = 0, Stone = 0, Metal = 0 },
			category = "Building",
			toolType = "BarrackL1",
		},
	},
}

return ShopConfig
