--!strict

--[[
	EntityAIManager - Wrapper for EntityController initialization

	This module serves as the AI manager entry point that initializes
	the centralized entity controller system.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local EntityController = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Entities"):WaitForChild("EntityController"))

local EntityAIManager = {}
local isInitialized = false

-- Initialize the entity AI manager
function EntityAIManager.initialize()
	if isInitialized then
		warn("[EntityAIManager] Already initialized")
		return
	end

	isInitialized = true

	-- Initialize the centralized entity controller system
	EntityController.initialize()

	print("[EntityAIManager] ✓ Initialized")
end

-- Export EntityController methods for convenience
EntityAIManager.EntityController = EntityController

return EntityAIManager
