--!strict

-- Main server entry point for the camping game
-- This script initializes all server-side systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

print("Server initializing...")

-- Wait for shared modules to load
local GameConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config")
local Types = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types")
local RemoteEvents = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents")

-- Initialize ProjectileManager
local ProjectileManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectileManager"))
ProjectileManager.initialize()

-- Pre-warm animation cache FIRST (before other systems)
local serverFolder = ServerScriptService:FindFirstChild("Server")
if serverFolder then
	local AnimationCache = require(serverFolder:WaitForChild("AnimationCache"))
	AnimationCache.Initialize()

	-- Initialize PlayerStats (sets up ProfileStore and PlayerAdded connection)
	local PlayerStats = require(serverFolder:WaitForChild("PlayerStats"))
	print("✓ PlayerStats initialized")
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
		"CreatureSpawner"
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
-- - Leaderboard system
-- - Anti-cheat systems
