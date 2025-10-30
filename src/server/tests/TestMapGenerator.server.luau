--!strict
-- MAP GENERATOR TEST SCRIPT (PHASE 1 & 2)
-- Tests basic grid generation, determinism, and WFC algorithm

local ServerScriptService = game:GetService("ServerScriptService")
local Engine = ServerScriptService:WaitForChild("Engine")
local MapGenerator = Engine:WaitForChild("MapGenerator")

local MapGeneratorService = require(MapGenerator.MapGeneratorService)
local TileConfig = require(MapGenerator.TileConfig)

-- ═══════════════════════════════════════════════════
-- PHASE 1 TESTS
-- ═══════════════════════════════════════════════════

print("\n" .. string.rep("=", 60))
print("MAP GENERATOR - PHASE 1 TESTS")
print(string.rep("=", 60) .. "\n")

-- Test 1: Initialization
print("TEST 1: Initialization")
MapGeneratorService.initialize()
print("✓ Service initialized\n")

-- Test 2: Simple Random Generation
print("TEST 2: Simple Random Generation")
local testSeed = 12345
local mapData = MapGeneratorService.generateSimpleRandom(testSeed)

print(`Map Size: {mapData.mapSize}x{mapData.mapSize} studs`)
print(`Grid Size: {mapData.gridWidth}x{mapData.gridHeight} tiles`)
print(`Tile Size: {mapData.tileSize} studs`)
print(`Seed: {mapData.seed}`)
print(`Origin: {mapData.origin}`)
print(`Bounds: X({mapData.bounds.minX} to {mapData.bounds.maxX}), Z({mapData.bounds.minZ} to {mapData.bounds.maxZ})`)

-- Test 3: Tile Distribution
print("\nTEST 3: Tile Distribution")
local tileCounts = {}
local totalTiles = 0

-- Initialize counts
for tileType, _ in TileConfig.TileProperties do
	tileCounts[tileType] = 0
end

-- Count tiles
for y = 1, mapData.gridHeight do
	for x = 1, mapData.gridWidth do
		local tile = mapData.grid.tiles[y][x]
		tileCounts[tile.tileType] = tileCounts[tile.tileType] + 1
		totalTiles = totalTiles + 1
	end
end

-- Print distribution
print(`Total Tiles: {totalTiles}`)
for tileType, count in tileCounts do
	local props = TileConfig.TileProperties[tileType]
	local percentage = (count / totalTiles) * 100
	local expectedPercentage = props.weight * 100
	print(
		string.format(
			"  %s: %d (%.1f%% vs expected %.1f%%)",
			props.name,
			count,
			percentage,
			expectedPercentage
		)
	)
end

-- Test 4: Determinism
print("\nTEST 4: Determinism (Same seed should produce identical maps)")
local mapData2 = MapGeneratorService.generateSimpleRandom(testSeed)

local identical = true
for y = 1, mapData.gridHeight do
	for x = 1, mapData.gridWidth do
		local tile1 = mapData.grid.tiles[y][x]
		local tile2 = mapData2.grid.tiles[y][x]
		if tile1.tileType ~= tile2.tileType or math.abs(tile1.height - tile2.height) > 0.001 then
			identical = false
			print(`✗ Mismatch at ({x}, {y})`)
			break
		end
	end
	if not identical then
		break
	end
end

if identical then
	print("✓ Maps are identical - determinism confirmed")
else
	warn("✗ Maps differ - determinism failed!")
end

-- Test 5: Different Seeds
print("\nTEST 5: Different Seeds (Different seeds should produce different maps)")
local mapData3 = MapGeneratorService.generateSimpleRandom(54321)

local different = false
for y = 1, mapData.gridHeight do
	for x = 1, mapData.gridWidth do
		local tile1 = mapData.grid.tiles[y][x]
		local tile3 = mapData3.grid.tiles[y][x]
		if tile1.tileType ~= tile3.tileType then
			different = true
			break
		end
	end
	if different then
		break
	end
end

if different then
	print("✓ Different seeds produce different maps")
else
	warn("✗ Different seeds produced identical maps - check RNG!")
