--!strict

-- Movement Controller - Handles player input for movement (server controls actual speed via attributes)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

-- Track input state only
local isShiftPressed = false

-- Update UI based on server attributes
local function updateStaminaUI()
	local character = player.Character
	if not character then return end

	local currentStamina = character:GetAttribute("CurrentStamina")
	local maxStamina = character:GetAttribute("MaxStamina")

	if currentStamina and maxStamina then
		-- Update UI via GameUI
		local GameUI = _G.GameUI
		if GameUI and GameUI.updateStaminaUI then
			GameUI.updateStaminaUI(currentStamina, maxStamina)
		end
	end
end

-- Start sprinting (request to server)
local function startSprinting()
	RemoteEvents.Events.StartSprint:FireServer()
	print("Requested sprint start")
end

-- Stop sprinting (request to server)
local function stopSprinting()
	RemoteEvents.Events.StopSprint:FireServer()
	print("Requested sprint stop")
end

-- Handle input
local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		isShiftPressed = true
		startSprinting()
	end
end

local function onInputEnded(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		isShiftPressed = false
		stopSprinting()
	end
end

-- Handle character spawning
local function onCharacterAdded(character: Model)
	-- Reset input state
	isShiftPressed = false

	print("Movement controller set up for new character")
end

-- Initialize
local function initialize()
	-- Connect input events
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	-- Connect character events
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Handle existing character
	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- Start UI update loop (reads from attributes)
	RunService.Heartbeat:Connect(updateStaminaUI)

	print("MovementController initialized")
end

-- Start the system
initialize()