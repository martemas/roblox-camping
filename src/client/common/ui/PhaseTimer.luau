--!strict

--[[
	Phase Timer UI Component

	Displays the current game phase (Day/Night/Prep) and remaining time.

	Usage:
		local PhaseTimer = require(...)
		PhaseTimer.create(screenGui)
		PhaseTimer.update("Day", 180)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))
local Types = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("Types"))

type GamePhase = Types.GamePhase

local PhaseTimer = UIComponent.new("PhaseTimer")

-- Component state
local phaseTimerFrame: Frame? = nil

--[[
	Create the Phase Timer UI

	@param parent - Parent ScreenGui
	@return The created Frame
]]
function PhaseTimer.create(parent: ScreenGui): Frame
	local config = UIConfig.phaseTimer

	-- Main Frame
	phaseTimerFrame = Instance.new("Frame")
	phaseTimerFrame.Name = "PhaseTimerFrame"
	phaseTimerFrame.Size = UIConfig.createUDim2(config.size)
	phaseTimerFrame.Position = UIConfig.createUDim2(config.position)
	phaseTimerFrame.BackgroundColor3 = config.backgroundColor
	phaseTimerFrame.BackgroundTransparency = config.backgroundTransparency
	phaseTimerFrame.BorderSizePixel = 2
	phaseTimerFrame.BorderColor3 = config.borderColor
	phaseTimerFrame.Parent = parent

	-- Phase Label
	local phaseLabel = Instance.new("TextLabel")
	phaseLabel.Name = "PhaseLabel"
	phaseLabel.Size = UDim2.new(1, 0, 0.5, 0)
	phaseLabel.Position = UDim2.new(0, 0, 0, 0)
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.Text = "Day"
	phaseLabel.TextColor3 = config.dayPhaseColor
	phaseLabel.TextScaled = true
	phaseLabel.Font = config.font
	phaseLabel.Parent = phaseTimerFrame

	-- Timer Label
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(1, 0, 0.5, 0)
	timerLabel.Position = UDim2.new(0, 0, 0.5, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "Gather resources, build and protect the camp!"
	timerLabel.TextColor3 = config.textColor
	timerLabel.TextScaled = true
	timerLabel.Font = config.font
	timerLabel.Parent = phaseTimerFrame

	print("[PhaseTimer] Component created")
	return phaseTimerFrame
end

--[[
	Update the phase timer display

	@param phase - Current game phase
	@param remainingTime - Remaining time in seconds
]]
function PhaseTimer.update(phase: GamePhase, remainingTime: number)
	if not phaseTimerFrame then
		warn("[PhaseTimer] Cannot update: component not created")
		return
	end

	local config = UIConfig.phaseTimer
	local phaseLabel = phaseTimerFrame:FindFirstChild("PhaseLabel") :: TextLabel?
	local timerLabel = phaseTimerFrame:FindFirstChild("TimerLabel") :: TextLabel?

	if phaseLabel then
		phaseLabel.Text = phase

		-- Change color based on phase
		if phase == "Day" then
			phaseLabel.TextColor3 = config.dayPhaseColor
		elseif phase == "Night" then
			phaseLabel.TextColor3 = config.nightPhaseColor
		else
			phaseLabel.TextColor3 = config.prepPhaseColor
		end
	end

	if timerLabel then
		local minutes = math.floor(remainingTime / 60)
		local seconds = math.floor(remainingTime % 60)
		timerLabel.Text = string.format("%d:%02d", minutes, seconds)
	end
end

--[[
	Destroy the component
]]
function PhaseTimer.destroy()
	if phaseTimerFrame then
		phaseTimerFrame:Destroy()
		phaseTimerFrame = nil
		print("[PhaseTimer] Component destroyed")
	end
end

--[[
	Check if component is enabled in UIConfig

	@return boolean
]]
function PhaseTimer.isEnabled(): boolean
	return UIConfig.phaseTimer.enabled
end

return PhaseTimer
