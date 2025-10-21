--!strict

-- GAME-SPECIFIC: Alpha game weapon display data
-- Type definitions are in shared/engine/Data/ItemDisplayTypes.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDisplayTypes = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("ItemDisplayTypes"))

local Weapons = {}

export type WeaponDisplayData = ItemDisplayTypes.WeaponDisplayData

Weapons.Display = {
	Axe = {
		displayName = "Axe",
		description = "A versatile chopping tool and weapon",
		attackSound = "Swing",
	},

	Pickaxe = {
		displayName = "Pickaxe",
		description = "For mining stone and ore",
		attackSound = "Swing",
	},

	Bow = {
		displayName = "Bow",
		description = "Ranged weapon for hunting",
		attackSound = "BowRelease",
	},

	MagicMissile = {
		displayName = "Magic Missile",
		description = "Hitscan magic projectile",
		attackSound = "MagicCast",
	},

	Fireball = {
		displayName = "Fireball",
		description = "Explosive projectile weapon",
		attackSound = "FireCast",
	},

	-- Entity weapons (for display purposes)
	WolfClaw = {
		displayName = "Wolf Claw",
		description = "Sharp claws",
		attackSound = "Claw",
	},

	BearClaw = {
		displayName = "Bear Claw",
		description = "Massive claws",
		attackSound = "Claw",
	},

	ZombieBite = {
		displayName = "Zombie Bite",
		description = "Infected bite",
		attackSound = "Bite",
	},
}

return Weapons
