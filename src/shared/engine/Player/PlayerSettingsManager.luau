--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerSettings = require(script.Parent.PlayerSettings)

type PlayerSettingsData = PlayerSettings.PlayerSettingsData

-- Player Settings Manager
-- Handles loading, saving, and managing player settings across sessions
-- Includes DataStore placeholders for future persistence implementation

local PlayerSettingsManager = {}

-- Runtime storage for player settings
local playerSettings: {[Player]: PlayerSettingsData} = {}
local settingsLoadState: {[Player]: "loading" | "loaded" | "failed"} = {}
local settingsChangedCallbacks: {[Player]: {(settings: PlayerSettingsData) -> ()}} = {}

-- Configuration
local AUTOSAVE_INTERVAL = 30 -- Auto-save every 30 seconds
local MAX_RETRIES = 3 -- Maximum retry attempts for DataStore operations

-- DataStore placeholders (implement later)
local function loadPlayerSettingsFromDataStore(player: Player): PlayerSettingsData?
	-- TODO: Implement DataStore loading
	-- Example implementation:
	-- local DataStoreService = game:GetService("DataStoreService")
	-- local settingsStore = DataStoreService:GetDataStore("PlayerSettings")
	--
	-- local success, result = pcall(function()
	--     return settingsStore:GetAsync("Player_" .. player.UserId)
	-- end)
	--
	-- if success and result then
	--     return PlayerSettings.validateSettings(result)
	-- end

	warn(`DataStore loading not implemented yet for {player.Name}`)
	return nil
end

local function savePlayerSettingsToDataStore(player: Player, settings: PlayerSettingsData): boolean
	-- TODO: Implement DataStore saving
	-- Example implementation:
	-- local DataStoreService = game:GetService("DataStoreService")
	-- local settingsStore = DataStoreService:GetDataStore("PlayerSettings")
	--
	-- local success, error = pcall(function()
	--     settingsStore:SetAsync("Player_" .. player.UserId, settings)
	-- end)
	--
	-- if not success then
	--     warn(`Failed to save settings for {player.Name}: {error}`)
	--     return false
	-- end
	--
	-- return true

	warn(`DataStore saving not implemented yet for {player.Name}`)
	return false
end

-- Load player settings (with fallback to defaults)
function PlayerSettingsManager.loadPlayerSettings(player: Player): PlayerSettingsData
	if settingsLoadState[player] == "loading" then
		-- Wait for loading to complete
		while settingsLoadState[player] == "loading" do
			task.wait(0.1)
		end
	end

	if settingsLoadState[player] == "loaded" then
		return playerSettings[player]
	end

	-- Mark as loading
	settingsLoadState[player] = "loading"

	-- Try to load from DataStore
	local loadedSettings = loadPlayerSettingsFromDataStore(player)
	local finalSettings: PlayerSettingsData

	if loadedSettings then
		-- Validate and potentially migrate settings
		if PlayerSettings.needsMigration(loadedSettings) then
			print(`Migrating settings for {player.Name} from version {loadedSettings.version or 0}`)
			finalSettings = PlayerSettings.mergeSettings(loadedSettings, PlayerSettings.getDefaultSettings())
		else
			finalSettings = PlayerSettings.validateSettings(loadedSettings)
		end
	else
		-- Use default settings
		finalSettings = PlayerSettings.getDefaultSettings()
		print(`Using default settings for {player.Name}`)
	end

	-- Store in memory
	playerSettings[player] = finalSettings
	settingsLoadState[player] = "loaded"

	print(`Loaded settings for {player.Name}`)
	return finalSettings
end

-- Save player settings to DataStore
function PlayerSettingsManager.savePlayerSettings(player: Player, retryCount: number?): boolean
	local settings = playerSettings[player]
	if not settings then
		warn(`No settings to save for {player.Name}`)
		return false
	end

	local success = savePlayerSettingsToDataStore(player, settings)

	if not success and (retryCount or 0) < MAX_RETRIES then
		-- Retry after a delay
		task.delay(2, function()
			PlayerSettingsManager.savePlayerSettings(player, (retryCount or 0) + 1)
		end)
	end

	return success
end

-- Get current player settings (loads if not already loaded)
function PlayerSettingsManager.getPlayerSettings(player: Player): PlayerSettingsData
	if not playerSettings[player] then
		return PlayerSettingsManager.loadPlayerSettings(player)
	end
	return playerSettings[player]
end

