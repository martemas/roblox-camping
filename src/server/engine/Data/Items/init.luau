--!strict

-- ENGINE MODULE: Item loader that combines base data with game-specific stats
-- Type definitions are in server/engine/Data/ItemTypes.luau (to avoid circular deps)
-- Game-specific stats are defined in src/server/games/{gameName}/Data/Items/

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Import and re-export types from ItemTypes module
local ItemTypes = require(script.Parent.ItemTypes)
export type WeaponType = ItemTypes.WeaponType
export type ProjectileConfig = ItemTypes.ProjectileConfig
export type WeaponSpec = ItemTypes.WeaponSpec
export type ToolCategory = ItemTypes.ToolCategory
export type ToolSpec = ItemTypes.ToolSpec
export type ConsumableEffect = ItemTypes.ConsumableEffect
export type ConsumableSpec = ItemTypes.ConsumableSpec

-- ═══════════════════════════════════════════════════
-- DEPENDENCIES
-- ═══════════════════════════════════════════════════

-- Game-specific data (from Games folder - ReplicatedStorage)
local GamesDataFolder = ReplicatedStorage:WaitForChild("Games"):WaitForChild("Data"):WaitForChild("Items")
local ItemDatabase = require(GamesDataFolder:WaitForChild("Items"))
local ConsumableData = require(GamesDataFolder:WaitForChild("Consumables"))
local ToolData = require(GamesDataFolder:WaitForChild("Tools"))
local WeaponData = require(GamesDataFolder:WaitForChild("Weapons"))

-- Game-specific stats (from Games folder - ServerScriptService)
local GamesFolder = ServerScriptService:WaitForChild("Games"):WaitForChild("Data"):WaitForChild("Items")
local ConsumableStats = require(GamesFolder:WaitForChild("ConsumableStats"))
local ToolStats = require(GamesFolder:WaitForChild("ToolStats"))
local WeaponStats = require(GamesFolder:WaitForChild("WeaponStats"))

local Items = {}

-- Cache for already-built items to avoid recomputing stats
local itemCache = {}

--[[
    Merges additional stats into base stats table
    @param base - The base stats table
    @param additional - Additional stats to merge in
    @return table - Merged stats table
]]
local function mergeStats(base: {[string]: any}, additional: {[string]: any}): {[string]: any}
    local merged = table.clone(base)
    for key, value in additional do
        merged[key] = value
    end
    return merged
end

--[[
    Returns the full item configuration including stats based on entity type
    @param itemId - The id of the item
    @return table? - The entity configuration with stats or nil if not found
]]
Items.getItem = function(itemId: string)
    -- Return cached item if already built
    if itemCache[itemId] then
        return itemCache[itemId]
    end

    local baseItem = ItemDatabase.Database[itemId]

    if not baseItem then
        warn(`ERROR - No items found for {itemId}`)
        return nil
    end

    -- Clone to avoid mutating the database
    local item = table.clone(baseItem)
    local stats = nil
    local display = nil

    if item.type == "Weapon" then
        stats = table.clone(WeaponStats.Stats[itemId])
        display = WeaponData.Display[itemId]
        if item.toolData then
            local toolStats = ToolStats.Stats[itemId]
            stats = mergeStats(stats, toolStats)
        end
    elseif item.type == "Consumable" then
        stats = ConsumableStats.Stats[itemId]
        display = ConsumableData.Display[itemId]
    elseif item.type == "Tool" then
        stats = ToolStats.Stats[itemId]
        display = ToolData.Display[itemId]
        if item.weaponData then
            local weaponStats = WeaponStats.Stats[itemId]
            stats = mergeStats(stats, weaponStats)            
        end
    else
        warn(`ItemStats: No stats found for itemId '{itemId}'`)
        return nil
    end

    item.Stats = stats
    item.Display = display

    -- Cache the complete item
    itemCache[itemId] = item
    return item
end

return Items