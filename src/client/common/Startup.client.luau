--!strict

--[[
	Main Client Entry Point

	This script delegates to the active game's client initialization system.
	The game (mapped in default.project.json) controls which client-side
	modules are loaded and how they're configured.
]]

local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer.StarterPlayerScripts
local Players = game:GetService("Players")

local player = Players.LocalPlayer

print("═══════════════════════════════════════════════════")
print(`Client starting for {player.Name}...`)
print("═══════════════════════════════════════════════════")

-- Load active game from Games folder (mapped in default.project.json)
local Games = StarterPlayerScripts:WaitForChild("Games")
local ClientGameInit = require(Games.ClientGameInit)

-- Game initializes client framework and runs game-specific setup
ClientGameInit.initialize()

print("═══════════════════════════════════════════════════")
print("✓ Client ready")
print("═══════════════════════════════════════════════════")

-- Handle character spawning
player.CharacterAdded:Connect(function(character)
	print(`Character spawned for {player.Name}`)
end)

-- Handle existing character if player already spawned
if player.Character then
	print(`Character already exists for {player.Name}`)
end