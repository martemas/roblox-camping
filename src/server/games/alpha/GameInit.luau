--!strict

--[[
	ALPHA GAME - Server Entry Point

	This file initializes the framework and runs alpha-specific game setup.

	The game controls what framework modules are loaded and how they're configured.
	This is the main entry point for the alpha game server.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Engine = ServerScriptService:WaitForChild("Engine")
local SpawnLoader = require(script.Parent.SpawnLoader)
local MapGeneratorService = require(Engine.MapGenerator.MapGeneratorService)
local Framework = require(Engine.Framework)

local GameInit = {}

function GameInit.initialize()
	print("═══════════════════════════════════════════════════")
	print("[Alpha Game] Starting initialization...")
	print("═══════════════════════════════════════════════════")

	-- ═══════════════════════════════════════════════════════
	-- STEP 1: Initialize Core Framework Modules
	-- ═══════════════════════════════════════════════════════

	print("\n[Alpha Game] Initializing core systems...")

	-- Map generator service
	MapGeneratorService.initialize()
	Framework.register("MapGeneratorService", MapGeneratorService)

	-- Animation system (required for entity animations)
	local AnimationCache = require(Engine.AnimationCache)
	AnimationCache.Initialize()
	print("✓ AnimationCache")

	-- Combat systems
	local ProjectileManager = require(Engine.Combat.ProjectileManager)
	ProjectileManager.initialize()
	Framework.register("ProjectileManager", ProjectileManager)

	-- Stats system (sets up RemoteFunction callbacks automatically)
	local Stats = require(Engine.Combat.Stats)
	Framework.register("Stats", Stats)
	print("✓ Stats")

	-- Player stats (sets up ProfileStore and PlayerAdded connection automatically)
	local PlayerStats = require(Engine.PlayerStats)
	Framework.register("PlayerStats", PlayerStats)
	print("✓ PlayerStats")

	-- ═══════════════════════════════════════════════════════
	-- STEP 2: Initialize Entity & Combat Systems
	-- ═══════════════════════════════════════════════════════

	print("\n[Alpha Game] Initializing entity systems...")

	-- Spawn management
	local SpawnManager = require(Engine.SpawnManager)
	SpawnManager.initialize()
	Framework.register("SpawnManager", SpawnManager)

	-- Entity AI
	local EntityAIManager = require(Engine.EntityAIManager)
	EntityAIManager.initialize()
	Framework.register("EntityAIManager", EntityAIManager)

	-- Targeting system
	local TargetManager = require(Engine.TargetManager)
	TargetManager.initialize()
	Framework.register("TargetManager", TargetManager)

	-- ═══════════════════════════════════════════════════════
	-- STEP 3: Initialize Game Systems
	-- ═══════════════════════════════════════════════════════

	print("\n[Alpha Game] Initializing game systems...")

	-- Inventory
	local InventoryManager = require(Engine.InventoryManager)
	InventoryManager.initialize()
	Framework.register("InventoryManager", InventoryManager)

	-- Pickup System (depends on InventoryManager)
	local PickupSystem = require(Engine.PickupSystem)
	PickupSystem.initialize()
	Framework.register("PickupSystem", PickupSystem)

	-- Day/Night cycle
	-- local DayNightCycle = require(Engine.DayNightCycle)
	-- DayNightCycle.initialize()
	-- Framework.register("DayNightCycle", DayNightCycle)

	-- Resources
	local ResourceManager = require(Engine.ResourceManager)
	ResourceManager.initialize()
	Framework.register("ResourceManager", ResourceManager)

	-- Tools
	local ToolManager = require(Engine.ToolManager)
	ToolManager.initialize()
	Framework.register("ToolManager", ToolManager)

	-- Weapon info provider
	local WeaponInfoProvider = require(Engine.WeaponInfoProvider)
	WeaponInfoProvider.initialize()
	Framework.register("WeaponInfoProvider", WeaponInfoProvider)

	-- Dragging System
	local DragManager = require(Engine.Dragging.DragManager)
	DragManager.Initialize()
	Framework.register("DragManager", DragManager)

	-- Team System
	local TeamManager = require(Engine.TeamManager)
	TeamManager.initialize()
	Framework.register("TeamManager", TeamManager)

	-- ═══════════════════════════════════════════════════════
	-- STEP 4: Initialize Optional Systems (Alpha-Specific)
	-- ═══════════════════════════════════════════════════════

	print("\n[Alpha Game] Initializing optional systems...")

	-- Generate and build terrain (uses WFC + altitude biomes + 3D building)
	local mapData = MapGeneratorService.generateAndBuildWorld()

	if mapData then
		print(`✓ World generated successfully (seed: {mapData.seed})`)
		-- Move baseplate down a couple of studs to avoid z-fighting
		local baseplate = workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate.Position = Vector3.new(0, -20, 0)
			-- baseplate:Destroy()
		end
	else
		warn("✗ Failed to generate world")
	end

	-- Townhall system (must be initialized before ShopManager)
	local TownhallManager = require(Engine.TownhallManager)
	TownhallManager.initialize()
	Framework.register("TownhallManager", TownhallManager)

	-- Shop system (depends on TownhallManager)
	local ShopManager = require(Engine.ShopManager)
	ShopManager.initialize()
	Framework.register("ShopManager", ShopManager)

	-- ═══════════════════════════════════════════════════════
	-- STEP 5: Alpha-Specific Game Setup
	-- ═══════════════════════════════════════════════════════

	print("\n[Alpha Game] Running game-specific setup...")

	GameInit.setupSpawning()

	print("\n═══════════════════════════════════════════════════")
	print("[Alpha Game] ✓ Initialization complete")
	print("═══════════════════════════════════════════════════")
end

--[[
	Alpha-specific: Load and spawn entities from workspace
]]
function GameInit.setupSpawning()
	-- Load spawn points from workspace parts
	local spawnPoints = SpawnLoader.loadSpawnConfigs()

	local SpawnManager = Framework.get("SpawnManager")
	if not SpawnManager then
		warn("[Alpha] SpawnManager not available - cannot spawn entities")
		return
	end

	-- Spawn all entities from workspace spawn points
	for _, spawnPoint in spawnPoints do
		-- print(`[Alpha] Spawning {spawnPoint.count}x {spawnPoint.entityType} at {spawnPoint.position}`)

		for i = 1, spawnPoint.count do
			SpawnManager.spawnEntity(spawnPoint.entityType, spawnPoint.position, 1, spawnPoint.teamId)
		end
	end

	print(`[Alpha] ✓ Spawned entities from {#spawnPoints} spawn points`)
end

return GameInit
