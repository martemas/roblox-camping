--!strict

--[[
	PickupSystem - Server-side item pickup validation and processing

	Handles item pickup requests from clients:
	- Validates proximity and inventory space
	- Adds items to inventory (auto-stacks via InventoryManager)
	- Destroys picked-up items
	- Anti-cheat: Distance validation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Engine = ServerScriptService:WaitForChild("Engine")
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))
local InventoryManager = require(Engine:WaitForChild("InventoryManager"))
local ItemValidator = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Systems"):WaitForChild("Inventory"):WaitForChild("ItemValidator"))

local PickupSystem = {}

local MAX_PICKUP_DISTANCE = 15 -- Anti-cheat: Slightly larger than client range
local pickedUpItems: {[Model]: boolean} = {} -- Track recently picked items to prevent double-pickup

-- Validate pickup request
local function validatePickup(player: Player, itemModel: Model): (boolean, string?)
	-- Check if item exists and hasn't been picked up
	if not itemModel or not itemModel.Parent or pickedUpItems[itemModel] then
		return false, "Item no longer exists"
	end

	-- Check if it's a valid dropped item
	if not itemModel:GetAttribute("IsDroppedItem") then
		return false, "Invalid item"
	end

	-- Check player distance (anti-cheat)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false, "Invalid character"
	end

	local itemPart = itemModel.PrimaryPart or itemModel:FindFirstChildOfClass("BasePart")
	if not itemPart then
		return false, "Invalid item model"
	end

	local distance = (itemPart.Position - character.HumanoidRootPart.Position).Magnitude
	if distance > MAX_PICKUP_DISTANCE then
		return false, "Too far away"
	end

	-- Check inventory space
	if not InventoryManager.HasSpace(player, 1) then
		return false, "Inventory full"
	end

	return true, nil
end

-- Handle pickup request from client
local function onPickupRequest(player: Player, itemModel: Model)
	local isValid, errorMsg = validatePickup(player, itemModel)

	if not isValid then
		warn(`[PickupSystem] {player.Name} failed to pickup: {errorMsg}`)
		return
	end

	-- Get item ID
	local itemId = itemModel:GetAttribute("ItemId")
	if not itemId then
		warn(`[PickupSystem] Item model missing ItemId attribute`)
		return
	end

	-- Add to inventory (auto-stacks via InventoryManager.AddItem)
	local success = InventoryManager.AddItem(player, itemId, 1)

	if success then
		-- Mark as picked up (prevent double-pickup)
		pickedUpItems[itemModel] = true

		-- Destroy item model
		itemModel:Destroy()

		-- Clean up tracking after a short delay
		task.delay(1, function()
			pickedUpItems[itemModel] = nil
		end)

		print(`[PickupSystem] {player.Name} picked up {itemId}`)
	else
		warn(`[PickupSystem] Failed to add {itemId} to {player.Name}'s inventory`)
	end
end

-- Initialize the pickup system
function PickupSystem.initialize()
	-- Connect remote event
	RemoteEvents.Events.PickupItem.OnServerEvent:Connect(onPickupRequest)

	print("[PickupSystem] ✓ Initialized")
end

return PickupSystem
