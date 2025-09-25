--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

type PlayerInventory = Types.PlayerInventory
type TeamResources = Types.TeamResources
type GamePhase = Types.GamePhase

local GameUI = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI elements
local mainGui: ScreenGui
local inventoryFrame: Frame
local teamResourcesFrame: Frame
local phaseTimerFrame: Frame
local healthFrame: Frame
local staminaFrame: Frame
local notificationFrame: Frame
local shopButton: TextButton
local shopFrame: Frame

-- Create the main UI structure
local function createMainUI()
	-- Main ScreenGui
	mainGui = Instance.new("ScreenGui")
	mainGui.Name = "GameUI"
	mainGui.ResetOnSpawn = false
	mainGui.Parent = playerGui

	-- Inventory Frame (Bottom Left)
	inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "InventoryFrame"
	inventoryFrame.Size = UDim2.new(0, 300, 0, 80)
	inventoryFrame.Position = UDim2.new(0, 20, 1, -100)
	inventoryFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	inventoryFrame.BackgroundTransparency = 0.3
	inventoryFrame.BorderSizePixel = 2
	inventoryFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	inventoryFrame.Parent = mainGui

	-- Inventory Title
	local invTitle = Instance.new("TextLabel")
	invTitle.Name = "Title"
	invTitle.Size = UDim2.new(1, 0, 0, 20)
	invTitle.Position = UDim2.new(0, 0, 0, 0)
	invTitle.BackgroundTransparency = 1
	invTitle.Text = "Inventory (0/5)"
	invTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	invTitle.TextScaled = true
	invTitle.Font = Enum.Font.PermanentMarker
	invTitle.Parent = inventoryFrame

	-- Inventory Slots
	for i = 1, GameConfig.player.inventorySize do
		local slot = Instance.new("Frame")
		slot.Name = `Slot{i}`
		slot.Size = UDim2.new(0, 50, 0, 50)
		slot.Position = UDim2.new(0, 10 + (i-1) * 55, 0, 25)
		slot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		slot.BorderSizePixel = 1
		slot.BorderColor3 = Color3.fromRGB(120, 120, 120)
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
		quantity.TextColor3 = Color3.fromRGB(255, 255, 255)
		quantity.TextScaled = true
		quantity.Font = Enum.Font.PermanentMarker
		quantity.Parent = slot
	end

	-- Team Resources Frame (Top Middle)
	teamResourcesFrame = Instance.new("Frame")
	teamResourcesFrame.Name = "TeamResourcesFrame"
	teamResourcesFrame.Size = UDim2.new(0, 300, 0, 60)
	teamResourcesFrame.Position = UDim2.new(0.5, -150, 0, 20)
	teamResourcesFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	teamResourcesFrame.BackgroundTransparency = 0.3
	teamResourcesFrame.BorderSizePixel = 2
	teamResourcesFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	teamResourcesFrame.Parent = mainGui

	-- Team Resources Title
	local teamTitle = Instance.new("TextLabel")
	teamTitle.Name = "Title"
	teamTitle.Size = UDim2.new(1, 0, 0, 20)
	teamTitle.Position = UDim2.new(0, 0, 0, 0)
	teamTitle.BackgroundTransparency = 1
	teamTitle.Text = "Team Resources"
	teamTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	teamTitle.TextScaled = true
	teamTitle.Font = Enum.Font.PermanentMarker
	teamTitle.Parent = teamResourcesFrame

	-- Resource displays
	local resourceTypes = {"Wood", "Stone", "Metal"}
	for i, resourceType in pairs(resourceTypes) do
		local resourceLabel = Instance.new("TextLabel")
		resourceLabel.Name = resourceType
		resourceLabel.Size = UDim2.new(0.33, -5, 0, 30)
		resourceLabel.Position = UDim2.new((i-1) * 0.33, 5, 0, 25)
		resourceLabel.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		resourceLabel.BorderSizePixel = 1
		resourceLabel.BorderColor3 = Color3.fromRGB(120, 120, 120)
		resourceLabel.Text = `{resourceType}: 0`
		resourceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		resourceLabel.TextScaled = true
		resourceLabel.Font = Enum.Font.PermanentMarker
		resourceLabel.Parent = teamResourcesFrame
	end

	-- Phase Timer Frame (Middle of screen, below team resources)
	phaseTimerFrame = Instance.new("Frame")
	phaseTimerFrame.Name = "PhaseTimerFrame"
	phaseTimerFrame.Size = UDim2.new(0, 200, 0, 80)
	phaseTimerFrame.Position = UDim2.new(0.5, -100, 0, 90) -- Below team resources frame
	phaseTimerFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	phaseTimerFrame.BackgroundTransparency = 0.3
	phaseTimerFrame.BorderSizePixel = 2
	phaseTimerFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	phaseTimerFrame.Parent = mainGui

	-- Phase Label
	local phaseLabel = Instance.new("TextLabel")
	phaseLabel.Name = "PhaseLabel"
	phaseLabel.Size = UDim2.new(1, 0, 0.5, 0)
	phaseLabel.Position = UDim2.new(0, 0, 0, 0)
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.Text = "Day"
	phaseLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	phaseLabel.TextScaled = true
	phaseLabel.Font = Enum.Font.Creepster
	phaseLabel.Parent = phaseTimerFrame

	-- Timer Label
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(1, 0, 0.5, 0)
	timerLabel.Position = UDim2.new(0, 0, 0.5, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "5:00"
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.Creepster
	timerLabel.Parent = phaseTimerFrame

	-- Health Frame (Top Left)
	healthFrame = Instance.new("Frame")
	healthFrame.Name = "HealthFrame"
	healthFrame.Size = UDim2.new(0, 200, 0, 40)
	healthFrame.Position = UDim2.new(0, 20, 0, 20)
	healthFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	healthFrame.BackgroundTransparency = 0.3
	healthFrame.BorderSizePixel = 2
	healthFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	healthFrame.Parent = mainGui

	-- Health Bar Background
	local healthBg = Instance.new("Frame")
	healthBg.Name = "HealthBackground"
	healthBg.Size = UDim2.new(1, -10, 0, 20)
	healthBg.Position = UDim2.new(0, 5, 0, 15)
	healthBg.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	healthBg.BorderSizePixel = 0
	healthBg.Parent = healthFrame

	-- Health Bar Fill
	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.Position = UDim2.new(0, 0, 0, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBg

	-- Health Text
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 0, 15)
	healthText.Position = UDim2.new(0, 0, 0, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = "Health: 100/100"
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.PermanentMarker
	healthText.Parent = healthFrame

	-- Stamina Frame (Below Health)
	staminaFrame = Instance.new("Frame")
	staminaFrame.Name = "StaminaFrame"
	staminaFrame.Size = UDim2.new(0, 200, 0, 40)
	staminaFrame.Position = UDim2.new(0, 20, 0, 70) -- Below health frame
	staminaFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	staminaFrame.BackgroundTransparency = 0.3
	staminaFrame.BorderSizePixel = 2
	staminaFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	staminaFrame.Parent = mainGui

	-- Stamina Bar Background
	local staminaBg = Instance.new("Frame")
	staminaBg.Name = "StaminaBackground"
	staminaBg.Size = UDim2.new(1, -10, 0, 20)
	staminaBg.Position = UDim2.new(0, 5, 0, 15)
	staminaBg.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	staminaBg.BorderSizePixel = 0
	staminaBg.Parent = staminaFrame

	-- Stamina Bar Fill
	local staminaFill = Instance.new("Frame")
	staminaFill.Name = "StaminaFill"
	staminaFill.Size = UDim2.new(1, 0, 1, 0)
	staminaFill.Position = UDim2.new(0, 0, 0, 0)
	staminaFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255) -- Blue color for stamina
	staminaFill.BorderSizePixel = 0
	staminaFill.Parent = staminaBg

	-- Stamina Text
	local staminaText = Instance.new("TextLabel")
	staminaText.Name = "StaminaText"
	staminaText.Size = UDim2.new(1, 0, 0, 15)
	staminaText.Position = UDim2.new(0, 0, 0, 0)
	staminaText.BackgroundTransparency = 1
	staminaText.Text = "Stamina: 100/100"
	staminaText.TextColor3 = Color3.fromRGB(255, 255, 255)
	staminaText.TextScaled = true
	staminaText.Font = Enum.Font.PermanentMarker
	staminaText.Parent = staminaFrame

	-- Notification Frame (Center)
	notificationFrame = Instance.new("Frame")
	notificationFrame.Name = "NotificationFrame"
	notificationFrame.Size = UDim2.new(0, 400, 0, 60)
	notificationFrame.Position = UDim2.new(0.5, -200, 0.3, 0)
	notificationFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notificationFrame.BackgroundTransparency = 0.5
	notificationFrame.BorderSizePixel = 2
	notificationFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	notificationFrame.Visible = false
	notificationFrame.Parent = mainGui

	local notificationText = Instance.new("TextLabel")
	notificationText.Name = "NotificationText"
	notificationText.Size = UDim2.new(1, -10, 1, -10)
	notificationText.Position = UDim2.new(0, 5, 0, 5)
	notificationText.BackgroundTransparency = 1
	notificationText.Text = ""
	notificationText.TextColor3 = Color3.fromRGB(255, 255, 255)
	notificationText.TextScaled = true
	notificationText.Font = Enum.Font.PermanentMarker
	notificationText.TextWrapped = true
	notificationText.Parent = notificationFrame

	-- Shop Button (Top Right)
	shopButton = Instance.new("TextButton")
	shopButton.Name = "ShopButton"
	shopButton.Size = UDim2.new(0, 80, 0, 40)
	shopButton.Position = UDim2.new(1, -100, 0, 20)
	shopButton.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
	shopButton.BorderSizePixel = 2
	shopButton.BorderColor3 = Color3.fromRGB(150, 200, 150)
	shopButton.Text = "SHOP"
	shopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	shopButton.TextScaled = true
	shopButton.Font = Enum.Font.PermanentMarker
	shopButton.Parent = mainGui

	-- Shop Frame (Initially Hidden)
	shopFrame = Instance.new("Frame")
	shopFrame.Name = "ShopFrame"
	shopFrame.Size = UDim2.new(0, 500, 0, 400)
	shopFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
	shopFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	shopFrame.BorderSizePixel = 3
	shopFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	shopFrame.Visible = false
	shopFrame.Parent = mainGui

	-- Shop Title
	local shopTitle = Instance.new("TextLabel")
	shopTitle.Name = "ShopTitle"
	shopTitle.Size = UDim2.new(1, 0, 0, 40)
	shopTitle.Position = UDim2.new(0, 0, 0, 0)
	shopTitle.BackgroundTransparency = 1
	shopTitle.Text = "SHOP"
	shopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	shopTitle.TextScaled = true
	shopTitle.Font = Enum.Font.PermanentMarker
	shopTitle.Parent = shopFrame

	-- Shop Close Button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.BorderSizePixel = 1
	closeButton.BorderColor3 = Color3.fromRGB(255, 100, 100)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.PermanentMarker
	closeButton.Parent = shopFrame

	-- Shop Content Frame
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -20, 1, -60)
	contentFrame.Position = UDim2.new(0, 10, 0, 50)
	contentFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	contentFrame.BorderSizePixel = 1
	contentFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	contentFrame.ScrollBarThickness = 8
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be set dynamically
	contentFrame.Parent = shopFrame

	print("Game UI created")
