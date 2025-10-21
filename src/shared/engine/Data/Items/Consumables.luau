--!strict

-- CLIENT-VISIBLE: Display information only
local Consumables = {}

export type ConsumableDisplayData = {
	displayName: string,
	description: string,
	icon: string?,
	useSound: string?,
}

Consumables.Display = {
	SmallMeat = {
		displayName = "Small Meat",
		description = "Restores a small amount of health",
		useSound = "Eating",
	},

	BigMeat = {
		displayName = "Big Meat",
		description = "Restores a large amount of health",
		useSound = "Eating",
	},

	RottenMeat = {
		displayName = "Rotten Meat",
		description = "Spoiled meat, might make you sick",
		useSound = "Eating",
	},
}

return Consumables
