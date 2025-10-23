--!strict

--[[
	Main Server Entry Point

	This script delegates to the active game's initialization system.
	The game (mapped in default.project.json) controls which framework
	modules are loaded and how they're configured.
]]

local ServerScriptService = game:GetService("ServerScriptService")

print("═══════════════════════════════════════════════════")
print("Server starting...")
print("═══════════════════════════════════════════════════")

-- Load active game from Games folder (mapped in default.project.json)
local Games = ServerScriptService:WaitForChild("Games")
local GameInit = require(Games.GameInit)

-- Game initializes framework and runs game-specific setup
GameInit.initialize()

print("═══════════════════════════════════════════════════")
print("✓ Server ready")
print("═══════════════════════════════════════════════════")
