--!strict

-- ENGINE: Entity type definitions ONLY (no dependencies, no circular refs)
-- This module is safe to require from anywhere without causing circular dependencies

export type AIBehavior = {
	profile: string,
	behaviors: {
		idle: string,
		onDamaged: string,
		onPlayerNear: string,
	},
	targetPriority: { string }?,
	aggroRange: number?,
	seekRange: number?,
	wanderRadius: number?,
	returnToSpawn: boolean?,
	returnSpeed: number?,
	retargetBehavior: string?,
}

export type DropConfig = {
	chance: number,
	min: number,
	max: number,
	chanceModifiers: { [string]: number }?,
	maxChance: number?,
	excludeIf: { string }?,
	requireIf: { string }?,
}

export type CreatureStats = {
	-- Health & Movement
	health: number,
	walkSpeed: number,
	runSpeed: number,
	jumpCooldown: number?,
	canJump: boolean?,
	canTakeDamage: boolean?,

	-- Spawning
	spawnWeight: number?, -- Relative spawn chance (for wave/night spawning)

	-- Combat
	primaryWeapon: string, -- Reference to Weapons (e.g., "ZombieBite")
	baseStats: {
		strength: number,
		magic: number,
		stamina: number,
		accuracy: number,
	},

	-- Drops (reference item IDs from Items.Database)
	drops: { [string]: DropConfig }?,

	-- AI Behavior
	ai: AIBehavior?,
}

export type NPCStats = {
	-- Health & Movement
	health: number,
	walkSpeed: number,
	runSpeed: number,
	jumpCooldown: number?,
	canJump: boolean?,
	canTakeDamage: boolean?,

	-- Combat
	primaryWeapon: string, -- Reference to Weapons (e.g., "Sword")
	baseStats: {
		strength: number,
		magic: number,
		stamina: number,
		accuracy: number,
	},

	-- Drops (reference item IDs from Items.Database)
	-- Usually empty for NPCs, but can drop items on death
	drops: { [string]: DropConfig }?,

	-- AI Behavior
	ai: AIBehavior?,
}

export type ResourceStats = {
	-- Health
	health: number,
	canTakeDamage: boolean?,
	nodesCount: number?, -- Number of times this resource can be harvested before depletion

	-- Harvesting
	requiredToolCategory: string?, -- Tool category required (e.g., "Axe", "Pickaxe")
	hitsRequired: number?,
	miningDuration: number?, -- Base time to harvest (modified by tool stats)

	-- Drops (reference item IDs from Items.Database)
	drops: { [string]: DropConfig },
}

export type StructureStats = {
	-- Health & Defense
	health: number,
	armor: number?,
	canTakeDamage: boolean?,

	-- Building
	buildCost: { [string]: number }?, -- Item costs (reference Items.Database)
	buildTime: number?, -- Seconds to construct

	-- Production (for production structures)
	production: {
		itemId: string, -- Reference to Items.Database
		quantity: number,
		time: number, -- Seconds per production cycle
	}?,

	-- Storage (for storage structures)
	capacity: number?,

	-- Combat (for defensive structures)
	attackRange: number?,
	attackCooldown: number?,
	damage: number?,
	projectileType: string?,
	projectileSpeed: number?,
	projectileArc: number?,
	targetType: string?, -- "Ground" | "Air" | "Both"
	weaponRef: string?, -- Reference to weapon system

	-- Healing/Repair (for support structures)
	healRate: number?,
	repairRate: number?,

	-- Buffs/Effects (for buff structures)
	effectRadius: number?,
	effectStrength: number?,
	effectDuration: number?,
}

export type WildlifeStats = {
	-- Health & Movement
	health: number,
	walkSpeed: number,
	runSpeed: number,
	jumpCooldown: number?,
	canJump: boolean?,
	canTakeDamage: boolean?,

	-- Combat
	primaryWeapon: string, -- Reference to Weapons (e.g., "WolfClaw" from Items/Weapons)
	baseStats: {
		strength: number,
		magic: number,
		stamina: number,
		accuracy: number,
	},

	-- Drops (reference item IDs from Items.Database)
	drops: { [string]: DropConfig }?,

	-- AI Behavior
	ai: AIBehavior?,
}

return {}
