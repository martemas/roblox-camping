local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityDatabase = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Entities"))
local CreatureData = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Creatures"))
local NPCData = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("NPCs"))
local ResourceData = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Resources"))
local StructureData = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Structures"))
local WildlifeData = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Wildlife"))

local Creature = require(script.CreatureStats)
local NPCStats = require(script.NPCStats)
local ResourceStats = require(script.ResourceStats)
local StructureStats = require(script.StructureStats)
local WildlifeStats = require(script.WildlifeStats)

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