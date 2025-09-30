--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

-- Player sprint data
local playerSprintData: {[Player]: {
	isSprinting: boolean,
	stamina: number,
	maxStamina: number,
	baseWalkSpeed: number,
	sprintWalkSpeed: number,
}} = {}

-- Update player stamina and speed
local function updatePlayerSprint(player: Player, deltaTime: number)
	local data = playerSprintData[player]
	if not data then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Update stamina
	if data.isSprinting and data.stamina > 0 then
		data.stamina = math.max(0, data.stamina - (GameConfig.player.staminaDrainRate * deltaTime))
		if data.stamina <= 0 then
			-- Stop sprinting when out of stamina
			data.isSprinting = false
			humanoid.WalkSpeed = data.baseWalkSpeed
			character:SetAttribute("IsSprinting", false)
			character:SetAttribute("WalkSpeed", data.baseWalkSpeed)
		end
	elseif not data.isSprinting and data.stamina < data.maxStamina then
		data.stamina = math.min(data.maxStamina, data.stamina + (GameConfig.player.staminaRegenRate * deltaTime))
	end

	-- Update stamina attribute for client UI
	character:SetAttribute("CurrentStamina", data.stamina)
	character:SetAttribute("MaxStamina", data.maxStamina)
end

-- Handle sprint start request
local function onStartSprint(player: Player)
	local data = playerSprintData[player]
	if not data then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if data.stamina > 0 and not data.isSprinting then
		data.isSprinting = true
		humanoid.WalkSpeed = data.sprintWalkSpeed
		character:SetAttribute("IsSprinting", true)
		character:SetAttribute("WalkSpeed", data.sprintWalkSpeed)
	end
end

-- Handle sprint stop request
local function onStopSprint(player: Player)
	local data = playerSprintData[player]
	if not data then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if data.isSprinting then
		data.isSprinting = false
		humanoid.WalkSpeed = data.baseWalkSpeed
		character:SetAttribute("IsSprinting", false)
		character:SetAttribute("WalkSpeed", data.baseWalkSpeed)
	end
end

-- Setup player sprint data when character spawns
local function onCharacterAdded(character: Model)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	-- Initialize sprint data
	local baseSpeed = GameConfig.player.baseWalkSpeed
	local sprintSpeed = baseSpeed * GameConfig.player.sprintMultiplier

	playerSprintData[player] = {
		isSprinting = false,
		stamina = GameConfig.player.maxStamina,
		maxStamina = GameConfig.player.maxStamina,
		baseWalkSpeed = baseSpeed,
		sprintWalkSpeed = sprintSpeed,
	}

	-- Set initial attributes
	humanoid.WalkSpeed = baseSpeed
	character:SetAttribute("IsSprinting", false)
	character:SetAttribute("WalkSpeed", baseSpeed)
	character:SetAttribute("CurrentStamina", GameConfig.player.maxStamina)
	character:SetAttribute("MaxStamina", GameConfig.player.maxStamina)

	print(`SprintManager: Set up sprint data for {player.Name}`)
end

-- Clean up when player leaves
local function onPlayerRemoving(player: Player)
	playerSprintData[player] = nil
end

-- Main update loop
local function updateSprints()
	local deltaTime = RunService.Heartbeat:Wait()
	for player, _ in pairs(playerSprintData) do
		updatePlayerSprint(player, deltaTime)
	end
end

-- Initialize the sprint manager
local function initialize()
	-- Connect player events
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(onCharacterAdded)
		if player.Character then
			onCharacterAdded(player.Character)
		end
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle existing players
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character then
			onCharacterAdded(player.Character)
		end
	end

	-- Connect remote events
	RemoteEvents.Events.StartSprint.OnServerEvent:Connect(onStartSprint)
	RemoteEvents.Events.StopSprint.OnServerEvent:Connect(onStopSprint)

	-- Start update loop
	task.spawn(function()
		while true do
			updateSprints()
		end
	end)

	print("SprintManager initialized")
end

-- Start the system
initialize()