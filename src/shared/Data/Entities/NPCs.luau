--!strict

-- CLIENT-VISIBLE: Display information only (names, animations, sounds, icons)
-- Actual stats, AI behavior, drops are in server/Data/Entities/NPCStats.luau

local NPCs = {}

export type NPCDisplayData = {
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
	dialogueLines: { string }?, -- Optional dialogue for interaction
}

NPCs.Display = {
	TownGuard = {
		displayName = "Town Guard",
		description = "Protector of the settlement",
		animationIds = {
			walk = "rbxassetid://125448487250472",
			run = "rbxassetid://70972717905830",
			jump = "rbxassetid://130986182083396",
			attack = "rbxassetid://83719559878946",
		},
		sounds = {
			idle = "GuardHum",
			attack = "GuardShout",
			hurt = "GuardHurt",
			death = "GuardDeath",
		},
		dialogueLines = {
			"Stay safe out there!",
			"I'll protect this town with my life.",
			"The nights have been dangerous lately...",
		},
	},
}

return NPCs
