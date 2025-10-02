--!strict

--[[
	HitscanManager - Hitscan Attack Execution and Validation

	Public API for performing hitscan attacks. All hitscan logic is server-authoritative.
	Follows the same pattern as ProjectileManager for consistency.

	Integration:
	- Called by ToolManager after castDuration
	- Delegates damage to CombatSystem
	- Handles visual effects via HitscanEffects
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local HitscanEffects = require(script.Parent:WaitForChild("HitscanEffects"))
local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

local HitscanManager = {}

--[[
	Perform hitscan attack

	@param origin - Starting position of hitscan
	@param direction - Direction vector (auto-aim or look direction)
	@param weaponName - Name of weapon (e.g., "MagicMissile")
	@param attacker - Entity firing the hitscan
	@param attackingPlayer - Player if attacker is player character
	@param lockedTarget - Locked target (for auto-aim and range validation)
	@return AttackResult - Result of the attack
]]
function HitscanManager.performHitscan(
	origin: Vector3,
	direction: Vector3,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	lockedTarget: Model?
): CombatSystem.AttackResult
	-- Validate via CombatSystem
	local result = CombatSystem.performHitscan(
		origin,
		direction,
		weaponName,
		attacker,
		attackingPlayer,
		lockedTarget
	)

	return result
end

--[[
	Calculate hitscan direction based on auto-aim setting

	@param attackerRoot - Attacker's HumanoidRootPart
	@param lockedTarget - Locked target (if any)
	@param origin - Origin position of hitscan
	@return Vector3 - Direction vector
]]
function HitscanManager.calculateDirection(
	attackerRoot: BasePart,
	lockedTarget: Model?,
	origin: Vector3
): Vector3
	-- Check auto-aim setting
	if GameConfig.combat.autoAim and lockedTarget then
		-- Auto-aim mode: Aim at locked target
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart") or lockedTarget:FindFirstChild("Torso") :: BasePart?
		if targetRoot and targetRoot:IsA("BasePart") then
			return (targetRoot.Position - origin).Unit
		end
	end

	-- Free-aim mode: Use look direction
	return attackerRoot.CFrame.LookVector
end

--[[
	Validate hitscan attack prerequisites

	@param attacker - Entity attempting to attack
	@param lockedTarget - Locked target (required for auto-aim)
	@param weaponName - Name of weapon
	@return boolean - True if valid, false otherwise
	@return string? - Error message if invalid
]]
function HitscanManager.validateAttack(
	attacker: Model,
	lockedTarget: Model?,
	weaponName: string
): (boolean, string?)
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig or weaponConfig.type ~= "hitscan" then
		return false, `Invalid weapon: {weaponName}`
	end

	-- Check combat mode
	if GameConfig.combat.combatMode == GameConfig.CombatMode.TACTICAL then
		-- TACTICAL mode: Must always have target to attack
		if not lockedTarget then
			return false, "No target selected"
		end
	elseif GameConfig.combat.combatMode == GameConfig.CombatMode.ACTION then
		-- ACTION mode: Only require target if weapon specifically requires it
		if weaponConfig.requiresTarget and not lockedTarget then
			return false, "No target selected"
		end
	end

	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not attackerRoot then
		return false, "Attacker has no HumanoidRootPart"
	end

	-- Check facing requirement (auto-aim mode only)
	-- Weapon can override global requireFacingForDamage setting
	local requireFacing = weaponConfig.requireFacingForDamage
	if requireFacing == nil then
		requireFacing = GameConfig.combat.requireFacingForDamage
	end

	if GameConfig.combat.autoAim and requireFacing and lockedTarget then
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart") or lockedTarget:FindFirstChild("Torso") :: BasePart?
		if targetRoot and targetRoot:IsA("BasePart") then
			if not CombatSystem.isFacingTarget(attackerRoot, targetRoot) then
				return false, "Not facing target"
			end
		end
	end

	-- Check line of sight (if required)
	if weaponConfig.requiresLineOfSight and lockedTarget then
		local ProjectileLOS = require(script.Parent:WaitForChild("ProjectileLOS"))
		local losResult = ProjectileLOS.canTargetEntity(attacker, lockedTarget)

		if not losResult.hasLineOfSight then
			return false, "No line of sight to target"
		end
	end

	return true
end

return HitscanManager
