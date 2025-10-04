--!strict

--[[
	XPBar - XP Progress Bar UI Component

	Displays player's current level and XP progress.
	Shows a green progress bar that fills as XP is gained.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage.Shared:WaitForChild("Stats"))
local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))

local XPBar = {}

-- Private state
local container: Frame? = nil
local progressBar: Frame? = nil
local xpText: TextLabel? = nil

--[[
	Create the XP bar UI

	@param parent - ScreenGui to parent the XP bar to
	@return Frame - The XP bar container
]]
function XPBar.create(parent: ScreenGui): Frame
	local config = UIConfig.xpBar

	-- Container frame
	container = Instance.new("Frame")
	container.Name = "XPBarContainer"
	container.Size = UIConfig.createUDim2(config.size)
	container.Position = UIConfig.createUDim2(config.position)
	container.AnchorPoint = UIConfig.createVector2(config.anchorPoint)
	container.BackgroundColor3 = config.backgroundColor
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Parent = parent

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.cornerRadius)
	corner.Parent = container

	-- Progress bar
	progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(0, 0, 1, 0)  -- Starts at 0 width
	progressBar.BackgroundColor3 = config.progressColor
	progressBar.BorderSizePixel = 0
	progressBar.ZIndex = 2
	progressBar.Parent = container

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, config.cornerRadius)
	progressCorner.Parent = progressBar

	-- XP Text
	xpText = Instance.new("TextLabel")
	xpText.Name = "XPText"
	xpText.Size = UDim2.new(1, 0, 1, 0)
	xpText.BackgroundTransparency = 1
	xpText.Font = config.font
	xpText.TextSize = config.textSize
	xpText.TextColor3 = config.textColor
	xpText.TextStrokeTransparency = config.textStrokeTransparency
	xpText.Text = "Level 1 - 0 / 100 XP"
	xpText.ZIndex = 3
	xpText.Parent = container

	return container
end

--[[
	Update XP bar display

	@param currentXP - Current XP amount
	@param currentLevel - Current level
]]
function XPBar.update(currentXP: number, currentLevel: number)
	if not container or not progressBar or not xpText then
		warn("[XPBar] UI not created yet!")
		return
	end

	local config = UIConfig.xpBar

	-- Calculate XP progress
	local xpForNext = Stats.getXPForNextLevel(currentLevel)
	local xpForCurrent = currentLevel > 1 and Stats.getXPForNextLevel(currentLevel - 1) or 0
	local xpInLevel = currentXP - xpForCurrent
	local xpNeeded = xpForNext - xpForCurrent

	-- Safety check: prevent division by zero
	if xpNeeded <= 0 then
		warn(`[XPBar] Invalid XP calculation: xpForNext={xpForNext}, xpForCurrent={xpForCurrent}, xpNeeded={xpNeeded}`)
		xpNeeded = 1
	end

	local progress = xpInLevel / xpNeeded

	-- Update progress bar with animation
	local tween = TweenService:Create(
		progressBar,
		TweenInfo.new(config.animationDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(progress, 0, 1, 0)}
	)
	tween:Play()

	-- Update text
	xpText.Text = `Level {currentLevel} - {xpInLevel} / {xpNeeded} XP`
end

--[[
	Show XP gain popup

	@param xpAmount - Amount of XP gained
]]
function XPBar.showXPGainPopup(xpAmount: number)
	if not container then
		warn("[XPBar] UI not created yet!")
		return
	end

	local config = UIConfig.xpBar
	if not config.showXPPopup then
		return
	end

	-- Create popup label
	local popup = Instance.new("TextLabel")
	popup.Name = "XPPopup"
	popup.Size = UDim2.new(0.5, 0, 0.5, 0)
	popup.Position = UDim2.new(0.5, 0, -0.5, 0)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundTransparency = 1
	popup.Font = config.font
	popup.TextSize = config.textSize * 1.2
	popup.TextColor3 = config.popupColor
	popup.TextStrokeTransparency = 0
	popup.Text = `+{xpAmount} XP`
	popup.ZIndex = 10
	popup.Parent = container

	-- Animate upwards and fade out
	local tween = TweenService:Create(
		popup,
		TweenInfo.new(config.popupDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0.5, 0, -1.5, 0),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)

	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

--[[
	Destroy the XP bar
]]
function XPBar.destroy()
	if container then
		container:Destroy()
		container = nil
		progressBar = nil
		xpText = nil
	end
end

--[[
	Check if XP bar is enabled in config

	@return boolean - Whether XP bar is enabled
]]
function XPBar.isEnabled(): boolean
	return UIConfig.xpBar.enabled
end

return XPBar
