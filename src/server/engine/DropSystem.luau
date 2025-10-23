--!strict

--[[
	DropSystem - Stateless drop resolution and spawning system

	Generic system that handles drops from any source:
	- Entity deaths (bears, wolves, zombies)
	- Treasure chests
	- Resource harvesting (trees → logs)
	- Quest rewards
	- Any other drop source

	Usage:
		local drops = DropSystem.resolveDrops(dropConfig, killerStats)
		DropSystem.spawnDrops(drops, position)

	Or combined:
		DropSystem.processDrops(dropConfig, killerStats, position)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local Engine = ServerScriptService:WaitForChild("Engine")
local EngineShared = ReplicatedStorage:WaitForChild("Engine")

local GameConfig = require(Engine.Config.GameConfig)
local Items = require(ReplicatedStorage:WaitForChild("Games"):WaitForChild("Data"):WaitForChild("Items"))

-- Types
export type DropItemConfig = {
	chance: number, -- Base chance (0.0 to 1.0)
	min: number, -- Minimum quantity
	max: number, -- Maximum quantity
	chanceModifiers: { [string]: number }?, -- Stat modifiers (e.g., {luck = 0.01})
	maxChance: number?, -- Cap on final chance (prevents over-stacking)
	excludeIf: { string }?, -- Don't drop if these items already dropped
	requireIf: { string }?, -- Only drop if these items already dropped
}

export type DropConfig = {
	[string]: DropItemConfig -- Item ID → config
}

export type ResolvedDrop = {
	itemId: string,
	quantity: number,
}

export type StatsTable = {
	[string]: number -- Stat name → value
}

local DropSystem = {}

--[[
	Search for item model in ReplicatedStorage using Items database
	@param itemId - Item identifier (e.g., "BigMeat", "Sword")
	@return Model or nil if not found
]]
local function findItemModel(itemId: string): Model?
	-- Get item data from Items database
	local itemData = Items.Database[itemId]
	if not itemData then
		warn(`[DropSystem] Unknown item: {itemId}`)
		return nil
	end

	if not itemData.dropModel then
		warn(`[DropSystem] No drop model defined for item: {itemId}`)
		return nil
	end

	local modelsFolder = ServerStorage:FindFirstChild("Assets")
	if not modelsFolder then
		warn("[DropSystem] Models folder not found in ReplicatedStorage")
		return nil
	end

	-- Use path from Items database (e.g., "Items/Wood" or "Weapons/Sword")
	local modelPath = itemData.dropModel
	local pathParts = string.split(modelPath, "/")

	local current = modelsFolder
	for _, part in pathParts do
		local child = current:FindFirstChild(part)
		if not child then
			warn(`[DropSystem] Model not found at path: {modelPath}`)
			return nil
		end
		current = child
	end

	if not current:IsA("Model") then
		warn(`[DropSystem] Path does not point to a Model: {modelPath}`)
		return nil
	end

	return current
end

--[[
	Calculate final drop chance with stat modifiers and cap
	@param baseChance - Base drop chance (0.0 to 1.0)
	@param statsTable - Table of killer stats {luck = 5, ...}
	@param modifiers - Stat modifiers {luck = 0.01 means +1% per luck point}
	@param maxChance - Optional cap on final chance
	@return Final calculated chance (0.0 to 1.0)
]]
local function calculateDropChance(
	baseChance: number,
	statsTable: StatsTable?,
	modifiers: { [string]: number }?,
	maxChance: number?
): number
	local finalChance = baseChance

	-- Apply stat modifiers
	if modifiers and statsTable then
		for statName, multiplier in modifiers do
			local statValue = statsTable[statName] or 0
			finalChance = finalChance + (statValue * multiplier)
		end
	end

	-- Apply cap if specified
	if maxChance then
		finalChance = math.min(finalChance, maxChance)
	end

	-- Clamp to valid range
	return math.clamp(finalChance, 0, 1)
end

--[[
	Roll RNG to determine if drop succeeds
	@param chance - Drop chance (0.0 to 1.0)
	@return True if drop succeeds
]]
local function rollForDrop(chance: number): boolean
	return math.random() <= chance
end

--[[
	Determine random quantity between min and max
	@param min - Minimum quantity
	@param max - Maximum quantity
	@return Random quantity
]]
local function determineQuantity(min: number, max: number): number
	if min == max then
		return min
	end
	return math.random(min, max)
end

--[[
	Check if item should be excluded based on already-dropped items
	@param itemConfig - Item configuration
	@param droppedItems - Set of already-dropped item IDs
	@return True if item should be excluded
]]
local function shouldExcludeItem(itemConfig: DropItemConfig, droppedItems: { [string]: boolean }): boolean
	if not itemConfig.excludeIf then
		return false
	end

	-- Check if any excluded items have already dropped
	for _, excludedItemId in itemConfig.excludeIf do
		if droppedItems[excludedItemId] then
			return true
		end
	end

	return false
end

--[[
	Check if item's requirements are met based on already-dropped items
	@param itemConfig - Item configuration
	@param droppedItems - Set of already-dropped item IDs
	@return True if requirements are met
]]
local function meetsRequirements(itemConfig: DropItemConfig, droppedItems: { [string]: boolean }): boolean
	if not itemConfig.requireIf then
		return true -- No requirements, always meets
	end

	-- Check if all required items have already dropped
	for _, requiredItemId in itemConfig.requireIf do
		if not droppedItems[requiredItemId] then
			return false
		end
	end

	return true
end

--[[
	Resolve drops from configuration with stat modifiers and conditional logic
	@param dropConfig - Drop configuration table
	@param statsTable - Optional killer/opener stats table
	@return Array of resolved drops {itemId, quantity}[]
]]
function DropSystem.resolveDrops(dropConfig: DropConfig, statsTable: StatsTable?): { ResolvedDrop }
	local resolvedDrops: { ResolvedDrop } = {}
	local droppedItems: { [string]: boolean } = {} -- Track what's been dropped for excludeIf/requireIf

	-- Convert to array and sort by drop chance (highest first) to ensure consistent processing order
	-- This ensures guaranteed drops (chance=1.0) are processed before conditional drops
	local sortedDrops: { { itemId: string, config: DropItemConfig } } = {}
	for itemId, itemConfig in dropConfig do
		table.insert(sortedDrops, { itemId = itemId, config = itemConfig })
	end
	table.sort(sortedDrops, function(a, b)
		return a.config.chance > b.config.chance
	end)

	-- Process each potential drop in sorted order
	for _, dropEntry in sortedDrops do
		local itemId = dropEntry.itemId
		local itemConfig = dropEntry.config

		-- Check exclusions first
		if shouldExcludeItem(itemConfig, droppedItems) then
			continue
		end

		-- Check requirements
		if not meetsRequirements(itemConfig, droppedItems) then
			continue
		end

		-- Calculate final chance with stat modifiers
		local finalChance = calculateDropChance(
			itemConfig.chance,
			statsTable,
			itemConfig.chanceModifiers,
			itemConfig.maxChance
		)

		-- Roll for drop
		if rollForDrop(finalChance) then
			local quantity = determineQuantity(itemConfig.min, itemConfig.max)

			table.insert(resolvedDrops, {
				itemId = itemId,
				quantity = quantity,
			})

			-- Mark as dropped for conditional logic
			droppedItems[itemId] = true
		end
	end

	return resolvedDrops
end

--[[
	Spawn scattered drops in the world (Mode 1: Scatter)
	Each quantity spawns as a separate model (no stacking)
	@param drops - Array of resolved drops
	@param position - World position to spawn drops
	@param scatterRadius - Optional radius to scatter drops (uses GameConfig default)
]]
function DropSystem.spawnScatteredDrops(drops: { ResolvedDrop }, position: Vector3, scatterRadius: number?)
	local radius = scatterRadius or GameConfig.drops.scatterRadius or 5
	local despawnTime = GameConfig.drops.despawnTime or 300

	-- Get or create DroppedItems folder in workspace
	local droppedItemsFolder = workspace:FindFirstChild("DroppedItems")
	if not droppedItemsFolder then
		droppedItemsFolder = Instance.new("Folder")
		droppedItemsFolder.Name = "DroppedItems"
		droppedItemsFolder.Parent = workspace
	end

	for _, drop in drops do
		-- Find item model template
		local itemTemplate = findItemModel(drop.itemId)
		if not itemTemplate then
			continue
		end

		-- Spawn drop.quantity individual models (no stacking)
		for i = 1, drop.quantity do
			-- Clone the model
			local itemModel = itemTemplate:Clone()

			-- Set CollisionGroup
			for _, descendant in itemModel:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.CollisionGroup = "Items"
				end
			end

			-- Calculate scatter position
			local angle = math.random() * math.pi * 2
			local distance = math.random() * radius
			local offset = vector.create(
				math.cos(angle) * distance,
				3, -- Spawn above ground
				math.sin(angle) * distance
			)
			local spawnPosition = position + offset

			-- Position the model
			if itemModel.PrimaryPart then
				itemModel:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
			else
				itemModel:MoveTo(spawnPosition)
			end

			-- Add attributes for pickup system
			itemModel:SetAttribute("IsDroppedItem", true)
			itemModel:SetAttribute("ItemId", drop.itemId)
			itemModel:SetAttribute("SpawnTime", workspace:GetServerTimeNow())
			itemModel:SetAttribute("DespawnTime", despawnTime)

			-- Add Highlight instance for client-side selection
			local highlight = Instance.new("Highlight")
			highlight.Name = "PickupHighlight"
			highlight.FillColor = Color3.fromRGB(255, 220, 100) -- Golden
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0.7
			highlight.OutlineTransparency = 0.5
			highlight.Enabled = false -- Client will enable for nearest item
			highlight.Parent = itemModel

			-- Parent to workspace
			itemModel.Parent = droppedItemsFolder

			-- Schedule auto-despawn
			task.delay(despawnTime, function()
				if itemModel and itemModel.Parent then
					itemModel:Destroy()
				end
			end)

			print(`[DropSystem] Spawned {drop.itemId} at {spawnPosition}`)
		end
	end
end

--[[
	Create loot container (Mode 2: Container) - PLACEHOLDER
	@param drops - Resolved drops
	@param containerModel - Entity corpse/container model
	@param statsTable - Killer stats (locked in)
]]
function DropSystem.createLootContainer(
	drops: { ResolvedDrop },
	containerModel: Model,
	statsTable: StatsTable?
)
	-- TODO: Implement container mode (see docs/DROP_CONTAINER_MODE_PLAN.md)
	-- 1. Store drops in container attributes (JSON encoded)
	-- 2. Add ProximityPrompt to container
	-- 3. Each player gets their own loot instance
	-- 4. Auto-despawn after configurable time

	warn("[DropSystem] Container mode not yet implemented - falling back to scatter mode")

	-- Placeholder: Just scatter for now
	local position = containerModel:GetPivot().Position
	DropSystem.spawnScatteredDrops(drops, position)
end

--[[
	Legacy method for backward compatibility
	@deprecated Use spawnScatteredDrops() instead
]]
function DropSystem.spawnDrops(drops: { ResolvedDrop }, position: Vector3, scatterRadius: number?)
	DropSystem.spawnScatteredDrops(drops, position, scatterRadius)
end

--[[
	Convenience method: Resolve and spawn drops based on GameSettings mode
	@param dropConfig - Drop configuration table
	@param statsTable - Optional killer/opener stats table
	@param position - World position to spawn drops
	@param scatterRadius - Optional radius override
	@param containerModel - Optional container model (for container mode)
	@return Array of resolved drops (for logging/debugging)
]]
function DropSystem.processDrops(
	dropConfig: DropConfig,
	statsTable: StatsTable?,
	position: Vector3,
	scatterRadius: number?,
	containerModel: Model?
): { ResolvedDrop }
	local drops = DropSystem.resolveDrops(dropConfig, statsTable)

	-- Check global drop mode from GameSettings
	local dropMode = GameConfig.drops.mode or "scatter"

	if dropMode == "scatter" then
		DropSystem.spawnScatteredDrops(drops, position, scatterRadius)
	elseif dropMode == "container" then
		if containerModel then
			DropSystem.createLootContainer(drops, containerModel, statsTable)
		else
			warn("[DropSystem] Container mode requires containerModel parameter - falling back to scatter")
			DropSystem.spawnScatteredDrops(drops, position, scatterRadius)
		end
	else
		warn(`[DropSystem] Unknown drop mode: {dropMode} - falling back to scatter`)
		DropSystem.spawnScatteredDrops(drops, position, scatterRadius)
	end

	return drops
end

return DropSystem
