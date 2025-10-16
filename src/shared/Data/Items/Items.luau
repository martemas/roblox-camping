--!strict

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

Items.Database = {
	-- ========================================
	-- RESOURCES
	-- ========================================
	Wood = {
		id = "Wood",
		name = "Wood",
		type = "Resource",
		description = "Basic building material from trees",
		stackable = true,
		maxStack = 999,
		droppable = true,
		dropModel = "Items/Wood",
	},

	Stone = {
		id = "Stone",
		name = "Stone",
		type = "Resource",
		description = "Durable material for construction",
		stackable = true,
		maxStack = 999,
		droppable = true,
		dropModel = "Items/Stone",
	},

	Metal = {
		id = "Metal",
		name = "Metal Ore",
		type = "Resource",
		description = "Raw metal for crafting",
		stackable = true,
		maxStack = 999,
		droppable = true,
		dropModel = "Items/Metal",
	},

	Gem = {
		id = "Gem",
		name = "Gem",
		type = "Resource",
		description = "Precious gemstone",
		stackable = true,
		maxStack = 999,
		droppable = true,
		dropModel = "Items/Gem",
	},

	-- ========================================
	-- CONSUMABLES
	-- ========================================
	SmallMeat = {
		id = "SmallMeat",
		name = "Small Meat",
		type = "Consumable",
		description = "Restores 25 health",
		stackable = true,
		maxStack = 20,
		droppable = true,
		dropModel = "Items/SmallMeat",
		consumableData = "SmallMeat",
	},

	BigMeat = {
		id = "BigMeat",
		name = "Big Meat",
		type = "Consumable",
		description = "Restores 50 health",
		stackable = true,
		maxStack = 20,
		droppable = true,
		dropModel = "Items/BigMeat",
		consumableData = "BigMeat",
	},

	RottenMeat = {
		id = "RottenMeat",
		name = "Rotten Meat",
		type = "Consumable",
		description = "Spoiled meat, might make you sick",
		stackable = true,
		maxStack = 20,
		droppable = true,
		dropModel = "Items/RottenMeat",
		consumableData = "RottenMeat",
	},

	-- ========================================
	-- TOOLS (with weapon capabilities)
	-- ========================================
	BasicAxe = {
		id = "BasicAxe",
		name = "Basic Axe",
		type = "Tool",
		description = "Chop trees and defend yourself",
		stackable = false,
		droppable = true,
		dropModel = "Items/BasicAxe",
		toolData = "BasicAxe",
		weaponData = "Axe",
	},

	SteelAxe = {
		id = "SteelAxe",
		name = "Steel Axe",
		type = "Tool",
		description = "Improved axe for faster gathering",
		stackable = false,
		droppable = true,
		dropModel = "Items/SteelAxe",
		toolData = "SteelAxe",
		weaponData = "Axe",
	},

	BasicPickaxe = {
		id = "BasicPickaxe",
		name = "Basic Pickaxe",
		type = "Tool",
		description = "Mine stone and ore",
		stackable = false,
		droppable = true,
		dropModel = "Items/BasicPickaxe",
		toolData = "BasicPickaxe",
		weaponData = "Pickaxe",
	},

	SilverPickaxe = {
		id = "SilverPickaxe",
		name = "Silver Pickaxe",
		type = "Tool",
		description = "Faster mining pickaxe",
		stackable = false,
		droppable = true,
		dropModel = "Items/SilverPickaxe",
		toolData = "SilverPickaxe",
		weaponData = "Pickaxe",
	},

	GoldenPickaxe = {
		id = "GoldenPickaxe",
		name = "Golden Pickaxe",
		type = "Tool",
		description = "The fastest mining pickaxe",
		stackable = false,
		droppable = true,
		dropModel = "Items/GoldenPickaxe",
		toolData = "GoldenPickaxe",
		weaponData = "Pickaxe",
	},

	-- ========================================
	-- WEAPONS (standalone)
	-- ========================================
	Bow = {
		id = "Bow",
		name = "Bow",
		type = "Weapon",
		description = "Ranged weapon for hunting",
		stackable = false,
		droppable = true,
		dropModel = "Items/Bow",
		weaponData = "Bow",
	},

	MagicMissile = {
		id = "MagicMissile",
		name = "Magic Missile",
		type = "Weapon",
		description = "Hitscan magic projectile",
		stackable = false,
		droppable = true,
		dropModel = "Items/MagicMissile",
		weaponData = "MagicMissile",
	},

	Fireball = {
		id = "Fireball",
		name = "Fireball",
		type = "Weapon",
		description = "Explosive projectile weapon",
		stackable = false,
		droppable = true,
		dropModel = "Items/Fireball",
		weaponData = "Fireball",
	},

	-- ========================================
	-- BUILDINGS
	-- ========================================
	WoodenWall = {
		id = "WoodenWall",
		name = "Wooden Wall",
		type = "Building",
		description = "A sturdy wooden wall for defense",
		stackable = true,
		maxStack = 50,
		droppable = false,
		buildingData = "WoodenWall",
	},

	BarrackL1 = {
		id = "BarrackL1",
		name = "Barrack Level 1",
		type = "Building",
		description = "Trains basic melee units",
		stackable = true,
		maxStack = 10,
		droppable = false,
		buildingData = "BarrackL1",
	},
}

return Items
