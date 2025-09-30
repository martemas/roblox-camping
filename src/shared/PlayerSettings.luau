--!strict

-- Player Settings Schema & Default Values
-- This file defines all configurable player preferences

export type TargetHUDSettings = {
	enabled: boolean,
	position: "TopLeft" | "TopRight" | "BottomLeft" | "BottomRight" | "Custom",
	customOffset: UDim2,
	scale: number,
	opacity: number,
	showDetailedStats: boolean,
	animationSpeed: number,
	updateFrequency: number, -- How often to update in seconds
}

export type TargetingSettings = {
	showOtherPlayersTargets: boolean,
	highlightOpacity: number,
	autoDeselectOnDeath: boolean,
	maxTargetDistance: number,
}

export type DamageDisplaySettings = {
	showDamageNumbers: boolean,
	damageNumberScale: number,
	showOwnDamage: boolean,
	showOtherPlayerDamage: boolean,
	animationDuration: number,
}

export type UISettings = {
	targetHUD: TargetHUDSettings,
	targeting: TargetingSettings,
	damage: DamageDisplaySettings,
}

export type ControlSettings = {
	targetClosestKey: Enum.KeyCode,
	clearTargetKey: Enum.KeyCode,
	toggleRunKey: Enum.KeyCode,
	toggleBuildModeKey: Enum.KeyCode,
	targetingMouseButton: "Left" | "Right" | "Middle",
}

export type CombatSettings = {
	autoAttackEnabled: boolean, -- Auto-attack when target is selected
}

export type AudioSettings = {
	masterVolume: number,
	sfxVolume: number,
	musicVolume: number,
	uiSoundVolume: number,
}

export type GameplaySettings = {
	controls: ControlSettings,
	combat: CombatSettings,
	audio: AudioSettings,
}

export type PlayerSettingsData = {
	ui: UISettings,
	gameplay: GameplaySettings,
	version: number, -- For settings migration
}

-- Default settings - these are the fallback values
local DEFAULT_SETTINGS: PlayerSettingsData = {
	ui = {
		targetHUD = {
			enabled = true,
			position = "BottomRight",
			customOffset = UDim2.new(0, 20, 0, 20),
			scale = 1.0,
			opacity = 0.9,
			showDetailedStats = true,
			animationSpeed = 0.3,
			updateFrequency = 0.1,
		},

		targeting = {
			showOtherPlayersTargets = false,
			highlightOpacity = 0.8,
			autoDeselectOnDeath = true,
			maxTargetDistance = 80,
		},

		damage = {
			showDamageNumbers = true,
			damageNumberScale = 1.0,
			showOwnDamage = true,
			showOtherPlayerDamage = false,
			animationDuration = 1.5,
		},
	},

	gameplay = {
		controls = {
			targetClosestKey = Enum.KeyCode.X,
			clearTargetKey = Enum.KeyCode.Escape,
			toggleRunKey = Enum.KeyCode.LeftShift,
			toggleBuildModeKey = Enum.KeyCode.B,
			targetingMouseButton = "Left",
		},

		combat = {
			autoAttackEnabled = true, -- Auto-attack when target is selected
		},

		audio = {
			masterVolume = 1.0,
			sfxVolume = 1.0,
			musicVolume = 0.7,
			uiSoundVolume = 0.8,
		},
	},

	version = 1, -- Increment when settings schema changes
}

-- Validation functions
local function validateNumber(value: any, min: number?, max: number?): number?
	if type(value) ~= "number" then
		return nil
	end

	if min and value < min then
		return nil
	end

	if max and value > max then
		return nil
	end

	return value
end

local function validateBoolean(value: any): boolean?
	if type(value) == "boolean" then
		return value
	end
	return nil
end

local function validateKeyCode(value: any): Enum.KeyCode?
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
		return value
	end
	return nil
end

