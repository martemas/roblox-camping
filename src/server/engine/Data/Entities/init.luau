--!strict

-- ENGINE MODULE: Entity loader that combines base data with game-specific stats
-- Type definitions are in server/engine/Data/EntityTypes.luau (to avoid circular deps)
-- Game-specific stats are defined in src/server/games/{gameName}/Data/Entities/

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Import and re-export types from EntityTypes module
local EntityTypes = require(script.Parent.EntityTypes)
export type AIBehavior = EntityTypes.AIBehavior
export type DropConfig = EntityTypes.DropConfig
export type CreatureStats = EntityTypes.CreatureStats
export type NPCStats = EntityTypes.NPCStats
export type ResourceStats = EntityTypes.ResourceStats
export type StructureStats = EntityTypes.StructureStats
export type WildlifeStats = EntityTypes.WildlifeStats

-- ═══════════════════════════════════════════════════
-- DEPENDENCIES
-- ═══════════════════════════════════════════════════

-- Game-specific data (from Games folder - ReplicatedStorage)
local GamesDataFolder = ReplicatedStorage:WaitForChild("Games"):WaitForChild("Data"):WaitForChild("Entities")
local EntityDatabase = require(GamesDataFolder:WaitForChild("Entities"))
local CreatureData = require(GamesDataFolder:WaitForChild("Creatures"))
local NPCData = require(GamesDataFolder:WaitForChild("NPCs"))
local ResourceData = require(GamesDataFolder:WaitForChild("Resources"))
local StructureData = require(GamesDataFolder:WaitForChild("Structures"))
local WildlifeData = require(GamesDataFolder:WaitForChild("Wildlife"))

-- Game-specific stats (from Games folder - ServerScriptService)
local GamesFolder = ServerScriptService:WaitForChild("Games"):WaitForChild("Data"):WaitForChild("Entities")
local Creature = require(GamesFolder:WaitForChild("CreatureStats"))
local NPCStats = require(GamesFolder:WaitForChild("NPCStats"))
local ResourceStats = require(GamesFolder:WaitForChild("ResourceStats"))
local StructureStats = require(GamesFolder:WaitForChild("StructureStats"))
local WildlifeStats = require(GamesFolder:WaitForChild("WildlifeStats"))

local Entities = {}

-- Cache for already-built entities to avoid recomputing stats
local entityCache = {}

--[[
    Returns the full entity configuration including stats based on entity type
    @param entityType - The type of the entity (e.g., "Creature", "NPC", "Resource", "Structure", "Wildlife")
    @return table? - The entity configuration with stats or nil if not found
]]
Entities.getEntity = function(entityId: string)
    -- Return cached entity if already built
    if entityCache[entityId] then
        return entityCache[entityId]
    end

    local baseEntity = EntityDatabase.Database[entityId]

    if not baseEntity then
        warn(`ERROR - No entity found for {entityId}`)
        return nil
    end

    -- Clone to avoid mutating the database
    local entity = table.clone(baseEntity)
    local stats = nil
    local display = nil

    if entity.type == "Creature" then
        stats = table.clone(Creature.Stats[entityId])
        display = CreatureData.Display[entityId]
    elseif entity.type == "NPC" then
        stats = table.clone(NPCStats.Stats[entityId])
        display = NPCData.Display[entityId]
    elseif entity.type == "Resource" then
        stats = table.clone(ResourceStats.Stats[entityId])
        display = ResourceData.Display[entityId]
    elseif entity.type == "Structure" then
        stats = table.clone(StructureStats.Stats[entityId])
        display = StructureData.Display[entityId]
    elseif entity.type == "Wildlife" then
        stats = table.clone(WildlifeStats.Stats[entityId])
        display = WildlifeData.Display[entityId]
    else
        warn(`ERROR - Entities: No stats found for entity type '{entityId}'`)
        return nil
    end

    entity.Stats = stats
    entity.Display = display

    -- Cache the complete entity
    entityCache[entityId] = entity
    return entity
end

return Entities