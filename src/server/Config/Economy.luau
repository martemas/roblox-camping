--!strict

-- SERVER-ONLY: Economy configuration (security-critical)
-- Prices and costs must never be exposed to client to prevent exploits

local Economy = {
	-- Shop items with costs
	shop = {
		WoodenWall = {
			name = "Wooden Wall",
			description = "A sturdy wooden wall for defense",
			cost = { Wood = 0, Stone = 0, Metal = 0 },
			category = "Building",
			itemId = "WoodenWall",
		},
		BarrackL1 = {
			name = "Barrack Level 1",
			description = "Trains basic melee units",
			cost = { Wood = 0, Stone = 0, Metal = 0 },
			category = "Building",
			itemId = "BarrackL1",
		},
	},

	-- Item prices (for future shop system with currency)
	itemPrices = {
		Wood = 10,
		Stone = 15,
		Metal = 50,
		Gem = 100,
		BasicAxe = 100,
		SteelAxe = 500,
		BasicPickaxe = 100,
		SilverPickaxe = 300,
		GoldenPickaxe = 600,
		SmallMeat = 20,
		BigMeat = 50,
		Bow = 200,
		MagicMissile = 300,
		Fireball = 400,
	},

	-- Sell values (what players get when selling)
	itemSellValues = {
		Wood = 5,
		Stone = 7,
		Metal = 25,
		Gem = 50,
		SmallMeat = 10,
		BigMeat = 25,
		RottenMeat = 1,
	},

	-- Balance multipliers
	sellValueMultiplier = 0.5, -- Items sell for 50% of buy price
	shopPriceMultiplier = 1.0,
}

return Economy
