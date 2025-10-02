# Combat Damage System

## Overview

The **DamageCalculator** module provides a centralized, server-authoritative damage calculation system for all combat interactions in the game. It handles damage for players, NPCs, and entities with support for body part multipliers, future stat-based combat, and extensibility for advanced combat mechanics.

## Architecture

### Core Module: `DamageCalculator.luau`

**Location:** `/src/shared/DamageCalculator.luau`

**Purpose:**
- Single source of truth for all damage calculations
- Server-side only execution (security)
- Supports current basic damage and future stat-based systems
- Body part damage multipliers
- Extensible for critical hits, miss chance, resistances, etc.

### Design Principles

1. **Server Authoritative** - All damage calculations occur on the server
2. **Single Responsibility** - One module handles all damage logic
3. **Extensibility** - Easy to add stats, modifiers, status effects
4. **Consistency** - Same logic for players, NPCs, projectiles, melee, AOE
5. **Security First** - Client cannot manipulate damage values

## Type Definitions

### DamageInput

Input parameters for damage calculation:

```lua
export type DamageInput = {
    attacker: Model,           -- Attacker's character/NPC model
    target: Model,             -- Target's character/NPC model
    weaponName: string,        -- Weapon identifier (from GameConfig)
    hitPart: BasePart?,        -- Body part hit (optional now, used for multipliers)

    -- Future: Stats system (Phase 2)
    attackerStats: Stats?,     -- Attacker's combat stats
    targetStats: Stats?,       -- Target's combat stats
}
```

### DamageResult

Output from damage calculation:

```lua
export type DamageResult = {
    finalDamage: number,       -- Calculated damage to apply
    wasHit: boolean,           -- Did attack land (future: miss system)
    wasCritical: boolean,      -- Was it a critical hit (future)
    hitLocation: string,       -- Body part name: "head", "torso", "limb", "unknown"
    damageMultiplier: number,  -- Total multiplier applied (for feedback)
    baseDamage: number,        -- Original weapon damage (for debugging)
}
```

### Stats (Future - Phase 2)

Combat stats for entities:

```lua
export type Stats = {
    -- Offensive
    strength: number?,         -- Increases physical damage
    dexterity: number?,        -- Increases hit chance
    intelligence: number?,     -- Increases magical damage (future)

    -- Defensive
    defense: number?,          -- Reduces incoming physical damage
    resistance: number?,       -- Reduces incoming magical damage (future)
    evasion: number?,          -- Increases dodge chance

    -- Special
    critChance: number?,       -- Critical hit chance (0.0 - 1.0)
    critDamage: number?,       -- Critical damage multiplier (e.g., 1.5 = 150%)
}
```

## Core Functions

### calculateDamage

Main entry point for all damage calculations.

```lua
function DamageCalculator.calculateDamage(input: DamageInput): DamageResult
```

**Flow:**
1. Get base damage from weapon config
2. Determine hit location from hitPart
3. Apply body part multiplier
4. Apply stat modifiers (future)
5. Roll for hit/miss (future)
6. Roll for critical hit (future)
7. Return damage result

**Usage Example:**
```lua
local damageResult = DamageCalculator.calculateDamage({
    attacker = attackerModel,
    target = targetModel,
    weaponName = "Axe",
    hitPart = raycastResult.Instance, -- or nil for melee
})

if damageResult.wasHit then
    targetHumanoid:TakeDamage(damageResult.finalDamage)
end
```

### getBodyPartMultiplier

Determines damage multiplier based on body part hit.

```lua
function DamageCalculator.getBodyPartMultiplier(hitPart: BasePart?): (number, string)
```

**Returns:**
- `multiplier` (number): Damage multiplier (e.g., 2.0 for head)
- `location` (string): Body part category ("head", "torso", "limb", "unknown")

**Logic:**
1. If hitPart is nil → return (1.0, "unknown")
2. Check hitPart.Name against GameConfig.combat.bodyPartMultipliers
3. Return configured multiplier or default (1.0)

### applyStatModifiers (Future - Phase 2)

Applies attacker and defender stats to base damage.

```lua
function DamageCalculator.applyStatModifiers(
    baseDamage: number,
    attackerStats: Stats?,
    targetStats: Stats?
): number
```

**Formula (example):**
```lua
local damageBonus = 1.0 + (attackerStats.strength or 0) * GameConfig.combat.strengthDamageBonus
local defenseReduction = 1.0 - (targetStats.defense or 0) * GameConfig.combat.defenseReduction
local finalDamage = baseDamage * damageBonus * defenseReduction
```

### rollHitChance (Future - Phase 2)

Determines if attack hits or misses.

```lua
function DamageCalculator.rollHitChance(
    attackerStats: Stats?,
    targetStats: Stats?
): boolean
```

