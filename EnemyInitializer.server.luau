--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the EntityController to be available
local EntityController
while not EntityController do
	local success, result = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EntityController"))
	end)
	if success then
		EntityController = result
	else
		task.wait(0.1)
	end
end

local model = script.Parent
local entityType = model.Name -- The entity type is determined by the model name (Wolf, Bear, Zombie, etc.)

-- Wait for model to be properly loaded (ensures model is fully loaded)
model:WaitForChild("Humanoid")
model:WaitForChild("HumanoidRootPart")

-- Initialize this entity with the centralized controller
local entity = EntityController.initializeEntity(model, entityType, "enemy")

if entity then
	print(`Successfully initialized {entityType} with centralized AI system`)
else
	warn(`Failed to initialize {entityType} - check GameConfig for entity configuration`)
end