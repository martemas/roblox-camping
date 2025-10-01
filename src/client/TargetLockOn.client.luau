--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TargetingSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TargetingSystem"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
local waist: Motor6D? = nil

-- Find Waist Motor6D (R15 only)
local function findWaist(): Motor6D?
	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		return upperTorso:FindFirstChild("Waist") :: Motor6D?
	end
	return nil
end

-- Store original Waist C0 for reset
local originalWaistC0: CFrame? = nil

-- Calculate rotation to face target
local function getRotationToTarget(targetPos: Vector3): (number, number)
	local rootCFrame = humanoidRootPart.CFrame
	local rootPos = humanoidRootPart.Position

	-- Get direction to target in local space
	local toTarget = (targetPos - rootPos).Unit
	local localTarget = rootCFrame:VectorToObjectSpace(toTarget)

	-- Calculate yaw (left/right) and pitch (up/down)
	local yaw = math.atan2(-localTarget.X, -localTarget.Z)
	local pitch = math.asin(localTarget.Y)

	return math.deg(yaw), math.deg(pitch)
end

-- Clamp angle to range
local function clampAngle(angle: number, max: number): number
	return math.clamp(angle, -max, max)
end

-- Update waist rotation to face target
local function updateWaistRotation()
	if not waist or not originalWaistC0 then
		return
	end

	local target = TargetingSystem.getTarget(player)
	local isLocked = TargetingSystem.isLockedOn(player)

	if not target or not isLocked then
		-- Reset to original position
		waist.C0 = waist.C0:Lerp(originalWaistC0, GameConfig.targeting.lockOn.rotationSpeed * 2)
		return
	end

	-- Get target position
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	-- Calculate desired rotation
	local yaw, pitch = getRotationToTarget(targetRoot.Position)

	-- Clamp to configured limits
	yaw = clampAngle(yaw, GameConfig.targeting.lockOn.maxYawAngle)
	pitch = clampAngle(pitch, GameConfig.targeting.lockOn.maxPitchAngle)

	-- Apply rotation
	local desiredRotation = CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
	local targetC0 = originalWaistC0 * desiredRotation

	-- Smooth lerp
	waist.C0 = waist.C0:Lerp(targetC0, GameConfig.targeting.lockOn.rotationSpeed)
end

-- Initialize waist
local function initializeWaist()
	waist = findWaist()
	if waist then
		originalWaistC0 = waist.C0
		print("Target lock-on initialized")
	else
		warn("Waist Motor6D not found - lock-on disabled (R6 character?)")
	end
end

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	initializeWaist()
end)

-- Toggle lock-on with key press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if not GameConfig.targeting.lockOn.enabled then
		return
	end

	if input.KeyCode == GameConfig.targeting.lockOn.toggleKey then
		local locked = TargetingSystem.toggleLockOn(player)
		print(locked and "LOCKED ON" or "LOCK OFF")
	end
end)

-- Auto-unlock if target too far
local function checkAutoUnlock()
	if not TargetingSystem.isLockedOn(player) then
		return
	end

	local targetInfo = TargetingSystem.getTargetInfo(player)
	if not targetInfo then
		TargetingSystem.setLockedOn(player, false)
		return
	end

	if targetInfo.distance > GameConfig.targeting.lockOn.autoUnlockDistance then
		TargetingSystem.setLockedOn(player, false)
		print("Auto-unlocked: target too far")
	end
end

-- Initialize
initializeWaist()

-- Update loop
RunService.RenderStepped:Connect(function()
	if waist then
		updateWaistRotation()
		checkAutoUnlock()
	end
end)
