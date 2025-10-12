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
local DamageCalculator = require(script.Parent:WaitForChild("DamageCalculator"))
local StatsProvider = require(script.Parent:WaitForChild("StatsProvider"))

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
	Show impact effect at position

	@param projectile - Projectile instance
	@param position - Impact position
]]
local function showImpactEffect(projectile: ProjectileInstance, position: Vector3)
	local weaponConfig = CombatSystem.getWeaponConfig(projectile.weapon)
	if not weaponConfig then
		return
	end

	-- For AOE projectiles, show explosion visual
	if weaponConfig.aoeOnImpact then
		-- Create explosion sphere
		local explosion = Instance.new("Part")
		explosion.Shape = Enum.PartType.Ball
		explosion.Size = Vector3.new(weaponConfig.aoeRadius or 10, weaponConfig.aoeRadius or 10, weaponConfig.aoeRadius or 10)
		explosion.Position = position
		explosion.Anchored = true
		explosion.CanCollide = false
		explosion.Material = Enum.Material.Neon
		explosion.Color = Color3.fromRGB(255, 150, 50) -- Orange explosion
		explosion.Transparency = 0.3
		explosion.Parent = workspace

		-- Animate explosion (expand and fade)
		local initialSize = explosion.Size * 0.3
		local finalSize = explosion.Size * 2 -- Calculate target size once
		explosion.Size = initialSize

		task.spawn(function()
			local startTime = tick()
			local duration = 0.3

			while tick() - startTime < duration do
				local progress = (tick() - startTime) / duration
				explosion.Size = initialSize:Lerp(finalSize, progress)
				explosion.Transparency = 0.3 + (progress * 0.7) -- Fade to 1.0
				task.wait()
			end

			explosion:Destroy()
		end)

		-- Also show AOE radius circle briefly
		local AOETelegraph = require(script.Parent:WaitForChild("AOETelegraph"))
		local circle = AOETelegraph.showCircleTelegraph(
			position,
			weaponConfig.aoeRadius or 10,
			0.5, -- Show for 0.5 seconds
			"damage"
		)
	end

	-- TODO: Add more impact effects (particles, sounds, etc.)
end

--[[
	Apply damage to an entity

	@param projectile - Projectile instance
	@param entity - Entity to damage
	@param hitPart - The specific body part that was hit
]]
local function applyDamage(projectile: ProjectileInstance, entity: Model, hitPart: BasePart?)
	-- Get stats for damage calculation
	local attackerStats = StatsProvider.getStats(projectile.attacker)
	local targetStats = StatsProvider.getStats(entity)

	-- Use centralized damage system which handles:
	-- - PvP rules
	-- - Damage calculation
	-- - XP tracking
	-- - Feedback
	-- - Entity aggro
	CombatSystem.applyDamageToEntity(projectile.attacker, entity, projectile.weapon, {
		hitPart = hitPart,
		attackingPlayer = projectile.attackingPlayer,
		attackerStats = attackerStats,
		targetStats = targetStats,
	})
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
		applyDamage(projectile, entity, raycastResult.Instance)
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
	-- Check for AOE on impact (before handling normal collision)
	local weaponConfig = CombatSystem.getWeaponConfig(projectile.weapon)
	if weaponConfig and weaponConfig.aoeOnImpact then
		-- Get attacker stats once for AOE
		local attackerStats = StatsProvider.getStats(projectile.attacker)

		-- Trigger AOE at impact position
		local hits = CombatSystem.performAOEAttack(
			projectile.attacker,
			raycastResult.Position,
			projectile.weapon,
			projectile.attackingPlayer,
			{
				damageOverride = weaponConfig.aoeDamage,
				radius = weaponConfig.aoeRadius,
				falloff = weaponConfig.aoeFalloff,
				maxTargets = weaponConfig.maxTargets,
				attackerStats = attackerStats,
			}
		)

		print(`Projectile AOE {projectile.weapon} hit {#hits} entities at {raycastResult.Position}`)

		-- Always destroy projectile after AOE explosion
		showImpactEffect(projectile, raycastResult.Position)
		return true
	end

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

		-- Trigger AOE at final position if configured
		local weaponConfig = CombatSystem.getWeaponConfig(projectile.weapon)
		if weaponConfig and weaponConfig.aoeOnImpact then
			-- Get attacker stats once for AOE
			local attackerStats = StatsProvider.getStats(projectile.attacker)

			local hits = CombatSystem.performAOEAttack(
				projectile.attacker,
				projectile.lastPosition,
				projectile.weapon,
				projectile.attackingPlayer,
				{
					damageOverride = weaponConfig.aoeDamage,
					radius = weaponConfig.aoeRadius,
					falloff = weaponConfig.aoeFalloff,
					maxTargets = weaponConfig.maxTargets,
					attackerStats = attackerStats,
				}
			)

			print(`Projectile AOE {projectile.weapon} hit {#hits} entities at max range`)
			showImpactEffect(projectile, projectile.lastPosition)
		end

		return true -- Destroy
	end

	return false -- Keep alive
end

return ProjectilePhysics
