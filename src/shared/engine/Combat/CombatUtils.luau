--!strict

--[[
	CombatUtils - Client-Safe Combat Utilities

	Provides utility functions that can safely run on the client for UI/visual feedback.
	Does NOT contain any sensitive combat logic or weapon stats.

	Used by:
	- TargetHUD (client) - for attack readiness indicators
	- Other client-side combat UI systems

	Security:
	- Only reads public game state (equipped tools, character positions)
	- No access to weapon stats or damage values
	- All calculations are cosmetic - server validates actual combat
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("Games"):WaitForChild("Data"):WaitForChild("Items"):WaitForChild("Items"))
local GameConfig = require(script.Parent.Parent:WaitForChild("Config"))

local CombatUtils = {}

-- Get player's equipped weapon name (from tool)
-- Returns weapon name for UI purposes only
function CombatUtils.getPlayerWeapon(player: Player): string?
	local character = player.Character
	if not character then
		return nil
	end

	-- Check for any equipped tool in character
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local toolName = child.Name
			-- Check Items database for weapon reference
			local itemData = Items.Database[toolName]
			if itemData and itemData.weaponData then
				-- Item has weapon data (e.g., BasicAxe → Axe)
				return itemData.weaponData
			else
				-- Pure weapon (e.g., Bow → Bow)
				return toolName
			end
		end
	end

	return nil
end

-- Check if attacker is facing target (within configured angle)
-- Pure geometry calculation - safe for client-side UI feedback
function CombatUtils.isFacingTarget(
	attackerRoot: BasePart,
	targetRoot: BasePart,
	customAngleDegrees: number?
): boolean
	if not GameConfig.combat.requireFacingForDamage then
		return true -- Always allow damage if directional check is disabled
	end

	-- Get attacker's look vector (direction they're facing)
	local attackerLookVector = attackerRoot.CFrame.LookVector

	-- Get direction from attacker to target
	local directionToTarget = (targetRoot.Position - attackerRoot.Position).Unit

	-- Calculate dot product to determine angle
	local dotProduct = attackerLookVector:Dot(directionToTarget)

	-- Use custom angle if provided, otherwise use global config
	local angleDegrees = customAngleDegrees or GameConfig.combat.facingAngleDegrees or 180

	-- Convert configured angle to threshold
	-- facingAngleDegrees of 120° = 60° on each side of center = cos(60°) = 0.5
	local angleThreshold = math.cos(math.rad(angleDegrees / 2))

	-- If dot product >= threshold, attacker is facing target
	return dotProduct >= angleThreshold
end

-- Find entity model from a part (includes player characters and NPCs)
-- Used for target detection in UI systems
function CombatUtils.findEntityFromPart(part: BasePart): Model?
	local current = part.Parent
	while current and current ~= workspace do
		if current:IsA("Model") then
			-- Check if it's a player character
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return current
			end

			-- Check if it's an NPC with EntityId attribute
			local entityId = current:GetAttribute("EntityId")
			if entityId then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

return CombatUtils
