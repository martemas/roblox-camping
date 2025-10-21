--!strict

-- CLIENT-VISIBLE: Display information only (names, animations, sounds, icons)
-- Actual stats, AI behavior, drops are in server/Data/Entities/WildlifeStats.luau

local Wildlife = {}

export type WildlifeDisplayData = {
	displayName: string,
	description: string?,
	icon: string?,
	animationIds: {
		walk: string?,
		run: string?,
		jump: string?,
		attack: string?,
		idle: string?,
		death: string?,
	}?,
	sounds: {
		idle: string?,
		attack: string?,
		hurt: string?,
		death: string?,
	}?,
}

Wildlife.Display = {
	Wolf = {
		displayName = "Wolf",
		description = "Fast and aggressive predator",
		animationIds = {
			walk = "rbxassetid://125448487250472",
			run = "rbxassetid://70972717905830",
			jump = "rbxassetid://130986182083396",
			attack = "rbxassetid://83719559878946",
		},
		sounds = {
			attack = "WolfHowl",
			hurt = "WolfWhine",
			death = "WolfDeath",
		},
	},

	Bear = {
		displayName = "Bear",
		description = "Powerful territorial beast",
		animationIds = {
			walk = "rbxassetid://97593039109435",
			attack = "rbxassetid://97384715486637",
		},
		sounds = {
			attack = "BearRoar",
			hurt = "BearGrowl",
			death = "BearDeath",
		},
	},
}

return Wildlife
