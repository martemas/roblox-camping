## Stats & Leveling System - Implementation Plan

### 1. **Create Stats Module** (`src/shared/Stats.luau`)
Define stat types and utilities:
- **Stats type**: `{ strength, defense, accuracy, agility, critical, level, xp }`
- **Strength**: +2% damage per point
- **Defense**: -1.5% damage taken per point  
- **Accuracy**: +1% hit chance per point (base 95%)
- **Agility**: +1% dodge per point
- **Critical**: +0.5% crit chance per point (base 5%)
- `calculateLevelFromXP(xp)`: Determine level from XP total
- `getXPForNextLevel(currentLevel)`: XP needed (formula: 100 * level^1.5)
- `validateStats(stats, config)`: Check against caps
- **`scaleStatsForLevel(baseStats, level)`**: Scale entity stats based on level

### 2. **Update GameConfig** (`src/shared/GameConfig.luau`)
Add stats configuration section:
```lua
stats = {
    -- Starting stats (configurable per class in future)
    defaultStartingStats = { strength=5, defense=5, accuracy=5, agility=5, critical=5 },
    
    -- Stat caps
    maxStatValue = 50,
    
    -- Leveling
    statPointsPerLevel = 2,  -- Free allocation (players only)
    
    -- Entity level scaling (automatic for NPCs)
    entityStatScalingPerLevel = 0.1,  -- 10% increase per level
    entityStatPointsPerLevel = 1,  -- Auto-allocated evenly across stats
    
    -- XP rewards (base values, scale with victim level)
    xpRewards = {
        -- Base XP per entity type
        Wolf = 15,
        Bear = 30,
        Zombie = 20,
        Player = 50,  -- PvP base XP
        
        -- XP scales with defeated entity/player level
        xpLevelMultiplier = 1.5,  -- XP = baseXP * (1 + victimLevel * multiplier)
    },
    
    -- Entity XP earning (configurable per entity type)
    entityCanEarnXP = {
        Wolf = false,  -- Wildlife doesn't level up
        Bear = false,
        Zombie = true,  -- Zombies can level up over time
    },
}

-- Add to wildlife/enemies config
wildlife = {
    Wolf = {
        -- ... existing config ...
        baseStats = { strength=3, defense=2, accuracy=5, agility=6, critical=1 },
    },
}

enemies = {
    Zombie = {
        -- ... existing config ...
        baseStats = { strength=4, defense=3, accuracy=4, agility=3, critical=2 },
        canEarnXP = true,  -- This zombie can level up
    },
}
```

