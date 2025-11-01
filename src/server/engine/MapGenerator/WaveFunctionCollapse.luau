--!strict
-- WAVE FUNCTION COLLAPSE ALGORITHM
-- Implements WFC for procedural map generation with adjacency constraints

local Types = require(script.Parent.Types)
local TileConfig = require(script.Parent.TileConfig)
local MapData = require(script.Parent.MapData)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local PerlinNoise = require(script.Parent.PerlinNoise)

local WaveFunctionCollapse = {}

-- ═══════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════

local MAX_ITERATIONS = 10000
local ALL_TILE_TYPES = {}

-- Build list of all tile types
for tileType, _ in TileConfig.TileProperties do
	table.insert(ALL_TILE_TYPES, tileType)
end

-- ═══════════════════════════════════════════════════
-- WFC STATE INITIALIZATION
-- ═══════════════════════════════════════════════════

-- Create initial WFC grid with all possibilities
local function createWFCGrid(width: number, height: number): Types.WFCGrid
	local grid: Types.WFCGrid = {
		width = width,
		height = height,
		cells = {},
	}

	-- Initialize all cells with all possible tiles
	for y = 1, height do
		grid.cells[y] = {}
		for x = 1, width do
			grid.cells[y][x] = {
				collapsed = false,
				possibleTiles = table.clone(ALL_TILE_TYPES),
				entropy = #ALL_TILE_TYPES,
			}
		end
	end

	return grid
end

-- ═══════════════════════════════════════════════════
-- HEIGHT CALCULATION HELPERS
-- ═══════════════════════════════════════════════════

-- Calculate height with constraints based on neighbor heights
local function calculateConstrainedHeight(
	x: number,
	y: number,
	tileProps: any,
	rng: Types.SeededRandom,
	mapGrid: Types.MapGrid,
	genConfig: any
): number
	local maxHeightDelta = genConfig.maxHeightDelta

	-- Get neighbor heights
	local neighbors = MapData.getNeighbors(mapGrid, x, y)
	local neighborHeights = {}

	for _, neighbor in neighbors do
		local neighborTile = MapData.getTile(mapGrid, neighbor.x, neighbor.y)
		if neighborTile and neighborTile.height then
			table.insert(neighborHeights, neighborTile.height)
		end
	end

	-- Calculate height range
	local baseHeight = tileProps.baseHeight
	local heightVar = tileProps.heightVariation / 2

	-- If we have collapsed neighbors, constrain height to be within maxHeightDelta of them
	if #neighborHeights > 0 then
		local avgNeighborHeight = 0
		for _, h in neighborHeights do
			avgNeighborHeight = avgNeighborHeight + h
		end
		avgNeighborHeight = avgNeighborHeight / #neighborHeights

		-- Constrain around neighbor average
		local minHeight = avgNeighborHeight - maxHeightDelta
		local maxHeight = avgNeighborHeight + maxHeightDelta

		-- Also respect tile type height bounds
		minHeight = math.max(minHeight, baseHeight - heightVar)
		maxHeight = math.min(maxHeight, baseHeight + heightVar)

		-- Random height within constrained range
		local range = maxHeight - minHeight
		if range > 0 then
			return minHeight + rng.nextFloat() * range
		else
			return minHeight
		end
	else
		-- No neighbors collapsed yet, use normal variation
		local heightVariation = rng.nextFloat() * tileProps.heightVariation - tileProps.heightVariation / 2
		return baseHeight + heightVariation
	end
end

-- ═══════════════════════════════════════════════════
-- ENTROPY CALCULATION
-- ═══════════════════════════════════════════════════

