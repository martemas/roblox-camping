--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TargetingSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TargetingSystem"))
local WeaponDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))
local EntityStats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EntityStats"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

-- Player combat data
local playerCombatData: {[Player]: {
	lastAttackTime: number,
	currentWeapon: string?,
	playerStats: any,
}} = {}

-- Get player's current equipped weapon
local function getEquippedWeapon(player: Player): string?
	local character = player.Character
	if not character then return nil end

	-- Check for equipped tool
	for _, tool in pairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			return tool.Name
		end
	end

	-- Default to fists if no tool equipped
	return GameConfig.player.defaultWeapon
end

-- Calculate player stats (for now use config, later integrate with player progression)
local function getPlayerStats(player: Player)
	-- For now, use base player stats from config
	-- In the future, this would load from player data/progression
	return EntityStats.calculateDerivedStats(GameConfig.player.stats)
end

-- Perform player attack on target
local function performPlayerAttack(player: Player, target: Model)
	local combatData = playerCombatData[player]
	if not combatData then return end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	-- Get weapon and stats
	local weaponName = getEquippedWeapon(player)
	if not weaponName then return end

	local weapon = WeaponDefinitions.getWeapon(weaponName)
	if not weapon then
		warn(`No weapon definition found for: {weaponName}`)
		return
	end

	local playerStats = getPlayerStats(player)

	-- Check attack cooldown
	local currentTime = tick()
	if currentTime - combatData.lastAttackTime < weapon.cooldown then
		return -- Still on cooldown
	end

	-- Check range
	local playerPos = character.HumanoidRootPart.Position
	local targetPart = target.PrimaryPart or target:FindFirstChildOfClass("BasePart")
	if not targetPart then return end

	local distance = (targetPart.Position - playerPos).Magnitude
	if distance > weapon.attackRange then
		return -- Too far away
	end

	-- Calculate damage using stats system
	local baseDamage = weapon.baseDamage
	local strengthBonus = playerStats.strength * weapon.strengthScaling
	local agilityBonus = playerStats.agility * weapon.agilityScaling
	local iqBonus = playerStats.iq * weapon.iqScaling

	local totalDamage = baseDamage + strengthBonus + agilityBonus + iqBonus

	-- Check for critical hit
	local isCritical = math.random() <= playerStats.critChance
	if isCritical then
		totalDamage = totalDamage * weapon.critMultiplier
	end

	local finalDamage = math.floor(totalDamage)

	-- Apply damage to target
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if targetHumanoid and targetHumanoid.Health > 0 then
		-- Check if target is an enemy managed by EnemySpawner
		if _G.EnemySpawner and _G.EnemySpawner.HandleToolHit then
			local targetType = target:GetAttribute("EntityType") or target.Name
			_G.EnemySpawner.HandleToolHit(player, target, finalDamage, targetType)
		else
			-- Fallback: direct damage application
			local currentHealth = target:GetAttribute("CurrentHealth") or targetHumanoid.Health
			currentHealth = math.max(0, currentHealth - finalDamage)
			target:SetAttribute("CurrentHealth", currentHealth)
			targetHumanoid.Health = math.max(0, currentHealth)
		end

		-- Update attack time
		combatData.lastAttackTime = currentTime

		-- Visual/audio feedback
		local critText = isCritical and " (CRITICAL!)" or ""
		print(`{player.Name} attacked {target.Name} for {finalDamage} damage{critText}`)

		-- TODO: Play attack animation
		-- TODO: Play attack sound
		-- TODO: Show damage numbers UI
	end
end

-- Update combat for a single player
local function updatePlayerCombat(player: Player)
	local target = TargetingSystem.getTarget(player)
	if not target then
		return -- No target = no auto-attack
	end

	-- Check if target is still valid and alive
	if not TargetingSystem.isValidTarget(target) then
		TargetingSystem.setTarget(player, nil) -- Clear invalid target
		return
	end

	-- Check if auto-attack is enabled in player settings
	local autoAttackEnabled = true -- Default to enabled
	-- TODO: Read from player settings when settings system is integrated
	-- local playerSettings = PlayerSettingsManager.getSettings(player)
	-- autoAttackEnabled = playerSettings.gameplay.combat.autoAttackEnabled

	if not autoAttackEnabled then
		return -- Auto-attack is disabled in settings
	end

	-- Perform attack if ready (target exists and auto-attack enabled)
	performPlayerAttack(player, target)
end

-- Initialize player combat data
local function initializePlayerCombat(player: Player)
	playerCombatData[player] = {
		lastAttackTime = 0,
		currentWeapon = nil,
		playerStats = getPlayerStats(player),
	}
	print(`PlayerCombat: Initialized combat data for {player.Name}`)
end

-- Clean up player data
local function cleanupPlayerCombat(player: Player)
	playerCombatData[player] = nil
end

-- Main combat update loop
local function updateAllPlayersCombat()
	for player, _ in pairs(playerCombatData) do
		if player.Character then
			updatePlayerCombat(player)
		end
	end
end

-- Initialize the player combat system
local function initialize()
	-- Initialize existing players
	for _, player in pairs(Players:GetPlayers()) do
		initializePlayerCombat(player)
	end

	-- Handle new players
	Players.PlayerAdded:Connect(initializePlayerCombat)
	Players.PlayerRemoving:Connect(cleanupPlayerCombat)

	-- Start combat update loop
	RunService.Heartbeat:Connect(updateAllPlayersCombat)

	print("PlayerCombat system initialized")
end

-- Start the system
initialize()

-- Export for access by other systems
_G.PlayerCombat = {
	getPlayerStats = getPlayerStats,
	getEquippedWeapon = getEquippedWeapon,
}