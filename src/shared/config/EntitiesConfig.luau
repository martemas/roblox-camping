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
		},
		Bear = {
			category = Categories.Wildlife,
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
			primaryWeapon = "BearClaw",
			baseStats = { strength = 6, magic = 0, stamina = 4, accuracy = 2 },
			animations = {
				walk = "rbxassetid://97593039109435",
				attack = "rbxassetid://97384715486637",
			},
			maxCount = 3,
			canTakeDamage = true,
		},
	},
	Creature = {
		Zombie = {
			category = Categories.Creature,
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
			targetPriority = "both",
			primaryWeapon = "ZombieBite",
			baseStats = { strength = 4, magic = 0, stamina = 3, accuracy = 3 },
			animations = {
				walk = "rbxassetid://125448487250472",
				run = "rbxassetid://70972717905830",
				jump = "rbxassetid://130986182083396",
				attack = "rbxassetid://83719559878946",
			},
			canTakeDamage = true,
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
