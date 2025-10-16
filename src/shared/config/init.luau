--!strict

-- CLIENT-ONLY CONFIG
-- This file provides client-safe configuration data
-- Server-side configs are in ServerScriptService/Config/

local ClientSettings = require(script.ClientSettings)
local DayNightCycleConfig = require(script.DayNightCycleConfig)
local EntitiesConfig = require(script.EntitiesConfig)
local BuildingsConfig = require(script.BuildingsConfig)

-- Client-safe config for legacy compatibility
local ClientConfig = {
	-- Client UI settings
	gameplay = {},
	wildlife = {},
	-- Player Settings
	player = {
		maxHealth = 100,
		inventorySize = 5,
		startingTools = { "Axe", "Pickaxe", "Bow", "MagicMissile", "Fireball" },
		healthRegenRate = 5, -- Percentage per interval
		healthRegenInterval = 5, -- Seconds
		respawnTimeout = 10, -- Seconds

		-- Movement settings
		walkSpeed = 16,
		sprintSpeed = 24,
		maxStamina = 100,
		staminaDrainRate = 20, -- Per second while sprinting
		staminaRegenRate = 30, -- Per second while not sprinting
	},
	combat = ClientSettings.combat,
	targeting = ClientSettings.targeting,
	stats = {},
	map = {},
	drops = {},

	-- Day/Night Cycle & Waves
	time = DayNightCycleConfig.time,
	nightWaves = DayNightCycleConfig.nightWaves,

	-- Entity display data
	entities = EntitiesConfig.Entities,
	buildings = BuildingsConfig.buildings,
}

return ClientConfig
