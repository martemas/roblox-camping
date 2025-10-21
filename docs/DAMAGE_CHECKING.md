# Damage Checking & Friendly Fire System

## Problem Statement

Wildlife entities (e.g., Wolves) are damaging each other when attacking players. When multiple wolves attack a player, they hit all entities within their melee range, including other wolves, causing unintended friendly fire.

## Root Cause Analysis

**Location:** `src/server/Combat/CombatSystem.luau`

**Issue Chain:**
1. `GameConfig.combat.damageTargetOnly = false` - Allows multi-target melee attacks
2. Line 374 in `attemptMeleeAttack()` - When `damageTargetOnly` is false, enters "Mode B"
3. Line 385 - Calls `findEntitiesInRange(attackerPos, weaponConfig.range, attacker)`
4. Lines 307-331 - `findEntitiesInRange()` returns ALL entities within range, only excluding attacker
5. Lines 393-452 - Attack loop damages every entity without checking faction/type

**Current Behavior:**
```
Wolf A attacks Player
└─> findEntitiesInRange() finds: [Player, Wolf B, Wolf C]
    └─> All 3 entities take damage ❌
```

## Phase 1 Solution: EntityType-Based Friendly Fire Prevention

### Overview
Prevent entities of the same type from damaging each other by checking the `EntityType` attribute.