-- Update player settings and trigger save
function PlayerSettingsManager.updatePlayerSettings(player: Player, newSettings: PlayerSettingsData): boolean
	-- Validate the new settings
	local validatedSettings = PlayerSettings.validateSettings(newSettings)

	-- Store in memory
	playerSettings[player] = validatedSettings

	-- Trigger callbacks
	local callbacks = settingsChangedCallbacks[player]
	if callbacks then
		for _, callback in pairs(callbacks) do
			task.spawn(callback, validatedSettings)
		end
	end

	-- Save to DataStore (async)
	task.spawn(function()
		PlayerSettingsManager.savePlayerSettings(player)
	end)

	print(`Updated settings for {player.Name}`)
	return true
end

-- Update specific setting category
function PlayerSettingsManager.updateUISettings(player: Player, uiSettings: PlayerSettings.UISettings)
	local currentSettings = PlayerSettingsManager.getPlayerSettings(player)
	currentSettings.ui = PlayerSettings.validateSettings({ui = uiSettings}).ui
	PlayerSettingsManager.updatePlayerSettings(player, currentSettings)
end

function PlayerSettingsManager.updateGameplaySettings(player: Player, gameplaySettings: PlayerSettings.GameplaySettings)
	local currentSettings = PlayerSettingsManager.getPlayerSettings(player)
	currentSettings.gameplay = PlayerSettings.validateSettings({gameplay = gameplaySettings}).gameplay
	PlayerSettingsManager.updatePlayerSettings(player, currentSettings)
end

-- Register callback for when settings change
function PlayerSettingsManager.onSettingsChanged(player: Player, callback: (settings: PlayerSettingsData) -> ())
	if not settingsChangedCallbacks[player] then
		settingsChangedCallbacks[player] = {}
	end
	table.insert(settingsChangedCallbacks[player], callback)
end

-- Remove callback
function PlayerSettingsManager.removeSettingsCallback(player: Player, callback: (settings: PlayerSettingsData) -> ())
	local callbacks = settingsChangedCallbacks[player]
	if callbacks then
		for i, existingCallback in pairs(callbacks) do
			if existingCallback == callback then
				table.remove(callbacks, i)
				break
			end
		end
	end
end

-- Get specific setting values (convenience functions)
function PlayerSettingsManager.getTargetHUDSettings(player: Player): PlayerSettings.TargetHUDSettings
	return PlayerSettingsManager.getPlayerSettings(player).ui.targetHUD
end

function PlayerSettingsManager.getTargetingSettings(player: Player): PlayerSettings.TargetingSettings
	return PlayerSettingsManager.getPlayerSettings(player).ui.targeting
end

function PlayerSettingsManager.getDamageDisplaySettings(player: Player): PlayerSettings.DamageDisplaySettings
	return PlayerSettingsManager.getPlayerSettings(player).ui.damage
end

function PlayerSettingsManager.getControlSettings(player: Player): PlayerSettings.ControlSettings
	return PlayerSettingsManager.getPlayerSettings(player).gameplay.controls
end

function PlayerSettingsManager.getAudioSettings(player: Player): PlayerSettings.AudioSettings
	return PlayerSettingsManager.getPlayerSettings(player).gameplay.audio
end

-- Auto-save system
local function autoSaveAllPlayers()
	for player, _ in pairs(playerSettings) do
		if player.Parent then -- Player still in game
			task.spawn(function()
				PlayerSettingsManager.savePlayerSettings(player)
			end)
		end
	end
end

-- Clean up when player leaves
local function onPlayerRemoving(player: Player)
	-- Final save before player leaves
	if playerSettings[player] then
		PlayerSettingsManager.savePlayerSettings(player)
	end

	-- Clean up memory
	playerSettings[player] = nil
	settingsLoadState[player] = nil
	settingsChangedCallbacks[player] = nil

	print(`Cleaned up settings for {player.Name}`)
end

-- Initialize the settings manager
function PlayerSettingsManager.initialize()
	-- Handle player cleanup
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Start auto-save system (server only)
	if RunService:IsServer() then
		task.spawn(function()
			while true do
				task.wait(AUTOSAVE_INTERVAL)
				autoSaveAllPlayers()
			end
		end)
		print("PlayerSettingsManager auto-save system started")
	end

	print("PlayerSettingsManager initialized")
end

-- Manual save all (useful for game shutdown)
function PlayerSettingsManager.saveAllPlayers()
	autoSaveAllPlayers()
end

-- Reset player settings to defaults
function PlayerSettingsManager.resetPlayerSettings(player: Player): boolean
	local defaultSettings = PlayerSettings.getDefaultSettings()
	return PlayerSettingsManager.updatePlayerSettings(player, defaultSettings)
end

-- Get settings status
function PlayerSettingsManager.getLoadState(player: Player): "loading" | "loaded" | "failed" | "not_started"
	return settingsLoadState[player] or "not_started"
end

return PlayerSettingsManager