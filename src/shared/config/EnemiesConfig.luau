--!strict

local EnemiesConfig = {
	-- Enemy Settings
	enemies = {
		Zombie = {
			health = 50,
			walkSpeed = 8,
			runSpeed = 12,
			aggroRange = 25,
			wanderRange = 5,
			jumpCooldown = 4,
			spawnWeight = 1,
			canJump = false,
			targetPriority = "both", -- Attack both players and structures
			primaryWeapon = "ZombieBite", -- References weapons.ZombieBite
			baseStats = { strength = 4, magic = 0, stamina = 3, accuracy = 3 },
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
		},
	},
}

return EnemiesConfig