### Entity Types (from `Entities.luau`)
- `"Wildlife"` - Wolf, Bear (won't damage each other)
- `"Creature"` - Zombie (won't damage other Creatures)
- `"NPC"` - TownGuard (won't damage other NPCs)
- `"Structure"` - Buildings
- `"Resource"` - Trees, Rocks
- `"Player"` - Player characters

### Implementation Changes

#### 1. Update `shouldAffectEntity()` Function

**Location:** `src/server/Combat/CombatSystem.luau:476-508`

**Current Code:**
```lua
elseif targetFilter == "enemies" then
    -- Only affect enemies (different player or NPCs)
    if entity == attacker then
        return false
    end
    if entityPlayer and attackerPlayer and entityPlayer == attackerPlayer then
        return false
    end
    return true  -- ❌ Allows all damage
end
```

**Updated Code:**
```lua
elseif targetFilter == "enemies" then
    -- Only affect enemies (different player or NPCs)
    if entity == attacker then
        return false
    end
    if entityPlayer and attackerPlayer and entityPlayer == attackerPlayer then
        return false
    end

    -- Prevent friendly fire between same entity types
    if not entityPlayer and not attackerPlayer then
        local entityType = entity:GetAttribute("EntityType")
        local attackerType = attacker:GetAttribute("EntityType")

        -- Wildlife don't damage Wildlife, Creatures don't damage Creatures, etc.
        if entityType and attackerType and entityType == attackerType then
            return false
        end
    end

    return true
end
```

#### 2. Update `findEntitiesInRange()` Function

**Location:** `src/server/Combat/CombatSystem.luau:307-331`

**Current Signature:**
```lua
local function findEntitiesInRange(
    origin: vector,
    range: number,
    excludeModel: Model?
): {Model}
```

**New Signature:**
```lua
local function findEntitiesInRange(
    origin: vector,
    range: number,
    excludeModel: Model?,
    attacker: Model?,        -- For faction checking
    targetFilter: string?    -- "enemies", "allies", "all"
): {Model}
```

**Logic Addition (after line 324):**
```lua
for _, part in parts do
    local entity = findEntityFromPart(part)
    if entity and not seen[entity] and entity ~= excludeModel then
        -- Apply target filtering if attacker is provided
        if attacker and targetFilter then
            if not shouldAffectEntity(entity, attacker, targetFilter) then
                continue  -- Skip this entity
            end
        end

        seen[entity] = true
        table.insert(entities, entity)
    end
end
```

#### 3. Update `attemptMeleeAttack()` Call

**Location:** `src/server/Combat/CombatSystem.luau:385`

**Current Code:**
```lua
else
    -- Mode B: Damage all entities in range
    targetsToCheck = findEntitiesInRange(attackerPos, weaponConfig.range, attacker)
end
```

**Updated Code:**
```lua
else
    -- Mode B: Damage all entities in range
    -- Use weapon's targetFilter if specified, otherwise default to "enemies"
    local targetFilter = weaponConfig.targetFilter or "enemies"
    targetsToCheck = findEntitiesInRange(attackerPos, weaponConfig.range, attacker, attacker, targetFilter)
end
```

### Expected Behavior After Phase 1

```
Wolf A attacks with WolfClaw (melee, range 10)
└─> findEntitiesInRange() finds: [Player, Wolf B, Wolf C]
    └─> shouldAffectEntity() checks each:
        ├─> Player: EntityType="Player" ≠ "Wildlife" → ✅ Damage
        ├─> Wolf B: EntityType="Wildlife" = "Wildlife" → ❌ Skip
        └─> Wolf C: EntityType="Wildlife" = "Wildlife" → ❌ Skip
```

### Test Cases for Phase 1

| Attacker | Target | Same EntityType? | Result |
|----------|--------|------------------|--------|
| Wolf | Player | No (Wildlife ≠ Player) | ✅ Damage |
| Wolf | Wolf | Yes (Wildlife = Wildlife) | ❌ No damage |
| Wolf | Zombie | No (Wildlife ≠ Creature) | ✅ Damage |
| Zombie | Zombie | Yes (Creature = Creature) | ❌ No damage |
| Player | Wolf | No (Player ≠ Wildlife) | ✅ Damage |
| Player | Player | Yes (Player = Player) | ❌ No damage* |

*Note: Player vs Player is also controlled by `GameConfig.combat.pvpEnabled`

### Files Modified (Phase 1)
- `src/server/Combat/CombatSystem.luau` (3 changes)

---

## Phase 2 Solution: Team-Aware System (Future)

### Overview
Implement full team support for PvP gameplay while maintaining entity-type friendly fire prevention.

### Limitations of Phase 1

**Problem:** All players have `EntityType = "Player"`, so in team-based PvP:
- Team Red players couldn't damage Team Blue players (same EntityType)
- OR all players could damage each other (breaking friendly fire for co-op)

### Team System Design

#### Team Hierarchy
```
Priority 1: Team Attribute (explicit team assignment)
Priority 2: Roblox Native Team (player.Team)
Priority 3: EntityType (fallback for neutral entities)
```

#### Helper Function: `getEntityTeam()`

```lua
-- Get entity's team/faction for damage calculations
local function getEntityTeam(entity: Model): string?
    -- Priority 1: Check for explicit Team attribute (custom teams)
    local team = entity:GetAttribute("Team")
    if team then
        return team  -- e.g., "Red", "Blue", "Team1", "Team2"
    end

    -- Priority 2: Check Roblox native team system
    local player = Players:GetPlayerFromCharacter(entity)
    if player and player.Team then
        return player.Team.Name  -- e.g., "Red Team", "Blue Team"
    end

    -- Priority 3: Fallback to EntityType for neutral entities
    local entityType = entity:GetAttribute("EntityType")
    if entityType then
        return entityType  -- e.g., "Wildlife", "Creature"
    end

    return nil
end
```

#### Updated `shouldAffectEntity()` with Team Support

```lua
local function shouldAffectEntity(entity: Model, attacker: Model, targetFilter: string?): boolean
    if not targetFilter or targetFilter == "all" then
        return true
    end

    local entityPlayer = Players:GetPlayerFromCharacter(entity)
    local attackerPlayer = Players:GetPlayerFromCharacter(attacker)

    if targetFilter == "allies" then
        -- Only affect allies (same team/faction)
        if entity == attacker then
            return true
        end

        local entityTeam = getEntityTeam(entity)
        local attackerTeam = getEntityTeam(attacker)

        if entityTeam and attackerTeam and entityTeam == attackerTeam then
            return true  -- Same team/faction
        end

        return false

    elseif targetFilter == "enemies" then
        -- Only affect enemies (different team/faction)
        if entity == attacker then
            return false  -- Never damage self
        end

        local entityTeam = getEntityTeam(entity)
        local attackerTeam = getEntityTeam(attacker)

        -- Both have team assignment - check if different
        if entityTeam and attackerTeam then
            if entityTeam == attackerTeam then
                -- Same team - check friendly fire setting
                return GameConfig.combat.friendlyFireEnabled or false
            else
                -- Different teams - can damage
                return true
            end
        end

        -- One or both don't have team - allow damage
        return true
    end

    return true
end
```

### Team Assignment Methods

#### Method 1: Roblox Native Teams (Recommended for Player PvP)
```lua
-- Setup in game
game.Teams:FindFirstChild("Red Team") or Instance.new("Team", {
    Name = "Red Team",
    TeamColor = BrickColor.new("Bright red"),
    Parent = game.Teams
})

-- Assign player on join
player.Team = game.Teams:FindFirstChild("Red Team")
```

**Pros:**
- Native UI support (player list, nametags)
- Built-in spawn location support
- Automatic player.TeamColor

#### Method 2: Custom Team Attribute (Flexible for NPCs)
```lua
-- Set on any entity (player character or NPC)
characterModel:SetAttribute("Team", "Red")
characterModel:SetAttribute("Team", "Blue")
```

**Pros:**
- Works for NPCs and players
- More flexible (can have many teams)
- Doesn't require Roblox Team objects

#### Method 3: Hybrid (Recommended)
- Use Roblox Teams for players (UI, spawns, etc.)
- Use Team attribute for NPCs aligned with teams
- Use EntityType fallback for neutral entities

### Configuration

**Add to `GameConfig.luau`:**
```lua
combat = {
    pvpEnabled = true,
    friendlyFireEnabled = false,  -- NEW: Allow same-team damage?
    damageTargetOnly = false,
    -- ... existing config
}
```

### Example Scenarios with Teams

#### Scenario 1: Team-Based PvP Match

```
Setup:
- Player Alice: Team = "Red"
- Player Bob: Team = "Blue"
- NPC Guard: Team = "Red", EntityType = "NPC"
- Wolf: EntityType = "Wildlife" (no Team)

Red Guard attacks:
├─> Alice (Team=Red) → ❌ No damage (same team, friendlyFire=false)
├─> Bob (Team=Blue) → ✅ Damage (different team)
└─> Wolf (no team) → ✅ Damage (no team = enemy)

Wolf attacks:
├─> Alice (Team=Red) → ✅ Damage (Wildlife ≠ Player team)
├─> Bob (Team=Blue) → ✅ Damage (Wildlife ≠ Player team)
├─> Red Guard (Team=Red) → ✅ Damage (Wildlife ≠ Red)
└─> Wolf B (EntityType=Wildlife) → ❌ No damage (same EntityType)
```

#### Scenario 2: Co-op PvE (Current Behavior)

```
Setup:
- Player 1: No Team attribute, EntityType = "Player"
- Player 2: No Team attribute, EntityType = "Player"
- Wolf: EntityType = "Wildlife"

Wolf attacks:
├─> Player 1 → ✅ Damage (Wildlife ≠ Player)
└─> Player 2 → ✅ Damage (Wildlife ≠ Player)

Wolf A attacks:
└─> Wolf B (EntityType=Wildlife) → ❌ No damage (same EntityType)

Player 1 attacks:
└─> Player 2 → Based on pvpEnabled setting
```

### Test Matrix for Phase 2

| Attacker | Attacker Team | Target | Target Team | Friendly Fire | Result |
|----------|---------------|--------|-------------|---------------|--------|
| Red Player | Red | Blue Player | Blue | false | ✅ Damage (different teams) |
| Red Player | Red | Red Player 2 | Red | false | ❌ No damage (same team) |
| Red Player | Red | Red Player 2 | Red | true | ✅ Damage (friendly fire on) |
| Red NPC | Red | Blue Player | Blue | false | ✅ Damage (different teams) |
| Wolf | Wildlife | Red Player | Red | false | ✅ Damage (different types) |
| Wolf | Wildlife | Wolf B | Wildlife | false | ❌ No damage (same type) |
| Player | (none) | Player 2 | (none) | false | ❌ No damage (same type) |

### Migration Path

Phase 1 → Phase 2 is **forward-compatible**:

1. **Phase 1** uses `EntityType` for team detection
2. **Phase 2** adds `Team` attribute with priority over `EntityType`
3. Existing code continues to work:
   - Entities without `Team` attribute fall back to `EntityType`
   - Wildlife continues to use `EntityType="Wildlife"`
   - No breaking changes required

### Implementation Checklist for Phase 2

- [ ] Add `getEntityTeam()` helper function
- [ ] Update `shouldAffectEntity()` to use `getEntityTeam()`
- [ ] Add `friendlyFireEnabled` to `GameConfig.luau`
- [ ] Update friendly fire logic with config check
- [ ] Set up Roblox Teams (if using native teams)
- [ ] Add team assignment on player spawn
- [ ] Add team synchronization for player characters
- [ ] Test all scenarios in test matrix
- [ ] Update NPC spawning to support Team attribute
- [ ] Document team assignment for level designers

---

## Implementation Order

### Immediate (Phase 1)
1. Fix wildlife friendly fire with EntityType checking
2. Test with multiple wolves attacking player
3. Verify other entity types (Zombies, NPCs)

### Future (Phase 2)
1. Design team system requirements with game designers
2. Implement `getEntityTeam()` helper
3. Add team-aware `shouldAffectEntity()` logic
4. Add friendly fire configuration
5. Set up team assignment systems
6. Test PvP scenarios

---

## Notes & Considerations

### Naming Conventions
- Use `weaponId` (not `weaponName`) when referring to weapon unique identifiers
- Keep variable names consistent with codebase standards

### Performance
- `GetAttribute()` calls are cached by Roblox, minimal performance impact
- `getEntityTeam()` could be memoized if needed for high-frequency calls

### Edge Cases
- What if entity has Team but attacker doesn't? → Allow damage (Phase 2)
- What if both have no team? → Use EntityType fallback
- Self-damage? → Always prevented (entity == attacker check)
- Structures? → Typically don't attack, but would use Team if set

### Alternative Approaches Considered

1. **Weapon-level friendly fire toggle**
   - Add `allowFriendlyFire` to each weapon config
   - Rejected: Too granular, harder to maintain

2. **Explicit faction enum**
   - Define factions: PLAYER_RED, PLAYER_BLUE, WILDLIFE, etc.
   - Rejected: Less flexible than attribute-based system

3. **Distance-based (closest enemy priority)**
   - Only hit closest different-type entity
   - Rejected: Doesn't solve root cause, changes game feel

---

## References

- **EntityType Values:** `src/shared/Data/Entities/Entities.luau:5`
- **Combat Config:** `src/server/Config/GameConfig.luau:39`
- **Combat System:** `src/server/Combat/CombatSystem.luau`
- **Entity Controller:** `src/server/Entities/EntityController.luau`

---

*Document created: 2025-01-XX*
*Last updated: 2025-01-XX*
*Status: Phase 1 pending implementation*
