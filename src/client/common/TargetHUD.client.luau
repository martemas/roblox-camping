--!strict

--[[
	TargetHUD Client Orchestrator

	Responsibilities:
	- RunService update loop (polling TargetingSystem)
	- Combat validation logic (range, facing, LOS)
	- Determine border colors based on attack readiness
	- Connect TargetHUD component to game systems

	Uses:
	- ui/TargetHUD.luau component for pure UI rendering
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TargetingSystem = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Player"):WaitForChild("TargetingSystem"))
local PlayerSettingsManager = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Player"):WaitForChild("PlayerSettingsManager"))
local PlayerSettings = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Player"):WaitForChild("PlayerSettings"))
local Types = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))
local CombatUtils = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Combat"):WaitForChild("CombatUtils"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Config"))
local WeaponInfoCache = require(script.Parent.WeaponInfoCache)

-- Import TargetHUD component
local TargetHUD = require(script.Parent.ui.TargetHUD)

type TargetInfo = Types.TargetInfo
type TargetHUDSettings = PlayerSettings.TargetHUDSettings

local player = Players.LocalPlayer

-- HUD state
local currentTarget: Model? = nil
local updateConnection: RBXScriptConnection? = nil

-- Initialize player settings
PlayerSettingsManager.initialize()

local function validateLOSPath(
	origin: vector,
	targetPosition: vector,
	attacker: Model
): boolean
	-- Initialize raycasting setup
	local raycastParams = RaycastParams.new()

	-- Setup raycast parameters
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Build ignore list: attacker + all characters/entities
	local ignoreList = {attacker}

	-- Add all player characters
	local Players = game:GetService("Players")
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignoreList, player.Character)
		end
	end

	-- Add all NPCs/entities (models with Humanoid)
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Humanoid") and descendant.Parent and descendant.Parent ~= attacker then
			local model = descendant.Parent
			if model:IsA("Model") then
				table.insert(ignoreList, model)
			end
		end
	end

	raycastParams.FilterDescendantsInstances = ignoreList

	-- Perform raycast from origin to target
	local direction = targetPosition - origin
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)

	if raycastResult then
		-- Hit something (structure, resource, terrain)
		return false
	end

	-- Clear path
	return true
end

-- Calculate border color and status based on attack readiness
local function calculateAttackStatus(targetInfo: TargetInfo): (Color3, string)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return Color3.fromRGB(150, 150, 150), "NO CHARACTER"
	end

	local playerRoot = character.HumanoidRootPart :: BasePart
	local targetRoot = targetInfo.model:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not targetRoot then
		return Color3.fromRGB(150, 150, 150), "NO TARGET ROOT"
	end

	-- Get player's equipped weapon
	local weaponName = CombatUtils.getPlayerWeapon(player)
	if not weaponName then
		return Color3.fromRGB(150, 150, 150), "NO WEAPON"
	end

	-- Get weapon info from cache (fetches from server if needed)
	local weaponInfo = WeaponInfoCache.getWeaponInfo(weaponName)
	if not weaponInfo then
		return Color3.fromRGB(150, 150, 150), "NO WEAPON DATA"
	end

	-- Use weapon config for UI feedback
	-- Note: This is for UI feedback only. Server validates actual attacks.
	local weaponConfig = {
		range = weaponInfo.range,
		targetFilter = weaponInfo.targetFilter,
		requireFacingForDamage = weaponInfo.requireFacingForDamage,
		requiresLineOfSight = weaponInfo.requiresLineOfSight,
		type = weaponInfo.weaponType,
	}

	-- Check target filter first (allies/enemies)
	local targetPlayer = Players:GetPlayerFromCharacter(targetInfo.model)
	local isValidTarget = true

	if weaponConfig.targetFilter then
		if weaponConfig.targetFilter == "allies" then
			-- Can only target allies (same player or teammates)
			if targetPlayer ~= player then
				-- TODO: Add team support when teams are implemented
				isValidTarget = false
			end
		elseif weaponConfig.targetFilter == "enemies" then
			-- Can only target enemies (different player or NPCs)
			if targetPlayer == player then
				isValidTarget = false
			end
		end
	end

	if not isValidTarget then
		return Color3.fromRGB(150, 150, 150), "INVALID TARGET"
	end

	-- Check distance
	local distance = (targetRoot.Position - playerRoot.Position).Magnitude
	local inRange = distance <= weaponConfig.range

	if not inRange then
		return Color3.fromRGB(255, 150, 0), "OUT OF RANGE"
	end

	-- Check facing (if required)
	local requireFacing = weaponConfig.requireFacingForDamage
	if requireFacing == nil then
		requireFacing = GameConfig.combat.requireFacingForDamage
	end

	local isFacing = true
	if requireFacing then
		isFacing = CombatUtils.isFacingTarget(playerRoot, targetRoot, nil)
	end

	if not isFacing then
		return Color3.fromRGB(255, 100, 0), "NOT FACING"
	end

	-- Check LOS (for projectile and hitscan weapons)
	local hasLOS = true

	if weaponConfig.requiresLineOfSight and (weaponConfig.type == "projectile" or weaponConfig.type == "hitscan") then
		local origin = playerRoot.Position + vector.create(0, 1, 0)
		local targetPos = targetRoot.Position + vector.create(0, 1, 0)
		local hasLOS = validateLOSPath(origin, targetPos, character)

		if not hasLOS then
			return Color3.fromRGB(255, 50, 50), "BLOCKED"
		end
	end

	-- Can attack: Green
	return Color3.fromRGB(0, 255, 0), "READY"
