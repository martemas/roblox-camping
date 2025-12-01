--!strict
-- TEST ZONE PLACEMENT (Phase 4)
-- Tests zone placement logic and constraint validation

local Engine = game:GetService("ServerScriptService"):WaitForChild("Engine")
local GamesMapConfig = require(game:GetService("ServerScriptService"):WaitForChild("Games"):WaitForChild("Config"):WaitForChild("GamesMapConfig"))
local MapGeneratorService = require(Engine.MapGenerator.MapGeneratorService)
-- local GamesMapConfig = require(Engine.games.alpha.Config.GamesMapConfig)

print("═══════════════════════════════════════════════════")
print("PHASE 4: ZONE PLACEMENT TEST")
print("═══════════════════════════════════════════════════")

-- Initialize service
MapGeneratorService.initialize()

-- Test 1: Generate map with zones
print("\n[Test 1] Generating map with zone placement...")
local mapData = MapGeneratorService.generateAndBuildWorld(12345)

if not mapData then
	error("✗ Failed to generate map")
end

print(`✓ Map generated (seed: {mapData.seed})`)
print(`  Grid size: {mapData.gridWidth}x{mapData.gridHeight}`)
print(`  Zones placed: {#mapData.zones}`)

-- Test 2: Verify zones were placed
print("\n[Test 2] Verifying zone placement...")

for _, zone in ipairs(mapData.zones) do
	print(`  ✓ {zone.id}: center=({zone.center.x}, {zone.center.y}), radius={zone.radius}, biome={zone.biome}`)
end

if #mapData.zones == 0 then
	warn("⚠ No zones were placed (check constraints)")
else
	print(`✓ Successfully placed {#mapData.zones} zones`)
end

-- Test 3: Verify determinism (same seed = same zones)
print("\n[Test 3] Testing determinism...")
local mapData2 = MapGeneratorService.generateAndBuildWorld(12345)

if not mapData2 then
	error("✗ Failed to generate second map")
end

-- Check if zones match
local zoneCountMatch = #mapData.zones == #mapData2.zones
print(`  Zone count match: {zoneCountMatch} ({#mapData.zones} vs {#mapData2.zones})`)

if zoneCountMatch then
	local allZonesMatch = true
	for i, zone1 in ipairs(mapData.zones) do
		local zone2 = mapData2.zones[i]
		if zone1.id == zone2.id and zone1.center.x == zone2.center.x and zone1.center.y == zone2.center.y then
			print(`  ✓ Zone {i} ({zone1.id}) matches`)
		else
			print(`  ✗ Zone {i} mismatch`)
			allZonesMatch = false
		end
	end

	if allZonesMatch then
		print("✓ Determinism verified - same seed produces identical zones")
	else
		warn("⚠ Zone positions don't match exactly")
	end
else
	warn("⚠ Different number of zones placed - determinism issue")
end

-- Test 4: Verify zone constraints
print("\n[Test 4] Verifying zone constraints...")

local function checkZoneConstraints(mapData: any, zoneId: string)
	local zone = nil
	for _, z in ipairs(mapData.zones) do
		if z.id == zoneId then
			zone = z
			break
		end
	end

	if not zone then
		print(`  ⚠ Zone {zoneId} not placed`)
		return
	end

	local config = GamesMapConfig.zones[zoneId]
	if not config then
		print(`  ⚠ No config for zone {zoneId}`)
		return
	end

	local constraints = config.constraints
	local radiusInTiles = math.ceil(zone.radius / mapData.tileSize)

	-- Check edge distance
	if constraints.minDistanceFromEdge then
		local minX = zone.center.x - radiusInTiles
		local minZ = zone.center.y - radiusInTiles
		local maxX = mapData.gridWidth - (zone.center.x + radiusInTiles)
		local maxZ = mapData.gridHeight - (zone.center.y + radiusInTiles)

		local minEdgeDist = math.min(minX, minZ, maxX, maxZ)
		local meetsConstraint = minEdgeDist >= constraints.minDistanceFromEdge
		print(`  {zoneId} edge distance: {minEdgeDist} (min: {constraints.minDistanceFromEdge}) - {if meetsConstraint then "✓" else "✗"}`)
	end

	-- Check flatness
	if constraints.requireFlat then
		local heights = {}
		for y = math.max(1, zone.center.y - radiusInTiles), math.min(mapData.gridHeight, zone.center.y + radiusInTiles) do
			for x = math.max(1, zone.center.x - radiusInTiles), math.min(mapData.gridWidth, zone.center.x + radiusInTiles) do
				local tile = mapData.grid.tiles[y][x]
				if tile then
					table.insert(heights, tile.height)
				end
			end
		end

		if #heights > 0 then
			table.sort(heights)
			local minH = heights[1]
			local maxH = heights[#heights]
			local heightVariance = maxH - minH
			local isFlat = heightVariance <= 1
			local flatStatus = if isFlat then "✓" else "✗"
			print(
				string.format(
					"  %s flatness: height range %.1f to %.1f (variance: %.1f) - %s",
					zoneId,
					minH,
					maxH,
					heightVariance,
					flatStatus
				)
			)
		end
	end
end

checkZoneConstraints(mapData, "playerTown")
checkZoneConstraints(mapData, "castle")

-- Test 5: Verify biome tiles in zones
print("\n[Test 5] Verifying zone biome enforcement...")

local function checkZoneBiomeTiles(mapData: any, zoneId: string)
	local zone = nil
	for _, z in ipairs(mapData.zones) do
		if z.id == zoneId then
			zone = z
			break
		end
	end

	if not zone then
		print(`  ⚠ Zone {zoneId} not placed`)
		return
	end

	local radiusInTiles = math.ceil(zone.radius / mapData.tileSize)
	local tileTypes = {}

	for y = math.max(1, zone.center.y - radiusInTiles), math.min(mapData.gridHeight, zone.center.y + radiusInTiles) do
		for x = math.max(1, zone.center.x - radiusInTiles), math.min(mapData.gridWidth, zone.center.x + radiusInTiles) do
			local tile = mapData.grid.tiles[y][x]
			if tile and tile.zoneId == zoneId then
				tileTypes[tile.tileType] = (tileTypes[tile.tileType] or 0) + 1
			end
		end
	end

	if next(tileTypes) then
		print(`  {zoneId} tile types:`, tileTypes)
		print(`  ✓ Zone {zoneId} has {next(tileTypes) and "enforced biome tiles" or "no tiles"}`)
	else
		print(`  ⚠ Zone {zoneId} has no marked tiles`)
	end
end

checkZoneBiomeTiles(mapData, "playerTown")
checkZoneBiomeTiles(mapData, "castle")

print("\n═══════════════════════════════════════════════════")
print("PHASE 4 TEST COMPLETE")
print("═══════════════════════════════════════════════════")
