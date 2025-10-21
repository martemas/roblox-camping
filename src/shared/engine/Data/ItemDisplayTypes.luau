--!strict

-- SHARED ENGINE: Item display type definitions ONLY (no dependencies, no circular refs)
-- This module is safe to require from anywhere without causing circular dependencies

export type WeaponDisplayData = {
	displayName: string,
	description: string?,
	icon: string?,
	animationId: string?,
	attackSound: string?,
	equipModel: string?,
}

export type ToolCategory = "Axe" | "Pickaxe"

export type ToolDisplayData = {
	displayName: string,
	category: ToolCategory,
	description: string?,
	icon: string?,
}

export type ConsumableDisplayData = {
	displayName: string,
	description: string,
	icon: string?,
	useSound: string?,
}

return {}