end

-- Update inventory display
local function updateInventoryUI(inventory: PlayerInventory)
	local invTitle = inventoryFrame:FindFirstChild("Title") :: TextLabel
	if not invTitle then return end

	-- Calculate total items
	local totalItems = 0
	for _, amount in pairs(inventory) do
		totalItems += amount
	end

	invTitle.Text = `Inventory ({totalItems}/{GameConfig.player.inventorySize})`

	-- Update slots
	local slotIndex = 1
	for resourceType, amount in pairs(inventory) do
		if amount > 0 then
			local slot = inventoryFrame:FindFirstChild(`Slot{slotIndex}`)
			if slot then
				local icon = slot:FindFirstChild("Icon") :: ImageLabel
				local quantity = slot:FindFirstChild("Quantity") :: TextLabel

				-- TODO: Set icon image when UI assets are ready
				-- icon.Image = `rbxasset://textures/{resourceType}Icon.png`

				quantity.Text = tostring(amount)
				slot.BackgroundColor3 = Color3.fromRGB(100, 150, 100) -- Filled slot color
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
			slot.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- Empty slot color
		end
	end
end

-- Update team resources display
local function updateTeamResourcesUI(teamResources: TeamResources)
	for resourceType, amount in pairs(teamResources) do
		local label = teamResourcesFrame:FindFirstChild(resourceType) :: TextLabel
		if label then
			label.Text = `{resourceType}: {amount}`
		end
	end
