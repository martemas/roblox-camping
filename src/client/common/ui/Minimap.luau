--!strict

--[[
	Minimap - Real-time minimap UI component

	Displays:
	- Terrain (color-coded by biome/altitude)
	- Zone boundaries
	- Structure markers (bases, POIs)
	- Player positions (real-time tracking)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))
local RemoteEventsModule = require(ReplicatedStorage.Engine:WaitForChild("Core"):WaitForChild("RemoteEvents"))

local Minimap = UIComponent.new("Minimap", UIConfig.minimap.enabled)

-- ═══════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════

local localPlayer = Players.LocalPlayer
local config = UIConfig.minimap

-- UI Elements - Minimap
local minimapFrame: Frame? = nil
local terrainCanvas: Frame? = nil
local zonesCanvas: Frame? = nil
local structuresCanvas: Frame? = nil
local playersCanvas: Frame? = nil

-- UI Elements - Expanded Map
local overlayFrame: Frame? = nil
local expandedMapFrame: Frame? = nil
local expandedTerrainCanvas: Frame? = nil
local expandedZonesCanvas: Frame? = nil
local expandedStructuresCanvas: Frame? = nil
local expandedPlayersCanvas: Frame? = nil
local closeButton: TextButton? = nil

-- Map data
local mapData: any = nil
local playerMarkerPool: { Frame } = {}
local activePlayerMarkers: { Frame } = {}
local expandedPlayerMarkerPool: { Frame } = {}
local activeExpandedPlayerMarkers: { Frame } = {}

-- State
local isExpanded: boolean = false

-- Tracking
local trackingConnection: RBXScriptConnection? = nil

-- ═══════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════

--- Convert world position to minimap normalized coordinates (0-1)
local function worldToMinimapPosition(worldPos: Vector3): Vector2
	if not mapData then
		return Vector2.new(0.5, 0.5)
	end

	local mapOrigin = Vector3.new(mapData.originX, mapData.originY, mapData.originZ)

	-- Convert world studs to grid coordinates
	local gridX = (worldPos.X - mapOrigin.X) / mapData.tileSize
	local gridY = (worldPos.Z - mapOrigin.Z) / mapData.tileSize

	-- Normalize to 0-1 range
	local normalizedX = gridX / mapData.gridWidth
	local normalizedY = gridY / mapData.gridHeight

	-- Clamp to bounds
	normalizedX = math.clamp(normalizedX, 0, 1)
	normalizedY = math.clamp(normalizedY, 0, 1)

	return Vector2.new(normalizedX, normalizedY)
end

--- Get team color from team ID
local function getTeamColor(teamId: string): Color3
	return config.teamColors[teamId] or config.teamColors.neutral
end

--- Get or create a player marker from pool
local function getPlayerMarker(): Frame
	local marker = table.remove(playerMarkerPool)
	if not marker then
		marker = Instance.new("Frame")
		marker.BorderSizePixel = 0

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = marker
	end

	marker.Visible = true
	table.insert(activePlayerMarkers, marker)
	return marker
end

--- Release all player markers back to pool
local function releaseAllPlayerMarkers()
	for _, marker in activePlayerMarkers do
		marker.Visible = false
		marker.Parent = playersCanvas
		table.insert(playerMarkerPool, marker)
	end
	table.clear(activePlayerMarkers)
end

-- ═══════════════════════════════════════════════════
-- RENDERING FUNCTIONS
-- ═══════════════════════════════════════════════════

--- Render terrain grid (color-coded by tile type)
local function renderTerrain()
	print(`[Minimap] Starting terrain render: {mapData.gridWidth}x{mapData.gridHeight} grid, {#mapData.terrainPixels} pixels`)
	renderTerrainToCanvas(terrainCanvas)
	print(`[Minimap] ✓ Rendered terrain tiles`)
end

--- Render zone overlays (semi-transparent circles)
local function renderZones()
	renderZonesToCanvas(zonesCanvas)
	print(`[Minimap] ✓ Rendered {#mapData.zones} zone overlays`)