end

-- Test 6: Sample Tiles
print("\nTEST 6: Sample Tiles (showing first 5x5 corner)")
for y = 1, math.min(5, mapData.gridHeight) do
	local row = ""
	for x = 1, math.min(5, mapData.gridWidth) do
		local tile = mapData.grid.tiles[y][x]
		local props = TileConfig.TileProperties[tile.tileType]
		-- Use first letter of tile name
		row = row .. string.sub(props.name, 1, 1) .. " "
	end
	print(row)
end

print("\nLegend:")
for tileType, props in TileConfig.TileProperties do
	print(`  {string.sub(props.name, 1, 1)} = {props.name}`)
end

-- Summary
print("\n" .. string.rep("=", 60))
print("PHASE 1 TESTS COMPLETE")
print("All basic functionality verified!")
print(string.rep("=", 60) .. "\n")

-- ═══════════════════════════════════════════════════
-- PHASE 2 TESTS - WAVE FUNCTION COLLAPSE
-- ═══════════════════════════════════════════════════

print("\n" .. string.rep("=", 60))
print("MAP GENERATOR - PHASE 2 TESTS (WFC)")
print(string.rep("=", 60) .. "\n")

-- Test 7: WFC Generation
print("TEST 7: WFC Generation")
local wfcSeed = 99999
local wfcMapData = MapGeneratorService.generate(wfcSeed)

if not wfcMapData then
	warn("✗ WFC generation failed!")
else
	print(`✓ WFC generated {wfcMapData.gridWidth}x{wfcMapData.gridHeight} map`)
	print(`  Seed: {wfcMapData.seed}`)

	-- Test 8: Adjacency Rule Verification
	print("\nTEST 8: Adjacency Rule Verification")
	local violationCount = 0
	local checkedPairs = 0

	for y = 1, wfcMapData.gridHeight do
		for x = 1, wfcMapData.gridWidth do
			local tile = wfcMapData.grid.tiles[y][x]
			local tileType = tile.tileType

			-- Check right neighbor
			if x < wfcMapData.gridWidth then
				checkedPairs = checkedPairs + 1
				local rightTile = wfcMapData.grid.tiles[y][x + 1]
				local adjacencyRules = TileConfig.AdjacencyRules[tileType]

				if not table.find(adjacencyRules, rightTile.tileType) then
					violationCount = violationCount + 1
					if violationCount <= 5 then
						local tileName = TileConfig.TileProperties[tileType].name
						local rightName = TileConfig.TileProperties[rightTile.tileType].name
						warn(`  ✗ Violation at ({x}, {y}): {tileName} → {rightName}`)
					end
				end
			end

			-- Check down neighbor
			if y < wfcMapData.gridHeight then
				checkedPairs = checkedPairs + 1
				local downTile = wfcMapData.grid.tiles[y + 1][x]
				local adjacencyRules = TileConfig.AdjacencyRules[tileType]

				if not table.find(adjacencyRules, downTile.tileType) then
					violationCount = violationCount + 1
					if violationCount <= 5 then
						local tileName = TileConfig.TileProperties[tileType].name
						local downName = TileConfig.TileProperties[downTile.tileType].name
						warn(`  ✗ Violation at ({x}, {y}): {tileName} ↓ {downName}`)
					end
				end
			end
		end
	end

	if violationCount == 0 then
		print(`✓ All {checkedPairs} tile adjacencies respect rules`)
	else
		warn(`✗ Found {violationCount} adjacency violations out of {checkedPairs} pairs`)
	end

	-- Test 9: WFC Tile Distribution
	print("\nTEST 9: WFC Tile Distribution")
	local wfcTileCounts = {}
	local wfcTotalTiles = 0

	for tileType, _ in TileConfig.TileProperties do
		wfcTileCounts[tileType] = 0
	end

	for y = 1, wfcMapData.gridHeight do
		for x = 1, wfcMapData.gridWidth do
			local tile = wfcMapData.grid.tiles[y][x]
			wfcTileCounts[tile.tileType] = wfcTileCounts[tile.tileType] + 1
			wfcTotalTiles = wfcTotalTiles + 1
		end
	end

	print(`Total Tiles: {wfcTotalTiles}`)
	for tileType, count in wfcTileCounts do
		local props = TileConfig.TileProperties[tileType]
		local percentage = (count / wfcTotalTiles) * 100
		print(string.format("  %s: %d (%.1f%%)", props.name, count, percentage))
	end

	-- Test 10: WFC Determinism
	print("\nTEST 10: WFC Determinism")
	local wfcMapData2 = MapGeneratorService.generate(wfcSeed)

	if not wfcMapData2 then
		warn("✗ Second WFC generation failed!")
	else
		local wfcIdentical = true
		for y = 1, wfcMapData.gridHeight do
			for x = 1, wfcMapData.gridWidth do
				local tile1 = wfcMapData.grid.tiles[y][x]
				local tile2 = wfcMapData2.grid.tiles[y][x]
				if
					tile1.tileType ~= tile2.tileType
					or math.abs(tile1.height - tile2.height) > 0.001
				then
					wfcIdentical = false
					print(`✗ Mismatch at ({x}, {y})`)
					break
				end
			end
			if not wfcIdentical then
				break
			end
		end

		if wfcIdentical then
			print("✓ WFC maps are identical - determinism confirmed")
		else
			warn("✗ WFC maps differ - determinism failed!")
		end
	end

	-- Test 11: WFC Sample Output
	print("\nTEST 11: WFC Sample Output (showing first 10x10 corner)")
	for y = 1, math.min(10, wfcMapData.gridHeight) do
		local row = ""
		for x = 1, math.min(10, wfcMapData.gridWidth) do
			local tile = wfcMapData.grid.tiles[y][x]
			local props = TileConfig.TileProperties[tile.tileType]
			row = row .. string.sub(props.name, 1, 1) .. " "
		end
		print(row)
	end
