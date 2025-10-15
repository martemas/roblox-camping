--!strict
local EntitiesConfig = {}

-- Categories enum (defined first for self-reference)
local Categories = {
	Resource = "Resource",
	Structure = "Structure",
	Wildlife = "Wildlife",
	Creature = "Creature",
	NPC = "NPC",
	Player = "Player",
}

local StructureTypes = {
	Utility = "Utility",
	Defence = "Defence",
	Emplacement = "Emplacement",
	Production = "Production",
}

export type Category = "Resource" | "Structure" | "Wildlife" | "Creature" | "NPC" | "Player"
export type StructureType = "Utility" | "Defence" | "Emplacement" | "Production"

-- GROUPED by category (for organized config and category iteration)
local CategoryLookup = {
	Wildlife = {
		Wolf = {
			category = Categories.Wildlife,
			health = 60,
			walkSpeed = 12,
			runSpeed = 22,
			jumpCooldown = 3,
			respawnTime = 60,
			canJump = true,
			drops = {
				["SmallMeat"] = {
					chance = 1.0, -- 100% chance
					min = 1,
					max = 1
				}
			},
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

			-- AI Behavior Configuration
			ai = {
				profile = "aggressive_wildlife",
				behaviors = {
					idle = "wander",              -- Wander when no target
					onDamaged = "retaliate_closest",  -- Attack back, switch if closer threat
					onPlayerNear = "chase",       -- Chase players in aggro range
				},
				targetPriority = {"Player"},      -- Only attack players
				aggroRange = 30,                  -- Detection range
				wanderRadius = 30,                -- Wander area from spawn
				returnToSpawn = true,             -- Walk back to spawn when idle
				returnSpeed = 0.5,                -- 50% speed when returning
				retargetBehavior = "closest",     -- Switch to closest threat if attacker leaves
			},
		},
		Bear = {
			category = Categories.Wildlife,
			health = 100,
			walkSpeed = 5,
			runSpeed = 10,
			jumpCooldown = 4,
			respawnTime = 90,
			canJump = false,
			drops = {
				["BigMeat"] = {
					chance = 1.0, -- 100% base chance
					min = 1,
					max = 1,
					chanceModifiers = {
						luck = 0.0, -- No luck modifier for guaranteed drops
					}
				},
				["SmallMeat"] = {
					chance = 0.1, -- 80% base chance
					min = 1,
					max = 1,
					excludeIf = { "BigMeat" }, -- Don't drop if BigMeat already dropped
					chanceModifiers = {
						luck = 0.01, -- +1% per luck point
					}
				},
				-- ["BearPelt"] = {
				-- 	chance = 0.01, -- 1% base chance (rare drop)
				-- 	min = 1,
				-- 	max = 1,
				-- 	chanceModifiers = {
				-- 		luck = 0.001, -- +0.1% per luck point
				-- 	},
				-- 	maxChance = 0.15 -- Cap at 15% to prevent over-stacking
				-- }
			},
			primaryWeapon = "BearClaw",
			baseStats = { strength = 6, magic = 0, stamina = 4, accuracy = 2 },
			animations = {
				walk = "rbxassetid://97593039109435",
				attack = "rbxassetid://97384715486637",
			},
			maxCount = 3,
			canTakeDamage = true,

			-- AI Behavior Configuration
			ai = {
				profile = "territorial_wildlife",
				behaviors = {
					idle = "wander",
					onDamaged = "retaliate_locked",   -- Never switch from attacker
					onPlayerNear = "chase",           -- Aggressive in range
				},
				targetPriority = {"Player"},
				aggroRange = 2,
				wanderRadius = 20,
				returnToSpawn = true,
				returnSpeed = 0.6,
				retargetBehavior = "locked",          -- Never retarget
			},
		},
	},
	NPC = {
		TownGuard = {
			category = Categories.NPC,
			health = 150,
			walkSpeed = 10,
			runSpeed = 15,
			jumpCooldown = 3,
			respawnTime = 300,
			canJump = true,
			drops = {},
			primaryWeapon = "Sword",
			baseStats = { strength = 8, magic = 0, stamina = 5, accuracy = 5 },
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
			maxCount = 2,
			canTakeDamage = true,

			-- AI Behavior Configuration
			ai = {
				profile = "defensive_npc",
				behaviors = {
					idle = "stand_guard",          -- Stand at post when idle
					onDamaged = "retaliate_closest",  -- Attack back, switch if closer threat
					onPlayerNear = "assist_ally",      -- Assist nearby allies under attack
				},
				targetPriority = {"Creature", "Wildlife", "Player"}, -- Attack threats in this order
				aggroRange = 20,                  -- Detection range
				wanderRadius = 0,                 -- No wandering, stands guard
				returnToSpawn = true,             -- Walk back to spawn when idle
				returnSpeed = 1.0,                -- Normal speed when returning
				retargetBehavior = "closest",     -- Switch to closest threat if attacker leaves
			},
		}
	},
	Creature = {
		Zombie = {
			category = Categories.Creature,
			health = 50,
			walkSpeed = 8,
			runSpeed = 12,
			jumpCooldown = 4,
			spawnWeight = 1,
			respawnTime = 90,
			canJump = false,
			drops = {
				["RottenMeat"] = {
					chance = 1.0, -- 100% chance
					min = 1,
					max = 1
				}
			},
			primaryWeapon = "ZombieBite",
			baseStats = { strength = 4, magic = 0, stamina = 3, accuracy = 3 },
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
			canTakeDamage = true,

			-- AI Behavior Configuration
			ai = {
				profile = "aggressive_creature",
				behaviors = {
					idle = "seek_target",             -- Always seeking targets
					onDamaged = "ignore",             -- Never retarget from damage
					onPlayerNear = "chase",           -- Chase when detected
				},
				targetPriority = {"Player", "Structure"},  -- Players first, then structures
				aggroRange = 25,
				seekRange = 100,                      -- Active seeking range
				wanderRadius = 20,                    -- Patrol area while seeking
				returnToSpawn = false,                -- Never return (attack mission)
				retargetBehavior = "priority",        -- Switch based on targetPriority
			},
		},
	},
}

-- Create flat lookup table for direct name-based access
local function createFlatLookup(grouped)
	local flat = {}
	for category, items in grouped do
		for name, config in items do
			flat[name] = config
		end
	end
	return flat
end

-- Export both access patterns
EntitiesConfig.Categories = Categories
EntitiesConfig.StructureTypes = StructureTypes
EntitiesConfig.Lookup = CategoryLookup           -- Grouped: EntityConfig.Lookup.Wildlife.Wolf
EntitiesConfig.Entities = createFlatLookup(CategoryLookup)  -- Flat: EntityConfig.Entities.Wolf

return EntitiesConfig
