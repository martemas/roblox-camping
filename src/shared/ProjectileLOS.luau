--!strict

--[[
	ProjectileLOS - Projectile Line of Sight Validation

	Provides server-authoritative line-of-sight validation for projectile weapons.
	Used by both player and AI entities to determine if a clear shot exists.

	Security: All validation happens server-side. Client cannot manipulate results.
]]

local ProjectileLOS = {}

-- Type Definitions
export type LOSResult = {
	hasLineOfSight: boolean,
	blockedBy: Instance?,
	blockedPosition: vector?,
}

--[[
	Validate clear path from origin to target position

	Filters out all entities (players, NPCs) and only checks for physical obstacles:
	- Structures (walls, buildings)
	- Resources (trees, rocks)
	- Terrain

	@param origin - Starting position of raycast (weapon origin)
	@param targetPosition - End position of raycast (target location)
	@param attacker - The entity performing the attack (excluded from raycast)
	@return LOSResult - Contains whether path is clear and what blocked it
]]
function ProjectileLOS.validatePath(
	origin: vector,
	targetPosition: vector,
	attacker: Model
): LOSResult
	-- Setup raycast parameters
	local raycastParams = RaycastParams.new()
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
		return {
			hasLineOfSight = false,
			blockedBy = raycastResult.Instance,
			blockedPosition = raycastResult.Position,
		}
	end

	-- Clear path
	return {
		hasLineOfSight = true,
		blockedBy = nil,
		blockedPosition = nil,
	}
end

--[[
	Check if entity has clear shot to target entity

	Convenience function for AI and targeting systems.
	Automatically extracts positions from entity models.

	@param sourceEntity - The attacking entity (Model with HumanoidRootPart)
	@param targetEntity - The target entity (Model with HumanoidRootPart)
	@return LOSResult - Contains whether entities have clear line of sight
]]
function ProjectileLOS.canTargetEntity(
	sourceEntity: Model,
	targetEntity: Model
): LOSResult
	local sourceRoot = sourceEntity:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = targetEntity:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not sourceRoot or not targetRoot then
		-- Invalid entities, return blocked
		return {
			hasLineOfSight = false,
			blockedBy = nil,
			blockedPosition = nil,
		}
	end

	-- Shoot from slightly elevated position (chest height)
	-- This prevents ground-level obstacles from blocking unnecessarily
	local origin = sourceRoot.Position + vector.create(0, 1, 0)
	local targetPos = targetRoot.Position + vector.create(0, 1, 0)

	return ProjectileLOS.validatePath(origin, targetPos, sourceEntity)
end

return ProjectileLOS
