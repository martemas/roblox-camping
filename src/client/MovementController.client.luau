--!strict

-- Movement Controller - Handles player movement including sprint functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

-- Sprint settings (loaded from config)
local NORMAL_WALKSPEED = GameConfig.player.walkSpeed
local SPRINT_WALKSPEED = GameConfig.player.sprintSpeed
local SPRINT_STAMINA_MAX = GameConfig.player.maxStamina
local STAMINA_DRAIN_RATE = GameConfig.player.staminaDrainRate
local STAMINA_REGEN_RATE = GameConfig.player.staminaRegenRate

-- Sprint state
local isSprinting = false
local currentStamina = SPRINT_STAMINA_MAX

-- Track input state
local isShiftPressed = false

-- Update stamina
local function updateStamina(deltaTime: number)
	if isSprinting and currentStamina > 0 then
		currentStamina = math.max(0, currentStamina - (STAMINA_DRAIN_RATE * deltaTime))
		if currentStamina <= 0 then
			-- Stop sprinting when out of stamina
			stopSprinting()
		end
	elseif not isSprinting and currentStamina < SPRINT_STAMINA_MAX then
		currentStamina = math.min(SPRINT_STAMINA_MAX, currentStamina + (STAMINA_REGEN_RATE * deltaTime))
	end

	-- Update UI via GameUI
	local GameUI = _G.GameUI
	if GameUI and GameUI.updateStaminaUI then
		GameUI.updateStaminaUI(currentStamina, SPRINT_STAMINA_MAX)
	end
end

-- Start sprinting
local function startSprinting()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if currentStamina > 0 and not isSprinting then
		isSprinting = true
		humanoid.WalkSpeed = SPRINT_WALKSPEED
		print("Started sprinting")
	end
end

-- Stop sprinting
function stopSprinting()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if isSprinting then
		isSprinting = false
		humanoid.WalkSpeed = NORMAL_WALKSPEED
		print("Stopped sprinting")
	end
end

-- Handle input
local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		isShiftPressed = true
		if currentStamina > 0 then
			startSprinting()
		end
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
	-- Reset sprint state
	isSprinting = false
	currentStamina = SPRINT_STAMINA_MAX
	isShiftPressed = false

	-- Wait for humanoid
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = NORMAL_WALKSPEED

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

	-- Start stamina update loop
	RunService.Heartbeat:Connect(updateStamina)

	print("MovementController initialized")
end

-- Start the system
initialize()