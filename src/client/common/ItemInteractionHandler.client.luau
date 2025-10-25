--!strict

--[[
	ItemInteractionHandler - Hybrid item pickup and drag system

	Features:
	- Click item to select and highlight
	- Press F to store item (spam-friendly with auto-select next)
	- Click and drag to relocate item with physics
	- Throw items by releasing during fast drag
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local player = Players.LocalPlayer
local Engine = ReplicatedStorage:WaitForChild("Engine")
local RemoteEvents = require(Engine:WaitForChild("Core"):WaitForChild("RemoteEvents"))
local PlayerSettings = require(Engine:WaitForChild("Player"):WaitForChild("PlayerSettings"))

-- Wait for GameConfig from server
local GameConfig
task.spawn(function()
	local ServerEngine = ServerScriptService:WaitForChild("Engine", 10)
	if ServerEngine then
		GameConfig = require(ServerEngine:WaitForChild("Config"):WaitForChild("GameConfig"))
	end
end)

-- State
local selectedItem: Model? = nil
local isDragging = false
local dragStartMousePos: Vector2? = nil
local dragConnection: RBXScriptConnection? = nil
local storagePromptUI: BillboardGui? = nil
local positionHistory = {} -- For velocity calculation

-- Config (with defaults until GameConfig loads)
local DRAG_THRESHOLD = 20
local MAX_DRAG_DISTANCE = 20
local MAX_THROW_VELOCITY = 50
local pickupKey = Enum.KeyCode.F

-- Update config when GameConfig loads
task.spawn(function()
	while not GameConfig do
		task.wait(0.1)
	end
	DRAG_THRESHOLD = GameConfig.itemInteraction.dragThreshold
	MAX_DRAG_DISTANCE = GameConfig.itemInteraction.maxDragDistance
	MAX_THROW_VELOCITY = GameConfig.itemInteraction.maxThrowVelocity
end)

-- Raycast from mouse position to world
local function raycastFromMouse(mousePosition: Vector2): RaycastResult?
	local camera = workspace.CurrentCamera
	if not camera then return nil end

	local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character }

	return workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
end

-- Find item at mouse position
local function getItemAtMouse(mousePos: Vector2): Model?
	local result = raycastFromMouse(mousePos)
	if not result then
		return nil
	end

	local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
	if hitModel and hitModel:GetAttribute("IsDroppedItem") then
		return hitModel
	end
	return nil
end

-- Create storage prompt UI
local function createStoragePrompt(item: Model): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StoragePrompt"
	billboard.Size = UDim2.new(4, 0, 1.5, 0)
	billboard.StudsOffset = vector.create(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = item

	local button = Instance.new("TextButton")
	button.Name = "StoreButton"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
	button.Text = "📦 Store (F)"
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.SourceSansBold
	button.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = button

	-- Click handler for mobile
	button.MouseButton1Click:Connect(function()
		storeSelectedItem()
	end)

	return billboard
end

-- Find next nearest item for auto-selection
local function findNearestItem(excludeItem: Model?): Model?
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	local hrp = character.HumanoidRootPart
	local droppedItemsFolder = workspace:FindFirstChild("DroppedItems")
	if not droppedItemsFolder then
		return nil
	end

	local nearestItem: Model? = nil
	local shortestDistance = MAX_DRAG_DISTANCE

	for _, item in droppedItemsFolder:GetChildren() do
		if item:IsA("Model") and item ~= excludeItem and item:GetAttribute("IsDroppedItem") then
			local itemPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
			if itemPart then
				local distance = (itemPart.Position - hrp.Position).Magnitude
				if distance < shortestDistance then
					nearestItem = item
					shortestDistance = distance
				end
			end
		end
	end

	return nearestItem
end

-- Select an item
local function selectItem(item: Model)
	-- Deselect previous
	if selectedItem then
		local oldHighlight = selectedItem:FindFirstChild("PickupHighlight")
		if oldHighlight and oldHighlight:IsA("Highlight") then
			oldHighlight.Enabled = false
		end
		if storagePromptUI then
			storagePromptUI:Destroy()
		end
	end

	-- Select new
	selectedItem = item

	-- Highlight
	local highlight = item:FindFirstChild("PickupHighlight")
	if highlight and highlight:IsA("Highlight") then
		highlight.Enabled = true
	end

	-- Show storage UI
	storagePromptUI = createStoragePrompt(item)
end

-- Store selected item and auto-select next
function storeSelectedItem()
	if not selectedItem then
		return
	end

	-- Send pickup request
	RemoteEvents.Events.PickupItem:FireServer(selectedItem)

	-- Store reference before clearing
	local oldItem = selectedItem

	-- Clear selection
	selectedItem = nil
	if storagePromptUI then
		storagePromptUI:Destroy()
		storagePromptUI = nil
	end

	-- Auto-select next nearest item
	local nextItem = findNearestItem(oldItem)
	if nextItem then
		selectItem(nextItem)
	end
end

-- Start dragging item
local function startDrag()
	if not selectedItem then
		return
	end

	isDragging = true

	-- Hide storage UI
	if storagePromptUI then
		storagePromptUI.Enabled = false
	end

	-- Disable collisions during drag for smooth movement
	for _, part in selectedItem:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	-- Notify server
	RemoteEvents.Events.StartDragItem:FireServer(selectedItem)

	-- Start drag update loop
	positionHistory = {}
	dragConnection = RunService.RenderStepped:Connect(function()
		updateDragPosition()
	end)
end

-- Update item position during drag
function updateDragPosition()
	if not selectedItem or not isDragging then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local mousePos = UserInputService:GetMouseLocation()

	-- Project mouse position into 3D space at fixed distance from camera
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local fixedDistance = 10 -- Distance from camera to hold item
	local targetPos = ray.Origin + (ray.Direction * fixedDistance)

	local playerPos = character.HumanoidRootPart.Position

	-- Check distance limit from player
	local distance = (targetPos - playerPos).Magnitude
	if distance > MAX_DRAG_DISTANCE then
		-- Clamp to max distance from player
		local direction = (targetPos - playerPos).Unit
		targetPos = playerPos + (direction * MAX_DRAG_DISTANCE)
	end

	-- Update item position on client immediately for smooth movement
	selectedItem:PivotTo(CFrame.new(targetPos))

	-- Store position for velocity calculation
	table.insert(positionHistory, {
		position = targetPos,
		time = tick(),
	})

	-- Keep only last 5 positions
	if #positionHistory > 5 then
		table.remove(positionHistory, 1)
	end

	-- Send to server for validation only (server doesn't update position during drag)
	RemoteEvents.Events.UpdateDragPosition:FireServer(selectedItem, targetPos)
end

-- Calculate throw velocity from position history
local function calculateThrowVelocity(): Vector3
	if #positionHistory < 2 then
		return vector.create(0, 0, 0)
	end

	local recent = positionHistory[#positionHistory]
	local previous = positionHistory[#positionHistory - 1]

	local deltaPos = recent.position - previous.position
	local deltaTime = recent.time - previous.time

	if deltaTime == 0 then
		return vector.create(0, 0, 0)
	end

	local velocity = deltaPos / deltaTime

	-- Clamp magnitude
	if velocity.Magnitude > MAX_THROW_VELOCITY then
		velocity = velocity.Unit * MAX_THROW_VELOCITY
	end

	return velocity
end

-- Wait for item to settle after physics simulation
local function waitForItemToSettle(item: Model, releaseVelocity: Vector3)
	local itemPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
	if not itemPart then
		return
	end

	local settleThreshold = 0.5 -- Velocity below this = settled
	local maxWaitTime = 5 -- Max 5 seconds to settle
	local checkInterval = 0.1 -- Check every 0.1 seconds
	local stableFrames = 0
	local requiredStableFrames = 3 -- Must be stable for 3 checks

	local startTime = tick()

	-- If release velocity was very small, item should settle quickly
	local isSlowDrop = releaseVelocity.Magnitude < 1

	while tick() - startTime < maxWaitTime do
		task.wait(checkInterval)

		if not itemPart or not itemPart.Parent then
			break
		end

		local currentVelocity = itemPart.AssemblyLinearVelocity.Magnitude

		if currentVelocity < settleThreshold then
			stableFrames += 1
			if stableFrames >= requiredStableFrames then
				-- Item has settled
				local finalPosition = itemPart.Position
				RemoteEvents.Events.ReleaseDragItem:FireServer(item, releaseVelocity, finalPosition)
				return
			end
		else
			stableFrames = 0
		end

		-- For slow drops, timeout faster
		if isSlowDrop and tick() - startTime > 2 then
			break
		end
	end

	-- Timeout - send current position anyway
	if itemPart and itemPart.Parent then
		local finalPosition = itemPart.Position
		RemoteEvents.Events.ReleaseDragItem:FireServer(item, releaseVelocity, finalPosition)
	end
end

-- End drag and apply throw
local function endDrag()
	if not isDragging or not selectedItem then
		return
	end

	isDragging = false

	-- Disconnect update loop
	if dragConnection then
		dragConnection:Disconnect()
		dragConnection = nil
	end

	-- Calculate throw velocity
	local velocity = calculateThrowVelocity()

	-- Re-enable collisions on client
	for _, part in selectedItem:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = true
		end
	end

	-- Apply physics on client
	local itemPart = selectedItem.PrimaryPart or selectedItem:FindFirstChildOfClass("BasePart")
	if itemPart then
		-- Clear existing velocity
		itemPart.AssemblyLinearVelocity = Vector3.zero
		itemPart.AssemblyAngularVelocity = Vector3.zero

		-- Apply throw velocity (let client physics simulate)
		if velocity.Magnitude >= 1 then
			itemPart.AssemblyLinearVelocity = velocity
		end
	end

	-- Store reference to item before clearing selectedItem
	local droppedItem = selectedItem

	-- Clear selection immediately so player can interact with other items
	selectedItem = nil
	if storagePromptUI then
		storagePromptUI:Destroy()
		storagePromptUI = nil
	end

	positionHistory = {}

	-- Wait for physics to settle, then notify server of final position
	task.spawn(function()
		waitForItemToSettle(droppedItem, velocity)
	end)
end

-- Input handlers
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	-- F key: Store selected item
	if input.KeyCode == pickupKey and selectedItem and not isDragging then
		storeSelectedItem()
		return
	end

	-- Mouse click: Select or start potential drag
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mousePos = UserInputService:GetMouseLocation()
		local item = getItemAtMouse(mousePos)

		if item then
			selectItem(item)
			dragStartMousePos = mousePos
		end
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	-- Detect drag
	if input.UserInputType == Enum.UserInputType.MouseMovement and dragStartMousePos then
		local currentPos = UserInputService:GetMouseLocation()
		local distance = (currentPos - dragStartMousePos).Magnitude

		if distance > DRAG_THRESHOLD and not isDragging and selectedItem then
			startDrag()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	-- Mouse release: End drag or keep selection
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isDragging then
			endDrag()
		end
		dragStartMousePos = nil
	end
end)

-- Update pickup key from settings
local function updatePickupKey()
	local settings = PlayerSettings.getDefaultSettings()
	pickupKey = settings.gameplay.controls.pickupItemKey
end

updatePickupKey()

print("✓ ItemInteractionHandler initialized")
print("  - Click item to select")
print("  - Press F to store (spam-friendly!)")
print("  - Click & drag to relocate/throw")
