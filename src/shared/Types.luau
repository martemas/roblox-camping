--!strict

local Stats = require(script.Parent:WaitForChild("Stats"))

-- Export Stats types (centralized from Stats module)
export type Stats = Stats.Stats
export type DerivedStats = Stats.DerivedStats

export type EntityCategory = "resource" | "building" | "wildlife" | "creature" | "npc" | "player"

export type ResourceType = "Wood" | "Stone" | "Metal" | "Rock" | "Gem"

export type ToolType = "BasicAxe" | "SteelAxe" | "BasicPickaxe" | "SilverPickaxe" | "GoldenPickaxe" | "Bow" | "MagicMissile" | "Fireball"

export type WildlifeType = "Wolf" | "Bear"

export type CreatureType = "Zombie"

export type GamePhase = "Day" | "Night" | "Transition"

export type PlayerInventory = {
	[ResourceType]: number
}

export type ResourceNode = {
	resourceType: ResourceType,
	currentHits: number,
	maxHits: number,
	isActive: boolean,
	part: BasePart,
	-- TODO: Add particle emitter and HP GUI when assets are ready
}

export type WildlifeEntity = {
	wildlifeType: WildlifeType,
	model: Model,
	humanoid: Humanoid,
	health: number,
	maxHealth: number,
	isAggro: boolean,
	target: Player?,
	lastAttackTime: number,
}

export type CreatureEntity = {
	creatureType: CreatureType,
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
	previousTool: ToolType?,
	task: thread,
	cancelled: boolean,
}

return {}