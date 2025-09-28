--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyController = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyController"))

-- Initialize the centralized enemy controller system
EnemyController.initialize()

-- Export to global _G for other servers to access
_G.EnemyController = EnemyController

print("EnemyAIManager: Centralized enemy system initialized")