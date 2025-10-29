--!strict
-- TILE TYPES AND CONFIGURATION

local TileConfig = {}

-- ═══════════════════════════════════════════════════
-- TILE TYPE ENUM
-- ═══════════════════════════════════════════════════

TileConfig.TileType = {
	DeepWater = 1,
	Water = 2,
	Sand = 3,
	Grass = 4,
	Forest = 5,
	Hill = 6,
	Mountain = 7,
	Snow = 8,
}

-- ═══════════════════════════════════════════════════
-- TILE PROPERTIES
-- ═══════════════════════════════════════════════════

TileConfig.TileProperties = {
	[TileConfig.TileType.DeepWater] = {
		name = "DeepWater",
		baseHeight = -8,
		terrain = Enum.Material.Water,
		color = Color3.fromRGB(0, 50, 100),
		heightVariation = 2,
		decorations = {},
		weight = 0.05, -- 5% of map (rare)
		isWalkable = false,
	},
	[TileConfig.TileType.Water] = {
		name = "Water",
		baseHeight = -4,
		terrain = Enum.Material.Water,
		color = Color3.fromRGB(50, 100, 200),
		heightVariation = 1,
		decorations = { "Lily", "Reed" },
		weight = 0.10,
		isWalkable = false,
	},
	[TileConfig.TileType.Sand] = {
		name = "Sand",
		baseHeight = 0,
		terrain = Enum.Material.Sand,
		color = Color3.fromRGB(220, 200, 150),
		heightVariation = 1,
		decorations = { "Shell", "Driftwood" },
		weight = 0.08,
		isWalkable = true,
	},
	[TileConfig.TileType.Grass] = {
		name = "Grass",
		baseHeight = 0,
		terrain = Enum.Material.Grass,
		color = Color3.fromRGB(100, 200, 100),
		heightVariation = 2,
		decorations = { "Tree", "Bush", "Rock", "Flower" },
		weight = 0.40, -- 40% of map (most common)
		isWalkable = true,
	},
	[TileConfig.TileType.Forest] = {
		name = "Forest",
		baseHeight = 0,
		terrain = Enum.Material.Grass,
		color = Color3.fromRGB(50, 150, 50),
		heightVariation = 2,
		decorations = { "TreeDense", "Bush", "Log" },
		weight = 0.15,
		isWalkable = true,
	},
	[TileConfig.TileType.Hill] = {
		name = "Hill",
		baseHeight = 4,
		terrain = Enum.Material.Ground,
		color = Color3.fromRGB(150, 150, 100),
		heightVariation = 3,
		decorations = { "Rock", "Bush" },
		weight = 0.12,
		isWalkable = true,
	},
	[TileConfig.TileType.Mountain] = {
		name = "Mountain",
		baseHeight = 12,
		terrain = Enum.Material.Rock,
		color = Color3.fromRGB(100, 100, 100),
		heightVariation = 5,
		decorations = { "RockLarge", "Boulder" },
		weight = 0.08,
		isWalkable = false,
	},
	[TileConfig.TileType.Snow] = {
		name = "Snow",
		baseHeight = 16,
		terrain = Enum.Material.Snow,
		color = Color3.fromRGB(255, 255, 255),
		heightVariation = 4,
		decorations = { "SnowPine", "IceRock" },
		weight = 0.02, -- 2% (rare, only high elevations)
		isWalkable = true,
	},
}

-- ═══════════════════════════════════════════════════
-- ADJACENCY RULES (Which tiles can be next to each other)
-- ═══════════════════════════════════════════════════

TileConfig.AdjacencyRules = {
	[TileConfig.TileType.DeepWater] = {
		TileConfig.TileType.DeepWater,
		TileConfig.TileType.Water,
	},
	[TileConfig.TileType.Water] = {
		TileConfig.TileType.DeepWater,
		TileConfig.TileType.Water,
		TileConfig.TileType.Sand,
		TileConfig.TileType.Grass,
	},
	[TileConfig.TileType.Sand] = {
		TileConfig.TileType.Water,
		TileConfig.TileType.Sand,
		TileConfig.TileType.Grass,
	},
	[TileConfig.TileType.Grass] = {
		TileConfig.TileType.Sand,
		TileConfig.TileType.Grass,
		TileConfig.TileType.Forest,
		TileConfig.TileType.Hill,
	},
	[TileConfig.TileType.Forest] = {
		TileConfig.TileType.Grass,
		TileConfig.TileType.Forest,
		TileConfig.TileType.Hill,
	},
	[TileConfig.TileType.Hill] = {
		TileConfig.TileType.Grass,
		TileConfig.TileType.Forest,
		TileConfig.TileType.Hill,
		TileConfig.TileType.Mountain,
	},
	[TileConfig.TileType.Mountain] = {
		TileConfig.TileType.Hill,
		TileConfig.TileType.Mountain,
		TileConfig.TileType.Snow,
	},
	[TileConfig.TileType.Snow] = {
		TileConfig.TileType.Mountain,
		TileConfig.TileType.Snow,
	},
}

-- ═══════════════════════════════════════════════════
-- BIOME DEFINITIONS (Used for zone constraints)
-- ═══════════════════════════════════════════════════

TileConfig.Biomes = {
	plains = {
		name = "Plains",
		allowedTiles = {
			TileConfig.TileType.Grass,
			TileConfig.TileType.Forest,
		},
		heightRange = { -2, 4 },
		description = "Flat grasslands suitable for settlements",
	},
	desert = {
		name = "Desert",
		allowedTiles = {
			TileConfig.TileType.Sand,
			TileConfig.TileType.Hill,
		},
		heightRange = { -1, 6 },
		description = "Sandy terrain with occasional hills",
	},
	mountains = {
		name = "Mountains",
		allowedTiles = {
			TileConfig.TileType.Hill,
			TileConfig.TileType.Mountain,
			TileConfig.TileType.Snow,
		},
		heightRange = { 4, 20 },
		description = "High elevation rocky terrain",
	},
	forest = {
		name = "Forest",
		allowedTiles = {
			TileConfig.TileType.Grass,
			TileConfig.TileType.Forest,
		},
		heightRange = { -2, 4 },
		description = "Dense woodland",
	},
	water = {
		name = "Water",
		allowedTiles = {
			TileConfig.TileType.Water,
			TileConfig.TileType.DeepWater,
		},
		heightRange = { -10, -2 },
		description = "Lakes and deep water",
	},
}

-- ═══════════════════════════════════════════════════
-- HEIGHT VALIDATION
-- ═══════════════════════════════════════════════════

function TileConfig.isValidHeightTransition(tile1: number, tile2: number): boolean
	local h1 = TileConfig.TileProperties[tile1].baseHeight
	local h2 = TileConfig.TileProperties[tile2].baseHeight
	local heightDiff = math.abs(h1 - h2)

	-- Max height difference of 8 studs between adjacent tiles (prevents cliffs)
	return heightDiff <= 8
end

return TileConfig
