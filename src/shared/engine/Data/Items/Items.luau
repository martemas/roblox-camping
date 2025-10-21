--!strict

-- ENGINE: Item database type definitions ONLY
-- Actual database is in shared/games/{gameName}/Data/Items/Items.luau

local Items = {}

export type ItemType = "Resource" | "Consumable" | "Weapon" | "Tool" | "Building"

export type ItemData = {
	id: string,
	name: string,
	type: ItemType,
	description: string,

	-- Inventory properties
	stackable: boolean,
	maxStack: number?,

	-- World properties
	droppable: boolean,
	dropModel: string?, -- Path relative to ReplicatedStorage.Models

	-- References to type-specific data
	weaponData: string?, -- → Weapons.luau (display) / WeaponStats.luau (server)
	toolData: string?, -- → Tools.luau (display) / ToolStats.luau (server)
	consumableData: string?, -- → Consumables.luau (display) / ConsumableStats.luau (server)
	buildingData: string?, -- → Buildings.luau (display) / BuildingStats.luau (server)
}

return Items
