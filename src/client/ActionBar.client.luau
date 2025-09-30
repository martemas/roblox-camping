--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local ACTION_SLOTS = 4 -- Configurable number of action bar slots
local SLOT_SIZE = 50 -- Size of each action slot
local SLOT_SPACING = 5 -- Space between slots

-- UI Elements
local actionBarGui: ScreenGui
local actionSlots: {[number]: {
	frame: Frame,
	button: TextButton,
	icon: TextLabel,
	hotkeyLabel: TextLabel,
	cooldownOverlay: Frame,
	cooldownLabel: TextLabel,
}} = {}

-- State tracking
local equippedTools: {[number]: Tool?} = {} -- Tools in slots 1-4
local toolCooldowns: {[number]: number} = {} -- Cooldown end times from server

-- Activate a slot (send request to server)
local function activateSlot(slotNumber: number)
	-- Check if slot has a tool
	if not equippedTools[slotNumber] then
		print(`Slot {slotNumber} is empty`)
		return
	end

	-- Check if tool is on cooldown (client-side check for responsiveness)
	local cooldownEnd = toolCooldowns[slotNumber]
	if cooldownEnd and tick() < cooldownEnd then
		print(`Tool in slot {slotNumber} is on cooldown`)
		return
	end

	print(`Activating tool in slot {slotNumber}`)
	-- Send activation request to server (server will validate)
	RemoteEvents.Events.ActivateTool:FireServer(slotNumber)
end

-- Update slot display based on equipped tool
local function updateSlotDisplay(slotNumber: number)
	local slotData = actionSlots[slotNumber]
	local tool = equippedTools[slotNumber]

	if not slotData then return end

	if tool then
		-- Show tool icon/name
		slotData.icon.Text = tool.Name:sub(1, 1):upper() -- First letter as icon for now
		slotData.frame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		slotData.frame.BorderColor3 = Color3.fromRGB(120, 120, 120)
	else
		-- Empty slot
		slotData.icon.Text = "➕"
		slotData.frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		slotData.frame.BorderColor3 = Color3.fromRGB(80, 80, 80)
	end
end

-- Update cooldown display
local function updateCooldownDisplay(slotNumber: number)
	local slotData = actionSlots[slotNumber]
	local cooldownEnd = toolCooldowns[slotNumber]

	if not slotData then return end

	if cooldownEnd and tick() < cooldownEnd then
		-- Show cooldown
		local remaining = cooldownEnd - tick()
		slotData.cooldownOverlay.Visible = true
		slotData.cooldownLabel.Text = string.format("%.1f", remaining)
		slotData.frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40) -- Darker during cooldown
	else
		-- Hide cooldown
		slotData.cooldownOverlay.Visible = false
		toolCooldowns[slotNumber] = nil -- Clear expired cooldown
	end
end

