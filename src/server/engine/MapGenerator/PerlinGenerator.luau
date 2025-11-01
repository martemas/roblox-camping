--!strict
-- PERLIN GENERATOR
-- Direct Perlin noise to tile type conversion (no WFC)
-- Simpler and faster than WFC + Perlin hybrid

local Types = require(script.Parent.Types)
local TileConfig = require(script.Parent.TileConfig)
local MapData = require(script.Parent.MapData)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local PerlinNoise = require(script.Parent.PerlinNoise)

local PerlinGenerator = {}

-- ═══════════════════════════════════════════════════
-- MAIN GENERATION
-- ═══════════════════════════════════════════════════

-- Generate map using pure Perlin noise (no WFC)
function PerlinGenerator.generate(
	width: number,
	height: number,
	rng: Types.SeededRandom
): Types.MapGrid?
	print(`[PerlinGen] Starting pure Perlin generation for {width}x{height} grid`)

	local genConfig = MapConfig.generation
	local renderConfig = MapConfig.rendering

	-- Create map grid for result
	local mapGrid = MapData.createGrid(width, height)

	-- Generate Perlin noise heightmap
	print(`[PerlinGen] Generating Perlin noise heightmap (scale={genConfig.perlinScale}, octaves={genConfig.perlinOctaves})`)
	local heightmap = PerlinNoise.generateHeightmap(width, height, rng, genConfig.perlinScale, genConfig.perlinOctaves, 5, 15)
	print("[PerlinGen] ✓ Heightmap generated")

	-- Track progress
	local totalTiles = width * height
	local processedTiles = 0
	local lastProgressPercent = 0

	-- Populate grid with tiles based on height
	for y = 1, height do
		for x = 1, width do
			-- Get height from Perlin noise
			local tileHeight = heightmap[y][x]

			-- Apply height quantization if enabled
			if renderConfig.heightQuantization > 0 then
				local step = renderConfig.heightQuantization
				tileHeight = math.floor(tileHeight / step) * step
			end

			-- Determine tile type based on height and altitude bands
			local tileType = TileConfig.TileType.Grass -- Default

			if renderConfig.useAltitudeBiomes then
				local altitudeBands = renderConfig.altitudeBands
				-- Find appropriate altitude band for this height
				for _, band in altitudeBands do
					if tileHeight <= band.maxHeight then
						tileType = band.tileType
						break
					end
				end
			end

			-- Store tile in grid
			mapGrid.tiles[y][x] = {
				tileType = tileType,
				height = tileHeight,
				zoneId = nil,
			}

			-- Progress tracking
			processedTiles = processedTiles + 1
			local progressPercent = math.floor((processedTiles / totalTiles) * 100)
			if progressPercent % 25 == 0 and progressPercent ~= lastProgressPercent then
				lastProgressPercent = progressPercent
				print(`[PerlinGen] Progress: {progressPercent}%`)
			end
		end
	end

	print("[PerlinGen] ✓ Generation complete")
	return mapGrid
end

return PerlinGenerator
