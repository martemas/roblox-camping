--!strict
-- MAP GENERATOR SERVICE
-- Main orchestrator for procedural map generation

local Types = require(script.Parent.Types)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local TileConfig = require(script.Parent.TileConfig)
local SeededRandom = require(script.Parent.SeededRandom)
local MapData = require(script.Parent.MapData)

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
-- GETTERS
-- ═══════════════════════════════════════════════════

function MapGeneratorService.getCurrentMapData(): Types.MapData?
	return currentMapData
end

return MapGeneratorService
