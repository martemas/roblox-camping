--!strict

-- GAME-SPECIFIC: Alpha game creature display data
-- Type definitions are in shared/engine/Data/EntityDisplayTypes.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityDisplayTypes = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("EntityDisplayTypes"))

local Creatures = {}

export type CreatureDisplayData = EntityDisplayTypes.CreatureDisplayData

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
