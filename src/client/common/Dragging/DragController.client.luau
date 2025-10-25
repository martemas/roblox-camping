local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))

--[[
    DragController - Client-side drag and drop controller

    Handles user input for dragging and dropping items in the game world.
    It communicates with the server to request drag actions and updates
    the position of dragged items based on mouse movement.
]]
local config = {
    draggableTag = "Draggable",
    maxInteractionDistance = 10, -- Pixels to move before drag activates
}

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local RequestDragEvent = RemoteEvents.Functions.RequestDrag

-- State variables
local isDragging = false
local draggedObject = nil
local dragConnection = nil
local grabDepth = 0
local grabOffset = CFrame.new()

-- Hover state variables
local currentHoverTarget = nil
local currentHighlight = nil
local currentNameGui = nil
local objectAttachment = nil
local targetAttachment = nil
local alignPosition = nil
local alignOrientation = nil

local function getPhysicsPart(object: Instance): Instance?
    if not object then return nil end
    return object:IsA("Model") and object.PrimaryPart or object
end

local function getMouseTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local mouseRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = workspace:GetDescendants()
    local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 200, raycastParams)

    if raycastResult then
        local instance = raycastResult.Instance
        while instance and not CollectionService:HasTag(instance, config.draggableTag) do
            instance = instance.Parent
        end
        return instance, raycastResult.Position
    end

    return nil, nil
end

local function updateDrag()
    if not isDragging or not targetAttachment then return end

    local mousePos = UserInputService:GetMouseLocation()
    local mouseRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    local worldPointCFrame = CFrame.new(mouseRay.Origin + mouseRay.Direction * grabDepth)
    local newCFrame = worldPointCFrame * grabOffset:Inverse()
    targetAttachment.CFrame = newCFrame
end

local function stopDrag()
    if not isDragging then return end

    isDragging = false
    draggedObject = nil
    grabDepth = 0
    grabOffset = CFrame.new()

    if dragConnection then
        dragConnection:Disconnect()
        dragConnection = nil
    end

    if targetAttachment then
        targetAttachment:Destroy()
        targetAttachment = nil
    end
    if objectAttachment then
        objectAttachment:Destroy()
        objectAttachment = nil
    end
    if alignPosition then
        alignPosition:Destroy()
        alignPosition = nil
    end
    if alignOrientation then
        alignOrientation:Destroy()
        alignOrientation = nil
    end

    RequestDragEvent:InvokeServer(nil)
end

local function startDrag(target:Instance, hitPosition:Vector3)
    if isDragging then return end

    local physicsPart = getPhysicsPart(target)
    if not physicsPart then
        warn("Cannot drag object without physics part")
        return
    end

    local canDrag = RequestDragEvent:InvokeServer(target)
    if not canDrag then
        warn("Server denied drag request")
        return
    end

    isDragging = true
    draggedObject = target

    -- Calculate grab depth and offset
    grabDepth = (camera.CFrame.Position - hitPosition).Magnitude
    grabOffset = physicsPart.CFrame:ToObjectSpace(CFrame.new(hitPosition))

    objectAttachment = Instance.new("Attachment", physicsPart)
    targetAttachment = Instance.new("Attachment", workspace.Terrain)

    alignPosition = Instance.new("AlignPosition", targetAttachment)
    alignPosition.Attachment0 = objectAttachment
    alignPosition.Attachment1 = targetAttachment
    alignPosition.Responsiveness = 25
    alignPosition.MaxForce = 100000

    alignOrientation = Instance.new("AlignOrientation", targetAttachment)
    alignOrientation.Attachment0 = objectAttachment
    alignOrientation.Attachment1 = targetAttachment
    alignOrientation.Responsiveness = 15
    alignOrientation.MaxTorque = 100000

    updateDrag()
    dragConnection = RunService.RenderStepped:Connect(updateDrag)
end

local function updateHoverEffect()
    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local target, _ = getMouseTarget()
    local physicsPart = getPhysicsPart(target)

    if physicsPart and (rootPart.Position - physicsPart.Position).Magnitude > config.maxInteractionDistance then
        target = nil
    end

    if target ~= currentHoverTarget then
        if currentHighlight then
            currentHighlight:Destroy()
            currentHighlight = nil
        end
        if currentNameGui then
            currentNameGui:Destroy()
            currentNameGui = nil
        end

        currentHighlight, currentNameGui, currentHoverTarget = nil, nil, nil

        if target then
            currentHoverTarget = target

            currentHighlight = Instance.new("Highlight", target)
            currentHighlight.FillColor = Color3.fromRGB(255, 255, 255)
            currentHighlight.FillTransparency = 0.7
            currentHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            currentHighlight.OutlineTransparency = 0.2

            local nameGui = Instance.new("BillboardGui", physicsPart)
            nameGui.Name = "ItemNameGui"
            nameGui.Adornee = physicsPart
            nameGui.Size = UDim2.new(4, 0, 1, 0)
            nameGui.StudsOffset = Vector3.new(0, 2.5, 0)
            nameGui.AlwaysOnTop = true

            local nameLabel = Instance.new("TextLabel", currentNameGui)
            nameLabel.Size = UDim2.new(1, 0, 1, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Font = Enum.Font.SourceSansBold
            nameLabel.Text = target.Name
            nameLabel.TextColor3 = Color3.new(255, 255, 255)
            nameLabel.TextScaled = true

            currentNameGui = nameGui
        end
    end
end

-- Input handlers
RunService.Heartbeat:Connect(function()
    if not isDragging then
        updateHoverEffect()
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local target, hitPosition = getMouseTarget()
        if target and hitPosition then
            local character = localPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local physicsPart = getPhysicsPart(target)
            if rootPart and physicsPart and (rootPart.Position - physicsPart.Position).Magnitude <= config.maxInteractionDistance then
                startDrag(target, hitPosition)
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    -- if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        stopDrag()
    end
end)