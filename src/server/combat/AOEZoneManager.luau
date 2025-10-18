--!strict

--[[
	AOEZoneManager - Persistent AOE Zone Management

	Manages persistent AOE zones that tick damage/healing over time.
	Examples: Poison Cloud, Healing Circle, Fire Zone

	Features:
	- Single update loop for all zones (efficient)
	- Auto-cleanup when zones expire
	- Tick-based damage/healing (configurable rate)
	- Visual effect persistence

	Integration:
	- Called by CombatSystem.performAOEAttack() when weapon has duration + tickRate
	- Auto-initializes on first zone creation
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Forward declare CombatSystem and StatsProvider (loaded on first use to avoid circular dependency)
local ServerScriptService = game:GetService("ServerScriptService")
local CombatSystem = nil
local StatsProvider = nil

export type AOEZone = {
	position: Vector3,
	radius: number,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	startTime: number,
	duration: number,
	tickRate: number,
	lastTickTime: number,
	visualEffect: Instance?,
}

local AOEZoneManager = {}

-- Active zones registry
local activeZones: {AOEZone} = {}
local isInitialized = false

--[[
	Get CombatSystem reference (lazy load to avoid circular dependency)

	@return CombatSystem module
]]
local function getCombatSystem()
	if not CombatSystem then
		CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
	end
	return CombatSystem
end

--[[
	Get StatsProvider reference (lazy load)

	@return StatsProvider module
]]
local function getStatsProvider()
	if not StatsProvider then
		StatsProvider = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("combat"):WaitForChild("StatsProvider"))
	end
	return StatsProvider
end

--[[
	Create visual effect for persistent zone

	@param position - Center of zone
	@param radius - Radius of zone
	@param weaponConfig - Weapon configuration
	@return Instance? - Visual effect instance
]]
local function createZoneVisual(position: Vector3, radius: number, weaponConfig: any): Instance?
	-- Try to load template
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		return nil
	end

	local effectsFolder = modelsFolder:FindFirstChild("Effects")
	if not effectsFolder then
		return nil
	end

	local aoeFolder = effectsFolder:FindFirstChild("AOE")
	if not aoeFolder then
		return nil
	end

	local template = aoeFolder:FindFirstChild("ZoneEffect")
	if not template or not template:IsA("Model") then
		-- Procedural fallback: Simple cylinder with particles
		local cylinder = Instance.new("Part")
		cylinder.Name = "ZoneEffect"
		cylinder.Shape = Enum.PartType.Cylinder
		cylinder.Size = Vector3.new(0.5, radius * 2, radius * 2)
		cylinder.Anchored = true
		cylinder.CanCollide = false
		cylinder.Transparency = 0.7
		cylinder.Material = Enum.Material.Neon

		-- Color based on damage type
		local damage = weaponConfig.aoeDamage or weaponConfig.damage or 0
		cylinder.Color = damage < 0 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)

		-- Position at ground level, rotate to lay flat
		local groundPosition = Vector3.new(position.X, position.Y + 0.25, position.Z)
		cylinder.CFrame = CFrame.new(groundPosition) * CFrame.Angles(0, 0, math.rad(90))
		cylinder.Parent = workspace

		return cylinder
	end

	-- Clone template
	local visual = template:Clone()
	visual:PivotTo(CFrame.new(position))
	visual.Parent = workspace

	return visual
end

--[[
	Tick a zone (apply damage/heal to entities inside)

	@param zone - Zone to tick
]]
local function tickZone(zone: AOEZone)
	local CS = getCombatSystem()
	local SP = getStatsProvider()
	local weaponConfig = CS.getWeaponConfig(zone.weaponName)
	if not weaponConfig then
		return
	end

	-- Get attacker stats ONCE for efficiency
	local attackerStats = SP.getStats(zone.attacker)

	-- Find entities in radius
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {zone.attacker}

	local parts = workspace:GetPartBoundsInRadius(zone.position, zone.radius, params)

	-- Find unique entities
	local hitEntities: {[Model]: boolean} = {}

	for _, part in parts do
		local entity = CS.findEntityFromPart(part)
		if entity and not hitEntities[entity] then
			hitEntities[entity] = true

			-- Get target stats (per target)
			local targetStats = SP.getStats(entity)

			-- Apply damage via applyDamageToEntity (respects all rules)
			local damage = weaponConfig.aoeDamage or weaponConfig.damage or 0

			CS.applyDamageToEntity(zone.attacker, entity, zone.weaponName, {
				damageOverride = damage,
				hitPosition = zone.position,
				bypassInvulnerability = false, -- Each tick respects invulnerability
				attackerStats = attackerStats, -- Reused attacker stats
				targetStats = targetStats, -- Per-target stats
			})
		end
	end

	-- Update last tick time
	zone.lastTickTime = tick()
end

--[[
	Update all active zones

	Called every frame by Heartbeat connection

	@param currentTime - Current time
]]
local function updateAllZones(currentTime: number)
	for i = #activeZones, 1, -1 do
		local zone = activeZones[i]

		-- Check if zone expired
		local elapsed = currentTime - zone.startTime
		if elapsed >= zone.duration then
			-- Destroy visual effect
			if zone.visualEffect and zone.visualEffect.Parent then
				zone.visualEffect:Destroy()
			end

			-- Remove from registry
			table.remove(activeZones, i)
			print(`AOEZone expired: {zone.weaponName}`)
			continue
		end

		-- Check if time to tick
		local timeSinceLastTick = currentTime - zone.lastTickTime
		if timeSinceLastTick >= zone.tickRate then
			tickZone(zone)
		end
	end
end

--[[
	Initialize the zone manager

	Auto-called on first zone creation
]]
local function initialize()
	if isInitialized then
		return
	end

	isInitialized = true

	-- Connect to Heartbeat for updates
	RunService.Heartbeat:Connect(function()
		updateAllZones(tick())
	end)

	print("AOEZoneManager initialized")
end

--[[
	Create a persistent AOE zone

	@param position - Center position of zone
	@param radius - Radius of zone
	@param weaponName - Name of weapon creating zone
	@param attacker - Entity that created zone
	@param attackingPlayer - Player if attacker is player character
	@param duration - How long zone lasts (seconds)
	@param tickRate - How often to tick damage (seconds)
	@return AOEZone - Created zone
]]
function AOEZoneManager.createZone(
	position: Vector3,
	radius: number,
	weaponName: string,
	attacker: Model,
	attackingPlayer: Player?,
	duration: number,
	tickRate: number
): AOEZone
	-- Auto-initialize on first use
	initialize()

	local CS = getCombatSystem()
	local weaponConfig = CS.getWeaponConfig(weaponName)

	-- Create visual effect
	local visual = createZoneVisual(position, radius, weaponConfig)

	-- Create zone
	local zone: AOEZone = {
		position = position,
		radius = radius,
		weaponName = weaponName,
		attacker = attacker,
		attackingPlayer = attackingPlayer,
		startTime = tick(),
		duration = duration,
		tickRate = tickRate,
		lastTickTime = tick(),
		visualEffect = visual,
	}

	-- Add to registry
	table.insert(activeZones, zone)

	-- Perform initial tick immediately
	tickZone(zone)

	print(`AOEZone created: {weaponName} at {position} (duration: {duration}s, tickRate: {tickRate}s)`)

	return zone
end

--[[
	Get count of active zones (for debugging)

	@return number - Count of active zones
]]
function AOEZoneManager.getActiveCount(): number
	return #activeZones
end

return AOEZoneManager
