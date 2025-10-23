--!strict

--[[
	Shop UI Component

	Displays shop interface with purchasable items.
	Includes shop button to open/close the shop frame.

	Usage:
		local Shop = require(...)
		Shop.create(screenGui)
		Shop.updateShop(shopData, teamResources)
		Shop.open()
		Shop.close()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))

local Shop = UIComponent.new("Shop")

-- Component state
local shopButton: TextButton? = nil
local shopFrame: Frame? = nil
local parentGui: ScreenGui? = nil

--[[
	Create a shop item display

	@param itemId - Item identifier
	@param itemData - Item data (name, description, cost)
	@param teamResources - Team resources data
	@param yPosition - Y position for the item frame
]]
local function createShopItem(itemId: string, itemData: any, teamResources: any, yPosition: number)
	if not shopFrame then
		return
	end

	local config = UIConfig.shop
	local contentFrame = shopFrame:FindFirstChild("ContentFrame") :: ScrollingFrame

	local itemFrame = Instance.new("Frame")
	itemFrame.Name = itemId
	itemFrame.Size = UDim2.new(1, -10, 0, config.itemHeight)
	itemFrame.Position = UDim2.new(0, 5, 0, yPosition)
	itemFrame.BackgroundColor3 = config.itemBackgroundColor
	itemFrame.BorderSizePixel = 2
	itemFrame.BorderColor3 = config.itemBorderColor
	itemFrame.Parent = contentFrame

	-- Item Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.4, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.name
	nameLabel.TextColor3 = config.textColor
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.Parent = itemFrame

	-- Item Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(0.4, 0, 0.5, 0)
	descLabel.Position = UDim2.new(0, 10, 0.5, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = itemData.description
	descLabel.TextColor3 = config.descTextColor
	descLabel.TextScaled = true
	descLabel.Font = Enum.Font.SourceSans
	descLabel.Parent = itemFrame

	-- Cost Display
	local costText = {}
	for resourceId, cost in itemData.cost do
		if cost > 0 then
			local hasEnough = (teamResources[resourceId] or 0) >= cost
			local colorHex = if hasEnough then "rgb(0,255,0)" else "rgb(255,0,0)"
			table.insert(costText, `<font color="{colorHex}">{cost} {resourceId}</font>`)
		end
	end

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.Size = UDim2.new(0.35, 0, 1, 0)
	costLabel.Position = UDim2.new(0.4, 0, 0, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.RichText = true
	costLabel.Text = table.concat(costText, "\n")
	costLabel.TextColor3 = config.textColor
	costLabel.TextScaled = false
	costLabel.TextSize = 32
	costLabel.TextXAlignment = Enum.TextXAlignment.Center
	costLabel.TextYAlignment = Enum.TextYAlignment.Center
	costLabel.Font = Enum.Font.SourceSans
	costLabel.Parent = itemFrame

	-- Purchase Button
	local purchaseButton = Instance.new("TextButton")
	purchaseButton.Name = "PurchaseButton"
	purchaseButton.Size = UDim2.new(0.2, -10, 0.6, 0)
	purchaseButton.Position = UDim2.new(0.8, 0, 0.2, 0)
	purchaseButton.BackgroundColor3 = config.purchaseButtonColor
	purchaseButton.BorderSizePixel = 1
	purchaseButton.BorderColor3 = config.purchaseButtonBorderColor
	purchaseButton.Text = "BUY"
	purchaseButton.TextColor3 = config.textColor
	purchaseButton.TextScaled = true
	purchaseButton.Font = config.font

	-- Check if can afford
	local canAfford = true
	for resourceId, cost in itemData.cost do
		if cost > 0 and (teamResources[resourceId] or 0) < cost then
			canAfford = false
			break
		end
	end

	if not canAfford then
		purchaseButton.BackgroundColor3 = config.purchaseButtonDisabledColor
		purchaseButton.BorderColor3 = config.purchaseButtonDisabledColor
		purchaseButton.TextColor3 = Color3.fromRGB(150, 150, 150)
	else
		purchaseButton.Activated:Connect(function()
			RemoteEvents.Events.PurchaseItem:FireServer(itemId)
			Shop.close() -- Close shop after purchase
		end)
	end

	purchaseButton.Parent = itemFrame
end

--[[
	Create the Shop UI

	@param parent - Parent ScreenGui
	@return The shop button (main UI element)
]]
function Shop.create(parent: ScreenGui): TextButton
	local config = UIConfig.shop
	parentGui = parent

	-- Shop Button (Top Right)
	shopButton = Instance.new("TextButton")
	shopButton.Name = "ShopButton"
	shopButton.Size = UIConfig.createUDim2(config.buttonSize)
	shopButton.Position = UIConfig.createUDim2(config.buttonPosition)
	shopButton.BackgroundColor3 = config.buttonBackgroundColor
	shopButton.BorderSizePixel = 2
	shopButton.BorderColor3 = config.buttonBorderColor
	shopButton.Text = "SHOP"
	shopButton.TextColor3 = config.textColor
	shopButton.TextScaled = true
	shopButton.Font = config.font
	shopButton.Parent = parent

	-- Shop Frame (Initially Hidden)
	shopFrame = Instance.new("Frame")
	shopFrame.Name = "ShopFrame"
	shopFrame.Size = UIConfig.createUDim2(config.frameSize)
	shopFrame.Position = UIConfig.createUDim2(config.framePosition)
	shopFrame.BackgroundColor3 = config.frameBackgroundColor
	shopFrame.BorderSizePixel = 3
	shopFrame.BorderColor3 = config.frameBorderColor
	shopFrame.Visible = false
	shopFrame.Parent = parent

	-- Shop Title
	local shopTitle = Instance.new("TextLabel")
	shopTitle.Name = "ShopTitle"
	shopTitle.Size = UDim2.new(1, 0, 0, 40)
	shopTitle.Position = UDim2.new(0, 0, 0, 0)
	shopTitle.BackgroundTransparency = 1
	shopTitle.Text = "SHOP"
	shopTitle.TextColor3 = config.textColor
	shopTitle.TextScaled = true
	shopTitle.Font = config.font
	shopTitle.Parent = shopFrame

	-- Shop Close Button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = config.closeButtonColor
	closeButton.BorderSizePixel = 1
	closeButton.BorderColor3 = config.closeButtonBorderColor
	closeButton.Text = "X"
	closeButton.TextColor3 = config.textColor
	closeButton.TextScaled = true
	closeButton.Font = config.font
	closeButton.Parent = shopFrame

	-- Shop Content Frame
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -20, 1, -60)
	contentFrame.Position = UDim2.new(0, 10, 0, 50)
	contentFrame.BackgroundColor3 = config.scrollBackgroundColor
	contentFrame.BorderSizePixel = 1
	contentFrame.BorderColor3 = config.frameBorderColor
	contentFrame.ScrollBarThickness = config.scrollBarThickness
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be set dynamically
	contentFrame.Parent = shopFrame

	-- Connect button events
	shopButton.Activated:Connect(function()
		Shop.open()
	end)

	closeButton.Activated:Connect(function()
		Shop.close()
	end)

	print("[Shop] Component created")
	return shopButton
end

--[[
	Update shop display with items and team resources

	@param shopData - Shop items data
	@param teamResources - Team resources data
]]
function Shop.update(shopData: any, teamResources: any)
	if not shopFrame then
		warn("[Shop] Cannot update: component not created")
		return
	end

	local config = UIConfig.shop
	local contentFrame = shopFrame:FindFirstChild("ContentFrame") :: ScrollingFrame

	-- Clear existing items
	for _, child in contentFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Create shop items
	local yPosition = 5
	for itemId, itemData in shopData do
		createShopItem(itemId, itemData, teamResources, yPosition)
		yPosition += config.itemHeight + config.itemSpacing
	end

	-- Update canvas size
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, yPosition + 10)
end

--[[
	Open the shop
]]
function Shop.open()
	if shopFrame then
		shopFrame.Visible = true
		RemoteEvents.Events.OpenShop:FireServer()
	end
end

--[[
	Close the shop
]]
function Shop.close()
	if shopFrame then
		shopFrame.Visible = false
	end
end

--[[
	Toggle shop visibility
]]
function Shop.toggle()
	if shopFrame then
		if shopFrame.Visible then
			Shop.close()
		else
			Shop.open()
		end
	end
end

--[[
	Destroy the component
]]
function Shop.destroy()
	if shopButton then
		shopButton:Destroy()
		shopButton = nil
	end

	if shopFrame then
		shopFrame:Destroy()
		shopFrame = nil
	end

	print("[Shop] Component destroyed")
end

--[[
	Check if component is enabled in UIConfig

	@return boolean
]]
function Shop.isEnabled(): boolean
	return UIConfig.shop.enabled
end

return Shop
