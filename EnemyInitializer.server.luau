--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the EnemyController to be available
local EnemyController
while not EnemyController do
	local success, result = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyController"))
	end)
	if success then
		EnemyController = result
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
local entity = EnemyController.initializeEntity(model, entityType)

if entity then
	print(`Successfully initialized {entityType} with centralized AI system`)
else
	warn(`Failed to initialize {entityType} - check GameConfig for entity configuration`)
end