end

-- Update phase timer display
local function updatePhaseTimerUI(phase: GamePhase, remainingTime: number)
	local phaseLabel = phaseTimerFrame:FindFirstChild("PhaseLabel") :: TextLabel
	local timerLabel = phaseTimerFrame:FindFirstChild("TimerLabel") :: TextLabel

	if phaseLabel then
		phaseLabel.Text = phase
		-- Change color based on phase
		if phase == "Day" then
			phaseLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
		elseif phase == "Night" then
			phaseLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red
		else
			phaseLabel.TextColor3 = Color3.fromRGB(200, 200, 200) -- Gray
		end
	end

	if timerLabel then
		local minutes = math.floor(remainingTime / 60)
		local seconds = math.floor(remainingTime % 60)
		timerLabel.Text = string.format("%d:%02d", minutes, seconds)
	end
end

-- Update health display
local function updateHealthUI()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local healthText = healthFrame:FindFirstChild("HealthText") :: TextLabel
	local healthFill = healthFrame:FindFirstChild("HealthBackground"):FindFirstChild("HealthFill") :: Frame?

	if healthText then
		healthText.Text = `Health: {math.floor(humanoid.Health)}/{math.floor(humanoid.MaxHealth)}`
	end

	if healthFill then
		local healthPercent = humanoid.Health / humanoid.MaxHealth
		healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)

		-- Change color based on health
		if healthPercent > 0.6 then
			healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Green
		elseif healthPercent > 0.3 then
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
		else
			healthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
		end
	end
