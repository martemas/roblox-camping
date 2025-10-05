--!strict

local WildlifeConfig = {
	-- Wildlife Settings
	wildlife = {
		Wolf = {
			maxCount = 5,
			health = 60,
			walkSpeed = 12,
			runSpeed = 22,
			aggroRange = 30,
			wanderRange = 10,
			jumpCooldown = 3,
			respawnTime = 60,
			canJump = true,
			drops = {"Food", "Hide", "Bones"},
			targetPriority = "players", -- "players", "structures", "both"
			primaryWeapon = "WolfClaw", -- References weapons.WolfClaw
			baseStats = { strength = 3, magic = 0, stamina = 2, accuracy = 6 },
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
		},
		Bear = {
			maxCount = 3,
			health = 100,
			walkSpeed = 5,
			runSpeed = 10,
			aggroRange = 25,
			wanderRange = 35,
			jumpCooldown = 4,
			respawnTime = 90,
			canJump = false,
			drops = {"Meat", "Hide", "Bones"},
			targetPriority = "players",
			primaryWeapon = "BearClaw", -- References weapons.BearClaw
			baseStats = { strength = 6, magic = 0, stamina = 4, accuracy = 2 },
			animations = {
				walk = "rbxassetid://97593039109435",
				attack = "rbxassetid://97384715486637",
			},
		},
	},
}

return WildlifeConfig
