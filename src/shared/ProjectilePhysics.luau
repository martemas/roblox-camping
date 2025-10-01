--!strict

--[[
	ProjectilePhysics - Projectile Physics and Collision Logic

	Handles physics simulation, collision detection, and damage application for projectiles.
	All logic is server-authoritative.

	Part of the ProjectileManager system.
]]

local Players = game:GetService("Players")

local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local CombatFeedback = require(script.Parent:WaitForChild("CombatFeedback"))

type ProjectileInstance = CombatSystem.ProjectileInstance
type DamageMode = CombatSystem.DamageMode

local ProjectilePhysics = {}

--[[
	Add all entities except target to ignore list

	@param ignoreList - List to append to
	@param target - Target entity to NOT ignore
]]
local function addAllEntitiesExceptTarget(ignoreList: {Instance}, target: Model?)
	-- Add all player characters except target
	for _, player in Players:GetPlayers() do
		if player.Character and player.Character ~= target then
			table.insert(ignoreList, player.Character)
		end
	end

	-- Add all NPCs except target
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Humanoid") and descendant.Parent ~= target then
			local model = descendant.Parent
			if model and model:IsA("Model") then
				table.insert(ignoreList, model)
			end
		end
	end
end

--[[
	Build raycast parameters based on damage mode

	@param projectile - Projectile instance
	@return RaycastParams - Configured raycast parameters
]]
local function buildRaycastParams(projectile: ProjectileInstance): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local ignoreList: {Instance} = {projectile.attacker, projectile.model}

	if projectile.damageMode.damageTargetOnly then
		-- Ignore ALL entities except locked target
		addAllEntitiesExceptTarget(ignoreList, projectile.lockedTarget)
	else
		-- Only ignore already-hit entities (for penetration mode)
		for entity, _ in projectile.entitiesHit do
			table.insert(ignoreList, entity)
		end
	end

	params.FilterDescendantsInstances = ignoreList
	return params
end

--[[
	Find entity model from a part

	@param part - Part that was hit
	@return Model or nil
]]
local function findEntityFromPart(part: BasePart): Model?
	local current = part.Parent
	while current and current ~= workspace do
		if current:IsA("Model") then
			-- Check if it's a player character
			local player = Players:GetPlayerFromCharacter(current)
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

--[[
	Show impact effect at position (future enhancement)

	@param projectile - Projectile instance
	@param position - Impact position
]]
local function showImpactEffect(projectile: ProjectileInstance, position: Vector3)
	-- TODO: Spawn impact particle effect
	-- For now, just a placeholder
end

--[[
	Apply damage to an entity

	@param projectile - Projectile instance
	@param entity - Entity to damage
]]
local function applyDamage(projectile: ProjectileInstance, entity: Model)
	local humanoid = entity:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Check PvP rules
	if not CombatSystem.isPvPAllowed(projectile.attacker, entity) then
		print(`PvP blocked: {projectile.attacker.Name} cannot damage {entity.Name}`)
		return
	end

	-- Get weapon config for damage value
	local weaponConfig = CombatSystem.getWeaponConfig(projectile.weapon)
	if not weaponConfig then
		return
	end

	-- Apply damage
	humanoid:TakeDamage(weaponConfig.damage)

	-- Determine damage type for feedback
	local damageType: CombatFeedback.DamageType
	local entityPlayer = Players:GetPlayerFromCharacter(entity)

	if entityPlayer then
		-- Damage to a player
		damageType = "incoming"
	else
		-- Damage to an NPC
		if projectile.attackingPlayer then
			damageType = "self"
		else
			damageType = "other_player"
		end
	end

	-- Show damage feedback
	CombatFeedback.showDamage(
		entity,
		weaponConfig.damage,
		projectile.weapon,
		damageType,
		projectile.attackingPlayer
	)

	-- Notify entity it was damaged (for aggro/retargeting) - lazy load to avoid circular dependency
	if not entityPlayer then
		-- Only trigger for NPCs (wildlife/enemies)
		local EntityController = require(script.Parent:WaitForChild("EntityController"))
		EntityController.onEntityDamaged(entity, projectile.attacker)
	end

	print(`Projectile {projectile.weapon} hit {entity.Name} for {weaponConfig.damage} damage`)
