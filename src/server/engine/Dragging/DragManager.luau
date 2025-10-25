--[[
    DragManager - Server-side manager for handling drag requests
    This module manages drag-and-drop interactions initiated by players,
    validating requests and maintaining drag states.
    To securely handle dragging, it verifies that players can only drag
    items within a certain distance and that the items are tagged as draggable.
    It also manages the network ownership of dragged items to ensure smooth physics simulation.
]]
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local DragManager = {}

local isInitialized = false

local Config = {
     maxDragDistance = 20,      -- Max distance to drag from player (studs)
     draggableTag = "Draggable"  -- Tag for draggable items
}

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))

local RequestDragEvent = RemoteEvents.Functions.RequestDrag

local playerDragStates = {} :: {[Player]: Instance?}

local function getPhysicsPart(object: Instance): Instance?
    if not object then return nil end
    return object:IsA("Model") and object.PrimaryPart or object
end

local function onRequestDragItem(player: Player, targetObject: Instance): boolean
    if not targetObject then
        local currentlyDragged = playerDragStates[player]
        if currentlyDragged then
            local physicsPartToRelease = getPhysicsPart(currentlyDragged)
            if physicsPartToRelease then
                physicsPartToRelease:SetNetworkOwner(nil)
            end
            playerDragStates[player] = nil
        end
        return false
    end

    if not CollectionService:HasTag(targetObject, Config.draggableTag) then
        warn("Player tried to drag non-draggable tag")
        return false
    end
    local physicsPart = getPhysicsPart(targetObject)
    if not physicsPart then
        warn(`{player.Name} tried to drag a Model without Primary Part part: {targetObject.Name}`)
        return false
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid then
        warn(`{player.Name} has no character or HumanoidRootPart`)
        return false
    end

    for _, draggedItem in playerDragStates do
        if draggedItem == targetObject then
            warn(`{player.Name} is already dragging this item: {targetObject.Name}`)
            return false
        end
    end

    local distance = (humanoid.Position - physicsPart.Position).Magnitude
    if distance > Config.maxDragDistance then
        warn(`{player.Name} tried to drag an item too far away: {targetObject.Name}`)
        return false
    end

    playerDragStates[player] = targetObject
    -- this gives the player control over the physics part
    physicsPart:SetNetworkOwner(player)
    return true
end

local function onPlayerRemoving(player: Player)
    local draggedItem = playerDragStates[player]
    if draggedItem then
        local physicsPartToRelease = getPhysicsPart(draggedItem)
        if physicsPartToRelease then
            physicsPartToRelease:SetNetworkOwner(nil)
        end
        playerDragStates[player] = nil
    end
end

function DragManager.Initialize(): ()
    if isInitialized then
		warn("[WeaponInfoProvider] Already initialized")
		return
	end

	isInitialized = true

    RequestDragEvent.OnServerInvoke = onRequestDragItem
    PlayerService.PlayerRemoving:Connect(onPlayerRemoving)
    print("[DragManager] Initialized")
end

return DragManager