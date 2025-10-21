--!strict

-- SERVER-ONLY: Actual NPC stats, AI behavior, drops
-- Client only sees display data from shared/Data/Entities/NPCs.luau

local NPCStats = {}

export type AIBehavior = {
	profile: string,
	behaviors: {
		idle: string,
		onDamaged: string,
		onPlayerNear: string,
	},
	targetPriority: { string }?,
	aggroRange: number?,
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

NPCStats.Stats = {
	TownGuard = {
		health = 150,
		walkSpeed = 10,
		runSpeed = 15,
		jumpCooldown = 3,
		canJump = true,
		canTakeDamage = true,

		primaryWeapon = "Sword",
		baseStats = {
			strength = 8,
			magic = 0,
			stamina = 5,
			accuracy = 5,
		},

		drops = {}, -- NPCs typically don't drop items

		ai = {
			profile = "defensive_npc",
			behaviors = {
				idle = "stand_guard",
				onDamaged = "retaliate_closest",
				onPlayerNear = "assist_ally",
			},
			targetPriority = { "Creature", "Wildlife", "Player" },
			aggroRange = 20,
			wanderRadius = 0, -- Stands at post
			returnToSpawn = true,
			returnSpeed = 1.0,
			retargetBehavior = "closest",
		},
	},
}

return NPCStats
