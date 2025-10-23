--!strict

--[[
	ALPHA GAME - Client Entry Point

	This file initializes the client framework and runs alpha-specific client setup.

	The game controls what client modules are loaded and how they're configured.
	This is the main entry point for the alpha game client.
]]

local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer.StarterPlayerScripts
local Common = StarterPlayerScripts:WaitForChild("Common")

local ClientFramework = require(Common.ClientFramework)

local ClientGameInit = {}

function ClientGameInit.initialize()
	print("═══════════════════════════════════════════════════")
	print("[Alpha Game Client] Starting initialization...")
	print("═══════════════════════════════════════════════════")

	-- ═══════════════════════════════════════════════════════
	-- STEP 1: Initialize Core Client Modules
	-- ═══════════════════════════════════════════════════════

	print("\n[Alpha Game Client] Initializing core systems...")

	-- NOTE: Client modules with .client.luau extension auto-execute and cannot be required.
	-- They register themselves with ClientFramework when they run.
	-- This includes:
	--   - UI.client.luau (registers as "UI")
	--   - UIManager.luau (required by UI.client)
	--   - EntityTargeting.client.luau
	--   - MovementController.client.luau
	--   - HealthBarAttacher.client.luau
	--   - BuildingController.client.luau (optional)

	-- All client modules auto-initialize when loaded by Roblox
	print("✓ Client modules loading automatically (.client.luau scripts)")

	-- ═══════════════════════════════════════════════════════
	-- STEP 3: Alpha-Specific Client Setup
	-- ═══════════════════════════════════════════════════════

	print("\n[Alpha Game Client] Running game-specific setup...")

	-- Add any alpha-specific client initialization here
	-- Example: Custom UI themes, key bindings, game mode UI, etc.

	print("\n═══════════════════════════════════════════════════")
	print("[Alpha Game Client] ✓ Initialization complete")
	print("═══════════════════════════════════════════════════")
end

return ClientGameInit