end

--- Render structure markers (icons)
local function renderStructures()
	renderStructuresToCanvas(structuresCanvas)
	print(`[Minimap] ✓ Rendered {#mapData.structures} structure markers`)
end

--- Update player positions (called every frame)
local function updatePlayerPositions()
	if not playersCanvas or not mapData or not config.playerMarkers.enabled then
		return
	end

	-- Release all markers back to pool
	releaseAllPlayerMarkers()

	-- Track all players
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			continue
		end

		-- Convert world position to minimap position
		local worldPos = humanoidRootPart.Position
		local minimapPos = worldToMinimapPosition(worldPos)

		-- Get player info
		local isLocalPlayer = (player == localPlayer)
		local teamId = player:GetAttribute("TeamId") or "neutral"

		-- Create player marker
		local marker = getPlayerMarker()
		marker.Parent = playersCanvas

		-- Size based on player type
		local markerSize = isLocalPlayer and config.playerMarkers.localPlayerSize or config.playerMarkers.otherPlayerSize

		-- Position on minimap
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.Position = UDim2.fromScale(minimapPos.X, minimapPos.Y)
		marker.Size = UDim2.fromOffset(markerSize, markerSize)
		marker.ZIndex = isLocalPlayer and 10 or 8

		-- Visual style
		local teamColor = getTeamColor(teamId)
		if isLocalPlayer then
			-- LocalPlayer: White center with colored border
			marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			marker.BorderSizePixel = 2
			marker.BorderColor3 = teamColor

			-- Add UIStroke for better visibility
			local stroke = marker:FindFirstChild("UIStroke")
			if not stroke then
				stroke = Instance.new("UIStroke")
				stroke.Color = teamColor
				stroke.Thickness = 2
				stroke.Parent = marker
			end
		else
			-- Other players: Solid colored dots
			marker.BackgroundColor3 = teamColor
			marker.BorderSizePixel = 0

			-- Remove stroke if exists
			local stroke = marker:FindFirstChild("UIStroke")
			if stroke then
				stroke:Destroy()
			end
		end

		-- Optional: Add direction indicator
		if config.playerMarkers.showDirection then
			local lookVector = humanoidRootPart.CFrame.LookVector
			local rotation = math.atan2(-lookVector.X, -lookVector.Z)
			marker.Rotation = math.deg(rotation)
		end
	end
end

-- ═══════════════════════════════════════════════════
-- EXPANDED MAP FUNCTIONS
-- ═══════════════════════════════════════════════════

--- Render terrain to a specific canvas
local function renderTerrainToCanvas(canvas: Frame)
	if not canvas or not mapData then
		return
	end

	canvas:ClearAllChildren()

	local gridWidth = mapData.gridWidth
	local gridHeight = mapData.gridHeight
	local pixelIndex = 1

	for y = 1, gridHeight do
		for x = 1, gridWidth do
			local tileType = mapData.terrainPixels[pixelIndex]
			local color = config.terrainColors[tileType] or Color3.fromRGB(128, 128, 128)

			local pixel = Instance.new("Frame")
			pixel.Name = `Tile_{x}_{y}`
			pixel.BorderSizePixel = 0
			pixel.BackgroundColor3 = color

			local normalizedX = (x - 1) / gridWidth
			local normalizedY = (y - 1) / gridHeight
			local cellWidth = 1 / gridWidth
			local cellHeight = 1 / gridHeight

			pixel.Position = UDim2.fromScale(normalizedX, normalizedY)
			pixel.Size = UDim2.fromScale(cellWidth, cellHeight)
			pixel.Parent = canvas

			pixelIndex = pixelIndex + 1
		end
	end
end

