--!strict

--[[
	LevelUpModal - Level Up Notification UI Component

	Displays a congratulatory modal when player levels up.
	Shows new level and available stat points.
]]

local TweenService = game:GetService("TweenService")
local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))

local LevelUpModal = {}

-- Private state
local modal: Frame? = nil
local content: Frame? = nil
local levelText: TextLabel? = nil
local pointsText: TextLabel? = nil

-- Callback for when stats panel should open
local onOpenStatsPanel: (() -> ())? = nil

--[[
	Create the level-up modal UI

	@param parent - ScreenGui to parent the modal to
	@return Frame - The modal container
]]
function LevelUpModal.create(parent: ScreenGui): Frame
	local config = UIConfig.levelUpModal

	-- Background overlay
	modal = Instance.new("Frame")
	modal.Name = "LevelUpModal"
	modal.Size = UDim2.new(1, 0, 1, 0)
	modal.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	modal.BackgroundTransparency = 0.5
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 10
	modal.Parent = parent

	-- Modal content
	content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UIConfig.createUDim2(config.size)
	content.Position = UDim2.new(0.5, 0, 0.5, 0)
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.BackgroundColor3 = config.backgroundColor
	content.BorderSizePixel = 3
	content.BorderColor3 = config.levelColor
	content.ZIndex = 11
	content.Parent = modal

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, config.cornerRadius)
	contentCorner.Parent = content

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.3, 0)
	title.Position = UDim2.new(0, 0, 0.1, 0)
	title.BackgroundTransparency = 1
	title.Font = config.titleFont
	title.TextSize = config.titleTextSize
	title.TextColor3 = config.levelColor
	title.Text = "LEVEL UP!"
	title.ZIndex = 11
	title.Parent = content

	-- Level text
	levelText = Instance.new("TextLabel")
	levelText.Name = "LevelText"
	levelText.Size = UDim2.new(1, 0, 0.2, 0)
	levelText.Position = UDim2.new(0, 0, 0.4, 0)
	levelText.BackgroundTransparency = 1
	levelText.Font = config.font
	levelText.TextSize = config.messageTextSize
	levelText.TextColor3 = config.textColor
	levelText.Text = "You are now Level 2!"
	levelText.ZIndex = 11
	levelText.Parent = content

	-- Points text
	pointsText = Instance.new("TextLabel")
	pointsText.Name = "PointsText"
	pointsText.Size = UDim2.new(1, 0, 0.15, 0)
	pointsText.Position = UDim2.new(0, 0, 0.6, 0)
	pointsText.BackgroundTransparency = 1
	pointsText.Font = config.font
	pointsText.TextSize = config.buttonTextSize
	pointsText.TextColor3 = config.textColor
	pointsText.Text = "2 Stat Points Available"
	pointsText.ZIndex = 11
	pointsText.Parent = content

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0.4, 0, 0.15, 0)
	closeButton.Position = UDim2.new(0.3, 0, 0.8, 0)
	closeButton.BackgroundColor3 = config.buttonColor
	closeButton.Font = config.font
	closeButton.TextSize = config.buttonTextSize
	closeButton.TextColor3 = config.textColor
	closeButton.Text = "Open Stats"
	closeButton.ZIndex = 11
	closeButton.Parent = content

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, config.cornerRadius - 4)
	closeCorner.Parent = closeButton

	-- Hover effect
	closeButton.MouseEnter:Connect(function()
		closeButton.BackgroundColor3 = config.buttonHoverColor
	end)
	closeButton.MouseLeave:Connect(function()
		closeButton.BackgroundColor3 = config.buttonColor
	end)

	-- Click handler
	closeButton.MouseButton1Click:Connect(function()
		LevelUpModal.hide()
		if config.autoOpenStatsPanel and onOpenStatsPanel then
			onOpenStatsPanel()
		end
	end)

	return modal
end

--[[
	Show level-up modal with animation

	@param newLevel - The new level reached
	@param statPoints - Number of stat points earned
]]
function LevelUpModal.show(newLevel: number, statPoints: number)
	if not modal or not content or not levelText or not pointsText then
		warn("[LevelUpModal] UI not created yet!")
		return
	end

	local config = UIConfig.levelUpModal

	-- Update text
	levelText.Text = `You are now Level {newLevel}!`
	pointsText.Text = `{statPoints} Stat Point{statPoints > 1 and "s" or ""} Available`

	-- Show modal
	modal.Visible = true

	-- Fade in animation
	modal.BackgroundTransparency = 1
	content.Position = UDim2.new(0.5, 0, 0.3, 0)  -- Start higher

	local fadeIn = TweenService:Create(
		modal,
		TweenInfo.new(config.fadeInDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 0.5}
	)

	local slideIn = TweenService:Create(
		content,
		TweenInfo.new(config.fadeInDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, 0.5, 0)}
	)

	fadeIn:Play()
	slideIn:Play()

	-- Auto-close after duration if configured
	if config.displayDuration > 0 then
		task.delay(config.displayDuration, function()
			if modal and modal.Visible then
				LevelUpModal.hide()
				if config.autoOpenStatsPanel and onOpenStatsPanel then
					onOpenStatsPanel()
				end
			end
		end)
	end
end

--[[
	Hide level-up modal with animation
]]
function LevelUpModal.hide()
	if not modal or not content then
		return
	end

	local config = UIConfig.levelUpModal

	local fadeOut = TweenService:Create(
		modal,
		TweenInfo.new(config.fadeInDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{BackgroundTransparency = 1}
	)

	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		if modal then
			modal.Visible = false
		end
	end)
end

--[[
	Set callback for when stats panel should open

	@param callback - Function to call when opening stats panel
]]
function LevelUpModal.setOpenStatsPanelCallback(callback: () -> ())
	onOpenStatsPanel = callback
end

--[[
	Destroy the level-up modal
]]
function LevelUpModal.destroy()
	if modal then
		modal:Destroy()
		modal = nil
		content = nil
		levelText = nil
		pointsText = nil
	end
end

--[[
	Check if level-up modal is enabled in config

	@return boolean - Whether level-up modal is enabled
]]
function LevelUpModal.isEnabled(): boolean
	return UIConfig.levelUpModal.enabled
end

return LevelUpModal
