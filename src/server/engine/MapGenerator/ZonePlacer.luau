--!strict
-- ZONE PLACER - Section-based zone positioning
-- Places zones in designated sections of the map with support for dependent zones

local Types = require(script.Parent.Types)
local TileConfig = require(script.Parent.TileConfig)
local MapData = require(script.Parent.MapData)
local SectionGrid = require(script.Parent.SectionGrid)

local ZonePlacer = {}

-- ═══════════════════════════════════════════════════
-- ZONE MODIFICATION HELPERS
-- ═══════════════════════════════════════════════════

--- Get all tiles in a zone for modification
local function getTilesInZone(
	centerX: number,
	centerY: number,
	radius: number,
	grid: Types.MapGrid,
	tileSize: number
): { Types.Tile }
	local radiusInTiles = math.ceil(radius / tileSize)
	local tiles: { Types.Tile } = {}

	for y = math.max(1, centerY - radiusInTiles), math.min(grid.height, centerY + radiusInTiles) do
		for x = math.max(1, centerX - radiusInTiles), math.min(grid.width, centerX + radiusInTiles) do
			local tile = MapData.getTile(grid, x, y)
			if tile then
				table.insert(tiles, tile)
			end
		end
	end

	return tiles
end

--- Calculate median height in zone
local function getMedianHeightInZone(
	centerX: number,
	centerY: number,
	radius: number,
	grid: Types.MapGrid,
	tileSize: number
): number
	local heights: { number } = {}
	local radiusInTiles = math.ceil(radius / tileSize)

	for y = math.max(1, centerY - radiusInTiles), math.min(grid.height, centerY + radiusInTiles) do
		for x = math.max(1, centerX - radiusInTiles), math.min(grid.width, centerX + radiusInTiles) do
			local tile = MapData.getTile(grid, x, y)
			if tile then
				table.insert(heights, tile.height)
			end
		end
	end

	if #heights == 0 then
		return 0
	end

	table.sort(heights)
	return heights[math.ceil(#heights / 2)]
end

--- Get biome's allowed tile types
local function getBiomeTiles(biomeName: string): { number }?
	local biome = TileConfig.Biomes[biomeName]
	if biome then
		return biome.allowedTiles
	end
	return nil
end

--- Check if zone contains water tiles
local function hasWater(
	centerX: number,
	centerY: number,
	radius: number,
	grid: Types.MapGrid,
	tileSize: number
): boolean
	local radiusInTiles = math.ceil(radius / tileSize)

	for y = math.max(1, centerY - radiusInTiles), math.min(grid.height, centerY + radiusInTiles) do
		for x = math.max(1, centerX - radiusInTiles), math.min(grid.width, centerX + radiusInTiles) do
			local tile = MapData.getTile(grid, x, y)
			if tile and (tile.tileType == TileConfig.TileType.Water or tile.tileType == TileConfig.TileType.DeepWater) then
				return true
			end
		end
	end

	return false
end

-- ═══════════════════════════════════════════════════
-- ZONE APPLICATION
-- ═══════════════════════════════════════════════════

--- Apply zone modifications to grid tiles
local function applyZoneModifications(
	centerX: number,
	centerY: number,
	zoneId: string,
	zoneConfig: Types.ZoneConfig,
	grid: Types.MapGrid,
	tileSize: number
): ()
	local zonesInArea = getTilesInZone(centerX, centerY, zoneConfig.radius, grid, tileSize)

	-- Flatten if required
	if zoneConfig.constraints.requireFlat then
		local medianHeight = getMedianHeightInZone(centerX, centerY, zoneConfig.radius, grid, tileSize)
		for _, tile in ipairs(zonesInArea) do
			tile.height = medianHeight
		end
	end

	-- Apply biome tiles
	local biomeTiles = getBiomeTiles(zoneConfig.biome)
	if biomeTiles and #biomeTiles > 0 then
		for _, tile in ipairs(zonesInArea) do
			-- Deterministic selection based on tile position to avoid issues
			local index = ((math.abs(math.floor(tile.height)) % #biomeTiles) + 1)
			if index < 1 or index > #biomeTiles then
				index = 1
			end
			local newTileType = biomeTiles[index]
			if newTileType and newTileType > 0 then
				tile.tileType = newTileType
			end
			tile.zoneId = zoneId
		end
	else
		-- Fallback: use grass if no biome
		for _, tile in ipairs(zonesInArea) do
			if tile.tileType == 0 then
				tile.tileType = TileConfig.TileType.Grass
			end
			tile.zoneId = zoneId
		end
	end
end

-- ═══════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════

--- Place zones on the map based on section-based positioning
function ZonePlacer.placeZones(
	mapData: Types.MapData,
	zoneConfigs: { [string]: Types.ZoneConfig },
	random: any -- SeededRandom instance
): { Types.PlacedZone }
	local placedZones: { Types.PlacedZone } = {}
	local grid = mapData.grid
	local tileSize = mapData.tileSize

	-- Create section grid
	local sectionGrid = SectionGrid.create(grid.width, grid.height)

	-- Priority order for zone placement
	local zoneOrder = { "playerTown", "castle", "desert", "mountains" }

	-- Phase 1: Place primary zones (no dependencies)
	for _, zoneId in ipairs(zoneOrder) do
		local zoneConfig = zoneConfigs[zoneId]

		-- Skip disabled zones or dependent zones
		if not zoneConfig or not zoneConfig.enabled or zoneConfig.constraints.relativeToZone then
			continue
		end

		-- Get valid sections for this zone
		local validSections = SectionGrid.getValidSections(zoneConfig.constraints.allowedSections, sectionGrid)

		if #validSections == 0 then
			warn(`✗ Zone {zoneId} has no valid sections`)
			continue
		end

		-- Pick a random section
		local section = validSections[random.nextInt(1, #validSections)]

		-- Pick random center within section
		local centerCoord = SectionGrid.getRandomCenterInSection(section, random)

		-- Check water constraint if specified
		if zoneConfig.constraints.noWater and hasWater(centerCoord.x, centerCoord.y, zoneConfig.radius, grid, tileSize) then
			warn(`✗ Zone {zoneId} position has water, skipping`)
			continue
		end

		-- Apply zone modifications
		applyZoneModifications(centerCoord.x, centerCoord.y, zoneId, zoneConfig, grid, tileSize)

		-- Record placed zone
		table.insert(placedZones, {
			id = zoneId,
			config = zoneConfig,
			center = centerCoord,
			radius = zoneConfig.radius,
			biome = zoneConfig.biome,
		})

		print(`✓ Placed zone: {zoneId} in section {section.name} at ({centerCoord.x}, {centerCoord.y})`)
	end

	-- Phase 2: Place dependent zones
	for _, zoneId in ipairs(zoneOrder) do
		local zoneConfig = zoneConfigs[zoneId]

		-- Skip disabled zones or non-dependent zones
		if not zoneConfig or not zoneConfig.enabled or not zoneConfig.constraints.relativeToZone then
			continue
		end

		-- Find parent zone
		local parentZone = nil
		for _, placedZone in ipairs(placedZones) do
			if placedZone.id == zoneConfig.constraints.relativeToZone then
				parentZone = placedZone
				break
			end
		end

		if not parentZone then
			warn(`✗ Zone {zoneId} depends on {zoneConfig.constraints.relativeToZone}, but parent not found`)
			continue
		end

		-- Get valid relative sections
		local relativeSections = zoneConfig.constraints.relativeSections or { "N", "E", "S", "W" }
		if #relativeSections == 0 then
			warn(`✗ Zone {zoneId} has no valid relative sections`)
			continue
		end

		-- Pick a random relative section
		local relativeSection = relativeSections[random.nextInt(1, #relativeSections)]
		local distance = zoneConfig.constraints.relativeDistance or 200

		-- Calculate position relative to parent
		local centerCoord = SectionGrid.getRelativePosition(parentZone.center, distance, relativeSection, random, tileSize)

		-- Clamp to grid bounds
		centerCoord.x = math.max(1, math.min(centerCoord.x, grid.width))
		centerCoord.y = math.max(1, math.min(centerCoord.y, grid.height))

		-- Check water constraint if specified
		if zoneConfig.constraints.noWater and hasWater(centerCoord.x, centerCoord.y, zoneConfig.radius, grid, tileSize) then
			warn(`✗ Zone {zoneId} position has water, skipping`)
			continue
		end

		-- Apply zone modifications
		applyZoneModifications(centerCoord.x, centerCoord.y, zoneId, zoneConfig, grid, tileSize)

		-- Record placed zone
		table.insert(placedZones, {
			id = zoneId,
			config = zoneConfig,
			center = centerCoord,
			radius = zoneConfig.radius,
			biome = zoneConfig.biome,
		})

		print(
			`✓ Placed zone: {zoneId} relative to {zoneConfig.constraints.relativeToZone} (section: {relativeSection}, distance: {distance}) at ({centerCoord.x}, {centerCoord.y})`
		)
	end

	return placedZones
end

--- Apply zone placement to map grid
function ZonePlacer.applyZones(
	mapData: Types.MapData,
	zoneConfigs: { [string]: Types.ZoneConfig },
	random: any -- SeededRandom instance
): ()
	local newZones = ZonePlacer.placeZones(mapData, zoneConfigs, random)
	mapData.zones = newZones
end

return ZonePlacer
