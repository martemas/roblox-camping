--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local TargetingSystem = {
	currentTarget = nil :: Model?,
	targetHighlight = nil :: SelectionBox?,
	targetConnection = nil :: RBXScriptConnection?,
}

-- Create visual highlight for selected target
local function createTargetHighlight(target: Model): SelectionBox
	local highlight = Instance.new("SelectionBox")
	highlight.Name = "TargetHighlight"
	highlight.Adornee = target
	highlight.Color3 = Color3.fromRGB(255, 100, 100) -- Red for enemies/wildlife
	highlight.LineThickness = 0.2
	highlight.Transparency = 0.3
	highlight.Parent = workspace

	-- Change color based on entity type
	local entityCategory = target:GetAttribute("EntityCategory")
	if entityCategory == "resource" then
		highlight.Color3 = Color3.fromRGB(100, 255, 100) -- Green for resources
	elseif entityCategory == "wildlife" then
		highlight.Color3 = Color3.fromRGB(255, 150, 0) -- Orange for wildlife
	end

	return highlight
end

-- Clear current target and highlighting
local function clearTarget()
	if TargetingSystem.targetHighlight then
		TargetingSystem.targetHighlight:Destroy()
		TargetingSystem.targetHighlight = nil
	end

	if TargetingSystem.targetConnection then
		TargetingSystem.targetConnection:Disconnect()
		TargetingSystem.targetConnection = nil
	end

	TargetingSystem.currentTarget = nil
	print("Target cleared") -- DEBUG
end

-- Check if entity is valid for targeting
local function isValidTarget(model: Model): boolean
	local entityType = model:GetAttribute("EntityType")
	local entityCategory = model:GetAttribute("EntityCategory")
	local canTakeDamage = model:GetAttribute("CanTakeDamage")

	-- Must be a valid entity that can take damage
	if not entityType or not entityCategory or not canTakeDamage then
		return false
	end

	-- Check if it's alive (has health > 0)
	local currentHealth = model:GetAttribute("CurrentHealth")
	if currentHealth and currentHealth <= 0 then
		return false
	end

	-- Check for Humanoid health for entities without CurrentHealth attribute
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end

	return true
end

-- Find the root entity model from a clicked part
local function findEntityFromPart(part: BasePart): Model?
	local current = part.Parent

	-- Traverse up the hierarchy to find an entity
	while current and current ~= workspace do
		if current:IsA("Model") then
			local entityType = current:GetAttribute("EntityType")
			if entityType then
				return current
			end
		end
		current = current.Parent
	end

	return nil
end

-- Set a new target
local function setTarget(target: Model)
	-- Clear previous target
	clearTarget()

	-- Validate new target
	if not isValidTarget(target) then
		print(`Invalid target: {target.Name}`) -- DEBUG
		return
	end

	-- Set new target
	TargetingSystem.currentTarget = target
	TargetingSystem.targetHighlight = createTargetHighlight(target)

	-- Monitor target for destruction/death
	TargetingSystem.targetConnection = target.AncestryChanged:Connect(function()
		if not target.Parent then
			clearTarget()
		end
	end)

	print(`Target selected: {target.Name} ({target:GetAttribute("EntityType")})`) -- DEBUG
end

-- Handle mouse click for target selection
local function onMouseClick()
	local hitPart = mouse.Hit and mouse.Target
	if not hitPart then
		-- Click on empty space - clear target
		clearTarget()
		return
	end

	-- Find entity from clicked part
	local entity = findEntityFromPart(hitPart)
	if not entity then
		-- Clicked on non-entity - clear target
		clearTarget()
		return
	end

	-- If clicking same target, clear it
	if entity == TargetingSystem.currentTarget then
		clearTarget()
		return
	end

	-- Set new target
	setTarget(entity)
end

-- Handle touch input for mobile devices
local function onTouchTap(touchPositions: {Vector2}, gameProcessed: boolean)
	if gameProcessed then return end

	-- For touch devices, we need to raycast from camera through touch position
	local camera = workspace.CurrentCamera
	if not camera then return end

	local screenPosition = touchPositions[1]
	local unitRay = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)

	-- Perform raycast
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {player.Character}

	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)

	if raycastResult then
		local hitPart = raycastResult.Instance
		local entity = findEntityFromPart(hitPart)

		if entity and entity ~= TargetingSystem.currentTarget then
			setTarget(entity)
		elseif entity == TargetingSystem.currentTarget then
			clearTarget()
		elseif not entity then
			clearTarget()
		end
	else
		clearTarget()
	end
end

-- Public API
function TargetingSystem.GetCurrentTarget(): Model?
	return TargetingSystem.currentTarget
end

function TargetingSystem.ClearTarget()
	clearTarget()
end

function TargetingSystem.SetTarget(target: Model)
	setTarget(target)
end

-- Initialize targeting system
local function initialize()
	-- Connect mouse click for desktop
	if UserInputService.MouseEnabled then
		mouse.Button1Down:Connect(onMouseClick)
	end

	-- Connect touch input for mobile
	if UserInputService.TouchEnabled then
		UserInputService.TouchTap:Connect(onTouchTap)
	end

	print("TargetingSystem initialized")
end

-- Start the system
initialize()

-- Export to global for other scripts to access
_G.TargetingSystem = TargetingSystem

return TargetingSystem