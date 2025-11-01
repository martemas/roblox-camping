--!strict
-- MAP GENERATOR SERVICE
-- Main orchestrator for procedural map generation

local Types = require(script.Parent.Types)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local TileConfig = require(script.Parent.TileConfig)
local SeededRandom = require(script.Parent.SeededRandom)
local MapData = require(script.Parent.MapData)
local WaveFunctionCollapse = require(script.Parent.WaveFunctionCollapse)
local PerlinGenerator = require(script.Parent.PerlinGenerator)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local PartsBuilder = require(script.Parent.PartsBuilder)
local AltitudeBiomes = require(script.Parent.AltitudeBiomes)

local MapGeneratorService = {}

-- ═══════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════

local currentMapData: Types.MapData? = nil
local initialized = false

-- ═══════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════

function MapGeneratorService.initialize()
	if initialized then
		warn("[MapGeneratorService] Already initialized")
		return
	end

	print("[MapGeneratorService] Initializing...")
	initialized = true
end

-- ═══════════════════════════════════════════════════
-- SIMPLE RANDOM GENERATION (Phase 1)
-- ═══════════════════════════════════════════════════

-- Generate a simple random map without WFC (for Phase 1 testing)
function MapGeneratorService.generateSimpleRandom(seed: number?): Types.MapData
	local config = MapConfig.generation
	local usedSeed = seed or os.time()
	local rng = SeededRandom.new(usedSeed)

	-- Calculate grid dimensions
	local gridWidth = math.floor(config.mapSize / config.tileSize)
	local gridHeight = gridWidth

	print(`[MapGeneratorService] Generating {gridWidth}x{gridHeight} grid (seed: {usedSeed})`)

	-- Create empty grid
	local grid = MapData.createGrid(gridWidth, gridHeight)

	-- Build weighted tile list for random selection
	local weightedTiles = {}
	for tileType, props in TileConfig.TileProperties do
		local weight = math.floor(props.weight * 100) -- Convert to integer
		for i = 1, weight do
			table.insert(weightedTiles, tileType)
		end
	end

	-- Generate random tiles
	for y = 1, gridHeight do
		for x = 1, gridWidth do
			local randomIndex = rng.nextInt(1, #weightedTiles)
			local tileType = weightedTiles[randomIndex]
			local tileProps = TileConfig.TileProperties[tileType]

			-- Apply height with small variation
			local heightVariation = rng.nextFloat() * tileProps.heightVariation - tileProps.heightVariation / 2
			local height = tileProps.baseHeight + heightVariation

			grid.tiles[y][x] = {
				tileType = tileType,
				height = height,
				zoneId = nil,
			}
		end
	end

	-- Calculate map bounds
	local mapOrigin = MapData.calculateMapOrigin(config.mapSize)
	local bounds = MapData.calculateMapBounds(config.mapSize, mapOrigin)

	-- Create map data
	local mapData: Types.MapData = {
		seed = usedSeed,
		mapSize = config.mapSize,
		tileSize = config.tileSize,
		gridWidth = gridWidth,
		gridHeight = gridHeight,
		grid = grid,
		zones = {},
		bounds = bounds,
		origin = mapOrigin,
	}

	currentMapData = mapData
	print(`[MapGeneratorService] ✓ Generation complete`)

	return mapData
end

-- ═══════════════════════════════════════════════════
-- WFC GENERATION (Phase 2)
-- ═══════════════════════════════════════════════════

-- Generate map using selected algorithm (WFC or Perlin)
function MapGeneratorService.generate(seed: number?): Types.MapData?
	local config = MapConfig.generation
	-- Priority: parameter seed > config seed > random seed
	local usedSeed = seed or config.seed or math.floor(tick() * 1000)
	local rng = SeededRandom.new(usedSeed)

	-- Calculate grid dimensions
	local gridWidth = math.floor(config.mapSize / config.tileSize)
	local gridHeight = gridWidth

	-- Determine which generation method to use
	local generationMethod = config.heightGenerationMode
	local grid = nil

	if generationMethod == "perlin_only" then
		-- Use pure Perlin noise generation (no WFC)
		print(`[MapGeneratorService] Generating {gridWidth}x{gridHeight} grid with Perlin (seed: {usedSeed})`)
		grid = PerlinGenerator.generate(gridWidth, gridHeight, rng)

		if not grid then
			warn("[MapGeneratorService] ✗ Perlin generation failed")
			return nil
		end
	else
		-- Use WFC-based generation (with constrained or perlin height modes)
		print(`[MapGeneratorService] Generating {gridWidth}x{gridHeight} grid with WFC (seed: {usedSeed})`)

		-- WFC can fail due to contradictions, so retry with different internal seeds
		local maxRetries = 10
		local attempt = 0

		while not grid and attempt < maxRetries do
			attempt = attempt + 1

			-- Use the base seed plus attempt number for deterministic but different results
			local attemptSeed = usedSeed + attempt - 1
			local attemptRng = SeededRandom.new(attemptSeed)

			if attempt > 1 then
				print(`[MapGeneratorService] Retry attempt {attempt}/{maxRetries} (seed: {attemptSeed})`)
			end

			grid = WaveFunctionCollapse.generate(gridWidth, gridHeight, attemptRng)
		end

		if not grid then
			warn(`[MapGeneratorService] ✗ WFC generation failed after {maxRetries} attempts`)
			return nil
		end

		if attempt > 1 then
			print(`[MapGeneratorService] ✓ WFC succeeded on attempt {attempt}`)
		end
	end

	-- Calculate map bounds
	local mapOrigin = MapData.calculateMapOrigin(config.mapSize)
	local bounds = MapData.calculateMapBounds(config.mapSize, mapOrigin)

	-- Create map data
	local mapData: Types.MapData = {
		seed = usedSeed,
		mapSize = config.mapSize,
		tileSize = config.tileSize,
		gridWidth = gridWidth,
		gridHeight = gridHeight,
		grid = grid,
		zones = {},
		bounds = bounds,
		origin = mapOrigin,
	}

	-- Apply altitude-based biome conversion (if enabled and not using perlin_only)
	-- Perlin_only handles this internally during generation
	if MapConfig.rendering.useAltitudeBiomes and generationMethod ~= "perlin_only" then
		mapData = AltitudeBiomes.applyAltitudeBiomes(mapData)
	end

	currentMapData = mapData
	print(`[MapGeneratorService] ✓ Generation complete`)

	return mapData
end

-- ═══════════════════════════════════════════════════
-- GENERATE AND BUILD WORLD (Phase 3)
-- ═══════════════════════════════════════════════════

-- Generate map and build 3D terrain in one step
function MapGeneratorService.generateAndBuildWorld(seed: number?): Types.MapData?
	-- Generate 2D map
	local mapData = MapGeneratorService.generate(seed)

	if not mapData then
		warn("[MapGeneratorService] ✗ Failed to generate map")
		return nil
	end

	-- Build 3D world using configured rendering mode
	local renderConfig = MapConfig.rendering
	print(`[MapGeneratorService] Rendering config: mode={renderConfig.mode}, style={renderConfig.style}, quantization={renderConfig.heightQuantization}`)
	local success = false

	if renderConfig.mode == "parts" then
		print("[MapGeneratorService] Using Parts rendering mode (Minecraft-style)")
		success = PartsBuilder.buildWorld(mapData)
	else
		print("[MapGeneratorService] Using Terrain rendering mode (smooth)")
		success = TerrainBuilder.buildTerrain(mapData)
	end

	if not success then
		warn("[MapGeneratorService] ✗ Failed to build world")
		return nil
	end

	print("[MapGeneratorService] ✓ World generation complete")
	return mapData
end

-- ═══════════════════════════════════════════════════
-- GETTERS
-- ═══════════════════════════════════════════════════

function MapGeneratorService.getCurrentMapData(): Types.MapData?
	return currentMapData
end

return MapGeneratorService
