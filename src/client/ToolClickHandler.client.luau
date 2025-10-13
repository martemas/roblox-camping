--!strict

--[[
	ToolClickHandler - Client-Side Click/Touch Target Detection

	Handles mouse click and mobile touch detection for projectile weapons in ACTION mode.
	When player clicks/taps to fire a projectile without a locked target, this
	searches for nearby targetable entities near the click/tap position.

	Flow:
	1. Capture touch/click position on input
	2. Tool.Activated fires when player clicks/taps
	3. Raycast from camera through stored input position to find click point
	4. Spherecast around click point to find targetable entities
	5. Send target (or click position if no target) to server
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local TargetingSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TargetingSystem"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config"))

type ToolType = Types.ToolType

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- Configuration
local MAX_RAYCAST_DISTANCE = 1000 -- Max distance for click raycast

-- Track last input position (for mobile touch support)
local lastInputPosition: Vector2? = nil

--[[
	Perform a raycast from camera through screen position

	@param screenPosition - Screen position (Vector2) to raycast from
	@return RaycastResult? - Hit result or nil
]]
local function raycastFromScreenPosition(screenPosition: Vector2): RaycastResult?
	if not camera then
		return nil
	end

	-- Get world ray from screen position
	local mouseRay = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)

	-- Setup raycast params
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {player.Character}
	raycastParams.IgnoreWater = true

	-- Perform raycast
	local origin = mouseRay.Origin
	local direction = mouseRay.Direction * MAX_RAYCAST_DISTANCE

	return workspace:Raycast(origin, direction, raycastParams)
end

--[[
	Find targetable entities near a position using spherecast

	@param position - Center position to search around
	@param radius - Search radius
	@return Model? - Closest targetable entity or nil
]]
local function findTargetNearPosition(position: Vector3, radius: number): Model?
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	local playerRoot = player.Character.HumanoidRootPart
	local closestTarget: Model? = nil
	local closestDistanceFromClick = math.huge

	-- Use GetPartBoundsInRadius to find all parts within radius of click position
	local parts = workspace:GetPartBoundsInRadius(position, radius)

	-- Check each part's parent model
	local checkedModels = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")

		-- Skip if already checked, is player's character, or not a model
		if model and model ~= player.Character and not checkedModels[model] then
			checkedModels[model] = true

			-- Check if targetable
			if TargetingSystem.isTargetable(model) and TargetingSystem.isValidTarget(model) then
				local modelRoot = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
				if modelRoot then
					-- Calculate distance from CLICK POSITION (not player)
					local distanceFromClick = (modelRoot.Position - position).Magnitude

					-- Verify target is actually within radius (double-check)
					if distanceFromClick <= radius then
						-- Prefer targets closer to click position
						if distanceFromClick < closestDistanceFromClick then
							closestTarget = model
							closestDistanceFromClick = distanceFromClick
						end
					end
				end
			end
		end
	end

	if closestTarget then
		print(`[ClickHandler] Selected target {closestTarget.Name} at {math.floor(closestDistanceFromClick * 10) / 10} studs from click`)
	end

	return closestTarget
end

--[[
	Handle tool activation with click/touch targeting

	@param toolType - Type of tool being used
]]
local function onToolActivated(toolType: ToolType)
	-- Get locked target (used for validation and autoAim=true)
	local lockedTarget = TargetingSystem.getTarget(player)

	local clickTarget: Model? = nil
	local clickPosition: Vector3? = nil

	-- ALWAYS capture click/tap position (needed for default behavior)
	-- Get screen position (use stored touch position or current mouse position)
	local screenPosition = lastInputPosition or vector.create(mouse.X, mouse.Y)

	-- Raycast from screen position to get click point
	local rayResult = raycastFromScreenPosition(screenPosition)

	if rayResult then
		clickPosition = rayResult.Position

		-- Search for targetable entities near click point (using configured radius)
		local searchRadius = GameConfig.combat.clickTargetSearchRadius
		clickTarget = findTargetNearPosition(clickPosition, searchRadius)

		if clickTarget then
			print(`[ClickHandler] Found click target: {clickTarget.Name} (within {searchRadius} studs)`)
		elseif clickPosition then
			print(`[ClickHandler] No target near click, using position: {clickPosition}`)
		end
	else
		print(`[ClickHandler] No raycast hit - will use look direction fallback`)
	end

	-- Clear stored input position after use
	lastInputPosition = nil

	-- Send to server (server will decide based on autoAim setting)
	-- - autoAim=true + lockedTarget: Server uses locked target
	-- - autoAim=false: Server uses clickTarget/clickPosition
	RemoteEvents.Events.SwingToolWithTarget:FireServer(toolType, clickTarget, clickPosition)
end

--[[
	Setup tool activation listeners for player's tools
]]
local function setupToolListeners()
	local function connectTool(tool: Tool)
		if not tool:IsA("Tool") then
			return
		end

		-- Get tool type from name
		local toolType = tool.Name :: ToolType

		-- Connect activation
		tool.Activated:Connect(function()
			onToolActivated(toolType)
		end)

		print(`[ClickHandler] Connected listener for {toolType}`)
	end

	-- Connect to character tools
	local function onCharacterAdded(character: Model)
		-- Monitor tools in character
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				connectTool(child)
			end
		end)

		-- Connect existing tools
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				connectTool(child)
			end
		end
	end

	-- Connect to backpack tools
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			connectTool(child)
		end
	end)

	-- Connect existing backpack tools
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") then
			connectTool(child)
		end
	end

	-- Handle character respawns
	if player.Character then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
end

--[[
	Capture input position for touch/click
]]
local function setupInputCapture()
	-- Capture touch/click position when input begins
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Don't capture if typing in UI
		if gameProcessed then
			return
		end

		-- Capture touch position (mobile)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastInputPosition = input.Position
		end

		-- Capture mouse position (PC/Mac)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			lastInputPosition = input.Position
		end
	end)

	print("[ToolClickHandler] Input capture setup")
end

--[[
	Initialize the click handler
]]
local function initialize()
	-- Wait for TargetingSystem to be ready
	task.wait(1)

	setupInputCapture()
	setupToolListeners()

	print("[ToolClickHandler] Initialized")
end

-- Start the system
initialize()
