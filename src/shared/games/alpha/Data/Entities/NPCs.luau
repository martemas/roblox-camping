--!strict

-- GAME-SPECIFIC: Alpha game NPC display data
-- Type definitions are in shared/engine/Data/EntityDisplayTypes.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityDisplayTypes = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("EntityDisplayTypes"))

local NPCs = {}

export type NPCDisplayData = EntityDisplayTypes.NPCDisplayData

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
