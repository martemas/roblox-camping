--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage:WaitForChild("Games"):WaitForChild("Data"):WaitForChild("Items"))

local ItemValidator = {}

function ItemValidator.isStackable(itemId: string): boolean
	local itemData = Items.Database[itemId]
	return itemData and itemData.stackable or false
end

function ItemValidator.getMaxStack(itemId: string): number?
	local itemData = Items.Database[itemId]
	return itemData and itemData.maxStack
end

function ItemValidator.isDroppable(itemId: string): boolean
	local itemData = Items.Database[itemId]
	return itemData and itemData.droppable or false
end

function ItemValidator.canStack(itemId: string, currentStack: number, addAmount: number): boolean
	if not ItemValidator.isStackable(itemId) then
		return false
	end

	local maxStack = ItemValidator.getMaxStack(itemId)
	if not maxStack then
		return true -- No stack limit
	end

	return currentStack + addAmount <= maxStack
end

function ItemValidator.exists(itemId: string): boolean
	return Items.Database[itemId] ~= nil
end

function ItemValidator.getItemData(itemId: string): Items.ItemData?
	return Items.Database[itemId]
end

function ItemValidator.hasWeaponData(itemId: string): boolean
	local itemData = Items.Database[itemId]
	return itemData and itemData.weaponData ~= nil or false
end

function ItemValidator.hasToolData(itemId: string): boolean
	local itemData = Items.Database[itemId]
	return itemData and itemData.toolData ~= nil or false
end

function ItemValidator.hasConsumableData(itemId: string): boolean
	local itemData = Items.Database[itemId]
	return itemData and itemData.consumableData ~= nil or false
end

return ItemValidator