**Formula (example):**
```lua
local baseHitChance = GameConfig.combat.baseHitChance -- 0.95
local attackerDex = (attackerStats and attackerStats.dexterity) or 0
local targetEvasion = (targetStats and targetStats.evasion) or 0

local hitChance = baseHitChance
    + (attackerDex * GameConfig.combat.dexterityHitBonus)
    - (targetEvasion * GameConfig.combat.evasionDodgeBonus)

return math.random() <= math.clamp(hitChance, 0.05, 0.95) -- Min 5%, max 95%
```

### rollCriticalHit (Future - Phase 2)

Determines if attack is a critical hit.

```lua
function DamageCalculator.rollCriticalHit(attackerStats: Stats?): boolean
```

**Formula:**
```lua
local critChance = GameConfig.combat.criticalHitChance -- Base 0.05
if attackerStats and attackerStats.critChance then
    critChance = critChance + attackerStats.critChance
end
return math.random() <= critChance
```

## GameConfig Integration

### Body Part Multipliers

Add to `GameConfig.combat`:

```lua
combat = {
    -- ... existing settings ...

    -- Body Part Damage Multipliers
    bodyPartMultipliers = {
        -- Head (R15)
        Head = 2.0,

        -- Torso (R15)
        UpperTorso = 1.0,
        LowerTorso = 1.0,

        -- Arms (R15)
        LeftUpperArm = 0.75,
        RightUpperArm = 0.75,
        LeftLowerArm = 0.75,
        RightLowerArm = 0.75,
        LeftHand = 0.75,
        RightHand = 0.75,

        -- Legs (R15)
        LeftUpperLeg = 0.8,
        RightUpperLeg = 0.8,
        LeftLowerLeg = 0.8,
        RightLowerLeg = 0.8,
        LeftFoot = 0.75,
        RightFoot = 0.75,

        -- R6 compatibility
        Torso = 1.0,
        ["Left Arm"] = 0.75,
        ["Right Arm"] = 0.75,
        ["Left Leg"] = 0.8,
        ["Right Leg"] = 0.8,

        -- Default for any unlisted parts
        default = 1.0,
    },
}
```

### Stats System Config (Future - Phase 2)

```lua
combat = {
    -- ... existing settings ...

    -- Hit/Miss System
    baseHitChance = 0.95,              -- 95% base hit chance
    dexterityHitBonus = 0.01,          -- +1% hit per dexterity point
    evasionDodgeBonus = 0.01,          -- +1% dodge per evasion point

    -- Critical Hit System
    criticalHitChance = 0.05,          -- 5% base crit chance
    criticalDamageMultiplier = 1.5,    -- 1.5x damage on crit

    -- Stat Scaling
    strengthDamageBonus = 0.02,        -- +2% damage per strength point
    defenseReduction = 0.015,          -- -1.5% damage taken per defense point
    intelligenceMagicBonus = 0.025,    -- +2.5% magic damage per intelligence (future)
}
```

## Integration Points

### 1. CombatSystem.luau (Melee)

**Current (Line 406):**
```lua
targetHumanoid:TakeDamage(weaponConfig.damage)
```

**Updated:**
```lua
local damageResult = DamageCalculator.calculateDamage({
    attacker = attacker,
    target = targetModel,
    weaponName = weaponName,
    hitPart = nil, -- Melee doesn't track specific part yet
})

if damageResult.wasHit then
    targetHumanoid:TakeDamage(damageResult.finalDamage)

    -- Update feedback to use damageResult
    CombatFeedback.showDamage(
        targetModel,
        damageResult.finalDamage,
        weaponName,
        damageType,
        attacker -- Changed from attackingPlayer
    )
end
```

### 2. ProjectilePhysics.luau (Projectiles)

**Current (Line 136):**
```lua
humanoid:TakeDamage(weaponConfig.damage)
```

**Updated:**
```lua
local damageResult = DamageCalculator.calculateDamage({
    attacker = projectile.attacker,
    target = entity,
    weaponName = projectile.weapon,
    hitPart = raycastResult.Instance, -- Actual hit part from raycast
})

if damageResult.wasHit then
    humanoid:TakeDamage(damageResult.finalDamage)

    CombatFeedback.showDamage(
        entity,
        damageResult.finalDamage,
        projectile.weapon,
        damageType,
        projectile.attacker -- Changed from attackingPlayer
    )
end
```

### 3. EntityController.luau (NPC Damage)

**Current (Line 642):**
```lua
entity.humanoid:TakeDamage(damage)
```

**Updated:**
```lua
local damageResult = DamageCalculator.calculateDamage({
    attacker = attackerModel, -- Need to pass this through
    target = model,
    weaponName = damageSource or "Unknown",
    hitPart = hitPart, -- Need to pass this through
})

if damageResult.wasHit then
    entity.humanoid:TakeDamage(damageResult.finalDamage)

    CombatFeedback.showDamage(
        model,
        damageResult.finalDamage,
        damageSource,
        damageType,
        attackerModel -- Changed from attackingPlayer
    )
end
```

