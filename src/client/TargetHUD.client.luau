--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TargetingSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TargetingSystem"))
local PlayerSettingsManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerSettingsManager"))
local PlayerSettings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerSettings"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

type TargetInfo = Types.TargetInfo
type TargetHUDSettings = PlayerSettings.TargetHUDSettings

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- HUD state
local currentHUD: ScreenGui? = nil
local currentTarget: Model? = nil
local updateConnection: RBXScriptConnection? = nil
local animationTween: Tween? = nil

-- Initialize player settings
PlayerSettingsManager.initialize()

-- Create the HUD GUI structure
local function createTargetHUD(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TargetHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 300, 0, 120)
	mainFrame.Position = UDim2.new(1, -320, 0, 20) -- Default to TopRight
	mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 2
	mainFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	mainFrame.Parent = screenGui

	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame

	-- Entity name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -10, 0, 25)
	nameLabel.Position = UDim2.new(0, 5, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Target Name"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = mainFrame

	-- Health bar background
	local healthBarBG = Instance.new("Frame")
	healthBarBG.Name = "HealthBarBG"
	healthBarBG.Size = UDim2.new(1, -20, 0, 20)
	healthBarBG.Position = UDim2.new(0, 10, 0, 35)
	healthBarBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	healthBarBG.BorderSizePixel = 1
	healthBarBG.BorderColor3 = Color3.fromRGB(100, 100, 100)
	healthBarBG.Parent = mainFrame

	local healthBarCorner = Instance.new("UICorner")
	healthBarCorner.CornerRadius = UDim.new(0, 4)
	healthBarCorner.Parent = healthBarBG

	-- Health bar fill
	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.Position = UDim2.new(0, 0, 0, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = healthBarBG

	local healthFillCorner = Instance.new("UICorner")
	healthFillCorner.CornerRadius = UDim.new(0, 4)
	healthFillCorner.Parent = healthBar

	-- Health text
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.Position = UDim2.new(0, 0, 0, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = "100 / 100"
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.SourceSans
	healthText.Parent = healthBarBG

	-- Details frame (for additional stats)
	local detailsFrame = Instance.new("Frame")
	detailsFrame.Name = "DetailsFrame"
	detailsFrame.Size = UDim2.new(1, -10, 0, 50)
	detailsFrame.Position = UDim2.new(0, 5, 0, 65)
	detailsFrame.BackgroundTransparency = 1
	detailsFrame.Parent = mainFrame

	-- Distance label
	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "DistanceLabel"
	distanceLabel.Size = UDim2.new(0.5, -5, 0, 20)
	distanceLabel.Position = UDim2.new(0, 0, 0, 0)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Text = "Distance: 0m"
	distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	distanceLabel.TextScaled = true
	distanceLabel.Font = Enum.Font.SourceSans
	distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
	distanceLabel.Parent = detailsFrame

	-- State label
	local stateLabel = Instance.new("TextLabel")
	stateLabel.Name = "StateLabel"
	stateLabel.Size = UDim2.new(0.5, -5, 0, 20)
	stateLabel.Position = UDim2.new(0.5, 5, 0, 0)
	stateLabel.BackgroundTransparency = 1
	stateLabel.Text = "State: idle"
	stateLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	stateLabel.TextScaled = true
	stateLabel.Font = Enum.Font.SourceSans
	stateLabel.TextXAlignment = Enum.TextXAlignment.Left
	stateLabel.Parent = detailsFrame

	-- Damage label
	local damageLabel = Instance.new("TextLabel")
	damageLabel.Name = "DamageLabel"
	damageLabel.Size = UDim2.new(0.5, -5, 0, 20)
	damageLabel.Position = UDim2.new(0, 0, 0, 25)
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = "Damage: 10"
	damageLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	damageLabel.TextScaled = true
	damageLabel.Font = Enum.Font.SourceSans
	damageLabel.TextXAlignment = Enum.TextXAlignment.Left
	damageLabel.Parent = detailsFrame

	-- Type label
	local typeLabel = Instance.new("TextLabel")
	typeLabel.Name = "TypeLabel"
	typeLabel.Size = UDim2.new(0.5, -5, 0, 20)
	typeLabel.Position = UDim2.new(0.5, 5, 0, 25)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Text = "Type: Enemy"
	typeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	typeLabel.TextScaled = true
	typeLabel.Font = Enum.Font.SourceSans
	typeLabel.TextXAlignment = Enum.TextXAlignment.Left
	typeLabel.Parent = detailsFrame

	return screenGui
end

-- Update HUD position and appearance based on settings
local function applyHUDSettings(hud: ScreenGui, settings: TargetHUDSettings)
	local mainFrame = hud:FindFirstChild("MainFrame") :: Frame
	if not mainFrame then return end

	-- Apply position
	local position: UDim2
	if settings.position == "TopLeft" then
		position = UDim2.new(0, 20, 0, 20)
	elseif settings.position == "TopRight" then
		position = UDim2.new(1, -320, 0, 20)
	elseif settings.position == "BottomLeft" then
		position = UDim2.new(0, 20, 1, -140)
	elseif settings.position == "BottomRight" then
		position = UDim2.new(1, -320, 1, -140)
	elseif settings.position == "Custom" then
		position = settings.customOffset
	else
		position = UDim2.new(1, -320, 0, 20) -- Default TopRight
	end

	mainFrame.Position = position

	-- Apply scale
	local baseSize = UDim2.new(0, 300, 0, 120)
	mainFrame.Size = UDim2.new(0, baseSize.X.Offset * settings.scale, 0, baseSize.Y.Offset * settings.scale)

	-- Apply opacity
	mainFrame.BackgroundTransparency = 1 - settings.opacity

	-- Show/hide detailed stats
	local detailsFrame = mainFrame:FindFirstChild("DetailsFrame") :: Frame
	if detailsFrame then
		detailsFrame.Visible = settings.showDetailedStats
		-- Adjust main frame size if details are hidden
		if not settings.showDetailedStats then
			mainFrame.Size = UDim2.new(0, baseSize.X.Offset * settings.scale, 0, 70 * settings.scale)
		end
	end
end

-- Update HUD content with target information
local function updateHUDContent(hud: ScreenGui, targetInfo: TargetInfo)
	local mainFrame = hud:FindFirstChild("MainFrame") :: Frame
	if not mainFrame then return end

	-- Update name
	local nameLabel = mainFrame:FindFirstChild("NameLabel") :: TextLabel
	if nameLabel then
		nameLabel.Text = `{targetInfo.entityType} ({targetInfo.model.Name})`
	end

	-- Update health bar and text
	local healthBarBG = mainFrame:FindFirstChild("HealthBarBG") :: Frame
	if healthBarBG then
		local healthBar = healthBarBG:FindFirstChild("HealthBar") :: Frame
		local healthText = healthBarBG:FindFirstChild("HealthText") :: TextLabel

		if healthBar and healthText then
			local healthPercent = if targetInfo.maxHealth > 0 then targetInfo.health / targetInfo.maxHealth else 0
			local settings = PlayerSettingsManager.getTargetHUDSettings(player)

			-- Animate health bar changes
			if animationTween then
				animationTween:Cancel()
			end

			animationTween = TweenService:Create(
				healthBar,
				TweenInfo.new(settings.animationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Size = UDim2.new(healthPercent, 0, 1, 0)}
			)
			animationTween:Play()

			-- Update health bar color based on percentage
			local healthColor: Color3
			if healthPercent > 0.6 then
				healthColor = Color3.fromRGB(0, 255, 0) -- Green
			elseif healthPercent > 0.3 then
				healthColor = Color3.fromRGB(255, 255, 0) -- Yellow
			else
				healthColor = Color3.fromRGB(255, 0, 0) -- Red
			end
			healthBar.BackgroundColor3 = healthColor

			healthText.Text = `{math.floor(targetInfo.health)} / {targetInfo.maxHealth}`
		end
	end

	-- Update details if visible
	local detailsFrame = mainFrame:FindFirstChild("DetailsFrame") :: Frame
	if detailsFrame and detailsFrame.Visible then
		local distanceLabel = detailsFrame:FindFirstChild("DistanceLabel") :: TextLabel
		local stateLabel = detailsFrame:FindFirstChild("StateLabel") :: TextLabel
		local damageLabel = detailsFrame:FindFirstChild("DamageLabel") :: TextLabel
		local typeLabel = detailsFrame:FindFirstChild("TypeLabel") :: TextLabel

		if distanceLabel then
			distanceLabel.Text = `Distance: {math.floor(targetInfo.distance * 10) / 10}m`
		end

		if stateLabel then
			stateLabel.Text = `State: {targetInfo.state}`
		end

		if damageLabel then
			damageLabel.Text = `Damage: {targetInfo.damage or "N/A"}`
		end

		if typeLabel then
			typeLabel.Text = `Type: {targetInfo.entityCategory}`
		end
	end
end

-- Show the target HUD
local function showTargetHUD(targetInfo: TargetInfo)
	local settings = PlayerSettingsManager.getTargetHUDSettings(player)

	if not settings.enabled then
		return
	end

	-- Create HUD if it doesn't exist
	if not currentHUD then
		currentHUD = createTargetHUD()
	end

	-- Apply settings and update content
	applyHUDSettings(currentHUD, settings)
	updateHUDContent(currentHUD, targetInfo)

	-- Make sure it's visible
	currentHUD.Enabled = true
end

-- Hide the target HUD
local function hideTargetHUD()
	if currentHUD then
		currentHUD.Enabled = false
	end

	-- Don't stop the update loop - we need it to detect new targets!
	currentTarget = nil
end

-- Main update loop for the HUD
local function updateHUD()
	local target = TargetingSystem.getTarget(player)

	-- If no target, hide HUD
	if not target then
		if currentTarget then
			hideTargetHUD()
		end
		return
	end

	-- Get target info
	local targetInfo = TargetingSystem.getTargetInfo(player)
	if not targetInfo then
		hideTargetHUD()
		return
	end

	-- Show/update HUD
	currentTarget = target
	showTargetHUD(targetInfo)
end

-- Start the update loop
local lastUpdateTime = 0
local function startUpdateLoop()
	local settings = PlayerSettingsManager.getTargetHUDSettings(player)

	if updateConnection then
		updateConnection:Disconnect()
	end

	updateConnection = RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		if currentTime - lastUpdateTime >= settings.updateFrequency then
			updateHUD()
			lastUpdateTime = currentTime
		end
	end)
end

-- Handle settings changes
local function onSettingsChanged(newSettings: PlayerSettings.PlayerSettingsData)
	-- Restart update loop with new frequency
	startUpdateLoop()

	-- Update HUD appearance if it's currently visible
	if currentHUD and currentHUD.Enabled then
		applyHUDSettings(currentHUD, newSettings.ui.targetHUD)
	end
end

-- Initialize the system
local function initialize()
	-- Load player settings
	PlayerSettingsManager.loadPlayerSettings(player)

	-- Register for settings changes
	PlayerSettingsManager.onSettingsChanged(player, onSettingsChanged)

	-- Start the update loop
	startUpdateLoop()

	print("TargetHUD initialized")
end

-- Start everything
initialize()

-- Clean up on player leaving (not needed for client scripts, but good practice)
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		if updateConnection then
			updateConnection:Disconnect()
		end
		if animationTween then
			animationTween:Cancel()
		end
	end
end)