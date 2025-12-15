--!strict
-- STRUCTURE PLACEMENT - Places structures inside zones
-- Handles loading assets and positioning them in the world

local Types = require(script.Parent.Types)
local MapData = require(script.Parent.MapData)

local StructurePlacement = {}

-- ═══════════════════════════════════════════════════
-- ASSET LOADING
-- ═══════════════════════════════════════════════════

--- Load asset from path string (e.g., "ServerStorage.Assets.Base.Team1")
local function loadAsset(assetPath: string): Model?
	local parts = string.split(assetPath, ".")

	if #parts == 0 then
		warn(`[StructurePlacement] Invalid asset path: {assetPath}`)
		return nil
	end

	-- Get the service (e.g., ServerStorage, ReplicatedStorage)
	local success, service = pcall(function()
		return game:GetService(parts[1])
	end)

	if not success then
		warn(`[StructurePlacement] Invalid service in path: {parts[1]}`)
		return nil
	end

	local current: any = service

	-- Navigate through the path
	for i = 2, #parts do
		current = current:FindFirstChild(parts[i])
		if not current then
			warn(`[StructurePlacement] Asset not found: {assetPath} (failed at {parts[i]})`)
			return nil
		end
	end

	-- Clone and return the asset
	if current:IsA("Model") or current:IsA("Folder") then
		return current:Clone()
	else
		warn(`[StructurePlacement] Asset is not a Model or Folder: {assetPath}`)
		return nil
	end
end

-- ═══════════════════════════════════════════════════
-- POSITION CALCULATION
-- ═══════════════════════════════════════════════════

--- Get height at grid position
local function getHeightAtGridPosition(
	gridX: number,
	gridY: number,
	grid: Types.MapGrid
): number
	local tile = MapData.getTile(grid, gridX, gridY)
	if tile then
		return tile.height
	end
	return 0
end

--- Calculate world position for structure
local function calculateStructurePosition(
	zone: Types.PlacedZone,
	structureConfig: Types.ZoneStructure,
	mapData: Types.MapData
): vector
	-- Zone center in grid coordinates
	local zoneCenterGrid = zone.center

	-- Convert to world coordinates
	local zoneCenterWorld = MapData.gridToWorld(
		zoneCenterGrid.x,
		zoneCenterGrid.y,
		mapData.tileSize,
		mapData.origin
	)

	-- Apply structure offset if specified
	local finalX = zoneCenterWorld.x
	local finalZ = zoneCenterWorld.z

	if structureConfig.position ~= "center" and type(structureConfig.position) == "table" then
		local offset = structureConfig.position :: { x: number, z: number }
		finalX = finalX + offset.x
		finalZ = finalZ + offset.z
	end

	-- Get terrain height at this location
	local heightAtPosition = getHeightAtGridPosition(zoneCenterGrid.x, zoneCenterGrid.y, mapData.grid)

	-- Final position (Y is the terrain height)
	return vector.create(finalX, heightAtPosition, finalZ)
end

-- ═══════════════════════════════════════════════════
-- STRUCTURE PLACEMENT
-- ═══════════════════════════════════════════════════

--- Place structures for a single zone
local function placeZoneStructures(
	zone: Types.PlacedZone,
	mapData: Types.MapData,
	worldFolder: Folder
): number
	local structuresPlaced = 0

	if not zone.config.structures or #zone.config.structures == 0 then
		return 0
	end

	for _, structureConfig in ipairs(zone.config.structures) do
		-- Load asset
		local asset = loadAsset(structureConfig.assetPath)
		if not asset then
			warn(`[StructurePlacement] Failed to load asset for {structureConfig.name} in zone {zone.id}`)
			continue
		end

		-- Calculate position
		local position = calculateStructurePosition(zone, structureConfig, mapData)

		-- Calculate rotation
		local rotationRadians = math.rad(structureConfig.rotation)
		local rotationCFrame = CFrame.Angles(0, rotationRadians, 0)

		-- Set CFrame
		local finalCFrame = CFrame.new(position) * rotationCFrame

		-- If asset has a PrimaryPart, use it
		if asset:IsA("Model") then
			if asset.PrimaryPart then
				asset:SetPrimaryPartCFrame(finalCFrame)
			else
				-- Try to set PrimaryPart to the first Part found
				local firstPart = asset:FindFirstChildWhichIsA("BasePart")
				if firstPart then
					asset.PrimaryPart = firstPart
					asset:SetPrimaryPartCFrame(finalCFrame)
				else
					warn(`[StructurePlacement] Model {structureConfig.name} has no BasePart`)
					asset:Destroy()
					continue
				end
			end
		end

		-- Set name
		asset.Name = `{structureConfig.name}_{zone.id}`

		-- Parent to world folder
		asset.Parent = worldFolder

		structuresPlaced = structuresPlaced + 1
		print(`✓ Placed structure: {structureConfig.name} in zone {zone.id} at {position}`)
	end

	return structuresPlaced
end

-- ═══════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════

--- Place all structures for all zones
function StructurePlacement.placeStructures(mapData: Types.MapData): boolean
	-- Get or create world folder
	local worldFolder = workspace:FindFirstChild("GeneratedWorld")
	if not worldFolder then
		worldFolder = Instance.new("Folder")
		worldFolder.Name = "GeneratedWorld"
		worldFolder.Parent = workspace
	end

	local totalStructures = 0

	-- Place structures for each zone
	for _, zone in ipairs(mapData.zones) do
		local placed = placeZoneStructures(zone, mapData, worldFolder)
		totalStructures = totalStructures + placed
	end

	print(`[StructurePlacement] ✓ Placed {totalStructures} total structures`)
	return totalStructures > 0
end

return StructurePlacement
