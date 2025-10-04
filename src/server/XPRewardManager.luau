--!strict

--[[
	XPRewardManager - Centralized XP Award System

	Manages last attacker tracking and XP rewards for kills.
	Used by both CombatSystem and EntityController to avoid duplicate code.

	SECURITY:
	- All XP calculations use centralized Stats.calculateXPReward
	- Server-side only (cannot be manipulated by client)
	- Attacker credit expires after configurable time
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage.Shared:WaitForChild("Stats"))
local GameConfig = require(ReplicatedStorage.Shared:WaitForChild("GameConfig"))

local XPRewardManager = {}

-- Lazy-loaded modules (avoid circular dependencies)
local PlayerStats
local EntityController

local function getPlayerStats()
	if not PlayerStats then
		PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
	end
	return PlayerStats
end

local function getEntityController()
	if not EntityController then
		EntityController = require(ReplicatedStorage.Shared:WaitForChild("EntityController"))
	end
	return EntityController
end

--[[
	Track attacker for kill credit

	@param victim - Victim's model
	@param attacker - Attacker's model
	@param attackerLevel - Attacker's level (for XP scaling)
]]
function XPRewardManager.trackAttacker(victim: Model, attacker: Model, attackerLevel: number)
	-- SECURITY: Only run on server
	if not RunService:IsServer() then
		return
	end

	-- Store attacker reference using ObjectValue (can't use attributes for Instances)
	local lastAttackerValue = victim:FindFirstChild("LastAttacker")
	if not lastAttackerValue then
		lastAttackerValue = Instance.new("ObjectValue")
		lastAttackerValue.Name = "LastAttacker"
		lastAttackerValue.Parent = victim
	end
	lastAttackerValue.Value = attacker

	-- Store level and time as attributes (these are numbers)
	victim:SetAttribute("LastAttackerLevel", attackerLevel)
	victim:SetAttribute("LastAttackerTime", tick())

	-- Debug logging
	local attackerName = attacker.Name
	local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
	if attackerPlayer then
		attackerName = attackerPlayer.Name
	end

	print(`XPReward: {attackerName} (Level {attackerLevel}) attacked {victim.Name}`)
end

--[[
	Clear expired attacker credit

	@param victim - Victim's model
]]
function XPRewardManager.clearExpiredAttacker(victim: Model)
	local lastTime = victim:GetAttribute("LastAttackerTime") or 0
	local expiry = GameConfig.stats.lastAttackerExpiry or 10

	if tick() - lastTime > expiry then
		local lastAttackerValue = victim:FindFirstChild("LastAttacker")
		if lastAttackerValue then
			lastAttackerValue:Destroy()
		end
		victim:SetAttribute("LastAttackerLevel", nil)
		victim:SetAttribute("LastAttackerTime", nil)
	end
end

--[[
	Award XP for kill (CENTRALIZED - used by both Combat and Entity death)

	@param victim - Victim's model that died
]]
function XPRewardManager.awardXPForKill(victim: Model)
	-- SECURITY: Only run on server
	if not RunService:IsServer() then
		return
	end

	-- Check if attacker credit has expired
	local lastTime = victim:GetAttribute("LastAttackerTime") or 0
	local expiry = GameConfig.stats.lastAttackerExpiry or 10

	if tick() - lastTime > expiry then
		print(`XPReward: No kill credit (attacker credit expired)`)
		return -- No credit
	end

	-- Get last attacker from ObjectValue
	local lastAttackerValue = victim:FindFirstChild("LastAttacker")
	if not lastAttackerValue or not lastAttackerValue:IsA("ObjectValue") then
		print(`XPReward: No LastAttacker ObjectValue found`)
		return
	end

	local lastAttacker = lastAttackerValue.Value
	if not lastAttacker or not lastAttacker:IsDescendantOf(workspace) then
		print(`XPReward: No valid last attacker`)
		return
	end

	-- Get victim info
	local victimLevel = victim:GetAttribute("Level") or 1
	local victimType = victim:GetAttribute("EntityType") or "Unknown"

	-- Determine attacker type (player or entity)
	local attackerPlayer = Players:GetPlayerFromCharacter(lastAttacker)

	if attackerPlayer then
		-- PLAYER KILLED ENTITY
		-- SECURITY: Uses server-side PlayerStats.awardXP (centralized calculation)
		local PlayerStatsModule = getPlayerStats()
		PlayerStatsModule.awardXP(attackerPlayer, victimType, victimLevel)

		print(`XPReward: {attackerPlayer.Name} earned XP for killing {victimType} (Level {victimLevel})`)
	else
		-- ENTITY KILLED ENTITY (or player)
		local EntityControllerModule = getEntityController()
		local attackerEntity = EntityControllerModule.getEntity(lastAttacker)
		if attackerEntity then
			-- SECURITY: Uses EntityController.awardEntityXP (centralized calculation)
			EntityControllerModule.awardEntityXP(lastAttacker, victimType, victimLevel)

			local attackerType = lastAttacker:GetAttribute("EntityType") or "Unknown"
			print(`XPReward: {attackerType} earned XP for killing {victimType} (Level {victimLevel})`)
		end
	end

	-- Clear attacker credit after awarding XP
	if lastAttackerValue then
		lastAttackerValue:Destroy()
	end
	victim:SetAttribute("LastAttackerLevel", nil)
	victim:SetAttribute("LastAttackerTime", nil)
end

return XPRewardManager
