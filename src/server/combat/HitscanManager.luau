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
local ServerScriptService = game:GetService("ServerScriptService")

local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local HitscanEffects = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual-effects"):WaitForChild("HitscanEffects"))
local GameConfig = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Config"):WaitForChild("GameConfig"))

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
	Calculate hitscan direction based on auto-aim setting and click targeting

	@param attackerRoot - Attacker's HumanoidRootPart
	@param lockedTarget - Locked target (if any)
	@param clickTarget - Click target (if any)
	@param clickPosition - Click position (if any)
	@param origin - Origin position of hitscan
	@return Vector3 - Direction vector
]]
function HitscanManager.calculateDirection(
	attackerRoot: BasePart,
	lockedTarget: Model?,
	clickTarget: Model?,
	clickPosition: Vector3?,
	origin: Vector3
): Vector3
	-- NEW BEHAVIOR:
	-- - Default: Aim at tap position (or target near tap)
	-- - autoAim=true + locked target: Override with locked target
	-- - autoAim=false: Always use tap position (ignore locked target)

	if GameConfig.combat.autoAim and lockedTarget then
		-- AUTO-AIM ON + LOCKED TARGET: Aim at locked target (override tap)
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart") or lockedTarget:FindFirstChild("Torso") :: BasePart?
		if targetRoot and targetRoot:IsA("BasePart") then
			return (targetRoot.Position - origin).Unit
		else
			-- Target lost, fallback to tap position or look direction
			if clickPosition then
				return (clickPosition - origin).Unit
			else
				return attackerRoot.CFrame.LookVector
			end
		end
	elseif clickTarget then
		-- DEFAULT BEHAVIOR: Target found near tap - aim at it
		local targetRoot = clickTarget:FindFirstChild("HumanoidRootPart") or clickTarget:FindFirstChild("Torso") :: BasePart?
		if targetRoot and targetRoot:IsA("BasePart") then
			return (targetRoot.Position - origin).Unit
		else
			-- Click target lost, fallback to tap position or look direction
			if clickPosition then
				return (clickPosition - origin).Unit
			else
				return attackerRoot.CFrame.LookVector
			end
		end
	elseif clickPosition then
		-- DEFAULT BEHAVIOR: No target near tap - aim at tap position
		return (clickPosition - origin).Unit
	else
		-- FALLBACK: No tap registered - use look direction
		return attackerRoot.CFrame.LookVector
	end
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
		local ProjectileLOS = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("combat"):WaitForChild("ProjectileLOS"))
		local losResult = ProjectileLOS.canTargetEntity(attacker, lockedTarget)

		if not losResult.hasLineOfSight then
			return false, "No line of sight to target"
		end
	end

	return true
end

return HitscanManager