end

-- Update stamina UI
local function updateStaminaUI(currentStamina: number, maxStamina: number)
	if not staminaFrame then return end

	local staminaText = staminaFrame:FindFirstChild("StaminaText") :: TextLabel?
	local staminaBg = staminaFrame:FindFirstChild("StaminaBackground") :: Frame?
	local staminaFill = staminaBg and staminaBg:FindFirstChild("StaminaFill") :: Frame?

	if staminaText then
		staminaText.Text = `Stamina: {math.floor(currentStamina)}/{math.floor(maxStamina)}`
	end

	if staminaFill then
		local staminaPercent = currentStamina / maxStamina
		staminaFill.Size = UDim2.new(staminaPercent, 0, 1, 0)

		-- Change color based on stamina
		if staminaPercent > 0.6 then
			staminaFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255) -- Blue
		elseif staminaPercent > 0.3 then
			staminaFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0) -- Orange
		else
			staminaFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100) -- Light Red
		end
	end
end

-- Open shop
local function openShop()
	shopFrame.Visible = true
	RemoteEvents.Events.OpenShop:FireServer()
end

-- Close shop
local function closeShop()
	shopFrame.Visible = false
end

-- Create shop item display
local function createShopItem(itemId: string, itemData: any, teamResources: any, yPosition: number)
	local contentFrame = shopFrame:FindFirstChild("ContentFrame") :: ScrollingFrame

	local itemFrame = Instance.new("Frame")
	itemFrame.Name = itemId
	itemFrame.Size = UDim2.new(1, -10, 0, 80)
	itemFrame.Position = UDim2.new(0, 5, 0, yPosition)
	itemFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	itemFrame.BorderSizePixel = 2
	itemFrame.BorderColor3 = Color3.fromRGB(120, 120, 120)
	itemFrame.Parent = contentFrame

	-- Item Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.4, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
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
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.TextScaled = true
	descLabel.Font = Enum.Font.SourceSans
	descLabel.Parent = itemFrame

	-- Cost Display
	local costText = {}
	for resourceType, cost in pairs(itemData.cost) do
		if cost > 0 then
			local hasEnough = (teamResources[resourceType] or 0) >= cost
			local color = hasEnough and "rgb(0,255,0)" or "rgb(255,0,0)"
			table.insert(costText, `<font color="{color}">{cost} {resourceType}</font>`)
		end
	end

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.Size = UDim2.new(0.35, 0, 1, 0)
	costLabel.Position = UDim2.new(0.4, 0, 0, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.RichText = true
	costLabel.Text = table.concat(costText, "\n")
	costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
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
	purchaseButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
	purchaseButton.BorderSizePixel = 1
	purchaseButton.BorderColor3 = Color3.fromRGB(150, 255, 150)
	purchaseButton.Text = "BUY"
	purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	purchaseButton.TextScaled = true
	purchaseButton.Font = Enum.Font.PermanentMarker

	-- Check if can afford
	local canAfford = true
	for resourceType, cost in pairs(itemData.cost) do
		if cost > 0 and (teamResources[resourceType] or 0) < cost then
			canAfford = false
			break
		end
	end

	if not canAfford then
		purchaseButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		purchaseButton.BorderColor3 = Color3.fromRGB(120, 120, 120)
		purchaseButton.TextColor3 = Color3.fromRGB(150, 150, 150)
	else
		purchaseButton.Activated:Connect(function()
			RemoteEvents.Events.PurchaseItem:FireServer(itemId)
			closeShop() -- Close shop after purchase
		end)
	end

	purchaseButton.Parent = itemFrame
end

-- Update shop display
local function updateShopUI(shopData: any, teamResources: any)
	local contentFrame = shopFrame:FindFirstChild("ContentFrame") :: ScrollingFrame

	-- Clear existing items
	for _, child in pairs(contentFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Create shop items
	local yPosition = 5
	for itemId, itemData in pairs(shopData) do
		createShopItem(itemId, itemData, teamResources, yPosition)
		yPosition += 90
	end

	-- Update canvas size
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, yPosition + 10)
end

-- Show notification
local function showNotification(message: string)
	local notificationText = notificationFrame:FindFirstChild("NotificationText") :: TextLabel
	if not notificationText then return end

	notificationText.Text = message
	notificationFrame.Visible = true

	-- Fade out after 3 seconds
	task.spawn(function()
		task.wait(3)
		local tween = TweenService:Create(
			notificationFrame,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine),
			{BackgroundTransparency = 1}
		)
		tween:Play()
		tween.Completed:Wait()
		notificationFrame.Visible = false
		notificationFrame.BackgroundTransparency = 0.5
	end)
