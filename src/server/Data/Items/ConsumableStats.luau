--!strict

-- SERVER-ONLY: Actual consumable effects (NEVER sent to client)
local ConsumableStats = {}

export type ConsumableEffect = {
	type: "heal" | "buff" | "debuff",
	value: number,
	duration: number?,
	stat: string?,
}

export type ConsumableSpec = {
	effects: { ConsumableEffect },
	cooldown: number?,
	soundEffect: string?,
}

ConsumableStats.Stats = {
	SmallMeat = {
		effects = {
			{ type = "heal", value = 25 },
		},
		cooldown = 1.0,
		soundEffect = "Eating",
	},

	BigMeat = {
		effects = {
			{ type = "heal", value = 50 },
		},
		cooldown = 1.0,
		soundEffect = "Eating",
	},

	RottenMeat = {
		effects = {
			{ type = "heal", value = 5 },
			{ type = "debuff", value = -2, duration = 10, stat = "stamina" },
		},
		cooldown = 1.0,
		soundEffect = "Eating",
	},
}

return ConsumableStats
