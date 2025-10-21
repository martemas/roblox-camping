--!strict

-- GAME-SPECIFIC: Alpha game wildlife display data
-- Type definitions are in shared/engine/Data/EntityDisplayTypes.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityDisplayTypes = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("EntityDisplayTypes"))

local Wildlife = {}

export type WildlifeDisplayData = EntityDisplayTypes.WildlifeDisplayData

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
