--!strict

--[[
	StatsUI - Client-side Stats & XP Interface

	Provides visual feedback for the stats system:
	- XP progress bar (always visible)
	- Stats panel (toggle with "C")
	- Level-up modal (stat allocation)

	SECURITY: Read-only display. All modifications via RemoteEvents to server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Stats = require(ReplicatedStorage.Shared:WaitForChild("Stats"))
local RemoteEventsModule = require(ReplicatedStorage.Shared:WaitForChild("RemoteEvents"))
local RemoteEvents = RemoteEventsModule.Events

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI State
local currentXP = 0
local currentLevel = 1
local currentStats = {
	strength = 5,
	magic = 5,
	stamina = 5,
	accuracy = 5,
}
local unallocatedPoints = 0

-- UI Elements (will be created)
local screenGui
local xpBar
local statsPanel
local levelUpModal

-- Constants
local STATS_PANEL_HOTKEY = Enum.KeyCode.C
local ANIMATION_DURATION = 0.3

--[[
	Create XP Bar (always visible above tools/hotbar)
]]
local function createXPBar()
	-- Container frame
	local container = Instance.new("Frame")
	container.Name = "XPBarContainer"
	container.Size = UDim2.new(0.4, 0, 0.04, 0)
	container.Position = UDim2.new(0.3, 0, 0.88, 0)  -- Positioned above hotbar (was 0.95)
	container.AnchorPoint = Vector2.new(0, 1)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	container.BorderSizePixel = 0
	container.ClipsDescendants = true  -- Clip progress bar to container bounds
	container.Parent = screenGui

	-- Add rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = container

	-- Progress bar
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
	progressBar.BorderSizePixel = 0
	progressBar.ZIndex = 2  -- Above container
	progressBar.Parent = container

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 8)
	progressCorner.Parent = progressBar

	-- XP Text
	local xpText = Instance.new("TextLabel")
	xpText.Name = "XPText"
	xpText.Size = UDim2.new(1, 0, 1, 0)
	xpText.BackgroundTransparency = 1
	xpText.Font = Enum.Font.GothamBold
	xpText.TextSize = 16
	xpText.TextColor3 = Color3.fromRGB(255, 255, 255)
	xpText.TextStrokeTransparency = 0.5
	xpText.Text = "Level 1 - 0 / 100 XP"
	xpText.ZIndex = 3  -- Above progress bar so text is visible
	xpText.Parent = container

	return container
end

--[[
	Create Stats Panel (toggle with "C")
]]
local function createStatsPanel()
	-- Main panel frame
	local panel = Instance.new("Frame")
	panel.Name = "StatsPanel"
	panel.Size = UDim2.new(0.25, 0, 0.4, 0)
	panel.Position = UDim2.new(0.02, 0, 0.3, 0)
	panel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	panel.BorderSizePixel = 2
	panel.BorderColor3 = Color3.fromRGB(100, 100, 100)
	panel.Visible = false
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.12, 0)
	title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "Character Stats"
	title.Parent = panel

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 12)
	titleCorner.Parent = title

	-- Stats list container
	local statsContainer = Instance.new("ScrollingFrame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Size = UDim2.new(1, -20, 0.85, 0)
	statsContainer.Position = UDim2.new(0, 10, 0.15, 0)
	statsContainer.BackgroundTransparency = 1
	statsContainer.BorderSizePixel = 0
	statsContainer.ScrollBarThickness = 6
	statsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	statsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	statsContainer.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = statsContainer

	-- Create stat rows
	local statOrder = {"strength", "magic", "stamina", "accuracy"}
	local statNames = {
		strength = "Strength",
		magic = "Magic",
		stamina = "Stamina",
		accuracy = "Accuracy"
	}
	local statDescriptions = {
		strength = "+2% Phys Dmg | +Defense | +Crit Dmg",
		magic = "+2% Magic Dmg | +Magic Resist",
		stamina = "+10 HP | +Defense",
		accuracy = "+1% Hit | +1% Dodge | +0.5% Crit"
	}

	for i, statKey in statOrder do
		local statRow = Instance.new("Frame")
		statRow.Name = statKey
		statRow.Size = UDim2.new(1, 0, 0, 70)
		statRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		statRow.BorderSizePixel = 0
		statRow.LayoutOrder = i
		statRow.Parent = statsContainer

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = statRow

		-- Stat name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(0.6, 0, 0.35, 0)
		nameLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 16
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = statNames[statKey]
		nameLabel.Parent = statRow

		-- Stat value
		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = "ValueLabel"
		valueLabel.Size = UDim2.new(0.3, 0, 0.35, 0)
		valueLabel.Position = UDim2.new(0.65, 0, 0.05, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.TextSize = 18
		valueLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Text = "5"
		valueLabel.Parent = statRow

		-- Stat description
		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "DescLabel"
		descLabel.Size = UDim2.new(0.9, 0, 0.55, 0)
		descLabel.Position = UDim2.new(0.05, 0, 0.42, 0)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 12
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Text = statDescriptions[statKey]
		descLabel.Parent = statRow
	end

	-- Help text
	local helpText = Instance.new("TextLabel")
	helpText.Name = "HelpText"
	helpText.Size = UDim2.new(1, 0, 0.08, 0)
	helpText.Position = UDim2.new(0, 0, 0.92, 0)
	helpText.BackgroundTransparency = 1
	helpText.Font = Enum.Font.GothamMedium
	helpText.TextSize = 12
	helpText.TextColor3 = Color3.fromRGB(200, 200, 200)
	helpText.Text = "Press C to close"
	helpText.Parent = panel

	return panel
end

--[[
	Create Level-Up Modal
]]
local function createLevelUpModal()
	-- Background overlay
	local modal = Instance.new("Frame")
	modal.Name = "LevelUpModal"
	modal.Size = UDim2.new(1, 0, 1, 0)
	modal.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	modal.BackgroundTransparency = 0.5
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 10
	modal.Parent = screenGui

	-- Modal content
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(0.4, 0, 0.6, 0)
	content.Position = UDim2.new(0.3, 0, 0.2, 0)
	content.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	content.BorderSizePixel = 3
	content.BorderColor3 = Color3.fromRGB(255, 215, 0)
	content.ZIndex = 11
	content.Parent = modal

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 16)
	contentCorner.Parent = content

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.15, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 32
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.Text = "LEVEL UP!"
	title.ZIndex = 11
	title.Parent = content

	-- Level text
	local levelText = Instance.new("TextLabel")
	levelText.Name = "LevelText"
	levelText.Size = UDim2.new(1, 0, 0.1, 0)
	levelText.Position = UDim2.new(0, 0, 0.15, 0)
	levelText.BackgroundTransparency = 1
	levelText.Font = Enum.Font.GothamBold
	levelText.TextSize = 24
	levelText.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelText.Text = "You are now Level 2!"
	levelText.ZIndex = 11
	levelText.Parent = content

	-- Points text
	local pointsText = Instance.new("TextLabel")
	pointsText.Name = "PointsText"
	pointsText.Size = UDim2.new(1, 0, 0.08, 0)
	pointsText.Position = UDim2.new(0, 0, 0.25, 0)
	pointsText.BackgroundTransparency = 1
	pointsText.Font = Enum.Font.Gotham
	pointsText.TextSize = 18
	pointsText.TextColor3 = Color3.fromRGB(200, 200, 200)
	pointsText.Text = "2 Stat Points Available"
	pointsText.ZIndex = 11
	pointsText.Parent = content

	-- Stat buttons container
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "ButtonsContainer"
	buttonsContainer.Size = UDim2.new(0.9, 0, 0.4, 0)
	buttonsContainer.Position = UDim2.new(0.05, 0, 0.35, 0)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.ZIndex = 11
	buttonsContainer.Parent = content

	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.Padding = UDim.new(0, 10)
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.Parent = buttonsContainer

	-- Create stat buttons
	local statOrder = {"strength", "magic", "stamina", "accuracy"}
	local statNames = {
		strength = "Strength",
		magic = "Magic",
		stamina = "Stamina",
		accuracy = "Accuracy"
	}

	for _, statKey in statOrder do
		local button = Instance.new("TextButton")
		button.Name = statKey .. "Button"
		button.Size = UDim2.new(0.8, 0, 0, 50)
		button.BackgroundColor3 = Color3.fromRGB(70, 130, 70)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 18
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Text = `+1 {statNames[statKey]}`
		button.ZIndex = 11
		button.Parent = buttonsContainer

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button

		-- Hover effect
		button.MouseEnter:Connect(function()
			button.BackgroundColor3 = Color3.fromRGB(90, 170, 90)
		end)

		button.MouseLeave:Connect(function()
			button.BackgroundColor3 = Color3.fromRGB(70, 130, 70)
		end)

		-- Click handler
		button.MouseButton1Click:Connect(function()
			if unallocatedPoints > 0 then
				RemoteEvents.RequestStatIncrease:FireServer(statKey)
				-- Visual feedback
				button.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
				task.wait(0.2)
				button.BackgroundColor3 = Color3.fromRGB(70, 130, 70)
			end
		end)
	end

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0.4, 0, 0.1, 0)
	closeButton.Position = UDim2.new(0.3, 0, 0.85, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 16
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Text = "Close"
	closeButton.ZIndex = 11
	closeButton.Parent = content

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	return modal
end

--[[
	Update XP Bar display
]]
local function updateXPBar()
	local xpForNext = Stats.getXPForNextLevel(currentLevel)
	local xpForCurrent = currentLevel > 1 and Stats.getXPForNextLevel(currentLevel - 1) or 0
	local xpInLevel = currentXP - xpForCurrent
	local xpNeeded = xpForNext - xpForCurrent

	-- Safety check: prevent division by zero
	if xpNeeded <= 0 then
		warn(`[StatsUI] Invalid XP calculation: xpForNext={xpForNext}, xpForCurrent={xpForCurrent}, xpNeeded={xpNeeded}`)
		xpNeeded = 1  -- Prevent NaN
	end

	local progress = xpInLevel / xpNeeded

	-- Update progress bar with tween
	local progressBar = xpBar:FindFirstChild("ProgressBar")
	if not progressBar then
		warn("[StatsUI] ProgressBar not found in XP bar!")
		return
	end

	local tween = TweenService:Create(
		progressBar,
		TweenInfo.new(ANIMATION_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(progress, 0, 1, 0)}
	)
	tween:Play()

	-- Update text
	local xpText = xpBar:FindFirstChild("XPText")
	if xpText then
		xpText.Text = `Level {currentLevel} - {xpInLevel} / {xpNeeded} XP`
	else
		warn("[StatsUI] XPText not found in XP bar!")
	end
end

--[[
	Update Stats Panel display
]]
local function updateStatsPanel()
	local statsContainer = statsPanel:FindFirstChild("StatsContainer")

	for statKey, value in currentStats do
		local statRow = statsContainer:FindFirstChild(statKey)
		if statRow then
			local valueLabel = statRow:FindFirstChild("ValueLabel")
			valueLabel.Text = tostring(value)

			-- Calculate derived bonuses
			local derived = Stats.getDerivedStats({
				strength = currentStats.strength,
				magic = currentStats.magic,
				stamina = currentStats.stamina,
				accuracy = currentStats.accuracy,
				level = currentLevel,
				xp = currentXP,
			})

			-- Update description with actual values
			local descLabel = statRow:FindFirstChild("DescLabel")
			if statKey == "strength" then
				local dmgBonus = math.floor((derived.physicalDamageBonus - 1) * 100)
				local defBonus = math.floor(derived.defense * 100 / 2)
				local critBonus = math.floor((derived.critMultiplier - 1.5) * 100)
				descLabel.Text = `+{dmgBonus}% Phys Dmg | +{defBonus}% Def | +{critBonus}% Crit Dmg`
			elseif statKey == "magic" then
				local magicDmg = math.floor((derived.magicDamageBonus - 1) * 100)
				local magicRes = math.floor(derived.magicResistance * 100)
				descLabel.Text = `+{magicDmg}% Magic Dmg | -{magicRes}% Magic Dmg Taken`
			elseif statKey == "stamina" then
				local hpBonus = derived.maxHealthBonus
				local defBonus = math.floor(derived.defense * 100 / 2)
				descLabel.Text = `+{hpBonus} HP | +{defBonus}% Defense`
			elseif statKey == "accuracy" then
				local hitBonus = math.floor((derived.hitChance - 0.95) * 100)
				local dodgeBonus = math.floor(derived.dodgeChance * 100)
				local critBonus = math.floor((derived.criticalChance - 0.05) * 100)
				descLabel.Text = `+{hitBonus}% Hit | +{dodgeBonus}% Dodge | +{critBonus}% Crit`
			end
		end
	end
end

--[[
	Show XP gain popup on the XP bar
]]
local function showXPGainPopup(amount: number)
	local popup = Instance.new("TextLabel")
	popup.Size = UDim2.new(0.2, 0, 0.8, 0)
	popup.Position = UDim2.new(0.5, 0, 0, 0)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundTransparency = 1
	popup.Font = Enum.Font.GothamBold
	popup.TextSize = 18
	popup.TextColor3 = Color3.fromRGB(100, 255, 100)
	popup.TextStrokeTransparency = 0
	popup.Text = `+{amount} XP`
	popup.Parent = xpBar

	-- Animate upward and fade
	local tween = TweenService:Create(
		popup,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, -0.5, 0), TextTransparency = 1, TextStrokeTransparency = 1}
	)
	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

