--!strict

--[[
	Stamina Bar UI Component

	Displays player's current and max stamina with a color-coded bar.

	Usage:
		local StaminaBar = require(...)
		StaminaBar.create(screenGui)
		StaminaBar.update(currentStamina, maxStamina)
]]

local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))

local StaminaBar = UIComponent.new("StaminaBar")

-- Component state
local staminaFrame: Frame? = nil

--[[
	Create the Stamina Bar UI

	@param parent - Parent ScreenGui
	@return The created Frame
]]
function StaminaBar.create(parent: ScreenGui): Frame
	local config = UIConfig.staminaBar

	-- Main Frame
	staminaFrame = Instance.new("Frame")
	staminaFrame.Name = "StaminaFrame"
	staminaFrame.Size = UIConfig.createUDim2(config.size)
	staminaFrame.Position = UIConfig.createUDim2(config.position)
	staminaFrame.BackgroundColor3 = config.backgroundColor
	staminaFrame.BackgroundTransparency = config.backgroundTransparency
	staminaFrame.BorderSizePixel = 2
	staminaFrame.BorderColor3 = config.borderColor
	staminaFrame.Parent = parent

	-- Stamina Bar Background
	local staminaBg = Instance.new("Frame")
	staminaBg.Name = "StaminaBackground"
	staminaBg.Size = UDim2.new(1, -10, 0, 20)
	staminaBg.Position = UDim2.new(0, 5, 0, 15)
	staminaBg.BackgroundColor3 = config.barBackgroundColor
	staminaBg.BorderSizePixel = 0
	staminaBg.Parent = staminaFrame

	-- Stamina Bar Fill
	local staminaFill = Instance.new("Frame")
	staminaFill.Name = "StaminaFill"
	staminaFill.Size = UDim2.new(1, 0, 1, 0)
	staminaFill.Position = UDim2.new(0, 0, 0, 0)
	staminaFill.BackgroundColor3 = config.staminaHighColor
	staminaFill.BorderSizePixel = 0
	staminaFill.Parent = staminaBg

	-- Stamina Text
	local staminaText = Instance.new("TextLabel")
	staminaText.Name = "StaminaText"
	staminaText.Size = UDim2.new(1, 0, 0, 15)
	staminaText.Position = UDim2.new(0, 0, 0, 0)
	staminaText.BackgroundTransparency = 1
	staminaText.Text = "Stamina: 100/100"
	staminaText.TextColor3 = config.textColor
	staminaText.TextScaled = true
	staminaText.Font = config.font
	staminaText.Parent = staminaFrame

	print("[StaminaBar] Component created")
	return staminaFrame
end

--[[
	Update the stamina display

	@param currentStamina - Current stamina value
	@param maxStamina - Max stamina value
]]
function StaminaBar.update(currentStamina: number, maxStamina: number)
	if not staminaFrame then
		warn("[StaminaBar] Cannot update: component not created")
		return
	end

	-- Validate inputs
	if not currentStamina or not maxStamina then
		warn("[StaminaBar] Invalid stamina values (nil)")
		return
	end

	local config = UIConfig.staminaBar
	local staminaText = staminaFrame:FindFirstChild("StaminaText") :: TextLabel?
	local staminaBg = staminaFrame:FindFirstChild("StaminaBackground") :: Frame?
	local staminaFill = staminaBg and staminaBg:FindFirstChild("StaminaFill") :: Frame?

	if staminaText then
		staminaText.Text = `Stamina: {math.floor(currentStamina)}/{math.floor(maxStamina)}`
	end

	if staminaFill then
		local staminaPercent = currentStamina / maxStamina
		staminaFill.Size = UDim2.new(staminaPercent, 0, 1, 0)

		-- Change color based on stamina percentage
		if staminaPercent > 0.6 then
			staminaFill.BackgroundColor3 = config.staminaHighColor
		elseif staminaPercent > 0.3 then
			staminaFill.BackgroundColor3 = config.staminaMediumColor
		else
			staminaFill.BackgroundColor3 = config.staminaLowColor
		end
	end
end

--[[
	Destroy the component
]]
function StaminaBar.destroy()
	if staminaFrame then
		staminaFrame:Destroy()
		staminaFrame = nil
		print("[StaminaBar] Component destroyed")
	end
end

--[[
	Check if component is enabled in UIConfig

	@return boolean
]]
function StaminaBar.isEnabled(): boolean
	return UIConfig.staminaBar.enabled
end

return StaminaBar
