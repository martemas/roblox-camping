--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local EntityController = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Entities"):WaitForChild("EntityController"))

-- Initialize the centralized entity controller system
EntityController.initialize()

-- Export to global _G for other servers to access
_G.EntityController = EntityController

print("EntityAIManager: Centralized entity system initialized")