--- Render zones to a specific canvas
local function renderZonesToCanvas(canvas: Frame)
	if not canvas or not mapData or not config.showZones then
		return
	end

	canvas:ClearAllChildren()

	for _, zone in mapData.zones do
		local normalizedX = (zone.centerX - 1) / mapData.gridWidth
		local normalizedY = (zone.centerY - 1) / mapData.gridHeight
		local radiusInCells = zone.radius / mapData.tileSize
		local normalizedRadius = radiusInCells / mapData.gridWidth

		local zoneCircle = Instance.new("Frame")
		zoneCircle.Name = `Zone_{zone.id}`
		zoneCircle.BackgroundTransparency = config.zoneOutlineTransparency
		zoneCircle.BackgroundColor3 = config.zoneOutlineColor
		zoneCircle.BorderSizePixel = 0
		zoneCircle.AnchorPoint = Vector2.new(0.5, 0.5)
		zoneCircle.Position = UDim2.fromScale(normalizedX, normalizedY)
		zoneCircle.Size = UDim2.fromScale(normalizedRadius * 2, normalizedRadius * 2)
		zoneCircle.ZIndex = 2

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = zoneCircle

		zoneCircle.Parent = canvas
	end
end

--- Render structures to a specific canvas
local function renderStructuresToCanvas(canvas: Frame)
	if not canvas or not mapData then
		return
	end

	canvas:ClearAllChildren()

	for _, structure in mapData.structures do
		local iconConfig = config.structureIcons[structure.structureType]
		if not iconConfig then
			continue
		end

		local normalizedX = (structure.gridX - 1) / mapData.gridWidth
		local normalizedY = (structure.gridY - 1) / mapData.gridHeight

		local marker = Instance.new("TextLabel")
		marker.Name = `Structure_{structure.name}`
		marker.Text = iconConfig.text
		marker.TextColor3 = iconConfig.color
		marker.TextSize = iconConfig.size
		marker.Font = config.font
		marker.BackgroundTransparency = 1
		marker.BorderSizePixel = 0
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.Position = UDim2.fromScale(normalizedX, normalizedY)
		marker.Size = UDim2.fromOffset(iconConfig.size, iconConfig.size)
		marker.ZIndex = 3
		marker.Parent = canvas
	end
end

--- Expand the minimap to full screen
local function expandMap()
	if isExpanded or not config.expanded.enabled then
		return
	end

	print("[Minimap] Expanding to full screen...")
	isExpanded = true

	-- Show and animate overlay
	if overlayFrame then
		overlayFrame.Visible = true
		overlayFrame.BackgroundTransparency = 1

		local overlayTween = TweenService:Create(
			overlayFrame,
			TweenInfo.new(config.expanded.animationDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = config.expanded.overlayTransparency }
		)
		overlayTween:Play()
	end

	-- Show and animate expanded map
	if expandedMapFrame then
		expandedMapFrame.Visible = true
		expandedMapFrame.Size = UDim2.fromScale(0.1, 0.1)

		local mapTween = TweenService:Create(
			expandedMapFrame,
			TweenInfo.new(config.expanded.animationDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UIConfig.createUDim2(config.expanded.size) }
		)
		mapTween:Play()

		-- Render to expanded canvases
		renderTerrainToCanvas(expandedTerrainCanvas)
		renderZonesToCanvas(expandedZonesCanvas)
		renderStructuresToCanvas(expandedStructuresCanvas)
	end

	-- Show close button
	if closeButton then
		closeButton.Visible = true
	end

	print("[Minimap] ✓ Expanded")
end

