--!strict
local Types = {}

-- local Stats = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("Stats"))
local Items = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("Items"))
local Entities = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("Entities"))
local DayNightCycleConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("DayNightCycleConfig"))

-- Export Stats types (centralized from Stats module)
-- export type Stats = Stats.Stats
-- export type DerivedStats = Stats.DerivedStats

-- Export Item types
export type ItemType = Items.ItemType
export type ItemData = Items.ItemData

-- Export Entity types
export type EntityType = Entities.EntityType
export type EntityData = Entities.EntityData

-- Re-export types from config modules
export type GamePhase = DayNightCycleConfig.GamePhase

-- Updated inventory to support all item types (not just resources)
export type PlayerInventory = {
	[string]: number -- itemId -> quantity
}

export type ResourceNode = {
	resourceType: string, -- itemId for resource (Wood, Stone, Metal, Gem)
	currentHits: number,
	maxHits: number,
	isActive: boolean,
	part: BasePart,
	stats: any,
	-- TODO: Add particle emitter and HP GUI when assets are ready
}

export type WildlifeEntity = {
	wildlifeType: string,
	model: Model,
	humanoid: Humanoid,
	health: number,
	maxHealth: number,
	isAggro: boolean,
	target: Player?,
	lastAttackTime: number,
}

export type CreatureEntity = {
	creatureType: string,
	model: Model,
	humanoid: Humanoid,
	health: number,
	maxHealth: number,
	target: BasePart?, -- Target warehouse or player
	lastAttackTime: number,
}

export type TeamResources = {
	Wood: number,
	Stone: number,
	Metal: number,
	Gem: number
}

export type TargetInfo = {
	model: Model,
	entityId: string,
	entityType: string,
	health: number,
	maxHealth: number,
	distance: number,
	state: string?,
	damage: number?,
	walkSpeed: number?,
	runSpeed: number?,
}

export type PlayerTarget = {
	player: Player,
	targetModel: Model?,
	lastUpdate: number,
}

export type MiningSession = {
	player: Player,
	resourceNode: ResourceNode,
	startPosition: Vector3,
	previousTool: string?, -- itemId for tool
	task: thread,
	cancelled: boolean,
}

return Types