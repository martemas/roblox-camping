--!strict
-- PARTS BUILDER
-- Converts 2D tile grid into Minecraft-style blocks using Roblox Parts

local Types = require(script.Parent.Types)
local TileConfig = require(script.Parent.TileConfig)
local MapData = require(script.Parent.MapData)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)

local PartsBuilder = {}

-- ═══════════════════════════════════════════════════
-- MATERIAL MAPPING
-- ═══════════════════════════════════════════════════

local MATERIAL_MAP = {
	[TileConfig.TileType.DeepWater] = Enum.Material.SmoothPlastic,
	[TileConfig.TileType.Water] = Enum.Material.SmoothPlastic,
	[TileConfig.TileType.Sand] = Enum.Material.Sand,
	[TileConfig.TileType.Grass] = Enum.Material.Grass,
	[TileConfig.TileType.Forest] = Enum.Material.Grass,
	[TileConfig.TileType.Hill] = Enum.Material.Ground,
	[TileConfig.TileType.Mountain] = Enum.Material.Slate,
	[TileConfig.TileType.Snow] = Enum.Material.Snow,
}

-- ═══════════════════════════════════════════════════
-- WORLD BUILDING
-- ═══════════════════════════════════════════════════

-- Build 3D world from map data using Parts
function PartsBuilder.buildWorld(mapData: Types.MapData): boolean
	print("[PartsBuilder] Building Minecraft-style world with Parts...")

	-- Clear existing generated world
	local existingWorld = game.Workspace:FindFirstChild("GeneratedWorld")
	if existingWorld then
		existingWorld:Destroy()
	end

	-- Create container model
	local worldModel = Instance.new("Model")
	worldModel.Name = "GeneratedWorld"

	local tileSize = mapData.tileSize
	local grid = mapData.grid
	local renderConfig = MapConfig.rendering

	-- Step 1: Find minimum height across all tiles
	local minHeight = math.huge
	for y = 1, grid.height do
		for x = 1, grid.width do
			local tile = grid.tiles[y][x]
			if tile.height < minHeight then
				minHeight = tile.height
			end
		end
	end
	print(`[PartsBuilder] Found minimum tile height: {minHeight}`)

	-- Track progress
	local totalTiles = grid.width * grid.height
	local processedTiles = 0
	local lastProgressPercent = 0

	-- Step 2: Generate parts for each tile with height calculated from minHeight
	for y = 1, grid.height do
		for x = 1, grid.width do
			local tile = grid.tiles[y][x]
			local tileProps = TileConfig.TileProperties[tile.tileType]

			-- Convert grid coordinates to world position
			local worldPos = MapData.gridToWorld(x, y, tileSize, mapData.origin)

			-- Create the part
			local part = Instance.new("Part")
			part.Name = `Tile_{x}_{y}_{tileProps.name}`

			-- Calculate block height as difference from minHeight
			local blockHeight = tile.height - minHeight
			-- Center Y position: minimum point + half of block height
			local centerY = minHeight + (blockHeight / 2) + renderConfig.heightOffset

			part.Size = Vector3.new(tileSize, blockHeight, tileSize)
			part.CFrame = CFrame.new(worldPos.x, centerY, worldPos.z)

			-- Set material based on config
			if renderConfig.useRobloxMaterials then
				part.Material = MATERIAL_MAP[tile.tileType]
			else
				part.Material = Enum.Material.SmoothPlastic
			end

			-- Set color from tile config
			part.Color = tileProps.color

			-- Set physics properties
			part.Anchored = true
			part.CanCollide = true

			-- Optimize rendering
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth

			-- Parent to world model
			part.Parent = worldModel

			-- Progress tracking
			processedTiles = processedTiles + 1
			local progressPercent = math.floor((processedTiles / totalTiles) * 100)
			if progressPercent % 25 == 0 and progressPercent ~= lastProgressPercent then
				lastProgressPercent = progressPercent
				print(`[PartsBuilder] Progress: {progressPercent}%`)
			end
		end
	end

	-- Parent world to workspace
	worldModel.Parent = game.Workspace

	-- Create water plate if enabled
	if renderConfig.water and renderConfig.water.enabled then
		PartsBuilder.createWaterPlate(mapData, worldModel)
	end

	print(`[PartsBuilder] ✓ World building complete ({totalTiles} blocks created)`)
	return true
end

-- ═══════════════════════════════════════════════════
-- WATER PLATE CREATION
-- ═══════════════════════════════════════════════════

-- Create a flat water surface overlay
function PartsBuilder.createWaterPlate(mapData: Types.MapData, parentModel: Model)
	local renderConfig = MapConfig.rendering
	local waterConfig = renderConfig.water

	-- Water plate positioned at the configured height
	-- waterConfig.height is the absolute Y position (0 = ground level, negative = below, positive = above)
	local waterLevel = waterConfig.height
	print(`[PartsBuilder] Creating water plate at height {waterLevel}...`)

	-- Create water plate part
	local waterPlate = Instance.new("Part")
	waterPlate.Name = "WaterPlate"
	waterPlate.Shape = Enum.PartType.Block
	waterPlate.Size = Vector3.new(mapData.mapSize + 64, 1, mapData.mapSize + 64) -- Slightly larger than map

	-- Position at water level height
	local mapCenterX = mapData.bounds.minX + (mapData.mapSize / 2)
	local mapCenterZ = mapData.bounds.minZ + (mapData.mapSize / 2)
	waterPlate.CFrame = CFrame.new(mapCenterX, waterLevel, mapCenterZ)

	-- Set water appearance
	waterPlate.Material = waterConfig.material or Enum.Material.Water
	waterPlate.Transparency = waterConfig.transparency or 0.3
	waterPlate.Color = Color3.fromRGB(50, 100, 200) -- Water blue

	-- Set physics
	waterPlate.Anchored = true
	waterPlate.CanCollide = false -- Water is passable
	waterPlate.CastShadow = false

	-- Surface properties
	waterPlate.TopSurface = Enum.SurfaceType.Smooth
	waterPlate.BottomSurface = Enum.SurfaceType.Smooth

	-- Parent to world model
	waterPlate.Parent = parentModel

	print("[PartsBuilder] ✓ Water plate created")
end

return PartsBuilder
