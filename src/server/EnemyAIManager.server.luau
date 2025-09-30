--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityController = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EntityController"))

-- Initialize the centralized entity controller system
EntityController.initialize()

-- Export to global _G for other servers to access
_G.EntityController = EntityController

print("EnemyAIManager: Centralized entity system initialized")