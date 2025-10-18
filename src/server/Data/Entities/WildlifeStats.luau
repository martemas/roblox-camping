--!strict

-- SERVER-ONLY: Actual wildlife stats, AI behavior, drops
-- Client only sees display data from shared/Data/Entities/Wildlife.luau

local WildlifeStats = {}

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

WildlifeStats.Stats = {
	Wolf = {
		health = 60,
		walkSpeed = 12,
		runSpeed = 22,
		jumpCooldown = 3,
		canJump = true,
		canTakeDamage = true,

		primaryWeapon = "WolfClaw",
		baseStats = {
			strength = 3,
			magic = 0,
			stamina = 2,
			accuracy = 6,
		},

		drops = {
			SmallMeat = {
				chance = 1.0, -- 100% chance
				min = 1,
				max = 1,
			},
		},

		ai = {
			profile = "aggressive_wildlife",
			behaviors = {
				idle = "wander",
				onDamaged = "retaliate_closest",
				onPlayerNear = "chase",
			},
			targetPriority = { "Player" },
			aggroRange = 30,
			wanderRadius = 30,
			returnToSpawn = true,
			returnSpeed = 0.5,
			retargetBehavior = "closest",
		},
	},

	Bear = {
		health = 100,
		walkSpeed = 5,
		runSpeed = 10,
		jumpCooldown = 4,
		canJump = false,
		canTakeDamage = true,

		primaryWeapon = "BearClaw",
		baseStats = {
			strength = 6,
			magic = 0,
			stamina = 4,
			accuracy = 2,
		},

		drops = {
			BigMeat = {
				chance = 1.0,
				min = 1,
				max = 1,
				chanceModifiers = {
					luck = 0.0,
				},
			},
			SmallMeat = {
				chance = 0.1, -- 10% base chance
				min = 1,
				max = 1,
				excludeIf = { "BigMeat" },
				chanceModifiers = {
					luck = 0.01, -- +1% per luck point
				},
			},
		},

		ai = {
			profile = "territorial_wildlife",
			behaviors = {
				idle = "wander",
				onDamaged = "retaliate_locked",
				onPlayerNear = "chase",
			},
			targetPriority = { "Player" },
			aggroRange = 10,
			wanderRadius = 20,
			returnToSpawn = true,
			returnSpeed = 0.6,
			retargetBehavior = "locked",
		},
	},
}

return WildlifeStats
