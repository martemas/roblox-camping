--!strict

--[[
	Notification UI Component

	Displays temporary notification messages in the center of the screen.

	Usage:
		local Notification = require(...)
		Notification.create(screenGui)
		Notification.show("Night phase has begun!")
]]

local TweenService = game:GetService("TweenService")

local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))

local Notification = UIComponent.new("Notification")

-- Component state
local notificationFrame: Frame? = nil

--[[
	Create the Notification UI

	@param parent - Parent ScreenGui
	@return The created Frame
]]
function Notification.create(parent: ScreenGui): Frame
	local config = UIConfig.notification

	-- Main Frame
	notificationFrame = Instance.new("Frame")
	notificationFrame.Name = "NotificationFrame"
	notificationFrame.Size = UIConfig.createUDim2(config.size)
	notificationFrame.Position = UIConfig.createUDim2(config.position)
	notificationFrame.BackgroundColor3 = config.backgroundColor
	notificationFrame.BackgroundTransparency = config.backgroundTransparency
	notificationFrame.BorderSizePixel = 2
	notificationFrame.BorderColor3 = config.borderColor
	notificationFrame.Visible = false
	notificationFrame.Parent = parent

	-- Notification Text
	local notificationText = Instance.new("TextLabel")
	notificationText.Name = "NotificationText"
	notificationText.Size = UDim2.new(1, -10, 1, -10)
	notificationText.Position = UDim2.new(0, 5, 0, 5)
	notificationText.BackgroundTransparency = 1
	notificationText.Text = ""
	notificationText.TextColor3 = config.textColor
	notificationText.TextScaled = true
	notificationText.Font = config.font
	notificationText.TextWrapped = true
	notificationText.Parent = notificationFrame

	print("[Notification] Component created")
	return notificationFrame
end

--[[
	Show a notification message

	@param message - Message to display
]]
function Notification.show(message: string)
	if not notificationFrame then
		warn("[Notification] Cannot show: component not created")
		return
	end

	local config = UIConfig.notification
	local notificationText = notificationFrame:FindFirstChild("NotificationText") :: TextLabel?

	if not notificationText then
		return
	end

	notificationText.Text = message
	notificationFrame.Visible = true
	notificationFrame.BackgroundTransparency = config.backgroundTransparency

	-- Fade out after display duration
	task.spawn(function()
		task.wait(config.displayDuration)

		local tween = TweenService:Create(
			notificationFrame,
			TweenInfo.new(config.fadeOutDuration, Enum.EasingStyle.Sine),
			{ BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()

		notificationFrame.Visible = false
		notificationFrame.BackgroundTransparency = config.backgroundTransparency
	end)
end

--[[
	Hide the notification immediately
]]
function Notification.hide()
	if notificationFrame then
		notificationFrame.Visible = false
	end
end

--[[
	Destroy the component
]]
function Notification.destroy()
	if notificationFrame then
		notificationFrame:Destroy()
		notificationFrame = nil
		print("[Notification] Component destroyed")
	end
end

--[[
	Check if component is enabled in UIConfig

	@return boolean
]]
function Notification.isEnabled(): boolean
	return UIConfig.notification.enabled
end

return Notification
