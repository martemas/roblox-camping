--!strict

--[[
	Health Bar UI Component

	Displays player's current and max health with a color-coded bar.

	Usage:
		local HealthBar = require(...)
		HealthBar.create(screenGui)
		HealthBar.startUpdating() -- Auto-updates from player's Humanoid
		HealthBar.stopUpdating()
]]

local Players = game:GetService("Players")

local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))

local HealthBar = UIComponent.new("HealthBar")

-- Component state
local healthFrame: Frame? = nil
local updateThread: thread? = nil
local player = Players.LocalPlayer

--[[
	Create the Health Bar UI

	@param parent - Parent ScreenGui
	@return The created Frame
]]
function HealthBar.create(parent: ScreenGui): Frame
	local config = UIConfig.healthBar

	-- Main Frame
	healthFrame = Instance.new("Frame")
	healthFrame.Name = "HealthFrame"
	healthFrame.Size = UIConfig.createUDim2(config.size)
	healthFrame.Position = UIConfig.createUDim2(config.position)
	healthFrame.BackgroundColor3 = config.backgroundColor
	healthFrame.BackgroundTransparency = config.backgroundTransparency
	healthFrame.BorderSizePixel = 2
	healthFrame.BorderColor3 = config.borderColor
	healthFrame.Parent = parent

	-- Health Bar Background
	local healthBg = Instance.new("Frame")
	healthBg.Name = "HealthBackground"
	healthBg.Size = UDim2.new(1, -10, 0, 20)
	healthBg.Position = UDim2.new(0, 5, 0, 15)
	healthBg.BackgroundColor3 = config.barBackgroundColor
	healthBg.BorderSizePixel = 0
	healthBg.Parent = healthFrame

	-- Health Bar Fill
	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.Position = UDim2.new(0, 0, 0, 0)
	healthFill.BackgroundColor3 = config.healthHighColor
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBg

	-- Health Text
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 0, 15)
	healthText.Position = UDim2.new(0, 0, 0, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = "Health: 100/100"
	healthText.TextColor3 = config.textColor
	healthText.TextScaled = true
	healthText.Font = config.font
	healthText.Parent = healthFrame

	print("[HealthBar] Component created")

	-- Start auto-updating
	HealthBar.startUpdating()

	return healthFrame
end

--[[
	Update the health display manually

	@param currentHealth - Current health value (optional, reads from character if not provided)
	@param maxHealth - Max health value (optional, reads from character if not provided)
]]
function HealthBar.update(currentHealth: number?, maxHealth: number?)
	if not healthFrame then
		return
	end

	local config = UIConfig.healthBar
	local character = player.Character

	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	-- Use provided values or read from humanoid
	local health = currentHealth or humanoid.Health
	local maxHp = maxHealth or humanoid.MaxHealth

	local healthText = healthFrame:FindFirstChild("HealthText") :: TextLabel?
	local healthFill = healthFrame:FindFirstChild("HealthBackground"):FindFirstChild("HealthFill") :: Frame?

	if healthText then
		healthText.Text = `Health: {math.floor(health)}/{math.floor(maxHp)}`
	end

	if healthFill then
		local healthPercent = health / maxHp
		healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)

		-- Change color based on health percentage
		if healthPercent > 0.6 then
			healthFill.BackgroundColor3 = config.healthHighColor
		elseif healthPercent > 0.3 then
			healthFill.BackgroundColor3 = config.healthMediumColor
		else
			healthFill.BackgroundColor3 = config.healthLowColor
		end
	end
end

--[[
	Start auto-updating the health bar
]]
function HealthBar.startUpdating()
	if updateThread then
		return -- Already updating
	end

	local config = UIConfig.healthBar

	updateThread = task.spawn(function()
		while healthFrame do
			HealthBar.update()
			task.wait(config.updateInterval)
		end
	end)
end

--[[
	Stop auto-updating the health bar
]]
function HealthBar.stopUpdating()
	if updateThread then
		task.cancel(updateThread)
		updateThread = nil
	end
end

--[[
	Destroy the component
]]
function HealthBar.destroy()
	HealthBar.stopUpdating()

	if healthFrame then
		healthFrame:Destroy()
		healthFrame = nil
		print("[HealthBar] Component destroyed")
	end
end

--[[
	Check if component is enabled in UIConfig

	@return boolean
]]
function HealthBar.isEnabled(): boolean
	return UIConfig.healthBar.enabled
end

return HealthBar
