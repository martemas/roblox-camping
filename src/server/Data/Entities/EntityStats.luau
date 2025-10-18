local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Entities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Entities"))
local CreatureData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Creatures"))
local NPCData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("NPCs"))
local ResourceData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Resources"))
local StructureData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Structures"))
local WildlifeData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Entities"):WaitForChild("Wildlife"))

local Creature = require(script.Parent:WaitForChild("CreatureStats"))
local NPCStats = require(script.Parent:WaitForChild("NPCStats"))
local ResourceStats = require(script.Parent:WaitForChild("ResourceStats"))
local StructureStats = require(script.Parent:WaitForChild("StructureStats"))
local WildlifeStats = require(script.Parent:WaitForChild("WildlifeStats"))

local EntityStats = {}

--[[
    Returns the full entity configuration including stats based on entity type
    @param entityType - The type of the entity (e.g., "Creature", "NPC", "Resource", "Structure", "Wildlife")
    @return table? - The entity configuration with stats or nil if not found
]]
EntityStats.getEntity = function(entityId: string)
    local entity = Entities.Database[entityId]
    local stats = nil
    local display = nil

    if entity.type == "Creature" then
        stats = Creature.Stats[entityId]
        display = CreatureData.Display[entityId]
    elseif entity.type == "NPC" then
        stats = NPCStats.Stats[entityId]
        display = NPCData.Display[entityId]
    elseif entity.type == "Resource" then
        stats = ResourceStats.Stats[entityId]
        display = ResourceData.Display[entityId]
    elseif entity.type == "Structure" then
        stats = StructureStats.Stats[entityId]
        display = StructureData.Display[entityId]
    elseif entity.type == "Wildlife" then
        stats = WildlifeStats.Stats[entityId]
        display = WildlifeData.Display[entityId]
    else
        warn(`EntityStats: No stats found for entity type '{entityId}'`)
        return nil
    end
    -- print("Stats for", entityId, stats)
    entity["Stats"] = stats
    entity["Display"] = display

    return entity
end

return EntityStats