--!strict

-- ENGINE: Item type definitions ONLY (no dependencies, no circular refs)
-- This module is safe to require from anywhere without causing circular dependencies

export type WeaponType = "melee" | "projectile" | "hitscan" | "aoe"

export type ProjectileConfig = {
	modelPath: string,
	trailEnabled: boolean,
	trailColor: Color3,
	impactEffect: string,
}

export type WeaponSpec = {
	type: WeaponType,
	name: string,
	damage: number,
	range: number,
	cooldown: number,
	castDuration: number,

	-- Projectile properties
	projectileSpeed: number?,
	requiresLineOfSight: boolean?,
	damageTargetOnly: boolean?,
	penetratesEntities: boolean?,
	projectileConfig: ProjectileConfig?,

	-- Hitscan properties
	visualEffect: string?,
	targetFilter: string?,
	requiresTarget: boolean?,
	requireFacingForDamage: boolean?,

	-- AOE properties
	aoeOnImpact: boolean?,
	aoeDamage: number?,
	aoeRadius: number?,
	aoeFalloff: boolean?,
	maxTargets: number?,
	duration: number?,
	tickRate: number?,
}

export type ToolCategory = "Axe" | "Pickaxe"

export type ToolSpec = {
	category: ToolCategory,
	miningSpeed: number, -- Multiplier for resource gathering
	swingCooldown: number,
	weaponRef: string, -- References WeaponStats for combat
}

export type ConsumableEffect = {
	type: "heal" | "buff" | "debuff",
	value: number,
	duration: number?,
	stat: string?,
}

export type ConsumableSpec = {
	effects: { ConsumableEffect },
	cooldown: number?,
	soundEffect: string?,
}

return {}
