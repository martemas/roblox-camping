--!strict

--[[
	PickupHelper - Client-side smart item pickup system

	Features:
	- Auto-detects nearest dropped item within range
	- Highlights current target item with golden glow
	- Press F to pickup (configurable via PlayerSettings)
	- Camera-independent (no need to look at items)
	- Chain pickup: Automatically selects next item after pickup
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))
local PlayerSettings = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Player"):WaitForChild("PlayerSettings"))

local PICKUP_RANGE = 10 -- studs
local UPDATE_INTERVAL = 0.1 -- seconds

local currentTargetItem: Model? = nil
local lastUpdateTime = 0
local pickupKey = Enum.KeyCode.F -- Default, will be updated from settings

-- Get pickup key from player settings
local function updatePickupKey()
	local defaultSettings = PlayerSettings.getDefaultSettings()
	pickupKey = defaultSettings.gameplay.controls.pickupItemKey
end

-- Find nearest dropped item within range
local function findNearestItem(): Model?
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
	local shortestDistance = PICKUP_RANGE

	for _, item in droppedItemsFolder:GetChildren() do
		if item:IsA("Model") and item:GetAttribute("IsDroppedItem") then
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

-- Update highlight on current target
local function updateTargetHighlight(newTarget: Model?)
	-- Clear old highlight
	if currentTargetItem and currentTargetItem.Parent then
		local oldHighlight = currentTargetItem:FindFirstChild("PickupHighlight")
		if oldHighlight and oldHighlight:IsA("Highlight") then
			oldHighlight.Enabled = false
		end
	end

	-- Set new highlight
	currentTargetItem = newTarget
	if currentTargetItem then
		local newHighlight = currentTargetItem:FindFirstChild("PickupHighlight")
		if newHighlight and newHighlight:IsA("Highlight") then
			newHighlight.Enabled = true
		end
	end
end

-- Update loop (runs every UPDATE_INTERVAL)
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastUpdateTime < UPDATE_INTERVAL then
		return
	end
	lastUpdateTime = now

	local nearestItem = findNearestItem()

	-- Update highlight if target changed
	if nearestItem ~= currentTargetItem then
		updateTargetHighlight(nearestItem)
	end
end)

-- Handle F key press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == pickupKey and currentTargetItem then
		-- Send pickup request to server
		RemoteEvents.Events.PickupItem:FireServer(currentTargetItem)

		-- Immediately clear highlight (optimistic update)
		-- The update loop will automatically select the next nearest item
		updateTargetHighlight(nil)
	end
end)

-- Initialize pickup key from settings
updatePickupKey()

print("✓ PickupHelper initialized (Press F to pickup nearest item)")
