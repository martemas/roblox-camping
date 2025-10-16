--!strict

local Entities = {}

export type EntityType = "Resource" | "Structure" | "Wildlife" | "Creature" | "NPC" | "Player"

export type EntityData = {
    -- id: string,
	-- name: string,
    -- type: EntityType,
    -- description: string,
    -- health: number,
    -- walkSpeed: number?,
    -- runSpeed: number?,
    -- jumpCooldown: number?,
    -- respawnTime: number?,
    -- canJump: boolean?,
    -- drops: { [string]: { chance: number, min: number, max: number } }?,
    -- primaryWeapon: string?,
    -- baseStats: { strength: number, magic: number, stamina: number, accuracy: number }?,
    -- animations: { walk: string, run: string, jump: string, attack: string }?,
    -- maxCount: number?,
    -- canTakeDamage: boolean?,
    -- ai: {
    --     profile: string,
    --     behaviors: {
    --         idle: string,
    --         onDamaged: string,
    --         onPlayerNear: string,
    --     },
    --     targetPriority: { string }?,
    --     aggroRange: number?,
    --     wanderRadius: number?,
    --     returnToSpawn: boolean?,
    --     returnSpeed: number?,
    --     retargetBehavior: string?,
    -- }?,
    -- structureType: string?,
    -- buildCost: { [string]: number }?,
    -- buildTime: number?,
    -- production: { itemId: string, quantity: number, time: number }?,
    -- capacity: number?,
    -- attackRange: number?,
    -- attackCooldown: number?,
    -- damage: number?,
    -- armor: number?,
    -- healRate: number?,
    -- repairRate: number?,
    -- effectRadius: number?,
    -- effectStrength: number?,
    -- effectDuration: number?,
    -- projectileType: string?,
    -- projectileSpeed: number?,
    -- projectileArc: number?, -- degrees
    -- targetType: string?,
    -- weaponRef: string?,
}

Entities.Database = {

}

return Entities
