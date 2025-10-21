--!strict

-- Main server entry point for the camping game
-- This script initializes all server-side systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

print("Server initializing...")

-- Wait for shared modules to load
local EngineShared = ReplicatedStorage:WaitForChild("Engine")
local Engine = ServerScriptService:WaitForChild("Engine")

local GameConfig = EngineShared:WaitForChild("Config")
local Types = EngineShared.Core.Types
local RemoteEvents = EngineShared.Core.RemoteEvents

-- Initialize ProjectileManager
local ProjectileManager = require(Engine.Combat.ProjectileManager)
ProjectileManager.initialize()

-- Pre-warm animation cache FIRST (before other systems)
local AnimationCache = require(Engine.AnimationCache)
AnimationCache.Initialize()

-- Initialize Stats (sets up RemoteFunction callbacks)
local Stats = require(Engine.Combat.Stats)
print("✓ Stats RemoteFunctions initialized")

-- Initialize PlayerStats (sets up ProfileStore and PlayerAdded connection)
local PlayerStats = require(Engine.PlayerStats)
print("✓ PlayerStats initialized")

-- All server systems initialize themselves automatically
-- We just need to wait for them to be ready

print("Waiting for all systems to initialize...")

-- Wait for all systems to be available in global scope
local function waitForSystems()
	local systems = {
		"InventoryManager",
		-- "TownhallManager",
		"DayNightCycle",
		"SpawnManager"
	}

	for _, systemName in pairs(systems) do
		while not _G[systemName] do
			task.wait(0.1)
		end
		print(`✓ {systemName} ready`)
	end
end

waitForSystems()

print("All systems initialized. Server is ready.")

-- TODO: Initialize additional systems as they are added
-- - Building system
-- - Leaderboard system
-- - Anti-cheat systems