--- Collapse the expanded map back to minimap
local function collapseMap()
	if not isExpanded then
		return
	end

	print("[Minimap] Collapsing to minimap...")
	isExpanded = false

	-- Animate expanded map
	if expandedMapFrame then
		local mapTween = TweenService:Create(
			expandedMapFrame,
			TweenInfo.new(config.expanded.animationDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = UDim2.fromScale(0.1, 0.1) }
		)
		mapTween:Play()
		mapTween.Completed:Connect(function()
			expandedMapFrame.Visible = false
		end)
	end

	-- Animate overlay
	if overlayFrame then
		local overlayTween = TweenService:Create(
			overlayFrame,
			TweenInfo.new(config.expanded.animationDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		overlayTween:Play()
		overlayTween.Completed:Connect(function()
			overlayFrame.Visible = false
		end)
	end

	-- Hide close button
	if closeButton then
		closeButton.Visible = false
	end

	print("[Minimap] ✓ Collapsed")
end

--- Toggle between expanded and collapsed states
local function toggleExpanded()
	if isExpanded then
		collapseMap()
	else
		expandMap()
	end
end

-- ═══════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════

--- Create the minimap UI
function Minimap.create(parent: ScreenGui): Frame
	print("[Minimap] Creating minimap UI...")

	-- Main minimap frame
	minimapFrame = Instance.new("Frame")
	minimapFrame.Name = "Minimap"
	minimapFrame.Position = UIConfig.createUDim2(config.position)
	minimapFrame.Size = UIConfig.createUDim2(config.size)
	minimapFrame.AnchorPoint = UIConfig.createVector2(config.anchorPoint)
	minimapFrame.BackgroundColor3 = config.backgroundColor
	minimapFrame.BackgroundTransparency = config.backgroundTransparency
	minimapFrame.BorderSizePixel = 0
	minimapFrame.ZIndex = 1
	minimapFrame.Visible = true -- Ensure visible by default

	-- Border
	local border = Instance.new("UIStroke")
	border.Color = config.borderColor
	border.Thickness = config.borderThickness
	border.Parent = minimapFrame

	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.cornerRadius)
	corner.Parent = minimapFrame

	-- Terrain layer (bottom)
	terrainCanvas = Instance.new("Frame")
	terrainCanvas.Name = "TerrainCanvas"
	terrainCanvas.Size = UDim2.fromScale(1, 1)
	terrainCanvas.BackgroundTransparency = 1
	terrainCanvas.BorderSizePixel = 0
	terrainCanvas.ZIndex = 1
	terrainCanvas.ClipsDescendants = true
	terrainCanvas.Parent = minimapFrame

	-- Zone layer
	zonesCanvas = Instance.new("Frame")
	zonesCanvas.Name = "ZonesCanvas"
	zonesCanvas.Size = UDim2.fromScale(1, 1)
	zonesCanvas.BackgroundTransparency = 1
	zonesCanvas.BorderSizePixel = 0
	zonesCanvas.ZIndex = 2
	zonesCanvas.Parent = minimapFrame

	-- Structure layer
	structuresCanvas = Instance.new("Frame")
	structuresCanvas.Name = "StructuresCanvas"
	structuresCanvas.Size = UDim2.fromScale(1, 1)
	structuresCanvas.BackgroundTransparency = 1
	structuresCanvas.BorderSizePixel = 0
	structuresCanvas.ZIndex = 3
	structuresCanvas.Parent = minimapFrame

	-- Player layer (top)
	playersCanvas = Instance.new("Frame")
	playersCanvas.Name = "PlayersCanvas"
	playersCanvas.Size = UDim2.fromScale(1, 1)
	playersCanvas.BackgroundTransparency = 1
	playersCanvas.BorderSizePixel = 0
	playersCanvas.ZIndex = 4
	playersCanvas.Parent = minimapFrame

	-- Click detection for expansion
	local minimapButton = Instance.new("TextButton")
	minimapButton.Size = UDim2.fromScale(1, 1)
	minimapButton.BackgroundTransparency = 1
	minimapButton.Text = ""
	minimapButton.ZIndex = 5
	minimapButton.Parent = minimapFrame
	minimapButton.MouseButton1Click:Connect(toggleExpanded)

	minimapFrame.Parent = parent
	Minimap.container = minimapFrame
	Minimap.visible = true -- Set component state to visible

	-- ═══════════════════════════════════════════════════
	-- CREATE EXPANDED MAP
	-- ═══════════════════════════════════════════════════

	if config.expanded.enabled then
		-- Overlay background
		overlayFrame = Instance.new("Frame")
		overlayFrame.Name = "MinimapOverlay"
		overlayFrame.Size = UDim2.fromScale(1, 1)
		overlayFrame.Position = UDim2.fromScale(0, 0)
		overlayFrame.BackgroundColor3 = config.expanded.overlayColor
		overlayFrame.BackgroundTransparency = config.expanded.overlayTransparency
		overlayFrame.BorderSizePixel = 0
		overlayFrame.ZIndex = 100
		overlayFrame.Visible = false
		overlayFrame.Parent = parent

		-- Click overlay to close
		if config.expanded.closeOnClickOutside then
			local overlayButton = Instance.new("TextButton")
			overlayButton.Size = UDim2.fromScale(1, 1)
			overlayButton.BackgroundTransparency = 1
			overlayButton.Text = ""
			overlayButton.ZIndex = 100
			overlayButton.Parent = overlayFrame
			overlayButton.MouseButton1Click:Connect(collapseMap)
		end

		-- Expanded map frame
		expandedMapFrame = Instance.new("Frame")
		expandedMapFrame.Name = "ExpandedMap"
		expandedMapFrame.Size = UIConfig.createUDim2(config.expanded.size)
		expandedMapFrame.Position = UDim2.fromScale(0.5, 0.5)
		expandedMapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		expandedMapFrame.BackgroundColor3 = config.backgroundColor
		expandedMapFrame.BackgroundTransparency = config.backgroundTransparency
		expandedMapFrame.BorderSizePixel = 0
		expandedMapFrame.ZIndex = 101
		expandedMapFrame.Visible = false
		expandedMapFrame.Parent = parent

		-- Border for expanded map
		local expandedBorder = Instance.new("UIStroke")
		expandedBorder.Color = config.borderColor
		expandedBorder.Thickness = config.borderThickness
		expandedBorder.Parent = expandedMapFrame

		-- Corner radius for expanded map
		local expandedCorner = Instance.new("UICorner")
		expandedCorner.CornerRadius = UDim.new(0, config.cornerRadius)
		expandedCorner.Parent = expandedMapFrame

		-- Expanded terrain canvas
		expandedTerrainCanvas = Instance.new("Frame")
		expandedTerrainCanvas.Name = "ExpandedTerrainCanvas"
		expandedTerrainCanvas.Size = UDim2.fromScale(1, 1)
		expandedTerrainCanvas.BackgroundTransparency = 1
		expandedTerrainCanvas.BorderSizePixel = 0
		expandedTerrainCanvas.ZIndex = 101
		expandedTerrainCanvas.ClipsDescendants = true
		expandedTerrainCanvas.Parent = expandedMapFrame

		-- Expanded zones canvas
		expandedZonesCanvas = Instance.new("Frame")
		expandedZonesCanvas.Name = "ExpandedZonesCanvas"
		expandedZonesCanvas.Size = UDim2.fromScale(1, 1)
		expandedZonesCanvas.BackgroundTransparency = 1
		expandedZonesCanvas.BorderSizePixel = 0
		expandedZonesCanvas.ZIndex = 102
		expandedZonesCanvas.Parent = expandedMapFrame

		-- Expanded structures canvas
		expandedStructuresCanvas = Instance.new("Frame")
		expandedStructuresCanvas.Name = "ExpandedStructuresCanvas"
		expandedStructuresCanvas.Size = UDim2.fromScale(1, 1)
		expandedStructuresCanvas.BackgroundTransparency = 1
		expandedStructuresCanvas.BorderSizePixel = 0
		expandedStructuresCanvas.ZIndex = 103
		expandedStructuresCanvas.Parent = expandedMapFrame

		-- Expanded players canvas
		expandedPlayersCanvas = Instance.new("Frame")
		expandedPlayersCanvas.Name = "ExpandedPlayersCanvas"
		expandedPlayersCanvas.Size = UDim2.fromScale(1, 1)
		expandedPlayersCanvas.BackgroundTransparency = 1
		expandedPlayersCanvas.BorderSizePixel = 0
		expandedPlayersCanvas.ZIndex = 104
		expandedPlayersCanvas.Parent = expandedMapFrame

		-- Close button
		closeButton = Instance.new("TextButton")
		closeButton.Name = "CloseButton"
		closeButton.Size = UDim2.fromOffset(config.expanded.closeButton.size, config.expanded.closeButton.size)
		closeButton.Position = UDim2.new(1, -10, 0, 10)
		closeButton.AnchorPoint = Vector2.new(1, 0)
		closeButton.BackgroundColor3 = config.expanded.closeButton.backgroundColor
		closeButton.Text = config.expanded.closeButton.text
		closeButton.TextColor3 = config.expanded.closeButton.color
		closeButton.TextSize = config.expanded.closeButton.textSize
		closeButton.Font = Enum.Font.GothamBold
		closeButton.ZIndex = 105
		closeButton.Visible = false
		closeButton.Parent = expandedMapFrame
		closeButton.MouseButton1Click:Connect(collapseMap)

		-- Close button styling
		local closeCorner = Instance.new("UICorner")
		closeCorner.CornerRadius = UDim.new(0.5, 0)
		closeCorner.Parent = closeButton

		print("[Minimap] ✓ Expanded map frames created")
	end

	-- Set up RemoteEvent listeners
	local RemoteEvents = RemoteEventsModule.Events
	print("[Minimap] Setting up RemoteEvent listeners...")
	RemoteEvents.MinimapDataUpdated.OnClientEvent:Connect(function(data)
		print("[Minimap] ========== RECEIVED MINIMAP DATA ==========")
		print(`[Minimap] Data type: {typeof(data)}`)
		if data then
			print(`[Minimap] Grid: {data.gridWidth}x{data.gridHeight}`)
			print(`[Minimap] Terrain pixels: {#data.terrainPixels}`)
			print(`[Minimap] Zones: {#data.zones}`)
			print(`[Minimap] Structures: {#data.structures}`)
		end
		mapData = data
		renderTerrain()
		renderZones()
		renderStructures()
		print("[Minimap] ========== RENDER COMPLETE ==========")
	end)

	RemoteEvents.MinimapStructuresUpdated.OnClientEvent:Connect(function(structures)
		print("[Minimap] Received structure update from server")
		if mapData then
			mapData.structures = structures
			renderStructures()
		end
	end)

	-- Start player tracking
	trackingConnection = RunService.Heartbeat:Connect(updatePlayerPositions)

	-- Toggle visibility with hotkey
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		-- ESC to close expanded map
		if config.expanded.enabled and config.expanded.closeOnEscape and input.KeyCode == Enum.KeyCode.Escape then
			if isExpanded then
				collapseMap()
				return
			end
		end

		-- M to toggle minimap visibility
		if input.KeyCode == config.toggleKey then
			Minimap.toggle()
		end
	end)

	print("[Minimap] ✓ Minimap created")
	return minimapFrame
end

--- Update minimap (not used for real-time tracking, but required by interface)
function Minimap.update()
	-- Real-time updates handled by Heartbeat connection
end

--- Destroy and clean up
function Minimap.destroy()
	if trackingConnection then
		trackingConnection:Disconnect()
		trackingConnection = nil
	end

	if minimapFrame then
		minimapFrame:Destroy()
		minimapFrame = nil
	end

	terrainCanvas = nil
	zonesCanvas = nil
	structuresCanvas = nil
	playersCanvas = nil
	mapData = nil
	table.clear(playerMarkerPool)
	table.clear(activePlayerMarkers)

	print("[Minimap] Destroyed")
end

--- Check if enabled
function Minimap.isEnabled(): boolean
	return config.enabled
end

--- Get component name
function Minimap.getName(): string
	return "Minimap"
end

return Minimap