### 4. CombatFeedback.luau (Feedback Update)

**Current:**
```lua
function CombatFeedback.showDamage(
    targetModel: Model,
    damage: number?,
    damageSource: string?,
    damageType: DamageType?,
    attackingPlayer: Player?
)
```

**Updated:**
```lua
function CombatFeedback.showDamage(
    targetModel: Model,
    damage: number?,
    damageSource: string?,
    damageType: DamageType?,
    attackerModel: Model? -- Changed from attackingPlayer
)
    -- Derive player if needed
    local attackingPlayer = if attackerModel
        then Players:GetPlayerFromCharacter(attackerModel)
        else nil

    -- Rest of logic uses attackingPlayer as before
```

## Security Model

### Server-Side Authority ✅

**All damage calculations occur server-side:**
1. Client never sends damage values
2. Client only sends action requests (attack, aim direction)
3. Server validates all inputs before calculation
4. Server performs raycasts and hit detection
5. Server applies final damage to Humanoid

### Input Validation

**DamageCalculator validates:**
1. ✅ Attacker and target must be valid Model instances
2. ✅ Weapon must exist in GameConfig.weapons
3. ✅ Hit part must be child of target (if provided)
4. ✅ Stats must be server-stored (never from client)

**Validation Flow:**
```lua
function DamageCalculator.calculateDamage(input: DamageInput): DamageResult
    -- Validate attacker
    if not input.attacker or not input.attacker:IsA("Model") then
        warn("Invalid attacker model")
        return createMissResult()
    end

    -- Validate target
    if not input.target or not input.target:IsA("Model") then
        warn("Invalid target model")
        return createMissResult()
    end

    -- Validate weapon
    local weaponConfig = GameConfig.weapons[input.weaponName]
    if not weaponConfig then
        warn(`Invalid weapon: {input.weaponName}`)
        return createMissResult()
    end

    -- Validate hit part (if provided)
    if input.hitPart and not input.hitPart:IsDescendantOf(input.target) then
        warn("Hit part is not part of target")
        input.hitPart = nil -- Ignore invalid hit part
    end

    -- Proceed with calculation...
end
```

### Client-Side Prevention

**What clients CANNOT do:**
1. ❌ Cannot send damage values
2. ❌ Cannot modify weapon stats
3. ❌ Cannot fake hit locations
4. ❌ Cannot modify entity stats (future)
5. ❌ Cannot bypass damage calculations

**What clients CAN do:**
1. ✅ Request to attack (server validates)
2. ✅ Provide aim direction (server validates with LOS)
3. ✅ Select target (server validates range/LOS)
4. ✅ Receive damage feedback (visual only, no gameplay impact)

### Exploit Prevention

**Prevented exploits:**

1. **Damage Spoofing**
   - ✅ Client never sends damage values
   - ✅ All calculations server-side

2. **Hit Location Spoofing**
   - ✅ Server performs raycasts
   - ✅ Server validates hit part belongs to target
   - ✅ Invalid hit parts ignored (fallback to default multiplier)

3. **Stat Manipulation**
   - ✅ Stats stored server-side only
   - ✅ Stats never passed from client
   - ✅ Stats retrieved from server database/storage

4. **Weapon Config Tampering**
   - ✅ GameConfig exists server-side
   - ✅ Client has read-only replica
   - ✅ Server always uses authoritative config

5. **Infinite Damage**
   - ✅ All values from server configs
   - ✅ Multipliers clamped to reasonable ranges
   - ✅ Final damage validated before application

### Security Checklist

- [x] All damage calculations on server
- [x] Client never sends damage values
- [x] Weapon configs server-authoritative
- [x] Hit detection server-side (raycasts)
- [x] Input validation on all parameters
- [x] Stats stored server-side (Phase 2)
- [x] Hit parts validated as target descendants
- [x] Fallback to safe defaults on invalid input
- [x] No trust in client-provided data

## Data Flow

### Melee Attack Flow

```
1. Client: Tool.Activated (no damage data)
   ↓
2. Server: Receives activation event
   ↓
3. Server: CombatSystem.attemptMeleeAttack()
   ↓
4. Server: Validates range, facing, PvP
   ↓
5. Server: DamageCalculator.calculateDamage()
   ├─ Gets weapon damage from GameConfig
   ├─ Applies body part multiplier
   ├─ Applies stat modifiers (future)
   └─ Returns DamageResult
   ↓
6. Server: Humanoid:TakeDamage(result.finalDamage)
   ↓
7. Server: Replicates health change to clients
   ↓
8. Client: Sees health bar update (automatic replication)
```