--[[
	Initialize UI
]]
local function initialize()
	print("[StatsUI] Initializing...")

	-- Create ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StatsUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	print("[StatsUI] ScreenGui created")

	-- Create UI elements
	xpBar = createXPBar()
	statsPanel = createStatsPanel()
	levelUpModal = createLevelUpModal()

	-- Update displays with default values
	updateXPBar()
	updateStatsPanel()

	print("[StatsUI] ✓ Initialized successfully")
end

--[[
	Handle input (toggle stats panel with C)
]]
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == STATS_PANEL_HOTKEY then
		statsPanel.Visible = not statsPanel.Visible
	end
end)

--[[
	Listen to RemoteEvents from server
]]

-- XP Updated
RemoteEvents.XPUpdated.OnClientEvent:Connect(function(newXP: number, newLevel: number)
	local xpGained = newXP - currentXP

	currentXP = newXP
	currentLevel = newLevel

	updateXPBar()

	-- Show XP gain popup if XP increased
	if xpGained > 0 then
		showXPGainPopup(xpGained)
	end
end)

-- Stats Updated
RemoteEvents.StatsUpdated.OnClientEvent:Connect(function(stats: any, points: number)
	currentStats = stats
	unallocatedPoints = points

	updateStatsPanel()

	-- Update level-up modal points text
	local pointsText = levelUpModal:FindFirstChild("Content"):FindFirstChild("PointsText")
	pointsText.Text = `{points} Stat Points Available`

	-- Close modal if no points left
	if points == 0 then
		levelUpModal.Visible = false
	end
end)

-- Level Up Notification
RemoteEvents.LevelUpNotification.OnClientEvent:Connect(function(newLevel: number, statPoints: number)
	currentLevel = newLevel
	unallocatedPoints = statPoints

	-- Update modal text
	local content = levelUpModal:FindFirstChild("Content")
	local levelText = content:FindFirstChild("LevelText")
	local pointsText = content:FindFirstChild("PointsText")

	levelText.Text = `You are now Level {newLevel}!`
	pointsText.Text = `{statPoints} Stat Points Available`

	-- Show modal
	levelUpModal.Visible = true

	-- Play sound effect (optional)
	-- Add particle effects (optional)

	print(`🎉 LEVEL UP! You are now level {newLevel}!`)
end)

-- Initialize on load
initialize()
