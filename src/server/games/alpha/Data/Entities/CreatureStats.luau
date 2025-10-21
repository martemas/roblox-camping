--!strict

-- GAME-SPECIFIC: Alpha game creature stats, AI behavior, drops
-- Client only sees display data from shared/Data/Entities/Creatures.luau
-- Type definitions are in server/engine/Data/EntityTypes.luau

local ServerScriptService = game:GetService("ServerScriptService")
local EntityTypes = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("EntityTypes"))

local CreatureStats = {}

export type CreatureStats = EntityTypes.CreatureStats

CreatureStats.Stats = {
	Zombie = {
		health = 50,
		walkSpeed = 8,
		runSpeed = 12,
		jumpCooldown = 4,
		canJump = false,
		canTakeDamage = true,

		spawnWeight = 1,

		primaryWeapon = "ZombieBite",
		baseStats = {
			strength = 4,
			magic = 0,
			stamina = 3,
			accuracy = 3,
		},

		drops = {
			RottenMeat = {
				chance = 1.0, -- 100% chance
				min = 1,
				max = 1,
			},
		},

		ai = {
			profile = "aggressive_creature",
			behaviors = {
				idle = "seek_target",
				onDamaged = "ignore",
				onPlayerNear = "chase",
			},
			targetPriority = { "Player", "Structure" },
			aggroRange = 25,
			seekRange = 100,
			wanderRadius = 20,
			returnToSpawn = false,
			retargetBehavior = "priority",
		},
	},
}

return CreatureStats
