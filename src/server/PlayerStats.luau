--!strict

--[[
	PlayerStats - Player Stats & Leveling System

	Manages player stats, XP, and leveling using ProfileStore for persistence.
	Server-authoritative: All stat operations validated server-side.

	SECURITY:
	- Client cannot manipulate stats/XP (all operations server-side)
	- All modifications validated before applying
	- Critical operations saved immediately to ProfileStore
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent:WaitForChild("ProfileStore"))
local Stats = require(ReplicatedStorage.Shared:WaitForChild("Stats"))
local GameConfig = require(ReplicatedStorage.Shared:WaitForChild("config"))

-- Initialize RemoteEvents
local RemoteEventsModule = require(ReplicatedStorage.Shared:WaitForChild("RemoteEvents"))
local RemoteEvents = RemoteEventsModule.Events

-- Access RemoteEvents
local RequestStatIncrease = RemoteEvents.RequestStatIncrease
local LevelUpNotification = RemoteEvents.LevelUpNotification
local XPUpdated = RemoteEvents.XPUpdated
local StatsUpdated = RemoteEvents.StatsUpdated

-- ProfileStore setup
local PROFILE_STORE_NAME = "PlayerData_v1"
local PROFILE_TEMPLATE = {
	stats = {
		strength = GameConfig.stats.defaultStartingStats.strength,
		magic = GameConfig.stats.defaultStartingStats.magic,
		stamina = GameConfig.stats.defaultStartingStats.stamina,
		accuracy = GameConfig.stats.defaultStartingStats.accuracy,
	},
	level = 1,
	xp = 0,
	unallocatedStatPoints = 0,
}

local PlayerProfileStore = ProfileStore.New(PROFILE_STORE_NAME, PROFILE_TEMPLATE)
local PlayerProfiles = {}  -- [Player] = Profile

local PlayerStats = {}

--[[
	Load player stats from ProfileStore

	@param player - Player instance
	@return Profile or nil (kicks player if failed)
]]
function PlayerStats.loadPlayerStats(player: Player)
	local profile = PlayerProfileStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		warn(`Failed to load profile for {player.Name}`)
		player:Kick("Failed to load your data. Please rejoin!")
		return nil
	end

	-- GDPR compliance
	profile:AddUserId(player.UserId)

	-- Reconcile profile (fill in missing fields from template)
	profile:Reconcile()

	-- Handle session end (kicked or left)
	profile.OnSessionEnd:Connect(function()
		PlayerProfiles[player] = nil
		player:Kick("Your data has been loaded on another server - please rejoin")
	end)

	-- Store profile
	PlayerProfiles[player] = profile

	-- Update player's MaxHealth based on stamina
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local derived = Stats.getDerivedStats({
		strength = profile.Data.stats.strength,
		magic = profile.Data.stats.magic,
		stamina = profile.Data.stats.stamina,
		accuracy = profile.Data.stats.accuracy,
		level = profile.Data.level,
		xp = profile.Data.xp,
	})
	humanoid.MaxHealth = GameConfig.player.maxHealth + derived.maxHealthBonus
	humanoid.Health = humanoid.MaxHealth

	-- Set Level attribute on character (health bar attached client-side)
	character:SetAttribute("Level", profile.Data.level)

	-- Send initial stats to client
	StatsUpdated:FireClient(player, profile.Data.stats, profile.Data.unallocatedStatPoints)
	XPUpdated:FireClient(player, profile.Data.xp, profile.Data.level)

	print(`Loaded profile for {player.Name} (Level {profile.Data.level}, {profile.Data.xp} XP)`)

	return profile
end

--[[
	Save player stats to ProfileStore

	@param player - Player instance
]]
function PlayerStats.savePlayerStats(player: Player)
	local profile = PlayerProfiles[player]
	if profile and profile:IsActive() then
		profile:EndSession()
		PlayerProfiles[player] = nil
		print(`Saved profile for {player.Name}`)
	end
end

--[[
	Get player stats (read-only for other systems)

	@param player - Player instance
	@return Stats or nil
]]
function PlayerStats.getPlayerStats(player: Player): Stats.Stats?
	local profile = PlayerProfiles[player]
	if not profile or not profile:IsActive() then
		return nil
	end

	return {
		strength = profile.Data.stats.strength,
		magic = profile.Data.stats.magic,
		stamina = profile.Data.stats.stamina,
		accuracy = profile.Data.stats.accuracy,
		level = profile.Data.level,
		xp = profile.Data.xp,
	}
end

--[[
	Get player level

	@param player - Player instance
	@return Level (1+)
]]
function PlayerStats.getPlayerLevel(player: Player): number
	local profile = PlayerProfiles[player]
	if not profile or not profile:IsActive() then
		return 1
	end

	return profile.Data.level
end

--[[
	Award XP to player (uses centralized Stats.calculateXPReward)
	Automatically handles level-up and grants stat points

	@param player - Player instance
	@param victimType - Entity type killed ("Wolf", "Bear", etc.)
	@param victimLevel - Level of victim
]]
function PlayerStats.awardXP(player: Player, victimType: string, victimLevel: number)
	local profile = PlayerProfiles[player]
	if not profile or not profile:IsActive() then
		return
	end

	-- SECURITY: Use centralized calculation (can't be manipulated)
	local xpAmount = Stats.calculateXPReward(victimType, victimLevel)

	-- Add XP
	profile.Data.xp = profile.Data.xp + xpAmount
	print(`[PlayerStats] {player.Name} earned {xpAmount} XP (total: {profile.Data.xp})`)

	-- Check for level-up
	local newLevel = Stats.calculateLevelFromXP(profile.Data.xp)
	if newLevel > profile.Data.level then
		-- Level up!
		local levelsGained = newLevel - profile.Data.level
		profile.Data.level = newLevel
		profile.Data.unallocatedStatPoints = profile.Data.unallocatedStatPoints + (levelsGained * GameConfig.stats.statPointsPerLevel)

		-- Update Level attribute on character
		local character = player.Character
		if character then
			character:SetAttribute("Level", newLevel)
		end

		-- Notify client
		print(`[PlayerStats] Firing LevelUpNotification to {player.Name}`)
		LevelUpNotification:FireClient(player, newLevel, profile.Data.unallocatedStatPoints)

		print(`{player.Name} leveled up to {newLevel}! ({profile.Data.unallocatedStatPoints} stat points)`)
	end

	-- Update client XP bar
	print(`[PlayerStats] Firing XPUpdated to {player.Name}: {profile.Data.xp} XP, Level {profile.Data.level}`)
	XPUpdated:FireClient(player, profile.Data.xp, profile.Data.level)
end

--[[
	Allocate a stat point (server validates all constraints)

	@param player - Player instance
	@param statName - Name of stat ("strength", "magic", "stamina", "accuracy")
	@return true if successful
]]
function PlayerStats.allocateStatPoint(player: Player, statName: string): boolean
	local profile = PlayerProfiles[player]
	if not profile or not profile:IsActive() then
		warn(`Cannot allocate stat for {player.Name}: Profile not active`)
		return false
	end

	-- SECURITY: Validate stat name
	if not profile.Data.stats[statName] then
		warn(`Invalid stat name: {statName}`)
		return false
	end

	-- SECURITY: Check available points
	if profile.Data.unallocatedStatPoints <= 0 then
		warn(`No stat points available for {player.Name}`)
		return false
	end

	-- SECURITY: Check stat cap (uses Stats.canAllocateStat)
	local currentStats = {
		strength = profile.Data.stats.strength,
		magic = profile.Data.stats.magic,
		stamina = profile.Data.stats.stamina,
		accuracy = profile.Data.stats.accuracy,
		level = profile.Data.level,
		xp = profile.Data.xp,
	}
	if not Stats.canAllocateStat(currentStats, statName, GameConfig.stats) then
		warn(`Stat {statName} at cap for {player.Name}`)
		return false
	end

	-- Apply stat increase
	profile.Data.stats[statName] = profile.Data.stats[statName] + 1
	profile.Data.unallocatedStatPoints = profile.Data.unallocatedStatPoints - 1

	-- Update MaxHealth if stamina changed
	if statName == "stamina" then
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if humanoid then
				local derived = Stats.getDerivedStats({
					strength = profile.Data.stats.strength,
					magic = profile.Data.stats.magic,
					stamina = profile.Data.stats.stamina,
					accuracy = profile.Data.stats.accuracy,
					level = profile.Data.level,
					xp = profile.Data.xp,
				})
				humanoid.MaxHealth = GameConfig.player.maxHealth + derived.maxHealthBonus
			end
		end
	end

	-- Save immediately (critical operation)
	profile:Save()

	-- Notify client
	StatsUpdated:FireClient(player, profile.Data.stats, profile.Data.unallocatedStatPoints)

	print(`{player.Name} allocated 1 point to {statName} ({profile.Data.stats[statName]} total)`)

	return true
end

-- Handle stat increase requests from client
RequestStatIncrease.OnServerEvent:Connect(function(player, statName)
	if type(statName) ~= "string" then
		warn(`Invalid stat name type from {player.Name}`)
		return
	end

	PlayerStats.allocateStatPoint(player, statName)
end)

-- Player joined
Players.PlayerAdded:Connect(function(player)
	PlayerStats.loadPlayerStats(player)
end)

-- Player leaving
Players.PlayerRemoving:Connect(function(player)
	PlayerStats.savePlayerStats(player)
end)

-- Server shutdown
game:BindToClose(function()
	-- ProfileStore handles shutdown automatically
	print("Server shutting down, ProfileStore will save all profiles...")
end)

return PlayerStats
