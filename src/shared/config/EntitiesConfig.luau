--!strict

local EntitiesConfig = {
	-- Entity System - defines all objects that can be interacted with
	entities = {
		-- Wildlife
		Wolf = {
			category = "wildlife",
			health = 60,
			walkSpeed = 12,
			runSpeed = 22,
			aggroRange = 30,
			wanderRange = 10,
			jumpCooldown = 3,
			respawnTime = 60,
			canJump = true,
			drops = {"Food", "Hide", "Bones"},
			targetPriority = "players",
			primaryWeapon = "WolfClaw",
			baseStats = { strength = 3, magic = 0, stamina = 2, accuracy = 6 },
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
			maxCount = 5,
			canTakeDamage = true,
			manager = "EntitySpawner", -- Which manager handles this entity
		},
		Bear = {
			category = "wildlife",
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
			maxCount = 3,
			canTakeDamage = true,
			manager = "EntitySpawner",
		},
		-- Enemies
		Zombie = {
			category = "enemy",
			health = 50,
			walkSpeed = 8,
			runSpeed = 12,
			aggroRange = 25,
			wanderRange = 5,
			jumpCooldown = 4,
			spawnWeight = 1,
			respawnTime = 90,
			canJump = false,
			drops = {"Cloth", "RottenMeat"},
			targetPriority = "both", -- Attack both players and structures
			primaryWeapon = "ZombieBite", -- References weapons.ZombieBite
			baseStats = { strength = 4, magic = 0, stamina = 3, accuracy = 3 },
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
			canTakeDamage = true,
			manager = "EntitySpawner",
		},
	},
}

return EntitiesConfig
