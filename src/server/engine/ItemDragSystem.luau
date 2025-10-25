--!strict

--[[
	ItemDragSystem - Server-side validation for item dragging and throwing

	Responsibilities:
	- Validate drag start requests
	- Update item positions during drag (with throttling)
	- Validate throw physics on release
	- Clean up on disconnect
	- Prevent exploits (distance/velocity validation)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Engine = ServerScriptService:WaitForChild("Engine")
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))
local GameConfig = require(Engine.Config.GameConfig)

local ItemDragSystem = {}

-- Track active drags
local activeDrags: { [Player]: { item: Model, lastUpdate: number } } = {}

local MAX_DRAG_DISTANCE = GameConfig.itemInteraction.maxDragDistance or 20
local MAX_FINAL_DISTANCE = GameConfig.itemInteraction.maxFinalDistance or 30
local MAX_THROW_VELOCITY = GameConfig.itemInteraction.maxThrowVelocity or 50
local UPDATE_THROTTLE = 0.05 -- 20 updates per second max

-- Start dragging an item
local function onStartDrag(player: Player, itemModel: Model)
	if not itemModel or not itemModel.Parent then
		return
	end
	if not itemModel:GetAttribute("IsDroppedItem") then
		return
	end

	-- Check player distance
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local itemPart = itemModel.PrimaryPart or itemModel:FindFirstChildOfClass("BasePart")
	if not itemPart then
		return
	end

	local distance = (itemPart.Position - character.HumanoidRootPart.Position).Magnitude
	if distance > MAX_DRAG_DISTANCE then
		return
	end

	-- Register drag
	activeDrags[player] = {
		item = itemModel,
		lastUpdate = tick(),
		startPosition = itemPart.Position, -- Store for validation later
	}

	print(`[ItemDragSystem] {player.Name} started dragging {itemModel.Name}`)
end

-- Update item position during drag
local function onUpdateDragPosition(player: Player, itemModel: Model, newPosition: Vector3)
	local dragData = activeDrags[player]
	if not dragData or dragData.item ~= itemModel then
		return
	end

	-- Throttle updates
	local now = tick()
	if now - dragData.lastUpdate < UPDATE_THROTTLE then
		return
	end
	dragData.lastUpdate = now

	-- Validate distance from player (reject if too far)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local distance = (newPosition - character.HumanoidRootPart.Position).Magnitude
	if distance > MAX_DRAG_DISTANCE then
		-- Client is trying to drag too far - force release
		activeDrags[player] = nil
		warn(`[ItemDragSystem] {player.Name} exceeded max drag distance - forcing release`)
		return
	end

	-- Server only validates during drag, does NOT update position
	-- Client handles smooth position updates directly
end

-- Validate final item position after client physics simulation
local function onReleaseDrag(player: Player, itemModel: Model, throwVelocity: Vector3, finalPosition: Vector3)
	local dragData = activeDrags[player]
	if not dragData or dragData.item ~= itemModel then
		return
	end

	-- Clear drag state
	activeDrags[player] = nil

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local itemPart = itemModel.PrimaryPart or itemModel:FindFirstChildOfClass("BasePart")
	if not itemPart then
		return
	end

	local playerPos = character.HumanoidRootPart.Position
	local releaseDistance = (dragData.startPosition - playerPos).Magnitude
	local finalDistance = (finalPosition - playerPos).Magnitude

	-- Validate final distance from player
	if finalDistance > MAX_FINAL_DISTANCE then
		warn(`[ItemDragSystem] {player.Name} item too far from player: {finalDistance} studs - rejecting`)
		-- Teleport item back to last valid position (release position)
		itemModel:PivotTo(CFrame.new(dragData.startPosition))
		return
	end

	-- Validate item is on/near ground (not floating in air)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { itemModel, character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local downwardRay = workspace:Raycast(finalPosition, Vector3.new(0, -10, 0), raycastParams)
	if not downwardRay then
		warn(`[ItemDragSystem] {player.Name} item not near ground - rejecting`)
		itemModel:PivotTo(CFrame.new(dragData.startPosition))
		return
	end

	local distanceToGround = (finalPosition - downwardRay.Position).Magnitude
	if distanceToGround > 5 then
		warn(`[ItemDragSystem] {player.Name} item too far from ground: {distanceToGround} - rejecting`)
		itemModel:PivotTo(CFrame.new(dragData.startPosition))
		return
	end

	-- For throws (high velocity), validate trajectory
	if throwVelocity.Magnitude > 5 then
		-- Calculate expected landing distance using parabolic motion
		local horizontalVelocity = Vector3.new(throwVelocity.X, 0, throwVelocity.Z).Magnitude
		local verticalVelocity = throwVelocity.Y
		local gravity = 196.2 -- Roblox gravity

		-- Time to hit ground (solving: y = v*t - 0.5*g*t^2, where y=0)
		local timeToLand = (verticalVelocity + math.sqrt(verticalVelocity ^ 2 + 2 * gravity * dragData.startPosition.Y)) / gravity
		local expectedHorizontalDistance = horizontalVelocity * timeToLand

		local actualHorizontalDistance = Vector3.new(finalPosition.X - dragData.startPosition.X, 0, finalPosition.Z - dragData.startPosition.Z).Magnitude

		-- Allow 50% tolerance for bounces and obstacles
		if actualHorizontalDistance > expectedHorizontalDistance * 1.5 then
			warn(
				`[ItemDragSystem] {player.Name} item landed too far (expected ~{expectedHorizontalDistance}, got {actualHorizontalDistance}) - rejecting`
			)
			itemModel:PivotTo(CFrame.new(dragData.startPosition))
			return
		end
	end

	-- Validation passed - accept final position
	print(`[ItemDragSystem] {player.Name} released item at {finalPosition} (velocity: {throwVelocity.Magnitude})`)

	-- Ensure item is at the validated position (client should already have it there)
	itemModel:PivotTo(CFrame.new(finalPosition))
end

-- Clean up on player disconnect
local function onPlayerRemoving(player: Player)
	if activeDrags[player] then
		-- Drop item at last position (physics applies)
		activeDrags[player] = nil
	end
end

-- Initialize
function ItemDragSystem.initialize()
	RemoteEvents.Events.StartDragItem.OnServerEvent:Connect(onStartDrag)
	RemoteEvents.Events.UpdateDragPosition.OnServerEvent:Connect(onUpdateDragPosition)
	RemoteEvents.Events.ReleaseDragItem.OnServerEvent:Connect(onReleaseDrag)

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	print("[ItemDragSystem] ✓ Initialized")
end

return ItemDragSystem
