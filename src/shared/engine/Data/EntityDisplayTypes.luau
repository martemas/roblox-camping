--!strict

-- SHARED ENGINE: Display data type definitions ONLY (no dependencies, no circular refs)
-- This module is safe to require from anywhere without causing circular dependencies

export type CreatureDisplayData = {
	displayName: string,
	description: string?,
	icon: string?,
	animationIds: {
		walk: string?,
		run: string?,
		jump: string?,
		attack: string?,
		idle: string?,
		death: string?,
	}?,
	sounds: {
		idle: string?,
		attack: string?,
		hurt: string?,
		death: string?,
	}?,
}

export type NPCDisplayData = {
	displayName: string,
	description: string?,
	icon: string?,
	animationIds: {
		walk: string?,
		run: string?,
		jump: string?,
		attack: string?,
		idle: string?,
		death: string?,
	}?,
	sounds: {
		idle: string?,
		attack: string?,
		hurt: string?,
		death: string?,
	}?,
	dialogueLines: { string }?, -- Optional dialogue for interaction
}

export type ResourceDisplayData = {
	displayName: string,
	description: string?,
	icon: string?,
	harvestTool: string?, -- Tool type required (Axe, Pickaxe, etc.)
	sounds: {
		harvest: string?,
		destroyed: string?,
	}?,
}

export type StructureCategory = "Defensive" | "Production" | "Utility" | "Emplacement"

export type StructureDisplayData = {
	displayName: string,
	description: string?,
	category: StructureCategory,
	icon: string?,
	buildPreviewModel: string?, -- Preview model shown during placement
	sounds: {
		build: string?,
		damaged: string?,
		destroyed: string?,
	}?,
}

export type WildlifeDisplayData = {
	displayName: string,
	description: string?,
	icon: string?,
	animationIds: {
		walk: string?,
		run: string?,
		jump: string?,
		attack: string?,
		idle: string?,
		death: string?,
	}?,
	sounds: {
		idle: string?,
		attack: string?,
		hurt: string?,
		death: string?,
	}?,
}

return {}