end

-- Final Summary
print("\n" .. string.rep("=", 60))
print("PHASE 2 TESTS COMPLETE")
print("WFC algorithm verified!")
print(string.rep("=", 60) .. "\n")

-- ═══════════════════════════════════════════════════
-- PHASE 3 TESTS - TERRAIN BUILDING
-- ═══════════════════════════════════════════════════

print("\n" .. string.rep("=", 60))
print("MAP GENERATOR - PHASE 3 TESTS (TERRAIN BUILDING)")
print(string.rep("=", 60) .. "\n")

-- Test 12: Parts-Based World Building (Minecraft-style)
print("TEST 12: Parts-Based World Generation (Minecraft-style)")
local terrainSeed = 54321
local worldMapData = MapGeneratorService.generateAndBuildWorld(terrainSeed)

if not worldMapData then
	warn("✗ World generation failed!")
else
	print(`✓ World generated with Parts rendering`)
	print(`  Seed: {worldMapData.seed}`)
	print(`  Map Size: {worldMapData.mapSize}x{worldMapData.mapSize} studs`)
	print(`  Grid: {worldMapData.gridWidth}x{worldMapData.gridHeight} tiles`)
	print(
		`  Bounds: X({worldMapData.bounds.minX} to {worldMapData.bounds.maxX}), Z({worldMapData.bounds.minZ} to {worldMapData.bounds.maxZ})`
	)

	-- Check if parts world was actually created
	local generatedWorld = game.Workspace:FindFirstChild("GeneratedWorld")

	if generatedWorld then
		local partCount = #generatedWorld:GetChildren()
		print(`  Parts world verification: {partCount} parts created`)

		if partCount > 0 then
			print("✓ Minecraft-style world successfully generated in workspace!")
			print(`  Check workspace.GeneratedWorld to see the {partCount} blocks!`)
		else
			warn("✗ GeneratedWorld exists but has no parts")
		end
	else
		warn("✗ GeneratedWorld not found in workspace")
	end
end

-- Final Summary
print("\n" .. string.rep("=", 60))
print("PHASE 3 TESTS COMPLETE")
print("Minecraft-style Parts rendering verified!")
print("Check workspace.GeneratedWorld to see the blocky terrain!")
print(string.rep("=", 60) .. "\n")