### Projectile Attack Flow

```
1. Client: Tool.Activated + Target lock
   ↓
2. Server: Receives activation + locked target
   ↓
3. Server: Validates LOS, range, cooldown
   ↓
4. Server: ProjectileManager.spawnProjectile()
   ↓
5. Server: ProjectilePhysics updates (heartbeat)
   ├─ Performs raycast
   ├─ Detects hit part
   └─ Calls DamageCalculator.calculateDamage()
       ├─ Uses actual raycast hit part
       ├─ Applies body part multiplier
       ├─ Applies stat modifiers (future)
       └─ Returns DamageResult
   ↓
6. Server: Humanoid:TakeDamage(result.finalDamage)
   ↓
7. Server: Replicates health + projectile visual
   ↓
8. Client: Sees projectile + damage feedback
```

### NPC Attack Flow

```
1. Server: EntityController AI update
   ↓
2. Server: Detects target in range
   ↓
3. Server: performAttack() after cast duration
   ↓
4. Server: CombatSystem.attemptMeleeAttack() or spawns projectile
   ↓
5. Server: DamageCalculator.calculateDamage()
   ├─ Gets NPC weapon damage from GameConfig
   ├─ Applies multipliers
   └─ Returns DamageResult
   ↓
6. Server: Humanoid:TakeDamage(result.finalDamage)
   ↓
7. Server: Replicates to clients
   ↓
8. Client: Sees damage feedback
```

## Future Extensibility

### Phase 2: Stats System

**Storage:**
- Player stats stored in DataStore or ProfileService
- Entity stats defined in GameConfig
- Server loads stats on player join
- Stats never sent to client (except for UI display)

**Integration:**
```lua
-- Server loads player stats
local playerStats = DataStoreService:GetPlayerStats(player)

-- Pass to damage calculator
local damageResult = DamageCalculator.calculateDamage({
    attacker = attackerModel,
    target = targetModel,
    weaponName = "Axe",
    hitPart = hitPart,
    attackerStats = playerStats, -- NEW
    targetStats = targetStats,   -- NEW
})
```

### Phase 3: Advanced Combat

**Planned features:**
- Status effects (poison, bleed, burn)
- Damage over time (DoT)
- Shields and armor layers
- Elemental damage types (fire, ice, lightning)
- Resistances and weaknesses
- Weapon durability affecting damage
- Combo multipliers
- Parry/block mechanics

**All will integrate through DamageCalculator:**
```lua
export type DamageInput = {
    -- ... existing fields ...

    -- Phase 3 additions
    damageType: DamageType?,      -- "physical", "fire", "ice", "poison"
    canBeCritical: boolean?,      -- Some attacks can't crit
    ignoreArmor: boolean?,        -- Armor-piercing attacks
    statusEffects: {StatusEffect}?, -- Apply on hit
    weaponDurability: number?,    -- Affects damage
}
```

## Testing & Debugging

### Debug Mode

Enable detailed logging:
```lua
-- In DamageCalculator
local DEBUG = true

if DEBUG then
    print(`=== DAMAGE CALCULATION ===`)
    print(`Attacker: {input.attacker.Name}`)
    print(`Target: {input.target.Name}`)
    print(`Weapon: {input.weaponName}`)
    print(`Base Damage: {baseDamage}`)
    print(`Hit Location: {hitLocation}`)
    print(`Body Part Multiplier: {bodyMultiplier}`)
    print(`Final Damage: {finalDamage}`)
    print(`=========================`)
end
```

### Test Scenarios

**Test cases to validate:**
1. Player melee vs NPC (no hit part)
2. Player projectile vs NPC (with hit part)
3. NPC melee vs Player
4. NPC projectile vs Player
5. Player vs Player (PvP)
6. NPC vs NPC
7. Headshot bonus (2x damage)
8. Limb penalty (0.75x damage)
9. Invalid weapon name (returns 0 damage)
10. Invalid hit part (ignores, uses 1.0x)

### Performance Monitoring

**DamageCalculator should:**
- ✅ Execute in <1ms per calculation
- ✅ No memory leaks from event connections
- ✅ Minimal garbage collection impact
- ✅ No yield/wait operations
- ✅ Pure function (no side effects except logging)

## Summary

The **DamageCalculator** system provides:

1. ✅ **Centralized Logic** - Single source for all damage
2. ✅ **Server Security** - Client cannot manipulate damage
3. ✅ **Body Part System** - Hit location affects damage
4. ✅ **Future-Ready** - Stats system prepared
5. ✅ **Consistent** - Same logic for all entity types
6. ✅ **Extensible** - Easy to add new features
7. ✅ **Performant** - Lightweight calculations
8. ✅ **Debuggable** - Clear data flow and logging

All damage flows through one validated, server-authoritative system, ensuring fair and secure combat mechanics.