-- Find cell with lowest entropy (but not collapsed)
local function findLowestEntropyCell(wfcGrid: Types.WFCGrid, rng: Types.SeededRandom): Types.GridCoord?
	local lowestEntropy = math.huge
	local candidates = {}

	for y = 1, wfcGrid.height do
		for x = 1, wfcGrid.width do
			local cell = wfcGrid.cells[y][x]
			if not cell.collapsed then
				local entropy = cell.entropy

				if entropy < lowestEntropy then
					lowestEntropy = entropy
					candidates = { { x = x, y = y } }
				elseif entropy == lowestEntropy then
					table.insert(candidates, { x = x, y = y })
				end
			end
		end
	end

	if #candidates == 0 then
		return nil
	end

	-- Pick random cell from candidates with same entropy
	local index = rng.nextInt(1, #candidates)
	return candidates[index]
end

-- ═══════════════════════════════════════════════════
-- WAVE COLLAPSE
-- ═══════════════════════════════════════════════════

-- Collapse a cell to a single tile type
local function collapseCell(
	wfcGrid: Types.WFCGrid,
	x: number,
	y: number,
	rng: Types.SeededRandom
): number?
	local cell = wfcGrid.cells[y][x]

	if #cell.possibleTiles == 0 then
		return nil -- Contradiction
	end

	-- Use weighted random selection
	local totalWeight = 0
	for _, tileType in cell.possibleTiles do
		totalWeight = totalWeight + TileConfig.TileProperties[tileType].weight
	end

	local randomValue = rng.nextFloat() * totalWeight
	local currentWeight = 0

	for _, tileType in cell.possibleTiles do
		currentWeight = currentWeight + TileConfig.TileProperties[tileType].weight
		if currentWeight >= randomValue then
			cell.collapsed = true
			cell.possibleTiles = { tileType }
			cell.entropy = 1
			return tileType
		end
	end

	-- Fallback: pick first tile
	local chosenTile = cell.possibleTiles[1]
	cell.collapsed = true
	cell.possibleTiles = { chosenTile }
	cell.entropy = 1
	return chosenTile
end

-- ═══════════════════════════════════════════════════
-- CONSTRAINT PROPAGATION
-- ═══════════════════════════════════════════════════

-- Propagate constraints from a collapsed cell to its neighbors
local function propagateConstraints(
	wfcGrid: Types.WFCGrid,
	startX: number,
	startY: number,
	mapGrid: Types.MapGrid
): boolean
	local stack = { { x = startX, y = startY } }
	local visited = {}

	while #stack > 0 do
		local current = table.remove(stack)
		local key = `{current.x},{current.y}`

		if visited[key] then
			continue
		end
		visited[key] = true

		local currentCell = wfcGrid.cells[current.y][current.x]
		if not currentCell.collapsed then
			continue
		end

		local currentTile = currentCell.possibleTiles[1]

		-- Get neighbors
		local neighbors = MapData.getNeighbors(mapGrid, current.x, current.y)

		for _, neighbor in neighbors do
			local neighborCell = wfcGrid.cells[neighbor.y][neighbor.x]

			if not neighborCell.collapsed then
				-- Get valid adjacent tiles for current tile
				local validAdjacent = TileConfig.AdjacencyRules[currentTile]

				-- Filter neighbor's possible tiles
				local newPossibleTiles = {}
				for _, possibleTile in neighborCell.possibleTiles do
					-- Check adjacency rules AND height constraints
					local validAdjacency = table.find(validAdjacent, possibleTile)
					local validHeight = TileConfig.isValidHeightTransition(currentTile, possibleTile)

					if validAdjacency and validHeight then
						table.insert(newPossibleTiles, possibleTile)
					end
				end

				-- If possibilities changed, update and add to stack
				if #newPossibleTiles ~= #neighborCell.possibleTiles then
					if #newPossibleTiles == 0 then
						-- Contradiction - cell has no valid options
						return false
					end

					neighborCell.possibleTiles = newPossibleTiles
					neighborCell.entropy = #newPossibleTiles

					-- Add neighbor to stack for further propagation
					table.insert(stack, neighbor)
				end
			end
		end
	end

	return true
end

-- ═══════════════════════════════════════════════════
-- MAIN WFC ALGORITHM
-- ═══════════════════════════════════════════════════

function WaveFunctionCollapse.generate(
	width: number,
	height: number,
	rng: Types.SeededRandom
): Types.MapGrid?
	print(`[WFC] Starting generation for {width}x{height} grid`)

	-- Create WFC state grid
	local wfcGrid = createWFCGrid(width, height)

	-- Create map grid for result
	local mapGrid = MapData.createGrid(width, height)
	local genConfig = MapConfig.generation

	-- Pre-generate Perlin noise heightmap if using perlin mode
	local perlinHeightmap = nil
	if genConfig.heightGenerationMode == "perlin" then
		print(`[WFC] Pre-generating Perlin noise heightmap (scale={genConfig.perlinScale}, octaves={genConfig.perlinOctaves})`)
		-- Scale heightmap from -10 to 20 studs to match altitude bands
		perlinHeightmap = PerlinNoise.generateHeightmap(width, height, rng, genConfig.perlinScale, genConfig.perlinOctaves, 5, 15)
		print("[WFC] ✓ Perlin heightmap generated")
	end

	local iterations = 0

	while iterations < MAX_ITERATIONS do
		iterations = iterations + 1

		-- Find cell with lowest entropy
		local coord = findLowestEntropyCell(wfcGrid, rng)

		if not coord then
			-- All cells collapsed - success!
			print(`[WFC] ✓ Generation complete in {iterations} iterations`)
			return mapGrid
		end

		-- Collapse the cell
		local chosenTile = collapseCell(wfcGrid, coord.x, coord.y, rng)

		if not chosenTile then
			-- Contradiction during collapse
			return nil
		end

		-- Update map grid
		local tileProps = TileConfig.TileProperties[chosenTile]
		local renderConfig = MapConfig.rendering

		-- Calculate height based on selected mode
		local tileHeight: number

		if genConfig.heightGenerationMode == "constrained" then
			-- Option 1: Height-aware constraint propagation
			tileHeight = calculateConstrainedHeight(coord.x, coord.y, tileProps, rng, mapGrid, genConfig)
		elseif genConfig.heightGenerationMode == "perlin" then
			-- Option 2: Perlin noise heightmap
			-- Use the Perlin noise value directly as height (don't clamp to tile type)
			-- This allows smooth transitions and lets altitude biomes handle tile type conversion
			tileHeight = perlinHeightmap[coord.y][coord.x]
		else
			-- Default: Random height with variation
			local heightVariation = rng.nextFloat() * tileProps.heightVariation - tileProps.heightVariation / 2
			tileHeight = tileProps.baseHeight + heightVariation
		end

		-- Apply height quantization if enabled
		if renderConfig.heightQuantization > 0 then
			local step = renderConfig.heightQuantization
			tileHeight = math.floor(tileHeight / step) * step
		end

		mapGrid.tiles[coord.y][coord.x] = {
			tileType = chosenTile,
			height = tileHeight,
			zoneId = nil,
		}

		-- Propagate constraints
		local success = propagateConstraints(wfcGrid, coord.x, coord.y, mapGrid)

		if not success then
			-- Contradiction during propagation
			return nil
		end

		-- Progress logging
		if iterations % 100 == 0 then
			local totalCells = width * height
			local collapsedCount = 0
			for y = 1, height do
				for x = 1, width do
					if wfcGrid.cells[y][x].collapsed then
						collapsedCount = collapsedCount + 1
					end
				end
			end
			local progress = (collapsedCount / totalCells) * 100
			print(string.format("[WFC] Progress: %.1f%% (%d/%d cells)", progress, collapsedCount, totalCells))
		end
	end

	-- Max iterations reached without completing
	return nil
end

return WaveFunctionCollapse
