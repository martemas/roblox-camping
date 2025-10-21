--!strict

--[[
	StatsProvider - Centralized Stats Retrieval

	Provides a unified interface for retrieving stats from any entity (player or NPC).
	This module eliminates circular dependencies by serving as a mediator between
	combat systems and stat management systems.

	Architecture:
	- PlayerStats (server) ──┐
	                         ├──> StatsProvider (server) ──> CombatSystem
	- EntityController ──────┘

	Performance: O(1) hash table lookups, no performance impact
]]

local PlayerStats = require(script.Parent.Parent.PlayerStats)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Stats = require(script.Parent.Stats)

-- Lazy-loaded modules (cached after first use)
local EntityController

-- Load EntityController module
local function getEntityController()
	if not EntityController then
		-- EntityController is now in server/entities
		local success, entityControllerModule = pcall(function()
			return ServerScriptService:WaitForChild("Server"):WaitForChild("Entities"):WaitForChild("EntityController", 5)
		end)

		if success and entityControllerModule then
			EntityController = require(entityControllerModule)
		else
			warn("[StatsProvider] Failed to load EntityController - module not found in ServerScriptService.Server.entities")
		end
	end
	return EntityController
end

local StatsProvider = {}

--[[
	Get stats for any entity (player character or NPC)

	@param model - The character/entity model
	@return Stats? - Stats object or nil if not found
]]
function StatsProvider.getStats(model: Model): Stats.Stats?
	if not model then
		return nil
	end

	-- Check if it's a player character
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		-- Player character - get stats from PlayerStats (server-side only)
		return PlayerStats.getPlayerStats(player)
	end

	-- Check if it's an NPC entity
	local entityType = model:GetAttribute("EntityType")
	if entityType then
		-- NPC entity - get stats from EntityController
		local EntityControllerModule = getEntityController()
		if EntityControllerModule then
			return EntityControllerModule.getEntityStats(model)
		end
		return nil
	end

	-- Unknown entity type
	return nil
end

--[[
	Get attacking player from a model (if the model is a player character)

	@param model - The character/entity model
	@return Player? - Player object or nil
]]
function StatsProvider.getPlayerFromModel(model: Model): Player?
	return Players:GetPlayerFromCharacter(model)
end

return StatsProvider
