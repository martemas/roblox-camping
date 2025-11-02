--!strict
-- MAP GENERATION CONFIGURATION (SERVER-ONLY)

local MapConfig = {}

-- ═══════════════════════════════════════════════════
-- GENERATION SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.generation = {
	enabled = true, -- Enable procedural generation
	mapSize = 1024, -- Total map size in studs (512×512)
	tileSize = 32, -- Each tile = 16×16 studs (64×64 grid)
	seed = nil, -- nil = random, or set specific number for deterministic map

	-- Perlin noise settings (used for terrain height generation)
	--[[
To adjust Perlin noise settings for different terrain types, modify these values:
To get more mountains and higher terrain: Try changing these values:
-- MORE CHAOTIC, DRAMATIC TERRAIN (more mountains)
perlinScale = 5,      -- Smaller scale = more variation (default was 10)
perlinOctaves = 5,    -- More octaves = more peaks and valleys (default was 3)
Or for a balanced approach:
perlinScale = 8,      -- Medium scale
perlinOctaves = 4,    -- Good balance
How Perlin works:
perlinScale:
Small (5-8) = chaotic, jagged terrain with lots of peaks
Large (15-20) = smooth, rolling hills
perlinOctaves:
Low (2-3) = smooth, simple terrain
High (4-6) = detailed, complex terrain with more variation
To test, change line 17-18 in MapConfig to:
perlinScale = 5,
perlinOctaves = 5,
--]]
	perlinScale = 10, -- Perlin noise scale/frequency (smaller = more detail, larger = smoother)
	perlinOctaves = 5, -- Number of noise octaves (more = more detail)

	-- Height generation settings
	baseHeight = 4, -- Base elevation (offset for all heights)
	heightScale = 30, -- Height multiplier (controls elevation range, bigger = taller mountains)

	-- Perlin noise distribution
	useExponentialPerlin = true, -- Use exponential distribution for more terrain variation (true = dramatic terrain with extreme peaks/valleys, false = natural smooth terrain)

	-- Exponential Perlin settings (only used if useExponentialPerlin = true)
	-- Applies amplitude modulation to dot products based on scalar hash h'(p)
	-- This creates more extreme variations in noise (steeper peaks, deeper valleys)
	--[[
	EXPONENTIAL MODE EXAMPLES:

	1. NATURAL/SMOOTH TERRAIN (useExponentialPerlin = false)
	   - Standard Perlin noise without exponential modification
	   - Smooth, rolling hills with gentle transitions
	   - Use this for natural-looking worlds

	2. IDEAL EXPONENTIAL (useExponentialPerlin = true)
	   exponentialMode = "linear"
	   exponentialAmplitude = 0.5
	   - Subtle dramatic effect (1x to 1.5x amplification)
	   - More noticeable variation without excessive extremes
	   - Good balance between dramatic and stable terrain

	3. DRAMATIC EXPONENTIAL (useExponentialPerlin = true)
	   exponentialMode = "exp"
	   exponentialAmplitude = 2.0
	   - Strong dramatic effect (1x to e^2 ≈ 7.4x amplification)
	   - Very jagged terrain with extreme peaks and valleys
	   - Can create challenging/interesting landscapes
	   - Note: e^(scalarHash * amplitude) where scalarHash ∈ [0,1]
	   - Actual range: [e^0, e^amplitude] = [1.0, e^amplitude]
	   - For amplitude=1.0: range is [1.0, 2.718] (2.7x max)
	   - For amplitude=2.0: range is [1.0, 7.39] (7.4x max)
	   - For amplitude=3.0: range is [1.0, 20.09] (20x max)

	4. QUADRATIC EXPONENTIAL (useExponentialPerlin = true)
	   exponentialMode = "quadratic"
	   exponentialAmplitude = 2.0
	   - Moderate dramatic effect (1x to 5x amplification)
	   - Range: [1.0, 1 + amplitude] = [1.0, 3.0] for amplitude=2.0
	   - Smoother than "exp" mode, good middle ground
	--]]
	exponentialMode = "exp", -- "exp" (e^x, most dramatic), "quadratic" (x^2), "linear" (1+x, subtle)
	exponentialAmplitude = 1.0, -- Multiplier for exponential effect (higher = more extreme variation)
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
	-- Perlin heights are used as-is without quantization (raw natural variation)
	heightOffset = 0, -- Global Y offset for entire map (positive = higher, negative = lower)
	useRobloxMaterials = true, -- true = use Grass/Sand/Rock materials, false = SmoothPlastic only

	-- Altitude-based biome system (realistic elevation zones)
	-- Converts tile types based on height/elevation bands for natural biome distribution
	useAltitudeBiomes = true, -- Enable altitude-based tile type conversion
	altitudeBands = {
		-- Tiles are converted based on their height (altitude)
		-- Lower altitudes listed first, checked in order
		-- Note: Water is handled by water plate, not altitude bands
		{ maxHeight = -5, tileType = 3 }, -- Sand (lowest elevation, beaches)
		{ maxHeight = 0, tileType = 4 }, -- Grass (lowlands)
		{ maxHeight = 20, tileType = 5 }, -- Forest (mid elevation)
		{ maxHeight = 32, tileType = 6 }, -- Hill (barren/rocky)
		{ maxHeight = 64, tileType = 7 }, -- Mountain (high peaks)
		{ maxHeight = math.huge, tileType = 8 }, -- Snow (very high)
	},

	-- Water plate settings (flat water surface overlay)
	-- Water plate is positioned at the specified height (independent of terrain blocks)
	water = {
		enabled = false,
		height = -0.2, -- Absolute Y position of water surface (0 = ground level, negative = below ground, positive = above ground)
		material = Enum.Material.Water,
		transparency = 0.3,
	},

	-- Block rendering settings
	-- Blocks are calculated dynamically: each block height = tileHeight - minHeight
	-- All blocks are positioned with bottom at Y=minHeight, extending upward to their tile height
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