end

--[[
	Handle entity collision

	@param projectile - Projectile instance
	@param entity - Entity that was hit
	@param raycastResult - Raycast result
	@return boolean - True if projectile should be destroyed
]]
local function handleEntityHit(
	projectile: ProjectileInstance,
	entity: Model,
	raycastResult: RaycastResult
): boolean
	-- Check if already hit this entity
	if projectile.entitiesHit[entity] then
		return false -- Already damaged, continue
	end

	-- Mark as hit
	projectile.entitiesHit[entity] = true

	-- Determine if should damage this entity
	local shouldDamage = false
	if projectile.damageMode.damageTargetOnly then
		-- Only damage if this is the locked target
		shouldDamage = (entity == projectile.lockedTarget)
	else
		-- Damage any entity hit
		shouldDamage = true
	end

	if shouldDamage then
		applyDamage(projectile, entity)
	end

	-- Check penetration
	if projectile.damageMode.penetratesEntities then
		-- Continue flying through entity
		return false
	else
		-- Stop at first entity hit
		print(`Projectile {projectile.weapon} hit entity {entity.Name}, stopping`)
		showImpactEffect(projectile, raycastResult.Position)
		return true
	end
end

--[[
	Handle raycast hit

	@param projectile - Projectile instance
	@param raycastResult - Raycast result
	@return boolean - True if projectile should be destroyed
]]
local function handleRaycastHit(
	projectile: ProjectileInstance,
	raycastResult: RaycastResult
): boolean
	-- Find entity from hit part
	local hitEntity = findEntityFromPart(raycastResult.Instance)

	if hitEntity then
		-- Hit an entity
		return handleEntityHit(projectile, hitEntity, raycastResult)
	else
		-- Hit terrain/structure - always destroy
		print(`Projectile {projectile.weapon} hit terrain/structure`)
		showImpactEffect(projectile, raycastResult.Position)
		return true
	end
end

--[[
	Update projectile physics for one frame

	@param projectile - Projectile to update
	@param deltaTime - Time since last frame
	@return boolean - True if projectile should be destroyed
]]
function ProjectilePhysics.updateProjectile(
	projectile: ProjectileInstance,
	deltaTime: number
): boolean
	-- Calculate movement
	local movement = projectile.direction * (projectile.speed * deltaTime)
	local currentPos = projectile.lastPosition
	local newPos = currentPos + movement

	-- Setup raycast parameters
	local raycastParams = buildRaycastParams(projectile)

	-- Perform raycast from last position to new position (prevents tunneling)
	local raycastResult = workspace:Raycast(currentPos, movement, raycastParams)

	if raycastResult then
		-- Hit something
		return handleRaycastHit(projectile, raycastResult)
	end

	-- No hit - update position
	if projectile.model.PrimaryPart then
		projectile.model:PivotTo(CFrame.new(newPos, newPos + projectile.direction))
	end

	projectile.lastPosition = newPos
	projectile.distanceTraveled = projectile.distanceTraveled + movement.Magnitude

	-- Check if projectile passed the target without hitting (for targeted projectiles)
	if projectile.lockedTarget and projectile.damageMode.damageTargetOnly then
		local targetRoot = projectile.lockedTarget:FindFirstChild("HumanoidRootPart")
			or projectile.lockedTarget:FindFirstChild("Torso")

		if targetRoot and targetRoot:IsA("BasePart") then
			local targetPos = targetRoot.Position
			local toTarget = targetPos - newPos

			-- If dot product is negative, we've passed the target
			local dotProduct = toTarget:Dot(projectile.direction)
			if dotProduct < 0 then
				print(`Projectile {projectile.weapon} missed target {projectile.lockedTarget.Name}`)
				return true -- Destroy (missed)
			end
		end
	end

	-- Check max range
	if projectile.distanceTraveled >= projectile.maxRange then
		print(`Projectile {projectile.weapon} reached max range`)
		return true -- Destroy
	end

	return false -- Keep alive
end

return ProjectilePhysics
