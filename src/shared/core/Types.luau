--!strict
local Types = {}

local Stats = require(script.Parent.Parent:WaitForChild("combat"):WaitForChild("Stats"))

local ResourcesConfig = require(script.Parent.Parent:WaitForChild("config"):WaitForChild("ResourcesConfig"))
local EntityConfig = require(script.Parent.Parent:WaitForChild("config"):WaitForChild("EntitiesConfig"))
local ToolsConfig = require(script.Parent.Parent:WaitForChild("config"):WaitForChild("ToolsConfig"))
local DayNightCycleConfig = require(script.Parent.Parent:WaitForChild("config"):WaitForChild("DayNightCycleConfig"))

-- Export Stats types (centralized from Stats module)
export type Stats = Stats.Stats
export type DerivedStats = Stats.DerivedStats

-- Re-export types from config modules
export type Tool = ToolsConfig.Tool
export type Category = EntityConfig.Category
export type StructureType = EntityConfig.StructureType
export type GamePhase = DayNightCycleConfig.GamePhase

export type PlayerInventory = {
	[ResourcesConfig.ResourceType]: number
}

export type ResourceNode = {
	resourceType: ResourcesConfig.ResourceType,
	currentHits: number,
	maxHits: number,
	isActive: boolean,
	part: BasePart,
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
	entityType: string,
	entityCategory: string,
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
	previousTool: Tool?,
	task: thread,
	cancelled: boolean,
}

return Types