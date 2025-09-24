--!strict

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

type GamePhase = Types.GamePhase

local DayNightCycle = {}
local currentPhase: GamePhase = "Day"
local phaseStartTime: number = 0
local phaseEndTime: number = 0
local isTransitioning: boolean = false

-- Lighting settings for different phases
local LIGHTING_SETTINGS = {
	Day = {
		TimeOfDay = "12:00:00",
		Brightness = 1,
		ColorShift_Top = Color3.fromRGB(0, 0, 0),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		Ambient = Color3.fromRGB(138, 138, 138),
		OutdoorAmbient = Color3.fromRGB(198, 198, 198),
	},
	Night = {
		TimeOfDay = "00:00:00",
		Brightness = 0.5,
		ColorShift_Top = Color3.fromRGB(76, 76, 127),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		Ambient = Color3.fromRGB(59, 59, 80),
		OutdoorAmbient = Color3.fromRGB(59, 59, 80),
	},
}

-- Properties that can be tweened (excludes TimeOfDay)
local TWEENABLE_PROPERTIES = {
	"Brightness",
	"ColorShift_Top",
	"ColorShift_Bottom",
	"Ambient",
	"OutdoorAmbient"
}

-- Update lighting smoothly to target settings
local function updateLighting(targetSettings: {[string]: any})
	-- Set TimeOfDay immediately (can't be tweened)
	if targetSettings.TimeOfDay then
		Lighting.TimeOfDay = targetSettings.TimeOfDay
	end

	-- Tween other properties
	local tweenInfo = TweenInfo.new(
		GameConfig.time.transitionTime,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut
	)

	local tweenableSettings = {}
	for _, property in pairs(TWEENABLE_PROPERTIES) do
		if targetSettings[property] then
			tweenableSettings[property] = targetSettings[property]
		end
	end

	if next(tweenableSettings) then
		local tween = TweenService:Create(Lighting, tweenInfo, tweenableSettings)
		tween:Play()
		tween.Completed:Wait()
	end
end

-- Get remaining time in current phase
local function getRemainingTime(): number
	return math.max(0, phaseEndTime - tick())
end

-- Get phase duration
local function getPhaseDuration(phase: GamePhase): number
	if phase == "Day" then
		return GameConfig.time.dayDuration
	elseif phase == "Night" then
		return GameConfig.time.nightDuration
	else -- Transition
		return GameConfig.time.transitionTime
	end
end

-- Start a new phase
local function startPhase(newPhase: GamePhase)
	currentPhase = newPhase
	phaseStartTime = tick()
	phaseEndTime = phaseStartTime + getPhaseDuration(newPhase)

	print(`Phase changed to: {newPhase}`)

	-- Update lighting
	if newPhase ~= "Transition" then
		local lightingSettings = LIGHTING_SETTINGS[newPhase]
		if lightingSettings then
			updateLighting(lightingSettings)
		end
	end

	-- Notify all players
	RemoteEvents.Events.PhaseChanged:FireAllClients(newPhase)

	-- TODO: Play phase transition sound when sound assets are ready
	-- local soundName = newPhase .. "Transition"
	-- local sound = ReplicatedStorage.Sounds:FindFirstChild(soundName)
	-- if sound then
	--     sound:Play()
	-- end

	-- Special actions for each phase
	if newPhase == "Day" then
		-- Day phase started - safe time for resource gathering
		print("Day has begun - players can safely gather resources")

	elseif newPhase == "Night" then
		-- Night phase started - danger time
		print("Night has fallen - enemies will spawn soon")

		-- Signal enemy spawner to start spawning
		task.spawn(function()
			-- Wait for EnemySpawner to be available in global scope
			while not _G.EnemySpawner do
				task.wait(0.1)
			end
			_G.EnemySpawner.StartNightWave()
		end)
	end
end

-- Update timer and check for phase transitions
local function updateCycle()
	if isTransitioning then
		return
	end

	local remainingTime = getRemainingTime()

	-- Send timer update to clients every second
	RemoteEvents.Events.UpdatePhaseTimer:FireAllClients(currentPhase, remainingTime)

	-- Check if phase should end
	if remainingTime <= 0 then
		isTransitioning = true

		-- Determine next phase
		local nextPhase: GamePhase
		if currentPhase == "Day" then
			nextPhase = "Night"
		else
			nextPhase = "Day"
		end

		-- Start transition
		startPhase("Transition")
		task.wait(GameConfig.time.transitionTime)

		-- Start the actual next phase
		startPhase(nextPhase)
		isTransitioning = false
	end
end

-- Force start a specific phase (for testing)
local function forcePhase(phase: GamePhase)
	if isTransitioning then
		return
	end

	print(`Forcing phase change to: {phase}`)
	startPhase(phase)
end

-- Public API
function DayNightCycle.GetCurrentPhase(): GamePhase
	return currentPhase
end

function DayNightCycle.GetRemainingTime(): number
	return getRemainingTime()
end

function DayNightCycle.IsDay(): boolean
	return currentPhase == "Day"
end

function DayNightCycle.IsNight(): boolean
	return currentPhase == "Night"
end

function DayNightCycle.ForceDay()
	forcePhase("Day")
end

function DayNightCycle.ForceNight()
	forcePhase("Night")
end

function DayNightCycle.GetPhaseProgress(): number
	local elapsed = tick() - phaseStartTime
	local duration = getPhaseDuration(currentPhase)
	return math.clamp(elapsed / duration, 0, 1)
end

-- Initialize the day/night cycle
local function initialize()
	-- Set initial lighting to day
	for property, value in pairs(LIGHTING_SETTINGS.Day) do
		if Lighting[property] ~= nil then
			Lighting[property] = value
		end
	end

	-- Start the first day phase
	startPhase("Day")

	-- Start the update loop
	RunService.Heartbeat:Connect(updateCycle)

	print("DayNightCycle initialized - starting with Day phase")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.DayNightCycle = DayNightCycle

return DayNightCycle