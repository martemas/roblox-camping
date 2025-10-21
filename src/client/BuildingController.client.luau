--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("RemoteEvents"))
local Utils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("Utils"))

local player = Players.LocalPlayer

local BuildingController = {
	_toolUnequipConnection = nil :: RBXScriptConnection?
}

-- Building state
local buildingMode = false
local currentBuildingItem: string? = nil
local placementConnection: RBXScriptConnection? = nil
local inputConnection: RBXScriptConnection? = nil
local previewModel: Model? = nil
local currentRotation = 0 -- Track preview rotation in degrees
local instructionGui: ScreenGui? = nil
local mobileControlsGui: ScreenGui? = nil



-- Create preview model
local function createPreviewModel(itemId: string): Model?
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		return nil
	end

	local shopItemsFolder = modelsFolder:FindFirstChild("ShopItems")
	if not shopItemsFolder then
		return nil
	end

	local itemTemplate = shopItemsFolder:FindFirstChild(itemId)
	if not itemTemplate then
		return nil
	end

	local preview = itemTemplate:Clone()
	preview.Parent = workspace
	preview.Name = "BuildingPreview"

	-- Make all parts semi-transparent and non-collidable (similar to ShopManager)
	local function makeTransparent(obj: Instance)
		if obj:IsA("BasePart") then
			obj.Transparency = 0.5
			obj.CanCollide = false
			obj.Material = Enum.Material.ForceField
			obj.Massless = true
			obj.BrickColor = BrickColor.new("Bright green") -- Green for valid placement
		end
		for _, child in obj:GetChildren() do
			makeTransparent(child)
		end
	end

	makeTransparent(preview)
	return preview
end

