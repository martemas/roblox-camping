--!strict

-- Main config entry point that re-exports all config modules
-- Maintains identical API structure to original GameConfig.luau

local GameSettings = require(script.GameSettings)
local DayNightCycleConfig = require(script.DayNightCycleConfig)
local WeaponsConfig = require(script.WeaponsConfig)
local ToolsConfig = require(script.ToolsConfig)
local ResourcesConfig = require(script.ResourcesConfig)
local EntitiesConfig = require(script.EntitiesConfig)
local BuildingsConfig = require(script.BuildingsConfig)
local ShopConfig = require(script.ShopConfig)

-- Export CombatMode type for external use
export type CombatMode = GameSettings.CombatMode

local GameConfig = {
	-- Core Framework Settings
	gameplay = GameSettings.gameplay,
	wildlife = GameSettings.wildlife,
	player = GameSettings.player,
	combat = GameSettings.combat,
	targeting = GameSettings.targeting,
	stats = GameSettings.stats,
	map = GameSettings.map,
	CombatMode = GameSettings.CombatMode,

	-- Day/Night Cycle & Waves
	time = DayNightCycleConfig.time,
	nightWaves = DayNightCycleConfig.nightWaves,

	-- Extensible Content (Frequently Modified)
	weapons = WeaponsConfig.weapons,
	toolCategories = ToolsConfig.toolCategories,
	tools = ToolsConfig.tools,
	resources = ResourcesConfig.Resources,
	entities = EntitiesConfig.Entities,
	buildings = BuildingsConfig.buildings,
	shop = ShopConfig.shop,
}

GameConfig.Types = {
	-- CombatMode = GameSettings.CombatMode,
	ResourceTypes = ResourcesConfig.Types,
	EntityCategories = EntitiesConfig.Categories,
	-- ToolType = ToolsConfig.ToolType,
	-- WildlifeType = EntitiesConfig.WildlifeType,
	-- CreatureType = EntitiesConfig.CreatureType,
}


return GameConfig
