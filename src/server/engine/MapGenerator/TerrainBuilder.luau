--!strict
-- TERRAIN BUILDER
-- Converts 2D tile grid into 3D Roblox terrain using Terrain API

local Types = require(script.Parent.Types)
local TileConfig = require(script.Parent.TileConfig)
local MapData = require(script.Parent.MapData)

local TerrainBuilder = {}

-- ═══════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════

local TERRAIN_HEIGHT_SCALE = 1 -- Scale factor for terrain height
local TERRAIN_SMOOTHING = false -- Apply smoothing between tiles

-- ═══════════════════════════════════════════════════
-- TERRAIN GENERATION
-- ═══════════════════════════════════════════════════

-- Build 3D terrain from map data
function TerrainBuilder.buildTerrain(mapData: Types.MapData): boolean
	print("[TerrainBuilder] Building 3D terrain...")

	local terrain = game.Workspace.Terrain

	-- Clear existing terrain in the map area
	local clearRegion = Region3.new(
		Vector3.new(mapData.bounds.minX, -50, mapData.bounds.minZ),
		Vector3.new(mapData.bounds.maxX, 100, mapData.bounds.maxZ)
	)
	terrain:Clear()

	local tileSize = mapData.tileSize
	local grid = mapData.grid

	-- Track progress
	local totalTiles = grid.width * grid.height
	local processedTiles = 0
	local lastProgressPercent = 0

	-- Generate terrain for each tile
	for y = 1, grid.height do
		for x = 1, grid.width do
			local tile = grid.tiles[y][x]
			local tileProps = TileConfig.TileProperties[tile.tileType]

			-- Convert grid coordinates to world position
			local worldPos = MapData.gridToWorld(x, y, tileSize, mapData.origin)

			-- Calculate terrain block dimensions
			local blockSize = Vector3.new(tileSize, 50, tileSize)
			local baseHeight = tile.height * TERRAIN_HEIGHT_SCALE

			-- Create terrain region from base height to surface
			local surfaceHeight = baseHeight + 4 -- Terrain thickness

			-- Calculate center point of the terrain block
			local centerX = worldPos.x
			local centerY = baseHeight + 2 -- Center of the 4-stud thick terrain
			local centerZ = worldPos.z

			local size = Vector3.new(tileSize, 4, tileSize)
			local cframe = CFrame.new(centerX, centerY, centerZ)

			-- Fill terrain using FillBlock
			terrain:FillBlock(cframe, size, tileProps.terrain)

			-- Progress tracking
			processedTiles = processedTiles + 1
			local progressPercent = math.floor((processedTiles / totalTiles) * 100)
			if progressPercent % 25 == 0 and progressPercent ~= lastProgressPercent then
				lastProgressPercent = progressPercent
				print(`[TerrainBuilder] Progress: {progressPercent}%`)
			end
		end
	end

	print("[TerrainBuilder] ✓ Terrain building complete")
	return true
end

-- ═══════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════

-- Get interpolated height between tiles (for future smoothing)
function TerrainBuilder.getInterpolatedHeight(
	grid: Types.MapGrid,
	x: number,
	y: number,
	offsetX: number,
	offsetY: number
): number
	local tile = MapData.getTile(grid, x, y)
	if not tile then
		return 0
	end

	local height = tile.height

	-- If smoothing is enabled, average with neighbors
	if TERRAIN_SMOOTHING then
		local neighborCount = 1
		local heightSum = height

		-- Check adjacent tiles
		local neighbor = MapData.getTile(grid, x + offsetX, y + offsetY)
		if neighbor then
			heightSum = heightSum + neighbor.height
			neighborCount = neighborCount + 1
		end

		height = heightSum / neighborCount
	end

	return height * TERRAIN_HEIGHT_SCALE
end

return TerrainBuilder