end

-- Connect remote events
local function connectEvents()
	-- Connect shop button clicks
	shopButton.Activated:Connect(openShop)
	local closeButton = shopFrame:FindFirstChild("CloseButton") :: TextButton
	closeButton.Activated:Connect(closeShop)

	RemoteEvents.Events.UpdateInventory.OnClientEvent:Connect(updateInventoryUI)
	RemoteEvents.Events.UpdateTeamResources.OnClientEvent:Connect(updateTeamResourcesUI)
	RemoteEvents.Events.UpdatePhaseTimer.OnClientEvent:Connect(updatePhaseTimerUI)
	RemoteEvents.Events.ShowNotification.OnClientEvent:Connect(showNotification)
	RemoteEvents.Events.UpdateShopData.OnClientEvent:Connect(updateShopUI)

	-- Handle phase changes
	RemoteEvents.Events.PhaseChanged.OnClientEvent:Connect(function(phase: GamePhase)
		showNotification(`{phase} phase has begun!`)
	end)

	-- Update health regularly
	task.spawn(function()
		while true do
			updateHealthUI()
			task.wait(1)
		end
	end)
end

-- Initialize the UI system
local function initialize()
	-- Wait for player to spawn
	if not player.Character then
		player.CharacterAdded:Wait()
	end

	-- Create UI
	createMainUI()

	-- Connect events
	connectEvents()

	-- Request initial data
	task.spawn(function()
		task.wait(2) -- Wait for server to initialize

		-- Request player inventory
		local inventory = RemoteEvents.Functions.GetPlayerData:InvokeServer()
		if inventory then
			updateInventoryUI(inventory)
		end

		-- Request team resources
		local teamResources = RemoteEvents.Functions.GetTeamResources:InvokeServer()
		if teamResources then
			updateTeamResourcesUI(teamResources)
		end
	end)

	print("GameUI initialized")
end

-- Public API
GameUI.updateStaminaUI = updateStaminaUI

-- Start the UI system
initialize()

-- Export to global _G for other client scripts to access
_G.GameUI = GameUI

return GameUI