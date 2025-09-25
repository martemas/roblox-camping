--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local Utils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"))

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
		for _, child in pairs(obj:GetChildren()) do
			makeTransparent(child)
		end
	end

	makeTransparent(preview)
	return preview
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
	local targetPosition = rootPart.Position + (forwardVector * 6)

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

	local finalPosition = Vector3.new(targetPosition.X, groundLevel.Y + heightOffset, targetPosition.Z)

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

	-- Start updating preview position (runs every 10 frames for performance)
	local frameCounter = 0
	placementConnection = RunService.Heartbeat:Connect(function()
		frameCounter = frameCounter + 1
		if frameCounter % 10 ~= 0 then return end -- Run every 10 frames

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

	-- Clean up building mode after successful placement
	BuildingController.CancelBuilding()
end

-- Cancel building mode
function BuildingController.CancelBuilding()
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

	-- Destroy the building tool
	local character = player.Character
	if character and buildingItemId then
		local tool = character:FindFirstChild(buildingItemId)
		if tool and tool:IsA("Tool") and tool:GetAttribute("BuildingItem") == buildingItemId then
			tool:Destroy()
			print("Destroyed building tool") -- DEBUG
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