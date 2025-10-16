--!strict

-- CLIENT-VISIBLE: Display information only
local Resources = {}

export type ResourceDisplayData = {
	displayName: string,
	description: string,
	icon: string?,
}

Resources.Display = {
	Wood = {
		displayName = "Wood",
		description = "Basic building material from trees",
	},

	Stone = {
		displayName = "Stone",
		description = "Durable material for construction",
	},

	Metal = {
		displayName = "Metal Ore",
		description = "Raw metal for crafting",
	},

	Gem = {
		displayName = "Gem",
		description = "Precious gemstone",
	},
}

return Resources