### 3. **Create PlayerStats Module** (`src/server/PlayerStats.server.luau`)
Server-authoritative stat manager:
- `loadPlayerStats(player)`: Load from DataStore or create default
- `savePlayerStats(player)`: Persist to DataStore
- **API: `awardXP(player, amount, source?)`** - Public API for external games
- **API: `getPlayerStats(player): Stats?`** - Returns stats (includes level, xp)
- **API: `getPlayerLevel(player): number`** - Returns current level
- `onLevelUp(player)`: Grant stat points, fire event to client
- **API: `allocateStatPoint(player, statName)`** - Player chooses stat (validates caps)
- Remote events: `RequestStatIncrease`, `LevelUpNotification`
- Track unallocated stat points (carry over if player doesn't allocate immediately)

### 4. **Update DamageCalculator** (`src/shared/DamageCalculator.luau`)
Implement stat-based combat (already has placeholders):
- `applyStatModifiers(baseDamage, attackerStats?, targetStats?)`: 
  - Apply strength bonus to damage
  - Apply defense reduction to damage taken
  - Return modified damage
- `rollHitChance(attackerStats?, targetStats?)`: 
  - Base 95% + accuracy - agility
  - Clamp between 5%-99%
  - Return boolean (hit/miss)
- `rollCriticalHit(attackerStats?)`:
  - Base 5% + critical stat bonus
  - Return boolean (crit/normal)
- Update `calculateDamage()` to call these functions
- **Stats passed as optional parameters** (nil stats = no bonuses, base values only)

### 5. **Entity Stats & Leveling** (`src/shared/EntityController.luau`)
Entities can have levels, XP, and level up:
- Add to `EntityInstance` type: `level: number, xp: number, baseStats: Stats`
- **API: `EntityController.awardEntityXP(model, amount, source?)`** - Give XP to entity
- **API: `EntityController.setEntityLevel(model, level)`** - Set entity level (scales stats)
- **API: `EntityController.getEntityStats(model): Stats?`** - Returns scaled stats
- **API: `EntityController.getEntityLevel(model): number`** - Returns entity level
- `initializeEntity()`: 
  - Load base stats from GameConfig (per entity type)
  - Default level = 1 (or configurable per spawn)
  - Scale stats using `Stats.scaleStatsForLevel(baseStats, level)`
- `onEntityLevelUp(entity)`:
  - Auto-allocate stat points evenly across all stats
  - Visual effect (particle, sound)
  - Scale stats automatically
- Check `canEarnXP` config flag before awarding XP to entities

### 6. **Update Integration Points** (Pass stats to DamageCalculator)
Wire stats into existing combat:
- `CombatSystem.attemptMeleeAttack()`: 
  - Lookup: `PlayerStats.getPlayerStats(attacker)` or `EntityController.getEntityStats(attacker)`
  - Pass to `DamageCalculator.calculateDamage({ ..., attackerStats, targetStats })`
- `CombatSystem.performHitscan()`: Same pattern
- `CombatSystem.performAOEAttack()`: Same pattern
- `CombatSystem.applyDamageToEntity()`: Same pattern
- **XP Rewards on Death** (Humanoid.Died event):
  - Identify victim: Player or Entity
  - Identify attacker: Player or Entity
  - Get victim's level and type
  - Calculate XP: `baseXP * (1 + victimLevel * xpLevelMultiplier)`
  - **If attacker is Player**: Call `PlayerStats.awardXP(attackerPlayer, scaledXP, source)`
  - **If attacker is Entity AND canEarnXP**: Call `EntityController.awardEntityXP(attackerEntity, scaledXP, source)`
- Update `DamageResult` type to include `{ wasCritical, wasDodged }`
- Track last attacker on each entity/player for XP credit

### 7. **Create Stats UI** (`src/client/StatsUI.client.luau`)
Easy to use, clean interface (sample implementation):
- **XP bar** showing progress to next level (large, clear)
- **Stats panel** (toggleable) showing current stats with tooltips
- **Level-up modal** with large buttons to allocate points
  - Big "+1" buttons next to each stat
  - Shows remaining points to allocate
  - Clear visual feedback on selection
- Listen for `LevelUpNotification` remote event
- Best practice example for other developers to extend

### 8. **Update CombatFeedback** (`src/shared/CombatFeedback.luau`)
Show stat-based outcomes:
- "CRITICAL!" indicator for crits (larger, gold text, particle effect)
- "MISS!" indicator for missed attacks (white text)
- "DODGE!" indicator for evaded attacks (cyan text, dodge animation)
- "+XP" floating text on kills (shows XP gained)
- Different colors/sizes/effects for each type

**Architecture Decisions:**
✓ **Stats passed to DamageCalculator** (keeps it pure, testable, flexible)
✓ **API-first**: `awardXP()`, `awardEntityXP()`, `getPlayerStats()`, `setEntityLevel()` for external games
✓ **Config-driven**: All numbers in GameConfig (extensible for classes, entity types)
✓ **Manual allocation (players)**: Players freely choose stats on level-up
✓ **Auto-allocation (entities)**: Entities auto-distribute stat points evenly
✓ **Entity XP configurable**: Each entity type can opt-in to XP earning
✓ **Level-based XP rewards**: XP scales with victim level
✓ **Server-authoritative**: All stat validation server-side
✓ **User friendly UI**: Clear, easy to use, sample implementation