-- Create instruction GUI for building mode
local function createInstructionGui(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BuildingInstructions"
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Create frame for the instruction
	local frame = Instance.new("Frame")
	frame.Name = "InstructionFrame"
	frame.Size = UDim2.new(0, 250, 0, 60)
	frame.Position = UDim2.new(1, -270, 1, -80) -- Bottom right corner with margin
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	-- Add rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- Create text label
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "InstructionText"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.Position = UDim2.new(0, 0, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "Press R to rotate\nEsc/Q to cancel"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
	textLabel.TextWrapped = true
	textLabel.Font = Enum.Font.SourceSans
	textLabel.Parent = frame

	return screenGui
end

-- Create mobile control buttons for building mode
local function createMobileControls(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MobileBuildingControls"
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Container frame positioned above mobile controls (right side)
	local containerFrame = Instance.new("Frame")
	containerFrame.Name = "MobileControlsContainer"
	containerFrame.Size = UDim2.new(0, 120, 0, 160)
	containerFrame.Position = UDim2.new(1, -140, 1, -200) -- Right side, above mobile controls
	containerFrame.BackgroundTransparency = 1
	containerFrame.Parent = screenGui

	-- Rotate button
	local rotateButton = Instance.new("TextButton")
	rotateButton.Name = "RotateButton"
	rotateButton.Size = UDim2.new(0, 100, 0, 50)
	rotateButton.Position = UDim2.new(0, 10, 0, 0)
	rotateButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	rotateButton.BorderSizePixel = 2
	rotateButton.BorderColor3 = Color3.fromRGB(255, 255, 255)
	rotateButton.Text = "🔄 Rotate"
	rotateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	rotateButton.TextSize = 16
	rotateButton.Font = Enum.Font.SourceSansBold
	rotateButton.Parent = containerFrame

	-- Add rounded corners to rotate button
	local rotateCorner = Instance.new("UICorner")
	rotateCorner.CornerRadius = UDim.new(0, 8)
	rotateCorner.Parent = rotateButton

	-- Place button
	local placeButton = Instance.new("TextButton")
	placeButton.Name = "PlaceButton"
	placeButton.Size = UDim2.new(0, 100, 0, 50)
	placeButton.Position = UDim2.new(0, 10, 0, 60)
	placeButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
	placeButton.BorderSizePixel = 2
	placeButton.BorderColor3 = Color3.fromRGB(255, 255, 255)
	placeButton.Text = "✓ Place"
	placeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	placeButton.TextSize = 16
	placeButton.Font = Enum.Font.SourceSansBold
	placeButton.Parent = containerFrame

	-- Add rounded corners to place button
	local placeCorner = Instance.new("UICorner")
	placeCorner.CornerRadius = UDim.new(0, 8)
	placeCorner.Parent = placeButton

	-- Cancel button
	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "CancelButton"
	cancelButton.Size = UDim2.new(0, 100, 0, 40)
	cancelButton.Position = UDim2.new(0, 10, 0, 120)
	cancelButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
	cancelButton.BorderSizePixel = 2
	cancelButton.BorderColor3 = Color3.fromRGB(255, 255, 255)
	cancelButton.Text = "✕ Cancel"
	cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelButton.TextSize = 14
	cancelButton.Font = Enum.Font.SourceSansBold
	cancelButton.Parent = containerFrame

	-- Add rounded corners to cancel button
	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelButton

	-- Connect button events
	rotateButton.Activated:Connect(function()
		if buildingMode then
			-- Rotate preview by 15 degrees
			currentRotation = currentRotation + 15
			if currentRotation >= 360 then
				currentRotation = currentRotation - 360
			end
			print(`Mobile: Rotated preview to {currentRotation}°`) -- DEBUG
			updatePreviewPosition() -- Update immediately
		end
	end)

	placeButton.Activated:Connect(function()
		if buildingMode then
			print("Mobile: Place button pressed") -- DEBUG
			BuildingController.PlaceBuilding()
		end
	end)

	cancelButton.Activated:Connect(function()
		if buildingMode then
			print("Mobile: Cancel button pressed") -- DEBUG
			BuildingController.CancelBuilding()
		end
	end)

	return screenGui
end

-- Update preview position and rotation
local function updatePreviewPosition()
	if not buildingMode or not previewModel or not previewModel.Parent then
		return
	end

	local character = player.Character
	if not character or not character.PrimaryPart then
		return
	end

	-- Calculate position 6 studs in front of player
	local rootPart = character.PrimaryPart
	local forwardVector = rootPart.CFrame.LookVector
	local targetPosition = rootPart.Position + (forwardVector * (6 + (previewModel.PrimaryPart and previewModel.PrimaryPart.Size.Z / 2 or 0)))

	-- Find ground level at target position
	local groundLevel = Utils.findGroundLevel(targetPosition)

	-- Calculate height offset to position bottom of model on ground
	local heightOffset = 0
	if previewModel:IsA("Model") then
		if previewModel.PrimaryPart then
			heightOffset = previewModel.PrimaryPart.Size.Y / 2
		else
			local firstPart = previewModel:FindFirstChildOfClass("BasePart")
			if firstPart then
				heightOffset = firstPart.Size.Y / 2
			end
		end
	elseif previewModel:IsA("BasePart") then
		heightOffset = previewModel.Size.Y / 2
	end

	local finalPosition = vector.create(targetPosition.X, groundLevel.Y + heightOffset, targetPosition.Z)

	-- Create rotation based on player facing + current rotation
	local playerRotation = math.atan2(-rootPart.CFrame.LookVector.X, -rootPart.CFrame.LookVector.Z)
	local totalRotation = playerRotation + math.rad(currentRotation)
	local rotationCFrame = CFrame.new(finalPosition) * CFrame.Angles(0, totalRotation, 0)

	-- Position preview model
	if previewModel:IsA("Model") then
		if previewModel.PrimaryPart then
			previewModel.PrimaryPart.CFrame = rotationCFrame
		else
			previewModel:MoveTo(finalPosition)
			-- Apply rotation to first part if no PrimaryPart
			local firstPart = previewModel:FindFirstChildOfClass("BasePart")
			if firstPart then
				firstPart.CFrame = rotationCFrame
			end
		end
	elseif previewModel:IsA("BasePart") then
		previewModel.CFrame = rotationCFrame
	end
end

-- Start building mode
local function startBuildingMode(itemId: string)
	print('Starting building workflow') -- DEBUG
	if buildingMode then
		-- Cancel previous building mode
		BuildingController.CancelBuilding()
	end

	buildingMode = true
	currentBuildingItem = itemId
	currentRotation = 0

	-- Create preview model
	previewModel = createPreviewModel(itemId)
	if not previewModel then
		warn(`Failed to create preview for {itemId}`)
		BuildingController.CancelBuilding()
		return
	end

	-- Create instruction GUI for keyboard users
	if UserInputService.KeyboardEnabled then
		instructionGui = createInstructionGui()
	end

	-- Create mobile controls for touch devices
	if UserInputService.TouchEnabled then
		mobileControlsGui = createMobileControls()
		print("Created mobile building controls for touch device") -- DEBUG
		print(`DEBUG: TouchEnabled={UserInputService.TouchEnabled}, KeyboardEnabled={UserInputService.KeyboardEnabled}`) -- DEBUG
	end

	-- Start updating preview position (runs every 10 frames for performance)
	local frameCounter = 0
	placementConnection = RunService.Heartbeat:Connect(function()
		frameCounter = frameCounter + 1
		if frameCounter % 1 ~= 0 then return end -- Run every 10 frames

		updatePreviewPosition()
	end)

	-- Handle keyboard input for cancellation and rotation
	inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		-- Only handle input if we're actually in building mode
		if not buildingMode then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Q then
			print("Escape/Q detected - cancelling building") -- DEBUG
			BuildingController.CancelBuilding()
		elseif input.KeyCode == Enum.KeyCode.R then
			-- Rotate preview by 45 degrees
			currentRotation = currentRotation + 15
			if currentRotation >= 360 then
				currentRotation = currentRotation - 360
			end
			print(`DEBUG: Rotated preview to {currentRotation}°`) -- DEBUG
			updatePreviewPosition() -- Update immediately
		end
	end)

	-- Monitor for tool unequipping to cancel building mode
	local character = player.Character
	if character then
		local toolUnequipConnection
		toolUnequipConnection = character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("BuildingItem") == itemId then
				print("Building tool was unequipped - cancelling building mode")
				BuildingController.CancelBuilding()
				toolUnequipConnection:Disconnect()
			end
		end)

		-- Store the connection so we can clean it up later
		BuildingController._toolUnequipConnection = toolUnequipConnection
	end

	print(`Started building mode for {itemId}`)
end

-- Place the building
function BuildingController.PlaceBuilding()
	if not buildingMode or not currentBuildingItem or not previewModel then
		print("Cannot place building - not in building mode or missing preview")
		return
	end

	-- Get placement position and rotation from preview model
	local placementCFrame
	if previewModel:IsA("Model") then
		if previewModel.PrimaryPart then
			placementCFrame = previewModel.PrimaryPart.CFrame
		else
			local firstPart = previewModel:FindFirstChildOfClass("BasePart")
			if firstPart then
				placementCFrame = firstPart.CFrame
			else
				print("Cannot determine placement position from preview")
				return
			end
		end
	elseif previewModel:IsA("BasePart") then
		placementCFrame = previewModel.CFrame
	else
		print("Invalid preview model type")
		return
	end

	-- Send placement request to server with position and rotation
	RemoteEvents.Events.PlaceBuilding:FireServer(currentBuildingItem, placementCFrame)

	-- Clean up building mode after successful placement (destroy tool since it was used)
	BuildingController.CancelBuilding(false)
end

-- Cancel building mode without destroying the tool
function BuildingController.CancelBuilding(preserveTool: boolean?)
	-- Only cancel if we're actually in building mode
	if not buildingMode then
		print("Not in building mode - ignoring cancel request")
		return
	end

	print("Cancelling building mode") -- DEBUG

	buildingMode = false
	local buildingItemId = currentBuildingItem
	currentBuildingItem = nil

	-- Clean up connections FIRST to stop the loop
	if placementConnection then
		placementConnection:Disconnect()
		placementConnection = nil
		print("Disconnected placement connection") -- DEBUG
	end

	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
		print("Disconnected input connection") -- DEBUG
	end

	-- Clean up tool unequip connection
	if BuildingController._toolUnequipConnection then
		BuildingController._toolUnequipConnection:Disconnect()
		BuildingController._toolUnequipConnection = nil
		print("Disconnected tool unequip connection") -- DEBUG
	end

	-- Clean up preview model
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
		print("Destroyed preview model") -- DEBUG
	end

	-- Clean up instruction GUI
	if instructionGui then
		instructionGui:Destroy()
		instructionGui = nil
		print("Destroyed instruction GUI") -- DEBUG
	end

	-- Clean up mobile controls GUI
	if mobileControlsGui then
		mobileControlsGui:Destroy()
		mobileControlsGui = nil
		print("Destroyed mobile controls GUI") -- DEBUG
	end

	-- Unequip the tool but don't destroy it (unless preserveTool is false)
	local character = player.Character
	if character and buildingItemId then
		local tool = character:FindFirstChild(buildingItemId)
		if tool and tool:IsA("Tool") and tool:GetAttribute("BuildingItem") == buildingItemId then
			if preserveTool == false then
				-- Only destroy tool if explicitly requested (like after successful placement)
				tool:Destroy()
				print("Destroyed building tool") -- DEBUG
			else
				-- Move tool back to backpack
				local backpack = player:FindFirstChild("Backpack")
				if backpack then
					tool.Parent = backpack
					print("Moved building tool back to backpack") -- DEBUG
				end
			end
		end
	end

	-- Reset rotation
	currentRotation = 0

	print("Building mode cancelled successfully")
end

-- Handle tool activation for building placement
local function onBuildingToolActivated(itemId: string)
	print("Building tool activated - placing building") -- DEBUG
	BuildingController.PlaceBuilding()
end

-- Connect to remote events
RemoteEvents.Events.StartBuildingMode.OnClientEvent:Connect(startBuildingMode)
RemoteEvents.Events.ActivateBuildingTool.OnClientEvent:Connect(onBuildingToolActivated)

-- Export to global for other scripts to access
_G.BuildingController = BuildingController

return BuildingController