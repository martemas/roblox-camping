--!strict
-- MAP GENERATION CONFIGURATION (SERVER-ONLY)

local MapConfig = {}

-- ═══════════════════════════════════════════════════
-- GENERATION SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.generation = {
	enabled = true, -- Enable procedural generation
	mapSize = 1024, -- Total map size in studs (512×512)
	tileSize = 16, -- Each tile = 32×32 studs (64×64 grid)
	seed = nil, -- nil = random, or set specific number for deterministic map

	-- Height generation mode
	heightGenerationMode = "perlin", -- "constrained" (smooth) or "perlin" (natural)
	maxHeightDelta = 2, -- Max height difference between adjacent tiles (for constrained mode)
	perlinScale = 10, -- Perlin noise scale/frequency (smaller = more detail, larger = smoother)
	perlinOctaves = 3, -- Number of noise octaves (more = more detail)
}

-- ═══════════════════════════════════════════════════
-- PERSISTENCE SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.persistence = {
	useSavedMaps = true, -- Load from DataStore if available
	saveGeneratedMaps = true, -- Auto-save after generation
	mapName = "AlphaWorld", -- DataStore key
	allowRegeneration = true, -- Can regenerate from seed via admin command
}

-- ═══════════════════════════════════════════════════
-- ZONE DEFINITIONS (Size-only, positions determined at runtime)
-- ═══════════════════════════════════════════════════

MapConfig.zones = {
	-- Player starting town zone
	playerTown = {
		enabled = true,
		radius = 40, -- Radius in studs (80×80 area)
		biome = "plains",
		constraints = {
			requireFlat = true, -- Must be flat terrain
			noWater = true, -- No water tiles allowed
			minDistanceFromEdge = 60, -- Must be at least 60 studs from map edge
		},
		-- Assets to place in this zone
		structures = {
			{
				name = "Townhall",
				assetPath = "ReplicatedStorage.MapAssets.Structures.Townhall",
				position = "center", -- "center" or offset like {x=10, z=5}
				rotation = 0, -- Degrees
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
			minDistanceFromEdge = 80,
			minDistanceFromOtherZones = 150, -- Must be far from player town
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

	-- Optional: Desert biome zone (position randomized)
	desert = {
		enabled = true,
		radius = 80,
		biome = "desert",
		constraints = {
			requireFlat = false, -- Can have hills
			noWater = true,
			minDistanceFromEdge = 40,
			minDistanceFromOtherZones = 60,
		},
		structures = {}, -- No structures, just biome
	},

	-- Optional: Mountain range (edge of map)
	mountains = {
		enabled = true,
		radius = 60,
		biome = "mountains",
		constraints = {
			requireFlat = false,
			noWater = true,
			preferEdge = true, -- Prefers to be near map edge
			minDistanceFromEdge = 0,
		},
		structures = {},
	},
}

-- ═══════════════════════════════════════════════════
-- DECORATION SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.decorations = {
	enabled = true,
	density = 0.15, -- 15% of eligible tiles get decorations
	useVariety = false, -- Use multiple models per decoration type
	scaleVariation = 0.2, -- ±20% size variation
}

-- ═══════════════════════════════════════════════════
-- PERFORMANCE SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.performance = {
	progressiveGeneration = false, -- Generate in chunks with yields (slower but prevents timeout)
	chunkSize = 64, -- Studs per chunk (if progressive)
	useWriteVoxels = true, -- Use bulk WriteVoxels (faster) vs FillBlock
	maxDecorations = 2000, -- Cap total decorations for performance
}

-- ═══════════════════════════════════════════════════
-- RENDERING SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.rendering = {
	mode = "parts", -- "terrain" (smooth Roblox terrain) or "parts" (Minecraft-style blocks)
	style = "blocky", -- "smooth" (height variation) or "blocky" (uniform heights)
	heightQuantization = 1, -- Snap heights to grid (4 = snap to 4-stud increments, 0 = disabled)
	heightOffset = 0, -- Global Y offset for entire map (positive = higher, negative = lower)
	useRobloxMaterials = true, -- true = use Grass/Sand/Rock materials, false = SmoothPlastic only

	-- Altitude-based biome system (realistic elevation zones)
	useAltitudeBiomes = true, -- Enable altitude-based tile type conversion
	altitudeBands = {
		-- Tiles are converted based on their height (altitude)
		-- Lower altitudes listed first, checked in order
		{ maxHeight = -8, tileType = 1 }, -- DeepWater
		{ maxHeight = -2, tileType = 2 }, -- Water
		{ maxHeight = 1, tileType = 3 }, -- Sand (beaches)
		{ maxHeight = 6, tileType = 4 }, -- Grass (lowlands)
		{ maxHeight = 10, tileType = 5 }, -- Forest (mid elevation)
		{ maxHeight = 14, tileType = 6 }, -- Hill (barren/rocky)
		{ maxHeight = 20, tileType = 7 }, -- Mountain (high peaks)
		{ maxHeight = math.huge, tileType = 8 }, -- Snow (very high)
	},
}

-- ═══════════════════════════════════════════════════
-- SPAWN INTEGRATION
-- ═══════════════════════════════════════════════════

MapConfig.spawn = {
	-- Link player spawn to generated town
	spawnAtPlayerTown = true, -- Place player spawn at town center
	spawnRadius = 10, -- Random spawn within radius of town center
}

return MapConfig
