--!strict

local Entities = {}

export type EntityType = "Wildlife" | "Creature" | "NPC" | "Structure" | "Resource" | "Player"

Entities.Types = {
	Wildlife = "Wildlife",
	Creature = "Creature",
	NPC = "NPC",
	Structure = "Structure",
	Resource = "Resource",
	Player = "Player",
}

export type EntityData = {
	id: string,
	name: string,
	type: EntityType,
	description: string?,

	-- World/spawn properties
	spawnModel: string?, -- Path relative to ReplicatedStorage.Models.Entities (e.g., "Wildlife/Wolf")
	maxCount: number?, -- Max instances allowed in world
	respawnTime: number?, -- Seconds until respawn after death/destruction

	-- References to type-specific data (display and stats)
	wildlifeData: string?, -- → Wildlife.luau (display) / WildlifeStats.luau (server)
	creatureData: string?, -- → Creatures.luau (display) / CreatureStats.luau (server)
	npcData: string?, -- → NPCs.luau (display) / NPCStats.luau (server)
	structureData: string?, -- → Structures.luau (display) / StructureStats.luau (server)
	resourceData: string?, -- → Resources.luau (display) / ResourceStats.luau (server)
}

-- Master Entity Registry - Single Source of Truth
-- All entities that can exist in the world (not in inventory)
Entities.Database = {
	-- ========================================
	-- WILDLIFE (Neutral/Aggressive Animals)
	-- ========================================
	Wolf = {
		id = "Wolf",
		name = "Wolf",
		type = "Wildlife",
		description = "Fast and aggressive predator",
		spawnModel = "Wildlife/Wolf",
		maxCount = 5,
		respawnTime = 60,
		wildlifeData = "Wolf",
	},

	Bear = {
		id = "Bear",
		name = "Bear",
		type = "Wildlife",
		description = "Powerful territorial beast",
		spawnModel = "Wildlife/Bear",
		maxCount = 3,
		respawnTime = 90,
		wildlifeData = "Bear",
	},

	-- ========================================
	-- CREATURES (Hostile Mobs)
	-- ========================================
	Zombie = {
		id = "Zombie",
		name = "Zombie",
		type = "Creature",
		description = "Undead horror that attacks at night",
		spawnModel = "Creature/Zombie",
		respawnTime = 90,
		creatureData = "Zombie",
	},

	-- ========================================
	-- NPCs (Friendly/Neutral Characters)
	-- ========================================
	TownGuard = {
		id = "TownGuard",
		name = "Town Guard",
		type = "NPC",
		description = "Protector of the settlement",
		spawnModel = "NPC/TownGuard",
		maxCount = 2,
		respawnTime = 300,
		npcData = "TownGuard",
	},

	-- ========================================
	-- STRUCTURES (Player-built or world structures)
	-- ========================================
	WoodenWall = {
		id = "WoodenWall",
		name = "Wooden Wall",
		type = "Structure",
		description = "Basic defensive wall",
		spawnModel = "Structures/WoodenWall",
		structureData = "WoodenWall",
	},

	BarrackL1 = {
		id = "BarrackL1",
		name = "Barrack Level 1",
		type = "Structure",
		description = "Trains basic melee units",
		spawnModel = "Structures/BarrackL1",
		structureData = "BarrackL1",
	},

	-- ========================================
	-- RESOURCES (Harvestable Nodes)
	-- ========================================
	-- Note: These are ENTITIES (world objects with health/position)
	-- They DROP resource ITEMS (Wood, Stone, etc. from Items.Database)
	Tree = {
		id = "Tree",
		name = "Tree",
		type = "Resource",
		description = "Harvestable wood source",
		spawnModel = "Resources/Tree",
		respawnTime = 0,
		resourceData = "Tree",
	},

	Rock = {
		id = "Rock",
		name = "Rock",
		type = "Resource",
		description = "Harvestable stone source",
		spawnModel = "Resources/Rock",
		respawnTime = 0,
		resourceData = "Rock",
	},

	RockMine = {
		id = "RockMine",
		name = "RockMine",
		type = "Resource",
		description = "Harvestable stone source",
		spawnModel = "Resources/Rock",
		respawnTime = 30,
		resourceData = "Rock",
	},

	MetalVein = {
		id = "MetalVein",
		name = "Metal Vein",
		type = "Resource",
		description = "Rich metal ore deposit",
		spawnModel = "Resources/MetalVein",
		respawnTime = 120,
		resourceData = "MetalVein",
	},

	GemNode = {
		id = "GemNode",
		name = "Gem Node",
		type = "Resource",
		description = "Rare gemstone deposit",
		spawnModel = "Resources/GemNode",
		respawnTime = 30,
		resourceData = "GemNode",
	},

	GemMine= {
		id = "GemMine",
		name = "Gem Mine",
		type = "Resource",
		description = "Rare gemstone mine",
		spawnModel = "Resources/GemNode",
		respawnTime = 0,
		resourceData = "GemNode",
	},
}

return Entities
