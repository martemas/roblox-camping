--!strict
-- GAME-SPECIFIC MAP CONFIGURATION FOR ALPHA GAME
-- Uses section-based zone positioning (3x3 grid)

local GamesMapConfig = {}

-- ═══════════════════════════════════════════════════
-- ZONE DEFINITIONS (Section-based positioning)
-- ═══════════════════════════════════════════════════
-- Map is divided into 9 sections:
--   NW | N | NE
--   W  | C | E
--   SW | S | SE
--
-- Each zone can specify:
--   allowedSections: Which sections it can spawn in
--   relativeToZone: Parent zone (for dependent zones)
--   relativeDistance: How far from parent (studs)
--   relativeSections: Which directions from parent

GamesMapConfig.zones = {
	-- PHASE PRIMARY ZONES (placed first, no dependencies)

	-- Player starting town zone
	playerTown = {
		enabled = true,
		radius = 40, -- Radius in studs (80×80 area)
		biome = "plains",
		constraints = {
			requireFlat = true, -- Flatten the area
			noWater = true, -- No water allowed
			allowedSections = { "NW", "W", "SW" }, -- Left side of map
		},
		-- Assets to place in this zone (Phase 4b - structure placement)
		structures = {
			{
				name = "Townhall",
				assetPath = "ReplicatedStorage.MapAssets.Structures.Townhall",
				position = "center",
				rotation = 0,
			},
			{
				name = "StartingCamp",
				assetPath = "ReplicatedStorage.MapAssets.Structures.Camp",
				position = { x = 15, z = 0 },
				rotation = 90,
			},
		},
	},

	-- Enemy castle zone
	castle = {
		enabled = true,
		radius = 64, -- Larger area for castle grounds
		biome = "plains",
		constraints = {
			requireFlat = true,
			noWater = true,
			allowedSections = { "NE", "E", "SE" }, -- Right side (opposite of player town)
		},
		structures = {
			{
				name = "EnemyCastle",
				assetPath = "ReplicatedStorage.MapAssets.Structures.Castle",
				position = "center",
				rotation = 0,
			},
		},
	},

	-- PHASE 2: DEPENDENT ZONES (placed relative to primary zones)

	-- Forest zone near player town
	forest = {
		enabled = false, -- Disable for now until structures implemented
		radius = 50,
		biome = "forest",
		constraints = {
			requireFlat = false, -- Allow some variation
			noWater = false,
			relativeToZone = "playerTown", -- Depends on player town
			relativeDistance = 250, -- 250 studs from player town
			relativeSections = { "N", "NE" }, -- North/Northeast of player town
		},
		structures = {},
	},

	-- Resource/mine zone near player town (opposite direction)
	mine = {
		enabled = false,
		radius = 40,
		biome = "mountains",
		constraints = {
			requireFlat = false,
			noWater = true,
			relativeToZone = "playerTown",
			relativeDistance = 300, -- 300 studs from player town
			relativeSections = { "S", "SE" }, -- South/Southeast of player town
		},
		structures = {},
	},

	-- Optional: Desert biome zone (primary zone)
	desert = {
		enabled = false,
		radius = 80,
		biome = "desert",
		constraints = {
			requireFlat = false,
			noWater = true,
			allowedSections = { "Center", "E" }, -- Center/east area
		},
		structures = {},
	},

	-- Optional: Mountain range (primary zone)
	mountains = {
		enabled = false,
		radius = 60,
		biome = "mountains",
		constraints = {
			requireFlat = false,
			noWater = true,
			allowedSections = { "N", "NE", "NW" }, -- Top of map
		},
		structures = {},
	},
}

return GamesMapConfig