-- Validate and sanitize settings data
local function validateSettings(settings: any): PlayerSettingsData
	if type(settings) ~= "table" then
		return DEFAULT_SETTINGS
	end

	-- Helper function to safely access nested properties
	local function safeGet(table: any, path: {string}): any
		local current = table
		for _, key in ipairs(path) do
			if type(current) ~= "table" or current[key] == nil then
				return nil
			end
			current = current[key]
		end
		return current
	end

	local validated: PlayerSettingsData = {
		ui = {
			targetHUD = {
				enabled = validateBoolean(safeGet(settings, {"ui", "targetHUD", "enabled"})) or DEFAULT_SETTINGS.ui.targetHUD.enabled,
				position = (function()
					local pos = safeGet(settings, {"ui", "targetHUD", "position"})
					if pos == "TopLeft" or pos == "TopRight" or pos == "BottomLeft" or pos == "BottomRight" or pos == "Custom" then
						return pos
					end
					return DEFAULT_SETTINGS.ui.targetHUD.position
				end)(),
				customOffset = (function()
					local offset = safeGet(settings, {"ui", "targetHUD", "customOffset"})
					if typeof(offset) == "UDim2" then
						return offset
					end
					return DEFAULT_SETTINGS.ui.targetHUD.customOffset
				end)(),
				scale = validateNumber(safeGet(settings, {"ui", "targetHUD", "scale"}), 0.5, 3.0) or DEFAULT_SETTINGS.ui.targetHUD.scale,
				opacity = validateNumber(safeGet(settings, {"ui", "targetHUD", "opacity"}), 0.1, 1.0) or DEFAULT_SETTINGS.ui.targetHUD.opacity,
				showDetailedStats = validateBoolean(safeGet(settings, {"ui", "targetHUD", "showDetailedStats"})) or DEFAULT_SETTINGS.ui.targetHUD.showDetailedStats,
				animationSpeed = validateNumber(safeGet(settings, {"ui", "targetHUD", "animationSpeed"}), 0.1, 2.0) or DEFAULT_SETTINGS.ui.targetHUD.animationSpeed,
				updateFrequency = validateNumber(safeGet(settings, {"ui", "targetHUD", "updateFrequency"}), 0.05, 1.0) or DEFAULT_SETTINGS.ui.targetHUD.updateFrequency,
			},

			targeting = {
				showOtherPlayersTargets = validateBoolean(safeGet(settings, {"ui", "targeting", "showOtherPlayersTargets"})) or DEFAULT_SETTINGS.ui.targeting.showOtherPlayersTargets,
				highlightOpacity = validateNumber(safeGet(settings, {"ui", "targeting", "highlightOpacity"}), 0.1, 1.0) or DEFAULT_SETTINGS.ui.targeting.highlightOpacity,
				autoDeselectOnDeath = validateBoolean(safeGet(settings, {"ui", "targeting", "autoDeselectOnDeath"})) or DEFAULT_SETTINGS.ui.targeting.autoDeselectOnDeath,
				maxTargetDistance = validateNumber(safeGet(settings, {"ui", "targeting", "maxTargetDistance"}), 50, 200) or DEFAULT_SETTINGS.ui.targeting.maxTargetDistance,
			},

			damage = {
				showDamageNumbers = validateBoolean(safeGet(settings, {"ui", "damage", "showDamageNumbers"})) or DEFAULT_SETTINGS.ui.damage.showDamageNumbers,
				damageNumberScale = validateNumber(safeGet(settings, {"ui", "damage", "damageNumberScale"}), 0.5, 3.0) or DEFAULT_SETTINGS.ui.damage.damageNumberScale,
				showOwnDamage = validateBoolean(safeGet(settings, {"ui", "damage", "showOwnDamage"})) or DEFAULT_SETTINGS.ui.damage.showOwnDamage,
				showOtherPlayerDamage = validateBoolean(safeGet(settings, {"ui", "damage", "showOtherPlayerDamage"})) or DEFAULT_SETTINGS.ui.damage.showOtherPlayerDamage,
				animationDuration = validateNumber(safeGet(settings, {"ui", "damage", "animationDuration"}), 0.5, 5.0) or DEFAULT_SETTINGS.ui.damage.animationDuration,
			},
		},

		gameplay = {
			controls = {
				targetClosestKey = validateKeyCode(safeGet(settings, {"gameplay", "controls", "targetClosestKey"})) or DEFAULT_SETTINGS.gameplay.controls.targetClosestKey,
				clearTargetKey = validateKeyCode(safeGet(settings, {"gameplay", "controls", "clearTargetKey"})) or DEFAULT_SETTINGS.gameplay.controls.clearTargetKey,
				toggleRunKey = validateKeyCode(safeGet(settings, {"gameplay", "controls", "toggleRunKey"})) or DEFAULT_SETTINGS.gameplay.controls.toggleRunKey,
				toggleBuildModeKey = validateKeyCode(safeGet(settings, {"gameplay", "controls", "toggleBuildModeKey"})) or DEFAULT_SETTINGS.gameplay.controls.toggleBuildModeKey,
				targetingMouseButton = (function()
					local mouseButton = safeGet(settings, {"gameplay", "controls", "targetingMouseButton"})
					if mouseButton == "Left" or mouseButton == "Right" or mouseButton == "Middle" then
						return mouseButton
					end
					return DEFAULT_SETTINGS.gameplay.controls.targetingMouseButton
				end)(),
			},

			audio = {
				masterVolume = validateNumber(safeGet(settings, {"gameplay", "audio", "masterVolume"}), 0.0, 1.0) or DEFAULT_SETTINGS.gameplay.audio.masterVolume,
				sfxVolume = validateNumber(safeGet(settings, {"gameplay", "audio", "sfxVolume"}), 0.0, 1.0) or DEFAULT_SETTINGS.gameplay.audio.sfxVolume,
				musicVolume = validateNumber(safeGet(settings, {"gameplay", "audio", "musicVolume"}), 0.0, 1.0) or DEFAULT_SETTINGS.gameplay.audio.musicVolume,
				uiSoundVolume = validateNumber(safeGet(settings, {"gameplay", "audio", "uiSoundVolume"}), 0.0, 1.0) or DEFAULT_SETTINGS.gameplay.audio.uiSoundVolume,
			},
		},

		version = validateNumber(safeGet(settings, {"version"}), 1) or DEFAULT_SETTINGS.version,
	}

	return validated
