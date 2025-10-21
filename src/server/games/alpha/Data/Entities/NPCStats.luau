--!strict

-- GAME-SPECIFIC: Alpha game NPC stats, AI behavior, drops
-- Client only sees display data from shared/Data/Entities/NPCs.luau
-- Type definitions are in server/engine/Data/EntityTypes.luau

local ServerScriptService = game:GetService("ServerScriptService")
local EntityTypes = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("EntityTypes"))

local NPCStats = {}

export type NPCStats = EntityTypes.NPCStats

NPCStats.Stats = {
	TownGuard = {
		health = 150,
		walkSpeed = 10,
		runSpeed = 15,
		jumpCooldown = 3,
		canJump = true,
		canTakeDamage = true,

		primaryWeapon = "Sword",
		baseStats = {
			strength = 8,
			magic = 0,
			stamina = 5,
			accuracy = 5,
		},

		drops = {}, -- NPCs typically don't drop items

		ai = {
			profile = "defensive_npc",
			behaviors = {
				idle = "stand_guard",
				onDamaged = "retaliate_closest",
				onPlayerNear = "assist_ally",
			},
			targetPriority = { "Creature", "Wildlife", "Player" },
			aggroRange = 20,
			wanderRadius = 0, -- Stands at post
			returnToSpawn = true,
			returnSpeed = 1.0,
			retargetBehavior = "closest",
		},
	},
}

return NPCStats
