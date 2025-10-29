--!strict
-- MAP GENERATOR TEST SCRIPT (PHASE 1)
-- Tests basic grid generation and determinism

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
