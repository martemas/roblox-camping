--!strict

-- Main server entry point for the camping game
-- This script initializes all server-side systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

print("Server initializing...")

-- Wait for shared modules to load
local GameConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
local Types = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types")
local RemoteEvents = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents")

-- Pre-warm animation cache FIRST (before other systems)
local serverFolder = ServerScriptService:FindFirstChild("Server")
if serverFolder then
	local AnimationCache = require(serverFolder:WaitForChild("AnimationCache"))
	AnimationCache.Initialize()
else
	warn("Server folder not found in ServerScriptService")
end

-- All server systems initialize themselves automatically
-- We just need to wait for them to be ready

print("Waiting for all systems to initialize...")

-- Wait for all systems to be available in global scope
local function waitForSystems()
	local systems = {
		"InventoryManager",
		"TownhallManager",
		"DayNightCycle",
		"EnemySpawner"
	}

	for _, systemName in pairs(systems) do
		while not _G[systemName] do
			task.wait(0.1)
		end
		print(`✓ {systemName} ready`)
	end
end

waitForSystems()

-- TODO: Initialize additional systems as they are added
-- - Building system
-- - Combat system improvements
-- - Leaderboard system
-- - Anti-cheat systems

print("All server systems initialized successfully!")
print("Phase 0 camping game is ready to play")
print(string.rep("=", 50))
print("READY FOR TESTING:")
print("- Resource mining (wood/stone/metal)")
print("- Inventory management (5-item limit)")
print("- Townhall deposits")
print("- Day/night cycle")
print("- Wildlife encounters")
print("- Enemy waves during night")
print(string.rep("=", 50))