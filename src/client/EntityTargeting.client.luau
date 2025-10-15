--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TargetingSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("player"):WaitForChild("TargetingSystem"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("core"):WaitForChild("RemoteEvents"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config"))
local PlayerSettingsManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("player"):WaitForChild("PlayerSettingsManager"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- Initialize systems
TargetingSystem.initialize()
PlayerSettingsManager.initialize()

-- PlayerSettingsManager will be used in connectMouseEvents()

-- Find entity model from a clicked part (traverse up the hierarchy)
local function findEntityFromPart(hitPart: BasePart): Model?
	local current = hitPart.Parent

	-- Traverse up the hierarchy to find a targetable entity
	while current and current ~= workspace do
		if current:IsA("Model") and TargetingSystem.isTargetable(current) then
			return current
		end
		current = current.Parent
	end

	return nil
end

-- Clear current target
local function clearTarget()
	TargetingSystem.setTarget(player, nil)
	RemoteEvents.Events.DeselectTarget:FireServer()
end

-- Set new target
local function setTarget(entity: Model)
	local success = TargetingSystem.setTarget(player, entity)
	if success then
		print(`Targeted {entity.Name}`)
		RemoteEvents.Events.SelectTarget:FireServer(entity)
	end
end

-- Raycast from screen position to find what was clicked/tapped
local function raycastFromScreenPosition(screenPosition: Vector2): BasePart?
	if not camera then
		return nil
	end

	-- Get world ray from screen position
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)

	-- Setup raycast params
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {player.Character}
	raycastParams.IgnoreWater = true

	-- Perform raycast
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

	return result and result.Instance
end

-- Handle mouse clicks for targeting (works with mouse or touch)
local function onMouseClick(screenPosition: Vector2?)
	-- Use provided screen position or current mouse position
	local hitPart: BasePart?
	if screenPosition then
		-- Touch input - use raycast
		hitPart = raycastFromScreenPosition(screenPosition)
	else
		-- Mouse input - use mouse.Target
		hitPart = mouse.Target
	end

	if not hitPart then
		-- Click on empty space - keep current target (if any)
		return
	end

	-- Find entity from clicked part
	local entity = findEntityFromPart(hitPart)
	if entity then
		-- Clicked on an entity - set it as target
		setTarget(entity)
	else
		-- Clicked on non-entity (ground, objects, etc.)
		-- Keep current target if one exists - just let the tool fire
		local currentTarget = TargetingSystem.getTarget(player)
		if currentTarget then
			-- Re-send target to server to ensure sync (in case it was lost)
			RemoteEvents.Events.SelectTarget:FireServer(currentTarget)
		end
	end
end

-- Handle keyboard shortcuts
local function onKeyPressed(key: string)
	if key == "X" then
		-- Find and target closest entity
		local closestTarget = TargetingSystem.findClosestTarget(player)
		if closestTarget then
			local success = TargetingSystem.setTarget(player, closestTarget)
			if success then
				print(`Targeted closest entity: {closestTarget.Name}`)
				RemoteEvents.Events.SelectTarget:FireServer(closestTarget)
			end
		else
			print("No targetable entities nearby")
		end
	elseif key == "Escape" then
		-- Clear current target
		TargetingSystem.setTarget(player, nil)
		RemoteEvents.Events.DeselectTarget:FireServer()
		print("Target cleared")
	end
end

-- Connect configurable mouse input events
local function connectMouseEvents()
	local controls = PlayerSettingsManager.getControlSettings(player)

	-- Connect the appropriate mouse button based on settings
	if controls.targetingMouseButton == "Left" then
		mouse.Button1Down:Connect(onMouseClick)
		print("EntityTargeting: Using LEFT mouse button for targeting")
	elseif controls.targetingMouseButton == "Right" then
		mouse.Button2Down:Connect(onMouseClick)
		print("EntityTargeting: Using RIGHT mouse button for targeting")
	elseif controls.targetingMouseButton == "Middle" then
		mouse.Button3Down:Connect(onMouseClick)
		print("EntityTargeting: Using MIDDLE mouse button for targeting")
	end
end

-- Connect mouse events
connectMouseEvents()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- Don't process if GUI consumed the input
	end

	local controls = PlayerSettingsManager.getControlSettings(player)

	if input.KeyCode == controls.targetClosestKey then
		onKeyPressed("X")
	elseif input.KeyCode == controls.clearTargetKey then
		onKeyPressed("Escape")
	end
end)

-- Handle touch input for mobile (if supported)
if UserInputService.TouchEnabled then
	UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
		if gameProcessed then
			return
		end

		-- Use the first touch position
		if #touchPositions > 0 then
			local touchPos = touchPositions[1]
			-- Pass touch position to onMouseClick for raycasting
			onMouseClick(vector.create(touchPos.X, touchPos.Y))
		end
	end)
end

print("EntityTargeting client initialized")