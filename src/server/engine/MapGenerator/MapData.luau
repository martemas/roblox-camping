--!strict
-- MAP DATA STRUCTURE AND UTILITIES
-- Manages grid storage and coordinate conversions

local Types = require(script.Parent.Types)

local MapData = {}

-- ═══════════════════════════════════════════════════
-- GRID CREATION
-- ═══════════════════════════════════════════════════

-- Create a new empty grid
function MapData.createGrid(width: number, height: number): Types.MapGrid
	local grid: Types.MapGrid = {
		width = width,
		height = height,
		tiles = {},
	}

	-- Initialize all tiles
	for y = 1, height do
		grid.tiles[y] = {}
		for x = 1, width do
			grid.tiles[y][x] = {
				tileType = 0,
				height = 0,
				zoneId = nil,
			}
		end
	end

	return grid
end

-- ═══════════════════════════════════════════════════
-- COORDINATE CONVERSION
-- ═══════════════════════════════════════════════════

-- Convert grid coordinates (1-based) to world coordinates (studs)
function MapData.gridToWorld(
	gridX: number,
	gridY: number,
	tileSize: number,
	mapOrigin: vector
): Types.WorldCoord
	-- Grid is 1-based, so offset by -0.5 to center tiles
	local worldX = mapOrigin.X + (gridX - 0.5) * tileSize
	local worldZ = mapOrigin.Z + (gridY - 0.5) * tileSize
	local worldY = mapOrigin.Y

	return {
		x = worldX,
		y = worldY,
		z = worldZ,
	}
end

-- Convert world coordinates (studs) to grid coordinates (1-based)
function MapData.worldToGrid(
	worldX: number,
	worldZ: number,
	tileSize: number,
	mapOrigin: vector
): Types.GridCoord
	local gridX = math.floor((worldX - mapOrigin.X) / tileSize) + 1
	local gridY = math.floor((worldZ - mapOrigin.Z) / tileSize) + 1

	return {
		x = gridX,
		y = gridY,
	}
end

-- ═══════════════════════════════════════════════════
-- GRID ACCESS
-- ═══════════════════════════════════════════════════

-- Get tile at grid coordinates (returns nil if out of bounds)
function MapData.getTile(grid: Types.MapGrid, x: number, y: number): Types.Tile?
	if x < 1 or x > grid.width or y < 1 or y > grid.height then
		return nil
	end
	return grid.tiles[y][x]
end

-- Set tile at grid coordinates (does nothing if out of bounds)
function MapData.setTile(grid: Types.MapGrid, x: number, y: number, tile: Types.Tile)
	if x < 1 or x > grid.width or y < 1 or y > grid.height then
		return
	end
	grid.tiles[y][x] = tile
end

-- Check if grid coordinates are in bounds
function MapData.isInBounds(grid: Types.MapGrid, x: number, y: number): boolean
	return x >= 1 and x <= grid.width and y >= 1 and y <= grid.height
end

-- ═══════════════════════════════════════════════════
-- DISTANCE CALCULATIONS
-- ═══════════════════════════════════════════════════

-- Calculate distance between two grid coordinates
function MapData.gridDistance(coord1: Types.GridCoord, coord2: Types.GridCoord): number
	local dx = coord1.x - coord2.x
	local dy = coord1.y - coord2.y
	return math.sqrt(dx * dx + dy * dy)
end

-- Get all neighbors of a grid cell (up to 4: north, south, east, west)
function MapData.getNeighbors(grid: Types.MapGrid, x: number, y: number): { Types.GridCoord }
	local neighbors = {}
	local directions = {
		{ x = 0, y = -1 }, -- North
		{ x = 0, y = 1 }, -- South
		{ x = -1, y = 0 }, -- West
		{ x = 1, y = 0 }, -- East
	}

	for _, dir in directions do
		local nx = x + dir.x
		local ny = y + dir.y
		if MapData.isInBounds(grid, nx, ny) then
			table.insert(neighbors, { x = nx, y = ny })
		end
	end

	return neighbors
end

-- ═══════════════════════════════════════════════════
-- MAP ORIGIN CALCULATION
-- ═══════════════════════════════════════════════════

-- Calculate the world origin point for centered map
function MapData.calculateMapOrigin(mapSize: number): vector
	local halfSize = mapSize / 2
	return vector.create(-halfSize, 0, -halfSize)
end

-- Calculate map bounds in world coordinates
function MapData.calculateMapBounds(mapSize: number, mapOrigin: vector): Types.MapBounds
	return {
		minX = mapOrigin.X,
		maxX = mapOrigin.X + mapSize,
		minZ = mapOrigin.Z,
		maxZ = mapOrigin.Z + mapSize,
	}
end

return MapData
