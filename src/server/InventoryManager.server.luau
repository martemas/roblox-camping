--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

type PlayerInventory = Types.PlayerInventory
type ResourceType = Types.ResourceType

local InventoryManager = {}
local playerInventories: {[Player]: PlayerInventory} = {}

-- Initialize empty inventory
local function createEmptyInventory(): PlayerInventory
	return {
		Wood = 0,
		Stone = 0,
		Metal = 0,
	}
end

-- Get total items in inventory
local function getInventoryCount(inventory: PlayerInventory): number
	local count = 0
	for _, amount in pairs(inventory) do
		count += amount
	end
	return count
end

-- Check if inventory has space for more items
local function hasInventorySpace(player: Player, amount: number?): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end

	local currentCount = getInventoryCount(inventory)
	local maxSize = GameConfig.player.inventorySize
	local requestedAmount = amount or 1

	return currentCount + requestedAmount <= maxSize
end

-- Add item to player inventory
local function addToInventory(player: Player, resourceType: ResourceType, amount: number): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end

	if not hasInventorySpace(player, amount) then
		return false
	end

	inventory[resourceType] += amount
	RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)
	return true
end

-- Remove item from player inventory
local function removeFromInventory(player: Player, resourceType: ResourceType, amount: number): boolean
	local inventory = playerInventories[player]
	if not inventory or inventory[resourceType] < amount then
		return false
	end

	inventory[resourceType] -= amount
	RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)
	return true
end

-- Clear entire inventory (used for warehouse deposits)
local function clearInventory(player: Player): PlayerInventory?
	local inventory = playerInventories[player]
	if not inventory then
		return nil
	end

	local clearedInventory = {}
	for resourceType, amount in pairs(inventory) do
		clearedInventory[resourceType] = amount
		inventory[resourceType] = 0
	end

	RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)
	return clearedInventory
end

-- Initialize player inventory when they join
local function onPlayerAdded(player: Player)
	playerInventories[player] = createEmptyInventory()

	-- Send initial empty inventory to client
	RemoteEvents.Events.UpdateInventory:FireClient(player, playerInventories[player])

	print(`Initialized inventory for {player.Name}`)
end

-- Clean up when player leaves
local function onPlayerRemoving(player: Player)
	playerInventories[player] = nil
	print(`Cleaned up inventory for {player.Name}`)
end

-- Handle remote function requests
local function onGetPlayerData(player: Player)
	local inventory = playerInventories[player]
	if not inventory then
		return createEmptyInventory()
	end
	return inventory
end

-- Public API
function InventoryManager.GetInventory(player: Player): PlayerInventory?
	return playerInventories[player]
end

function InventoryManager.GetInventoryCount(player: Player): number
	local inventory = playerInventories[player]
	if not inventory then
		return 0
	end
	return getInventoryCount(inventory)
end

function InventoryManager.HasSpace(player: Player, amount: number?): boolean
	return hasInventorySpace(player, amount)
end

function InventoryManager.AddItem(player: Player, resourceType: ResourceType, amount: number): boolean
	return addToInventory(player, resourceType, amount)
end

function InventoryManager.RemoveItem(player: Player, resourceType: ResourceType, amount: number): boolean
	return removeFromInventory(player, resourceType, amount)
end

function InventoryManager.ClearInventory(player: Player): PlayerInventory?
	return clearInventory(player)
end

function InventoryManager.GetMaxSize(): number
	return GameConfig.player.inventorySize
end

-- Initialize the inventory manager
local function initialize()
	-- Connect player events
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already in game
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Connect remote functions
	RemoteEvents.Functions.GetPlayerData.OnServerInvoke = onGetPlayerData

	print("InventoryManager initialized")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.InventoryManager = InventoryManager

return InventoryManager