--!strict

-- SERVER-ONLY: Actual creature stats, AI behavior, drops
-- Client only sees display data from shared/Data/Entities/Creatures.luau

local CreatureStats = {}

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

CreatureStats.Stats = {
	Zombie = {
		health = 50,
		walkSpeed = 8,
		runSpeed = 12,
		jumpCooldown = 4,
		canJump = false,
		canTakeDamage = true,

		spawnWeight = 1,

		primaryWeapon = "ZombieBite",
		baseStats = {
			strength = 4,
			magic = 0,
			stamina = 3,
			accuracy = 3,
		},

		drops = {
			RottenMeat = {
				chance = 1.0, -- 100% chance
				min = 1,
				max = 1,
			},
		},

		ai = {
			profile = "aggressive_creature",
			behaviors = {
				idle = "seek_target",
				onDamaged = "ignore",
				onPlayerNear = "chase",
			},
			targetPriority = { "Player", "Structure" },
			aggroRange = 25,
			seekRange = 100,
			wanderRadius = 20,
			returnToSpawn = false,
			retargetBehavior = "priority",
		},
	},
}

return CreatureStats
