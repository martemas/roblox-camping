--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityController = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EntityController"))

-- Initialize the centralized entity controller system
EntityController.initialize()

-- Export to global _G for other systems to access
_G.EntityController = EntityController

print("EntityAIManager: Centralized entity system initialized with stats support")