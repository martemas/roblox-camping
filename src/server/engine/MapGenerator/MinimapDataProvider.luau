--!strict
-- MINIMAP DATA PROVIDER
-- Generates minimap data from MapData for client visualization

local Types = require(script.Parent.Types)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEventsModule = require(ReplicatedStorage.Engine:WaitForChild("Core"):WaitForChild("RemoteEvents"))

local MinimapDataProvider = {}

-- ═══════════════════════════════════════════════════
-- CACHED STATE
-- ═══════════════════════════════════════════════════

local cachedMinimapData: MinimapData? = nil

-- ═══════════════════════════════════════════════════
-- TYPE DEFINITIONS
-- ═══════════════════════════════════════════════════

export type MinimapStructure = {
	name: string,
	gridX: number,
	gridY: number,
	structureType: string,
	zoneId: string,
}

export type MinimapZone = {
	id: string,
	centerX: number,
	centerY: number,
	radius: number,
	biome: string,
}

export type MinimapData = {
	gridWidth: number,
	gridHeight: number,
	mapSize: number,
	tileSize: number,
	originX: number,
	originY: number,
	originZ: number,
	terrainPixels: { number },
	zones: { MinimapZone },
	structures: { MinimapStructure },
}

-- ═══════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════

--- Extract structure positions from placed zones
local function extractStructureMarkers(mapData: Types.MapData): { MinimapStructure }
	local structures = {}

	for _, zone in mapData.zones do
		if zone.config.structures then
			for _, structureConfig in zone.config.structures do
				-- Calculate grid position
				local gridPos = { x = zone.center.x, y = zone.center.y }

				-- Apply structure offset if specified
				if structureConfig.position ~= "center" and type(structureConfig.position) == "table" then
					local offset = structureConfig.position :: { x: number, z: number }
					-- Convert stud offset to grid offset
					local gridOffsetX = math.floor(offset.x / mapData.tileSize)
					local gridOffsetZ = math.floor(offset.z / mapData.tileSize)
					gridPos = {
						x = zone.center.x + gridOffsetX,
						y = zone.center.y + gridOffsetZ,
					}
				end

				table.insert(structures, {
					name = structureConfig.name,
					gridX = gridPos.x,
					gridY = gridPos.y,
					structureType = structureConfig.name,
					zoneId = zone.id,
				})
			end
		end
	end

	return structures
end

--- Convert zones to minimap format
local function convertZonesToMinimapFormat(zones: { Types.PlacedZone }): { MinimapZone }
	local minimapZones = {}

	for _, zone in zones do
		table.insert(minimapZones, {
			id = zone.id,
			centerX = zone.center.x,
			centerY = zone.center.y,
			radius = zone.radius,
			biome = zone.biome,
		})
	end

	return minimapZones
end

-- ═══════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════

--- Generate minimap data from MapData
function MinimapDataProvider.generateMinimapData(mapData: Types.MapData): MinimapData
	print("[MinimapDataProvider] Generating minimap data (direct grid conversion)...")

	local terrainPixels = {}

	-- Direct iteration - no sampling needed
	for y = 1, mapData.gridHeight do
		for x = 1, mapData.gridWidth do
			local tile = mapData.grid.tiles[y][x]
			table.insert(terrainPixels, tile.tileType) -- Already computed by Perlin
		end
	end

	local minimapData: MinimapData = {
		gridWidth = mapData.gridWidth,
		gridHeight = mapData.gridHeight,
		mapSize = mapData.mapSize,
		tileSize = mapData.tileSize,
		originX = mapData.origin.X,
		originY = mapData.origin.Y,
		originZ = mapData.origin.Z,
		terrainPixels = terrainPixels,
		zones = convertZonesToMinimapFormat(mapData.zones),
		structures = extractStructureMarkers(mapData),
	}

	print(`[MinimapDataProvider] ✓ Generated minimap data ({#terrainPixels} pixels, {#minimapData.zones} zones, {#minimapData.structures} structures)`)

	return minimapData
end

--- Broadcast minimap data to all players
function MinimapDataProvider.broadcastToPlayers(minimapData: MinimapData)
	print("[MinimapDataProvider] Broadcasting minimap data to all players...")

	-- Cache the data for late-joining players
	cachedMinimapData = minimapData

	local RemoteEvents = RemoteEventsModule.Events
	if RemoteEvents.MinimapDataUpdated then
		RemoteEvents.MinimapDataUpdated:FireAllClients(minimapData)
		print("[MinimapDataProvider] ✓ Minimap data broadcasted")
	else
		warn("[MinimapDataProvider] MinimapDataUpdated RemoteEvent not found!")
	end
end

--- Send cached minimap data to a specific player (for late joiners)
function MinimapDataProvider.sendToPlayer(player: Player)
	if not cachedMinimapData then
		warn(`[MinimapDataProvider] No cached minimap data available for {player.Name}`)
		return
	end

	print(`[MinimapDataProvider] Sending cached minimap data to {player.Name}`)

	local RemoteEvents = RemoteEventsModule.Events
	if RemoteEvents.MinimapDataUpdated then
		RemoteEvents.MinimapDataUpdated:FireClient(player, cachedMinimapData)
		print(`[MinimapDataProvider] ✓ Minimap data sent to {player.Name}`)
	else
		warn("[MinimapDataProvider] MinimapDataUpdated RemoteEvent not found!")
	end
end

--- Initialize player listener to send minimap to new players
function MinimapDataProvider.initialize()
	print("[MinimapDataProvider] Initializing player join listener...")

	Players.PlayerAdded:Connect(function(player)
		-- Wait a moment for the player's UI to load
		task.wait(2)

		-- Send cached minimap data if available
		if cachedMinimapData then
			MinimapDataProvider.sendToPlayer(player)
		end
	end)

	print("[MinimapDataProvider] ✓ Player join listener initialized")
end

--- Update structure markers only (after structure placement)
function MinimapDataProvider.updateStructureMarkers(mapData: Types.MapData)
	print("[MinimapDataProvider] Sending structure marker update...")

	local structures = extractStructureMarkers(mapData)
	local RemoteEvents = RemoteEventsModule.Events

	if RemoteEvents.MinimapStructuresUpdated then
		RemoteEvents.MinimapStructuresUpdated:FireAllClients(structures)
		print(`[MinimapDataProvider] ✓ Structure markers updated ({#structures} structures)`)
	else
		warn("[MinimapDataProvider] MinimapStructuresUpdated RemoteEvent not found!")
	end
end

return MinimapDataProvider
