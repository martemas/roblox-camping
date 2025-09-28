--!strict

export type ResourceType = "Wood" | "Stone" | "Metal"

export type ToolType = "Axe" | "Pickaxe"

export type WildlifeType = "Wolf" | "Bear"

export type EnemyType = "Zombie"

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

export type EnemyEntity = {
	enemyType: EnemyType,
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

return {}