end

-- Public API
local PlayerSettings = {}

function PlayerSettings.getDefaultSettings(): PlayerSettingsData
	-- Return a deep copy to prevent modification
	return validateSettings(DEFAULT_SETTINGS)
end

function PlayerSettings.validateSettings(settings: any): PlayerSettingsData
	return validateSettings(settings)
end

function PlayerSettings.getDefaultTargetHUDSettings(): TargetHUDSettings
	return DEFAULT_SETTINGS.ui.targetHUD
end

function PlayerSettings.getDefaultTargetingSettings(): TargetingSettings
	return DEFAULT_SETTINGS.ui.targeting
end

function PlayerSettings.getDefaultDamageDisplaySettings(): DamageDisplaySettings
	return DEFAULT_SETTINGS.ui.damage
end

function PlayerSettings.getDefaultControlSettings(): ControlSettings
	return DEFAULT_SETTINGS.gameplay.controls
end

function PlayerSettings.getDefaultAudioSettings(): AudioSettings
	return DEFAULT_SETTINGS.gameplay.audio
end

-- Utility functions for specific setting categories
function PlayerSettings.mergeSettings(userSettings: any, defaultSettings: PlayerSettingsData): PlayerSettingsData
	-- Deep merge user settings with defaults, preferring user values when valid
	local merged = validateSettings(userSettings)

	-- If user settings are completely invalid, return defaults
	if not userSettings or type(userSettings) ~= "table" then
		return defaultSettings
	end

	return merged
end

-- Version migration helper (for future use)
function PlayerSettings.needsMigration(settings: any): boolean
	if type(settings) ~= "table" then
		return true
	end

	local currentVersion = DEFAULT_SETTINGS.version
	local settingsVersion = settings.version or 0

	return settingsVersion < currentVersion
end

return PlayerSettings