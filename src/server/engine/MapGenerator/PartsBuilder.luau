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

	-- Track progress
	local totalTiles = grid.width * grid.height
	local processedTiles = 0
	local lastProgressPercent = 0

	-- Generate parts for each tile
	for y = 1, grid.height do
		for x = 1, grid.width do
			local tile = grid.tiles[y][x]
			local tileProps = TileConfig.TileProperties[tile.tileType]

			-- Convert grid coordinates to world position
			local worldPos = MapData.gridToWorld(x, y, tileSize, mapData.origin)

			-- Create the part
			local part = Instance.new("Part")
			part.Name = `Tile_{x}_{y}_{tileProps.name}`

			-- Make blocks extend from base (y=0 or lower for water) up to tile height
			-- This creates proper Minecraft-style columns with no gaps
			local baseLevel = 0 -- Ground level
			if tile.height < 0 then
				-- Water tiles: extend from their height up to ground level
				baseLevel = tile.height
			end

			local blockHeight = math.max(4, tile.height - baseLevel + 4) -- At least 4 studs thick
			local centerY = baseLevel + (blockHeight / 2) + renderConfig.heightOffset

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
			-- All blocks should have collision EXCEPT water (water should be passable)
			local isWaterTile = tile.tileType == TileConfig.TileType.Water
				or tile.tileType == TileConfig.TileType.DeepWater
			part.CanCollide = not isWaterTile

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

	print(`[PartsBuilder] ✓ World building complete ({totalTiles} blocks created)`)
	return true
end

return PartsBuilder