end

-- Update HUD with target information
local function updateHUDWithTarget(targetInfo: TargetInfo)
	local settings = PlayerSettingsManager.getTargetHUDSettings(player)

	if not settings.enabled then
		TargetHUD.hide()
		return
	end

	-- Calculate attack status
	local borderColor, statusText = calculateAttackStatus(targetInfo)

	-- Prepare update data
	local updateData = {
		name = `{targetInfo.entityType} ({targetInfo.model.Name})`,
		health = targetInfo.health,
		maxHealth = targetInfo.maxHealth,
		distance = targetInfo.distance,
		state = targetInfo.state,
		damage = targetInfo.damage,
		entityType = targetInfo.entityType,
		entityCategory = targetInfo.entityCategory,
		borderColor = borderColor,
		statusText = statusText,
		animationSpeed = settings.animationSpeed,
	}

	-- Update component
	TargetHUD.update(updateData)
	TargetHUD.show()
end

-- Main update loop for the HUD
local function updateHUD()
	local target = TargetingSystem.getTarget(player)

	-- If no target, hide HUD
	if not target then
		if currentTarget then
			TargetHUD.hide()
			currentTarget = nil
		end
		return
	end

	-- Get target info
	local targetInfo = TargetingSystem.getTargetInfo(player)
	if not targetInfo then
		TargetHUD.hide()
		currentTarget = nil
		return
	end

	-- Show/update HUD
	currentTarget = target
	updateHUDWithTarget(targetInfo)
end

-- Start the update loop
local lastUpdateTime = 0
local function startUpdateLoop()
	local settings = PlayerSettingsManager.getTargetHUDSettings(player)

	if updateConnection then
		updateConnection:Disconnect()
	end

	updateConnection = RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		if currentTime - lastUpdateTime >= settings.updateFrequency then
			updateHUD()
			lastUpdateTime = currentTime
		end
	end)
end

-- Handle settings changes
local function onSettingsChanged(newSettings: PlayerSettings.PlayerSettingsData)
	-- Restart update loop with new frequency
	startUpdateLoop()

	-- Apply new settings to component
	TargetHUD.applySettings(newSettings.ui.targetHUD)
end

-- Initialize the system
local function initialize()
	-- Create component
	TargetHUD.create(player)

	-- Load player settings
	PlayerSettingsManager.loadPlayerSettings(player)

	-- Apply initial settings
	local settings = PlayerSettingsManager.getTargetHUDSettings(player)
	TargetHUD.applySettings(settings)

	-- Connect close button
	local closeButton = TargetHUD.getCloseButton()
	if closeButton then
		closeButton.MouseButton1Click:Connect(function()
			TargetingSystem.setTarget(player, nil)
			RemoteEvents.Events.DeselectTarget:FireServer()
		end)
	end

	-- Register for settings changes
	PlayerSettingsManager.onSettingsChanged(player, onSettingsChanged)

	-- Start the update loop
	startUpdateLoop()

	print("[TargetHUD] Orchestrator initialized")
end


-- Start everything
initialize()

-- Clean up on player leaving
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		if updateConnection then
			updateConnection:Disconnect()
		end
		TargetHUD.destroy()
	end
end)