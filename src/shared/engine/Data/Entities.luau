--!strict

-- ENGINE: Entity database type definitions ONLY
-- Actual database is in shared/games/{gameName}/Data/Entities/Entities.luau

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

return Entities
