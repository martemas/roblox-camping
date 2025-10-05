--!strict

--[[
	Inventory UI Component

	Displays player's inventory slots with item icons and quantities.

	Usage:
		local Inventory = require(...)
		Inventory.create(screenGui)
		Inventory.update(inventoryData)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

type PlayerInventory = Types.PlayerInventory

local Inventory = UIComponent.new("Inventory")

-- Component state
local inventoryFrame: Frame? = nil

--[[
	Create the Inventory UI

	@param parent - Parent ScreenGui
	@return The created Frame
]]
function Inventory.create(parent: ScreenGui): Frame
	local config = UIConfig.inventory

	-- Main Frame
	inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "InventoryFrame"
	inventoryFrame.Size = UIConfig.createUDim2(config.size)
	inventoryFrame.Position = UIConfig.createUDim2(config.position)
	inventoryFrame.BackgroundColor3 = config.backgroundColor
	inventoryFrame.BackgroundTransparency = config.backgroundTransparency
	inventoryFrame.BorderSizePixel = 2
	inventoryFrame.BorderColor3 = config.borderColor
	inventoryFrame.Parent = parent

	-- Title
	local invTitle = Instance.new("TextLabel")
	invTitle.Name = "Title"
	invTitle.Size = UDim2.new(1, 0, 0, 20)
	invTitle.Position = UDim2.new(0, 0, 0, 0)
	invTitle.BackgroundTransparency = 1
	invTitle.Text = "Inventory (0/5)"
	invTitle.TextColor3 = config.textColor
	invTitle.TextScaled = true
	invTitle.Font = config.font
	invTitle.Parent = inventoryFrame

	-- Create inventory slots
	for i = 1, GameConfig.player.inventorySize do
		local slot = Instance.new("Frame")
		slot.Name = `Slot{i}`
		slot.Size = UDim2.new(0, config.slotSize, 0, config.slotSize)
		slot.Position = UDim2.new(0, 10 + (i - 1) * (config.slotSize + config.slotSpacing), 0, 25)
		slot.BackgroundColor3 = config.slotEmptyColor
		slot.BorderSizePixel = 1
		slot.BorderColor3 = config.borderColor
		slot.Parent = inventoryFrame

		-- Slot icon (placeholder)
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, -4, 1, -4)
		icon.Position = UDim2.new(0, 2, 0, 2)
		icon.BackgroundTransparency = 1
		icon.Image = "" -- TODO: Set when icon assets are ready
		icon.Parent = slot

		-- Quantity label
		local quantity = Instance.new("TextLabel")
		quantity.Name = "Quantity"
		quantity.Size = UDim2.new(0.5, 0, 0.5, 0)
		quantity.Position = UDim2.new(0.5, 0, 0.5, 0)
		quantity.BackgroundTransparency = 1
		quantity.Text = ""
		quantity.TextColor3 = config.textColor
		quantity.TextScaled = true
		quantity.Font = config.font
		quantity.Parent = slot
	end

	print("[Inventory] Component created")
	return inventoryFrame
end

--[[
	Update the inventory display

	@param inventory - Player inventory data
]]
function Inventory.update(inventory: PlayerInventory)
	if not inventoryFrame then
		warn("[Inventory] Cannot update: component not created")
		return
	end

	local config = UIConfig.inventory
	local invTitle = inventoryFrame:FindFirstChild("Title") :: TextLabel

	if not invTitle then
		return
	end

	-- Calculate total items
	local totalItems = 0
	for _, amount in inventory do
		totalItems += amount
	end

	invTitle.Text = `Inventory ({totalItems}/{GameConfig.player.inventorySize})`

	-- Update slots
	local slotIndex = 1
	for resourceType, amount in inventory do
		if amount > 0 then
			local slot = inventoryFrame:FindFirstChild(`Slot{slotIndex}`)
			if slot then
				local icon = slot:FindFirstChild("Icon") :: ImageLabel
				local quantity = slot:FindFirstChild("Quantity") :: TextLabel

				-- TODO: Set icon image when UI assets are ready
				-- icon.Image = `rbxasset://textures/{resourceType}Icon.png`

				quantity.Text = tostring(amount)
				slot.BackgroundColor3 = config.slotFilledColor
				slotIndex += 1
			end
		end
	end

	-- Clear remaining slots
	for i = slotIndex, GameConfig.player.inventorySize do
		local slot = inventoryFrame:FindFirstChild(`Slot{i}`)
		if slot then
			local quantity = slot:FindFirstChild("Quantity") :: TextLabel
			quantity.Text = ""
			slot.BackgroundColor3 = config.slotEmptyColor
		end
	end
end

--[[
	Destroy the component
]]
function Inventory.destroy()
	if inventoryFrame then
		inventoryFrame:Destroy()
		inventoryFrame = nil
		print("[Inventory] Component destroyed")
	end
end

--[[
	Check if component is enabled in UIConfig

	@return boolean
]]
function Inventory.isEnabled(): boolean
	return UIConfig.inventory.enabled
end

return Inventory