-- Create individual action slot UI
local function createActionSlot(slotNumber: number, position: UDim2)
	-- Main slot frame
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = `ActionSlot{slotNumber}`
	slotFrame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slotFrame.Position = position
	slotFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	slotFrame.BackgroundTransparency = 0.2
	slotFrame.BorderSizePixel = 2
	slotFrame.BorderColor3 = Color3.fromRGB(120, 120, 120)
	slotFrame.Parent = actionBarGui

	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slotFrame

	-- Clickable button
	local slotButton = Instance.new("TextButton")
	slotButton.Name = "SlotButton"
	slotButton.Size = UDim2.new(1, 0, 1, 0)
	slotButton.Position = UDim2.new(0, 0, 0, 0)
	slotButton.BackgroundTransparency = 1
	slotButton.Text = ""
	slotButton.Parent = slotFrame

	-- Tool icon
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, 0, 0.7, 0)
	iconLabel.Position = UDim2.new(0, 0, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "➕" -- Empty slot indicator
	iconLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	iconLabel.TextSize = 20
	iconLabel.Font = Enum.Font.SourceSansBold
	iconLabel.Parent = slotFrame

	-- Hotkey label
	local hotkeyLabel = Instance.new("TextLabel")
	hotkeyLabel.Name = "Hotkey"
	hotkeyLabel.Size = UDim2.new(1, 0, 0.3, 0)
	hotkeyLabel.Position = UDim2.new(0, 0, 0.7, 0)
	hotkeyLabel.BackgroundTransparency = 1
	hotkeyLabel.Text = tostring(slotNumber)
	hotkeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	hotkeyLabel.TextSize = 12
	hotkeyLabel.TextStrokeTransparency = 0
	hotkeyLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hotkeyLabel.Font = Enum.Font.SourceSansBold
	hotkeyLabel.Parent = slotFrame

	-- Cooldown overlay
	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
	cooldownOverlay.Position = UDim2.new(0, 0, 0, 0)
	cooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cooldownOverlay.BackgroundTransparency = 0.6
	cooldownOverlay.BorderSizePixel = 0
	cooldownOverlay.Visible = false
	cooldownOverlay.Parent = slotFrame

	-- Cooldown corner rounding
	local cooldownCorner = Instance.new("UICorner")
	cooldownCorner.CornerRadius = UDim.new(0, 4)
	cooldownCorner.Parent = cooldownOverlay

	-- Cooldown timer label
	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "CooldownTimer"
	cooldownLabel.Size = UDim2.new(1, 0, 1, 0)
	cooldownLabel.Position = UDim2.new(0, 0, 0, 0)
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Text = "3.2"
	cooldownLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	cooldownLabel.TextSize = 14
	cooldownLabel.TextStrokeTransparency = 0
	cooldownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	cooldownLabel.Font = Enum.Font.SourceSansBold
	cooldownLabel.Parent = cooldownOverlay

	-- Store slot data
	actionSlots[slotNumber] = {
		frame = slotFrame,
		button = slotButton,
		icon = iconLabel,
		hotkeyLabel = hotkeyLabel,
		cooldownOverlay = cooldownOverlay,
		cooldownLabel = cooldownLabel,
	}

	-- Handle slot activation
	slotButton.Activated:Connect(function()
		activateSlot(slotNumber)
	end)

	-- Visual feedback
	slotButton.MouseEnter:Connect(function()
		if not cooldownOverlay.Visible then
			slotFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		end
	end)

	slotButton.MouseLeave:Connect(function()
		if not cooldownOverlay.Visible then
			slotFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		end
	end)

	print(`Created action slot {slotNumber}`)
end

-- Create the action bar UI
local function createActionBarUI()
	-- Create ScreenGui
	actionBarGui = Instance.new("ScreenGui")
	actionBarGui.Name = "ActionBar"
	actionBarGui.ResetOnSpawn = false
	actionBarGui.IgnoreGuiInset = true
	actionBarGui.Parent = playerGui

	-- Create individual action slots centered above toolbox
	local totalWidth = (SLOT_SIZE * ACTION_SLOTS) + (SLOT_SPACING * (ACTION_SLOTS - 1))
	local startOffset = -(totalWidth / 2) -- Center the group

	for i = 1, ACTION_SLOTS do
		local xOffset = startOffset + ((i - 1) * (SLOT_SIZE + SLOT_SPACING))
		local position = UDim2.new(0.5, xOffset, 1, -130) -- Centered above toolbox
		createActionSlot(i, position)
	end

	print("ActionBar UI created")
end

-- Monitor player's equipped tools in slots 1-4
local function updateEquippedTools()
	local character = player.Character
	if not character then return end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	-- Get all tools (equipped + in backpack)
	local allTools = {}
	for _, tool in pairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			table.insert(allTools, tool)
		end
	end
	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			table.insert(allTools, tool)
		end
	end

	-- Update equipped tools tracking (simplified - tools are assigned to slots 1-4 based on order)
	-- Note: Real implementation would need proper slot assignment logic
	for i = 1, ACTION_SLOTS do
		local previousTool = equippedTools[i]
		local newTool = allTools[i]

		if previousTool ~= newTool then
			equippedTools[i] = newTool
			updateSlotDisplay(i)
			print(`Tool slot {i} updated: {newTool and newTool.Name or "Empty"}`)
		end
	end
end

-- Handle hotkey inputs (1-4)
local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	local slotNumber = nil
	if input.KeyCode == Enum.KeyCode.One then slotNumber = 1
	elseif input.KeyCode == Enum.KeyCode.Two then slotNumber = 2
	elseif input.KeyCode == Enum.KeyCode.Three then slotNumber = 3
	elseif input.KeyCode == Enum.KeyCode.Four then slotNumber = 4
	end

	if slotNumber and slotNumber <= ACTION_SLOTS then
		activateSlot(slotNumber)
	end
end

-- Handle cooldown updates from server
local function onCooldownUpdate(cooldownData: {[any]: number})
	for slotKey, cooldownEnd in pairs(cooldownData) do
		local slotNumber = tonumber(slotKey)
		if slotNumber and slotNumber <= ACTION_SLOTS then
			toolCooldowns[slotNumber] = cooldownEnd
		end
	end
end

-- Main update loop
local function updateActionBar()
	-- Update equipped tools
	updateEquippedTools()

	-- Update cooldown displays
	for i = 1, ACTION_SLOTS do
		updateCooldownDisplay(i)
	end
end

-- Hide default toolbox
local function hideDefaultToolbox()
	-- Hide the default Roblox toolbox
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	print("Default toolbox hidden")
end

-- Initialize the action bar
local function initialize()
	-- Hide default toolbox first
	hideDefaultToolbox()

	-- Create UI
	createActionBarUI()

	-- Connect input handling
	UserInputService.InputBegan:Connect(onInputBegan)

	-- Connect server cooldown updates
	RemoteEvents.Events.UpdateToolCooldowns.OnClientEvent:Connect(onCooldownUpdate)

	-- Start update loop
	RunService.Heartbeat:Connect(updateActionBar)

	print("ActionBar system initialized")
end

-- Start the system
initialize()