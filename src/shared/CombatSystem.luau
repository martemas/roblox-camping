--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(script.Parent:WaitForChild("GameConfig"))
local CombatFeedback = require(script.Parent:WaitForChild("CombatFeedback"))

-- Export types
export type WeaponType = "melee" | "projectile" | "hitscan" | "aoe"

export type WeaponConfig = {
	type: WeaponType,
	name: string,
	damage: number,
	range: number,
	cooldown: number,
	castDuration: number,

	-- Projectile-specific
	projectileSpeed: number?,

	-- AOE-specific
	aoeRadius: number?,
	aoeFalloff: boolean?,
	maxTargets: number?,
	duration: number?,
	tickRate: number?,
	targetFilter: string?,
}

export type AttackResult = {
	hit: boolean,           -- Was attack successful
	target: Model?,         -- Entity that was hit (nil for AOE/miss)
	damage: number?,        -- Damage dealt (nil if miss)
	wasInRange: boolean,    -- Was target in range after castDuration
	wasDodged: boolean,     -- Did target dodge (was in range, now isn't)
	blockedByInvulnerability: boolean?, -- Was attack blocked by invulnerability frames
}

export type AOEHitInfo = {
	entity: Model,
	damage: number,
	distance: number,       -- Distance from AOE center
}

local CombatSystem = {}

-- Get weapon config from GameConfig
function CombatSystem.getWeaponConfig(weaponName: string): WeaponConfig?
	local weaponConfig = GameConfig.weapons[weaponName]
	if not weaponConfig then
		warn(`Weapon config not found: {weaponName}`)
		return nil
	end
	return weaponConfig
end

-- Get entity's weapon (for wildlife/enemies)
function CombatSystem.getEntityWeapon(entityType: string): string?
	-- Check wildlife
	local wildlifeConfig = GameConfig.wildlife[entityType]
	if wildlifeConfig and wildlifeConfig.primaryWeapon then
		return wildlifeConfig.primaryWeapon
	end

	-- Check enemies
	local enemyConfig = GameConfig.enemies[entityType]
	if enemyConfig and enemyConfig.primaryWeapon then
		return enemyConfig.primaryWeapon
	end

	return nil
end

-- Get player's equipped weapon (from tool)
function CombatSystem.getPlayerWeapon(player: Player): string?
	local character = player.Character
	if not character then
		return nil
	end

	-- Check for equipped tool
	for _, toolName in GameConfig.player.startingTools do
		local tool = character:FindFirstChild(toolName)
		if tool and tool:IsA("Tool") then
			-- Get weapon reference from tool config
			local toolConfig = GameConfig.tools[toolName]
			if toolConfig and toolConfig.weaponRef then
				return toolConfig.weaponRef
			end
		end
	end

	return nil
end

-- Calculate distance between two positions
local function getDistance(pos1: vector, pos2: vector): number
	return (pos2 - pos1).Magnitude
end

-- Find entity model from a part (includes player characters and NPCs)
local function findEntityFromPart(part: BasePart): Model?
	local current = part.Parent
	while current and current ~= workspace do
		if current:IsA("Model") then
			-- Check if it's a player character
			local player = game:GetService("Players"):GetPlayerFromCharacter(current)
			if player then
				return current
			end

			-- Check if it's an NPC with EntityType attribute
			local entityType = current:GetAttribute("EntityType")
			if entityType then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

-- Check if target is invulnerable to this weapon type
local function checkInvulnerability(targetModel: Model, weaponName: string): boolean
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	-- Check if invulnerability system is enabled
	if not GameConfig.combat.invulnerabilityFrames then
		return false
	end

	-- Check weapon-specific invulnerability
	local invulnAttr = `InvulnerableTo_{weaponName}`
	local isInvulnerable = humanoid:GetAttribute(invulnAttr)
	return isInvulnerable == true
end

-- Set invulnerability for a target to a specific weapon type
local function setInvulnerability(targetModel: Model, weaponName: string, duration: number)
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if not GameConfig.combat.invulnerabilityFrames then
		return
	end

	local invulnAttr = `InvulnerableTo_{weaponName}`
	humanoid:SetAttribute(invulnAttr, true)

	-- Clear invulnerability after duration
	task.delay(duration, function()
		if humanoid and humanoid.Parent then
			humanoid:SetAttribute(invulnAttr, false)
		end
	end)
end

-- Check if PvP is allowed for this attack
local function isPvPAllowed(attacker: Model, target: Model): boolean
	-- Check if both are player characters
	local attackerPlayer = game:GetService("Players"):GetPlayerFromCharacter(attacker)
	local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(target)

	if not attackerPlayer or not targetPlayer then
		-- Not PvP if either is not a player
		return true
	end

	-- Check if PvP is enabled
	return GameConfig.combat.pvpEnabled
end

-- Find all entities within range of a position
local function findEntitiesInRange(
	origin: vector,
	range: number,
	excludeModel: Model?
): {Model}
	local entities: {Model} = {}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if excludeModel then {excludeModel} else {}

	local parts = workspace:GetPartBoundsInRadius(origin, range, params)

	-- Find unique entity models
	local seen: {[Model]: boolean} = {}
	for _, part in parts do
		local entity = findEntityFromPart(part)
		if entity and not seen[entity] and entity ~= excludeModel then
			seen[entity] = true
			table.insert(entities, entity)
		end
	end

	return entities
end

-- Main attack function for melee weapons
function CombatSystem.attemptMeleeAttack(
	attacker: Model,
	target: Model?,
	weaponName: string,
	attackingPlayer: Player?
): AttackResult
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		return {
			hit = false,
			target = nil,
			damage = nil,
			wasInRange = false,
			wasDodged = false,
			blockedByInvulnerability = false
		}
	end

	-- Get attacker position
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not attackerRoot then
		return {
			hit = false,
			target = nil,
			damage = nil,
			wasInRange = false,
			wasDodged = false,
			blockedByInvulnerability = false
		}
	end

	local attackerPos = attackerRoot.Position

	-- Determine hit detection mode
	local damageTargetOnly = GameConfig.combat.damageTargetOnly

	local targetsToCheck: {Model} = {}

	if damageTargetOnly then
		-- Mode A: Only damage the specified target
		if target then
			table.insert(targetsToCheck, target)
		end
	else
		-- Mode B: Damage all entities in range
		targetsToCheck = findEntitiesInRange(attackerPos, weaponConfig.range, attacker)
	end

	-- Check each potential target
	local hitAny = false
	local firstHit: Model? = nil
	local totalDamage = 0

	for _, targetModel in targetsToCheck do
		local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not targetRoot then
			continue
		end

		-- Check if target is in range
		local distance = getDistance(attackerPos, targetRoot.Position)
		local inRange = distance <= weaponConfig.range

		if not inRange then
			-- Target out of range - dodged or miss
			if targetModel == target then
				-- Primary target dodged
				CombatFeedback.showDamage(targetModel, nil, weaponName, "dodge", attackingPlayer)
			end
			continue
		end

		-- Check PvP rules
		if not isPvPAllowed(attacker, targetModel) then
			print(`PvP blocked: {attacker.Name} cannot attack {targetModel.Name}`)
			continue
		end

		-- Check invulnerability
		if checkInvulnerability(targetModel, weaponName) then
			print(`{targetModel.Name} is invulnerable to {weaponName}`)
			if not hitAny and targetModel == target then
				-- Return blocked result for primary target
				return {
					hit = false,
					target = targetModel,
					damage = nil,
					wasInRange = true,
					wasDodged = false,
					blockedByInvulnerability = true
				}
			end
			continue
		end

		-- Target is in range and not invulnerable - apply damage
		local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
		if targetHumanoid and targetHumanoid.Health > 0 then
			targetHumanoid:TakeDamage(weaponConfig.damage)

			-- Set invulnerability
			setInvulnerability(
				targetModel,
				weaponName,
				GameConfig.combat.invulnerabilityDuration or 0.5
			)

			-- Determine damage type for feedback
			local damageType: CombatFeedback.DamageType
			local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(targetModel)

			if targetPlayer then
				-- Damage to a player
				damageType = "incoming"
			else
				-- Damage to an NPC
				if attackingPlayer then
					damageType = "self"
				else
					damageType = "other_player"
				end
			end

			-- Show damage feedback
			CombatFeedback.showDamage(
				targetModel,
				weaponConfig.damage,
				weaponName,
				damageType,
				attackingPlayer
			)

			-- Play hit sound
			CombatFeedback.playHitSound(targetModel, "Hit")

			hitAny = true
			if not firstHit then
				firstHit = targetModel
			end
			totalDamage = totalDamage + weaponConfig.damage

			print(`*** {attacker.Name} hit {targetModel.Name} for {weaponConfig.damage} damage with {weaponName}`)
		end
	end

	if hitAny then
		return {
			hit = true,
			target = firstHit,
			damage = totalDamage,
			wasInRange = true,
			wasDodged = false,
			blockedByInvulnerability = false
		}
	else
		-- No hits - either out of range or all invulnerable
		return {
			hit = false,
			target = target,
			damage = nil,
			wasInRange = false,
			wasDodged = true,
			blockedByInvulnerability = false
		}
	end
end

-- Perform AOE attack (stub for Phase 2)
function CombatSystem.performAOEAttack(
	attacker: Model,
	targetPosition: vector,
	weaponName: string
): {AOEHitInfo}
	-- Phase 2 implementation
	warn("AOE attacks not yet implemented - Phase 2")
	return {}
end

-- Perform hitscan attack (stub for Phase 2)
function CombatSystem.performHitscan(
	origin: vector,
	direction: vector,
	weaponName: string,
	attacker: Model
): AttackResult
	-- Phase 2 implementation
	warn("Hitscan attacks not yet implemented - Phase 2")
	return {
		hit = false,
		target = nil,
		damage = nil,
		wasInRange = false,
		wasDodged = false,
		blockedByInvulnerability = false
	}
end

return CombatSystem