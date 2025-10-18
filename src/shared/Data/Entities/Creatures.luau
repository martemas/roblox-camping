--!strict

-- CLIENT-VISIBLE: Display information only (names, animations, sounds, icons)
-- Actual stats, AI behavior, drops are in server/Data/Entities/CreatureStats.luau

local Creatures = {}

export type CreatureDisplayData = {
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

Creatures.Display = {
	Zombie = {
		displayName = "Zombie",
		description = "Undead horror that attacks at night",
		animationIds = {
			walk = "rbxassetid://125448487250472",
			run = "rbxassetid://70972717905830",
			jump = "rbxassetid://130986182083396",
			attack = "rbxassetid://83719559878946",
		},
		sounds = {
			idle = "ZombieGroan",
			attack = "ZombieAttack",
			hurt = "ZombieHurt",
			death = "ZombieDeath",
		},
	},
}

return Creatures
