--!strict

--[[
	TargetHUD Component - Pure UI Component

	Responsibilities:
	- Create TargetHUD GUI structure
	- Update display with target information
	- Apply visual settings (position, scale, opacity)
	- Show/hide HUD

	Does NOT handle:
	- RunService update loops
	- TargetingSystem integration
	- Combat validation logic
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIComponent = require(script.Parent.UIComponent)

local TargetHUD = {}

-- Component metadata
TargetHUD.name = "TargetHUD"
TargetHUD.requiresPlayer = true

-- Private state
local screenGui: ScreenGui? = nil
local animationTween: Tween? = nil

-- Create the HUD GUI structure
local function createTargetHUDGui(playerGui: PlayerGui): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "TargetHUD"
	gui.ResetOnSpawn = false
	gui.Enabled = false -- Start hidden
	gui.Parent = playerGui

	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 300, 0, 120)
	mainFrame.Position = UDim2.new(1, -320, 0, 20) -- Default to TopRight
	mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = gui

	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame

	-- Add UIStroke for border (works with UICorner)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "BorderStroke"
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = mainFrame

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
	typeLabel.Text = "Type: Hostile"
	typeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	typeLabel.TextScaled = true
	typeLabel.Font = Enum.Font.SourceSans
	typeLabel.TextXAlignment = Enum.TextXAlignment.Left
	typeLabel.Parent = detailsFrame

	-- Close button (X)
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	closeButton.BackgroundTransparency = 0.3
	closeButton.BorderSizePixel = 1
	closeButton.BorderColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	return gui
end

-- Initialize component
function TargetHUD.create(player: Player)
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	screenGui = createTargetHUDGui(playerGui)

	print("[TargetHUD] Component created")
end

-- Apply settings (position, scale, opacity, show details)
type TargetHUDSettings = {
	enabled: boolean,
	position: string, -- "TopLeft" | "TopRight" | "BottomLeft" | "BottomRight" | "Custom"
	customOffset: UDim2,
	scale: number,
	opacity: number,
	showDetailedStats: boolean,
	updateFrequency: number,
	animationSpeed: number,
}

function TargetHUD.applySettings(settings: TargetHUDSettings)
	if not screenGui then return end

	local mainFrame = screenGui:FindFirstChild("MainFrame") :: Frame?
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
	local detailsFrame = mainFrame:FindFirstChild("DetailsFrame") :: Frame?
	if detailsFrame then
		detailsFrame.Visible = settings.showDetailedStats
		-- Adjust main frame size if details are hidden
		if not settings.showDetailedStats then
			mainFrame.Size = UDim2.new(0, baseSize.X.Offset * settings.scale, 0, 70 * settings.scale)
		end
	end
end

-- Update HUD content
type TargetUpdateData = {
	name: string,
	health: number,
	maxHealth: number,
	distance: number?,
	state: string?,
	damage: number?,
	entityType: string?,
	entityCategory: string?,
	borderColor: Color3?,
	statusText: string?,
	animationSpeed: number?,
	teamColor: Color3?, -- Team color for name display
}

function TargetHUD.update(data: TargetUpdateData)
	if not screenGui then return end

	local mainFrame = screenGui:FindFirstChild("MainFrame") :: Frame?
	if not mainFrame then return end

	-- Update name and team color
	local nameLabel = mainFrame:FindFirstChild("NameLabel") :: TextLabel?
	if nameLabel and data.name then
		nameLabel.Text = data.name

		-- Apply team color if provided
		if data.teamColor then
			nameLabel.TextColor3 = data.teamColor
		else
			-- Default white color
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	-- Update border color
	if data.borderColor then
		local stroke = mainFrame:FindFirstChild("BorderStroke") :: UIStroke?
		if stroke then
			stroke.Color = data.borderColor
		end
	end

	-- Update health bar and text
	local healthBarBG = mainFrame:FindFirstChild("HealthBarBG") :: Frame?
	if healthBarBG then
		local healthBar = healthBarBG:FindFirstChild("HealthBar") :: Frame?
		local healthText = healthBarBG:FindFirstChild("HealthText") :: TextLabel?

		if healthBar and healthText then
			local healthPercent = if data.maxHealth > 0 then data.health / data.maxHealth else 0

			-- Animate health bar changes
			if animationTween then
				animationTween:Cancel()
			end

			local speed = data.animationSpeed or 0.3
			animationTween = TweenService:Create(
				healthBar,
				TweenInfo.new(speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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

			healthText.Text = `{math.floor(data.health)} / {data.maxHealth}`
		end
	end

	-- Update details if visible
	local detailsFrame = mainFrame:FindFirstChild("DetailsFrame") :: Frame?
	if detailsFrame and detailsFrame.Visible then
		-- Distance
		local distanceLabel = detailsFrame:FindFirstChild("DistanceLabel") :: TextLabel?
		if distanceLabel and data.distance then
			distanceLabel.Text = `Distance: {math.floor(data.distance * 10) / 10}m`
		end

		-- State/Status
		local stateLabel = detailsFrame:FindFirstChild("StateLabel") :: TextLabel?
		if stateLabel then
			if data.statusText then
				stateLabel.Text = `Status: {data.statusText}`
				if data.borderColor then
					stateLabel.TextColor3 = data.borderColor
				end
			elseif data.state then
				stateLabel.Text = `State: {data.state}`
			end
		end

		-- Damage
		local damageLabel = detailsFrame:FindFirstChild("DamageLabel") :: TextLabel?
		if damageLabel and data.damage then
			damageLabel.Text = `Damage: {data.damage}`
		end

		-- Type
		local typeLabel = detailsFrame:FindFirstChild("TypeLabel") :: TextLabel?
		if typeLabel and data.entityCategory then
			typeLabel.Text = `Type: {data.entityCategory}`
		end
	end
end

-- Show HUD
function TargetHUD.show()
	if screenGui then
		screenGui.Enabled = true
	end
end

-- Hide HUD
function TargetHUD.hide()
	if screenGui then
		screenGui.Enabled = false
	end

	-- Cancel any ongoing animations
	if animationTween then
		animationTween:Cancel()
		animationTween = nil
	end
end

-- Get the close button for event binding
function TargetHUD.getCloseButton(): TextButton?
	if not screenGui then return nil end

	local mainFrame = screenGui:FindFirstChild("MainFrame") :: Frame?
	if not mainFrame then return nil end

	return mainFrame:FindFirstChild("CloseButton") :: TextButton?
end

-- Cleanup
function TargetHUD.destroy()
	if animationTween then
		animationTween:Cancel()
		animationTween = nil
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return TargetHUD
