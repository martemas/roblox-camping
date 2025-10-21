# Damage & XP System Guide

## Overview

The Roblox Camping game uses a **centralized damage and XP system** that handles all combat interactions, stat-based calculations, and experience point rewards. All damage flows through a single point (`CombatSystem.applyDamageToEntity`) to ensure consistency, security, and proper XP tracking.

## Core Architecture

### Centralized Damage Flow

```
Attack Source → StatsProvider.getStats() → CombatSystem.applyDamageToEntity() → Target
    ↓                                              ↓
  [Fetch Stats]                        [Stats] → [DamageCalculator] → [XP Tracking] → [Feedback]
```

**All weapon types use the same centralized system:**
- ✅ Melee attacks (Sword, Axe, Pickaxe)
- ✅ Projectile attacks (Bow, Magic)
- ✅ Hitscan attacks (Guns, lasers)
- ✅ AOE attacks (Explosions, zones)

### StatsProvider Module

**Purpose:** Unified interface for retrieving stats from any entity (player or NPC)

**Location:** `src/shared/StatsProvider.luau`

**Why it exists:** Eliminates circular dependencies between combat systems and stat management

```lua
local StatsProvider = require(ReplicatedStorage.Engine.StatsProvider)

-- Get stats for any entity (player character or NPC)
local stats = StatsProvider.getStats(model)
-- Returns: Stats? (nil if entity has no stats)

-- Check if model is a player character
local player = StatsProvider.getPlayerFromModel(model)
-- Returns: Player? (nil if not a player character)
```

**How it works:**
- For player characters: Fetches from `PlayerStats` module (server-side)
- For NPC entities: Fetches from `EntityController` module
- Returns `nil` for unknown/invalid entities

**Performance:** O(1) hash table lookups, no performance impact even with hundreds of simultaneous attacks

## Stats System

### Stat Types

The game uses **4 primary stats**:

| Stat | Effect |
|------|--------|
| **Strength** | Physical damage (+2% per point), Defense (+0.75% per point with stamina), Critical multiplier (+1% per point) |
| **Magic** | Magic damage, spell effectiveness (future) |
| **Stamina** | Max HP (+10 HP per point), Defense (+0.75% per point with strength) |
| **Accuracy** | Hit chance (+1% per point), Dodge chance (+1% per point), Critical chance (+0.5% per point) |

### Derived Stats

Derived stats are **automatically calculated** from primary stats:

```lua
-- From src/shared/Stats.luau
function Stats.getDerivedStats(stats: Stats): DerivedStats
    return {
        physicalDamageBonus = 1.0 + (stats.strength * 0.02),
        magicDamageBonus = 1.0 + (stats.magic * 0.02),
        defense = (stats.strength + stats.stamina) * 0.0075,
        maxHealthBonus = stats.stamina * 10,
        hitChance = 0.95 + (stats.accuracy * 0.01),
        dodgeChance = stats.accuracy * 0.01,
        criticalChance = 0.05 + (stats.accuracy * 0.005),
        critMultiplier = 1.5 + (stats.strength * 0.01),
    }
end
```

### Customizing Stats Formulas

**Location:** `src/shared/Stats.luau`

All combat formulas are centralized here for easy balance adjustments:

```lua
-- Example: Increase strength bonus from +2% to +3% per point
physicalDamageBonus = 1.0 + (stats.strength * 0.03)  -- Changed from 0.02

-- Example: Make stamina give more HP (+20 HP per point)
maxHealthBonus = stats.stamina * 20  -- Changed from 10

-- Example: Reduce crit chance scaling
criticalChance = 0.05 + (stats.accuracy * 0.003)  -- Changed from 0.005
```

### Player Stats Configuration

**Location:** `src/shared/GameConfig.luau` → `stats` section

```lua
stats = {
    -- Starting stats for new players
    defaultStartingStats = {
        strength = 5,
        magic = 5,
        stamina = 5,
        accuracy = 5,
    },

    -- Maximum value for any stat
    maxStatValue = 50,

    -- Stat points awarded per level
    statPointsPerLevel = 2,

    -- Entity stats scale with level (10% per level)
    entityStatScalingPerLevel = 0.1,
},
```

### Entity Stats Configuration

**Location:** `src/shared/GameConfig.luau` → `wildlife`/`enemies` sections

```lua
wildlife = {
    Wolf = {
        health = 100,
        damage = 15,
        range = 3,

        -- NEW: Base stats for wolves
        baseStats = {
            strength = 8,
            magic = 0,
            stamina = 5,
            accuracy = 10,
        },
    },
},
```

**Stats scale with entity level:**
```lua
-- A level 5 wolf with 10% scaling per level:
-- strength = 8 * (1 + 5 * 0.1) = 12
-- stamina = 5 * (1 + 5 * 0.1) = 7.5
```

## XP System

### XP Formula

XP required for each level is calculated using a **power curve** (rounded to nearest 100):

```lua
-- From src/shared/Stats.luau
function Stats.getXPForNextLevel(level: number): number
    return math.floor(100 * level^1.5 / 100) * 100
end

-- Examples:
-- Level 1 → 2: 100 XP
-- Level 2 → 3: 200 XP
-- Level 3 → 4: 500 XP
-- Level 5 → 6: 1100 XP
-- Level 10 → 11: 3100 XP
```

### XP Rewards

**Location:** `src/shared/GameConfig.luau` → `stats.xpRewards`

```lua
stats = {
    xpRewards = {
        -- Base XP per entity type
        Wolf = 15,
        Bear = 30,
        Zombie = 20,
        Player = 50,  -- PvP reward
    },

    -- XP scales with victim level
    xpLevelMultiplier = 1.5,  -- 50% more XP per victim level

    -- Which entities can earn XP
    entityCanEarnXP = {
        Wolf = false,   -- Wolves don't level up
        Bear = false,   -- Bears don't level up
        Zombie = true,  -- Zombies can level up!
        Player = false, -- Not applicable
    },
},
```

### XP Reward Calculation

```lua
-- From src/shared/Stats.luau
function Stats.calculateXPReward(victimType: string, victimLevel: number): number
    local baseXP = GameConfig.stats.xpRewards[victimType] or 10
    local levelBonus = (victimLevel - 1) * GameConfig.stats.xpLevelMultiplier
    return math.floor(baseXP + levelBonus)
end

-- Example: Killing a level 5 bear
-- baseXP = 30
-- levelBonus = (5 - 1) * 1.5 = 6
-- Total XP = 30 + 6 = 36 XP
```

### Customizing XP Rewards

```lua
-- Make wolves give more XP
xpRewards = {
    Wolf = 25,  -- Changed from 15
}

-- Reduce level scaling
xpLevelMultiplier = 1.0,  -- Changed from 1.5 (now +1 XP per level)

-- Make zombies not earn XP
entityCanEarnXP = {
    Zombie = false,  -- Changed from true
}
```

### XP Tracking & Last Attacker

The system tracks the **last attacker** for 10 seconds to award XP on kill:

```lua
stats = {
    lastAttackerExpiry = 10,  -- Seconds before last attacker credit expires
}
```

**How it works:**
1. Player hits enemy → System tracks player as "last attacker" with 10s timer
2. If enemy dies within 10s → Player gets XP
3. If another player hits the enemy → They become the new "last attacker"
4. If 10s pass without damage → XP credit expires

## Damage Calculation

### Damage Flow

```
1. Weapon Base Damage
   ↓
2. Hit/Dodge Roll (based on accuracy)
   ↓
3. Critical Hit Roll (if hit)
   ↓
4. Apply Damage Multipliers (stats, crits, hit location)
   ↓
5. Apply Defense Reduction
   ↓
6. Final Damage
```

### Weapon Configuration

**Location:** `src/shared/GameConfig.luau` → `weapons` section

```lua
weapons = {
    Sword = {
        type = "melee",
        damage = 20,
        range = 5,
        cooldown = 1.0,
        castDuration = 0.3,

        -- Damage type affects which stat bonus applies
        damageType = "physical",  -- Uses physicalDamageBonus from strength

        requiresTarget = false,
    },
}
```

### Hit Location Multipliers

**Location:** `src/shared/DamageCalculator.luau`

```lua
local HIT_LOCATION_MULTIPLIERS = {
    Head = 2.0,      -- Headshots deal 2x damage
    Torso = 1.0,     -- Normal damage
    LeftArm = 0.8,   -- Limbs deal 80% damage
    RightArm = 0.8,
    LeftLeg = 0.8,
    RightLeg = 0.8,
    unknown = 1.0,   -- Default multiplier
}
```

**Customize hit location damage:**
```lua
-- Make headshots more rewarding
Head = 3.0,  -- Changed from 2.0

-- Make limb shots less penalized
LeftArm = 0.9,  -- Changed from 0.8
```

### Critical Hits

Critical hits deal **1.5x base damage** (+ strength bonus):

```lua
-- Critical multiplier formula (from Stats.luau)
critMultiplier = 1.5 + (stats.strength * 0.01)

-- Example: Player with 20 strength
-- critMultiplier = 1.5 + (20 * 0.01) = 1.7x damage
```

**Critical hit chance:**
```lua
-- Base 5% + 0.5% per accuracy point
criticalChance = 0.05 + (stats.accuracy * 0.005)

-- Example: Player with 30 accuracy
-- critChance = 0.05 + (30 * 0.005) = 0.20 (20% crit chance)
```

## Using the Damage System

### Basic Damage Application

**ALWAYS use the centralized function with stats:**

```lua
local CombatSystem = require(ReplicatedStorage.Engine.CombatSystem)
local StatsProvider = require(ReplicatedStorage.Engine.StatsProvider)

-- Get stats for both attacker and target
local attackerStats = StatsProvider.getStats(attacker)
local targetStats = StatsProvider.getStats(target)

local result = CombatSystem.applyDamageToEntity(
    attacker,      -- Model: The attacking entity
    target,        -- Model: The target entity
    weaponName,    -- string: Weapon config name (e.g., "Sword")
    {
        -- Stats (required for proper damage calculation):
        attackerStats = attackerStats,     -- Stats?: Attacker's stats
        targetStats = targetStats,         -- Stats?: Target's stats

        -- Optional parameters:
        damageOverride = nil,              -- number?: Override calculated damage
        hitPart = nil,                     -- BasePart?: Specific body part hit
        bypassInvulnerability = false,     -- boolean?: Skip invuln check
        bypassPvP = false,                 -- boolean?: Skip PvP check
        attackingPlayer = nil,             -- Player?: Override attacker player
        onDamageCallback = nil,            -- function?: Callback after damage applied
    }
)

-- Result structure:
-- {
--     success: boolean,
--     damage: number?,
--     failureReason: string?,  -- "no_humanoid" | "pvp_blocked" | "invulnerable" | "dodged" | "no_weapon_config"
--     wasDodged: boolean,
--     wasCritical: boolean,
--     blockedByInvulnerability: boolean,
--     blockedByPvP: boolean,
-- }
```

### Example: Custom Spell with Bypass Options

```lua
local StatsProvider = require(ReplicatedStorage.Engine.StatsProvider)

-- Get stats
local casterStats = StatsProvider.getStats(caster)
local allyStats = StatsProvider.getStats(ally)

-- Healing spell that bypasses PvP restrictions
local result = CombatSystem.applyDamageToEntity(caster, ally, "HealingSpell", {
    attackerStats = casterStats,
    targetStats = allyStats,
    damageOverride = -50,  -- Negative damage = healing
    bypassPvP = true,      -- Allow healing allies even if PvP is disabled
    bypassInvulnerability = true,  -- Can heal through invulnerability
})

if result.success then
    print(`Healed {ally.Name} for {math.abs(result.damage)} HP`)
end
```

### Example: Environmental Damage

```lua
local StatsProvider = require(ReplicatedStorage.Engine.StatsProvider)

-- Lava damage (no attacker, no XP)
-- attackerStats = nil since environment has no stats
local targetStats = StatsProvider.getStats(player.Character)

local result = CombatSystem.applyDamageToEntity(
    workspace.Lava,  -- Use environment as "attacker"
    player.Character,
    "Lava",
    {
        attackerStats = nil,       -- No attacker stats (environmental)
        targetStats = targetStats,  -- Target stats for defense calculation
        damageOverride = 10,
        bypassPvP = true,  -- Environmental damage ignores PvP
    }
)
```

### Example: Checking Failure Reason

```lua
local attackerStats = StatsProvider.getStats(attacker)
local targetStats = StatsProvider.getStats(target)

local result = CombatSystem.applyDamageToEntity(attacker, target, "Sword", {
    attackerStats = attackerStats,
    targetStats = targetStats,
})

if not result.success then
    if result.blockedByPvP then
        print("Cannot attack this player (PvP disabled)")
    elseif result.blockedByInvulnerability then
        print("Target is invulnerable")
    elseif result.wasDodged then
        print("Attack was dodged!")
    end
end
```

### Example: AOE Attack (Multi-Target Efficiency)

```lua
local StatsProvider = require(ReplicatedStorage.Engine.StatsProvider)

-- Get attacker stats ONCE for efficiency (reused across all targets)
local attackerStats = StatsProvider.getStats(attacker)

local hits = CombatSystem.performAOEAttack(
    attacker,
    targetPosition,
    "Fireball",
    player,
    {
        attackerStats = attackerStats,  -- Fetched once, reused for all targets
        -- CombatSystem fetches target stats per-target automatically
    }
)

print(`Hit {#hits} entities with Fireball`)
```

**Performance Note:** In AOE attacks, attacker stats are fetched once and reused across all targets. Target stats are fetched per-target (necessary since each target is different). This pattern ensures optimal performance even with large AOE radius hitting many targets.

## Invulnerability System

**Purpose:** Prevents spam-damage from rapid attacks

**Duration:** Configured in `GameConfig.combat.invulnerabilityDuration`

```lua
combat = {
    invulnerabilityDuration = 0.5,  -- 0.5 seconds of invulnerability after being hit
}
```

**How it works:**
1. Entity takes damage from weapon "Sword"
2. Entity becomes invulnerable to "Sword" for 0.5s
3. During this time, all "Sword" attacks are blocked
4. After 0.5s, entity can be hit by "Sword" again

**Per-weapon invulnerability:** Each weapon has its own invulnerability timer, so you can be invulnerable to "Sword" but still take damage from "Bow".

## PvP System

**Location:** `src/shared/GameConfig.luau` → `combat.pvpEnabled`

```lua
combat = {
    pvpEnabled = false,  -- Players cannot damage each other
}
```

**How it works:**
- When `pvpEnabled = false`: Players can only damage NPCs
- When `pvpEnabled = true`: Players can damage each other
- Always applies to `applyDamageToEntity` unless `bypassPvP = true`

## Data Persistence

**System:** ProfileStore (wrapper around DataStore)

**Location:** `src/server/PlayerStats.luau`

**Stored data:**
```lua
{
    stats = {
        strength = number,
        magic = number,
        stamina = number,
        accuracy = number,
    },
    level = number,
    xp = number,
    unallocatedStatPoints = number,
}
```

**Profile Store Configuration:**
```lua
local PROFILE_STORE_NAME = "PlayerData_v1"  -- Change version to reset all player data
```

⚠️ **Warning:** Changing `PROFILE_STORE_NAME` will reset ALL player data. Only change during development/testing.

## UI System

### XP Bar

**Location:** On-screen at bottom (above hotbar)

**Features:**
- Green progress bar shows XP progress to next level
- Text shows current level and XP fraction
- Animates smoothly when XP is gained
- Popup notification shows "+X XP" when earned

**Configuration:**
```lua
-- In src/client/StatsUI.client.luau
local XP_BAR_POSITION = UDim2.new(0.3, 0, 0.88, 0)  -- 30% from left, 88% from top
local ANIMATION_DURATION = 0.3  -- XP bar animation speed
```

### Stats Panel

**Toggle:** Press `C` key

**Features:**
- Shows all 4 stats with current values
- Displays derived bonuses (damage %, HP +, crit %, etc.)
- Shows unallocated stat points
- Click `+` buttons to allocate points
- Server validates all stat increases

**Changing Hotkey:**
```lua
-- In src/client/StatsUI.client.luau
local STATS_PANEL_HOTKEY = Enum.KeyCode.C  -- Change to any key
```

### Level Up Modal

**Trigger:** Automatically appears when player levels up

**Features:**
- Congratulatory message with new level
- Shows how many stat points were earned
- Auto-opens stats panel for immediate allocation

## Combat Feedback

### Damage Numbers

**Colors:**
- **White:** Normal damage to NPC
- **Red:** Incoming damage to player
- **Gold:** Critical hit (50% larger)
- **Blue:** "DODGE!" when attack misses

**Critical Hit Display:**
```lua
-- From src/shared/CombatFeedback.luau
if isCritical then
    textColor = Color3.fromRGB(255, 215, 0)  -- Gold
    displayText = "CRITICAL! -" .. damage
    scale = scale * 1.5  -- 50% larger
end
```

**Customizing feedback:**
```lua
-- Change critical hit color
textColor = Color3.fromRGB(255, 0, 0)  -- Red instead of gold

-- Make crits even bigger
scale = scale * 2.0  -- 2x size instead of 1.5x
```

## UI Customization

### Modular UI System

The UI is split into **3 independent modules** that can be enabled/disabled and customized separately:

1. **XPBar** - XP progress bar (`src/client/ui/XPBar.luau`)
2. **StatsPanel** - Stats panel with allocation buttons (`src/client/ui/StatsPanel.luau`)
3. **LevelUpModal** - Level-up notification modal (`src/client/ui/LevelUpModal.luau`)

All configuration is centralized in **`src/client/UIConfig.luau`**.

### Enabling/Disabling UI Components

**Location:** `src/client/UIConfig.luau`

```lua
local UIConfig = {
    xpBar = {
        enabled = true,  -- Set to false to disable XP bar
        -- ... other settings ...
    },

    statsPanel = {
        enabled = true,  -- Set to false to disable stats panel
        -- ... other settings ...
    },

    levelUpModal = {
        enabled = true,  -- Set to false to disable level-up modal
        -- ... other settings ...
    },
}
```

**Example: Disable XP Bar**
```lua
xpBar = {
    enabled = false,  -- XP bar will not appear
}
```

### XP Bar Customization

**Position and Size:**
```lua
xpBar = {
    enabled = true,

    -- Position (UDim2)
    position = {
        scaleX = 0.3,    -- 30% from left
        offsetX = 0,
        scaleY = 0.88,   -- 88% from top (above hotbar)
        offsetY = 0,
    },

    -- Size (UDim2)
    size = {
        scaleX = 0.4,    -- 40% of screen width
        offsetX = 0,
        scaleY = 0.04,   -- 4% of screen height
        offsetY = 0,
    },
}
```

**Colors:**
```lua
xpBar = {
    -- Colors
    backgroundColor = Color3.fromRGB(30, 30, 30),      -- Dark gray background
    progressColor = Color3.fromRGB(100, 200, 100),     -- Green progress bar
    textColor = Color3.fromRGB(255, 255, 255),         -- White text

    -- XP Popup
    showXPPopup = true,  -- Show "+X XP" popup when XP is gained
    popupColor = Color3.fromRGB(100, 255, 100),  -- Bright green
}
```

**Styling:**
```lua
xpBar = {
    cornerRadius = 8,           -- Corner rounding in pixels
    textSize = 16,              -- Font size
    font = Enum.Font.GothamBold,
    animationDuration = 0.3,    -- Seconds for progress bar animation
}
```

### Stats Panel Customization

**Hotkey:**
```lua
statsPanel = {
    hotkey = Enum.KeyCode.C,  -- Change to any key (e.g., Enum.KeyCode.Tab)
}
```

**Position and Size:**
```lua
statsPanel = {
    position = {
        scaleX = 0.02,   -- 2% from left
        offsetX = 0,
        scaleY = 0.15,   -- 15% from top
        offsetY = 0,
    },

    size = {
        scaleX = 0.25,   -- 25% of screen width
        offsetX = 0,
        scaleY = 0.5,    -- 50% of screen height
        offsetY = 0,
    },
}
```

**Colors:**
```lua
statsPanel = {
    backgroundColor = Color3.fromRGB(30, 30, 30),
    headerColor = Color3.fromRGB(50, 50, 50),
    statRowColor = Color3.fromRGB(40, 40, 40),
    buttonColor = Color3.fromRGB(60, 180, 60),
    buttonHoverColor = Color3.fromRGB(80, 200, 80),
    textColor = Color3.fromRGB(255, 255, 255),
    descTextColor = Color3.fromRGB(200, 200, 200),
}
```

**Start Visible:**
```lua
statsPanel = {
    startVisible = false,  -- Set to true to show panel on load
}
```

### Level-Up Modal Customization

**Auto-Open Stats Panel:**
```lua
levelUpModal = {
    autoOpenStatsPanel = true,  -- Open stats panel when clicking "Open Stats"
}
```

**Display Duration:**
```lua
levelUpModal = {
    displayDuration = 3.0,  -- Seconds before auto-close (0 = no auto-close)
}
```

**Colors:**
```lua
levelUpModal = {
    backgroundColor = Color3.fromRGB(40, 40, 40),
    textColor = Color3.fromRGB(255, 255, 255),
    levelColor = Color3.fromRGB(255, 215, 0),  -- Gold for "LEVEL UP!"
    buttonColor = Color3.fromRGB(60, 180, 60),
}
```

### Example: Custom Dark Blue Theme

```lua
-- In src/client/UIConfig.luau
local UIConfig = {
    xpBar = {
        enabled = true,
        backgroundColor = Color3.fromRGB(10, 20, 40),      -- Dark blue
        progressColor = Color3.fromRGB(50, 150, 255),      -- Bright blue
        textColor = Color3.fromRGB(200, 220, 255),         -- Light blue
    },

    statsPanel = {
        enabled = true,
        backgroundColor = Color3.fromRGB(10, 20, 40),
        headerColor = Color3.fromRGB(20, 40, 80),
        statRowColor = Color3.fromRGB(15, 30, 60),
        buttonColor = Color3.fromRGB(40, 120, 200),
        buttonHoverColor = Color3.fromRGB(60, 150, 230),
    },

    levelUpModal = {
        enabled = true,
        backgroundColor = Color3.fromRGB(15, 30, 60),
        levelColor = Color3.fromRGB(100, 200, 255),  -- Bright blue instead of gold
    },
}
```

### Example: Minimal UI (XP Bar Only)

```lua
local UIConfig = {
    xpBar = {
        enabled = true,  -- Keep XP bar
    },

    statsPanel = {
        enabled = false,  -- Hide stats panel
    },

    levelUpModal = {
        enabled = false,  -- Hide level-up modal
    },
}
```

### Creating Custom UI Components

You can create your own UI components alongside the existing ones:

**1. Create new module** in `src/client/ui/MyCustomUI.luau`:
```lua
local MyCustomUI = {}

function MyCustomUI.create(parent: ScreenGui)
    -- Create your UI here
end

function MyCustomUI.isEnabled(): boolean
    return UIConfig.myCustomUI.enabled
end

return MyCustomUI
```

**2. Add config** to `src/client/UIConfig.luau`:
```lua
local UIConfig = {
    -- ... existing config ...

    myCustomUI = {
        enabled = true,
        -- your custom settings
    },
}
```

**3. Use in StatsUI.client.luau**:
```lua
local MyCustomUI = require(script.Parent:WaitForChild("ui"):WaitForChild("MyCustomUI"))

-- In initialize():
if MyCustomUI.isEnabled() then
    MyCustomUI.create(screenGui)
end
```

## Security Considerations

### Server Authority

**All critical operations are server-side:**
- ✅ Damage calculation
- ✅ XP awarding
- ✅ Stat allocation validation
- ✅ Level-up detection
- ✅ Data persistence

**Clients only:**
- Display UI
- Send stat allocation requests
- Show visual feedback

### Validation

**Stat allocation is validated:**
```lua
-- From src/server/PlayerStats.luau
if points < 1 then return end  -- Can't allocate 0 or negative
if profile.Data.unallocatedStatPoints < 1 then return end  -- No points available
if currentValue >= GameConfig.stats.maxStatValue then return end  -- Hit max cap
```

### Anti-Cheat

**XP Tracking:**
- Attacker is tracked server-side using ObjectValue (can't be manipulated)
- Last attacker expires after 10s (prevents stale credit)
- Only server can award XP

**Stats:**
- Stats are stored in ProfileStore (inaccessible to client)
- Client can't modify stats directly
- All damage calculations use server-side stats

## Advanced Customization

### Custom Damage Type

**1. Add to GameConfig:**
```lua
weapons = {
    PoisonDagger = {
        type = "melee",
        damage = 10,
        damageType = "poison",  -- New damage type
    },
}
```

**2. Add stat scaling in Stats.luau:**
```lua
function Stats.getDerivedStats(stats: Stats): DerivedStats
    return {
        -- ... existing stats ...
        poisonDamageBonus = 1.0 + (stats.magic * 0.03),  -- Magic affects poison
    }
end
```

**3. Update DamageCalculator.luau:**
```lua
local function getDamageTypeMultiplier(weaponConfig: any, derivedStats: any): number
    if weaponConfig.damageType == "physical" then
        return derivedStats.physicalDamageBonus
    elseif weaponConfig.damageType == "magic" then
        return derivedStats.magicDamageBonus
    elseif weaponConfig.damageType == "poison" then
        return derivedStats.poisonDamageBonus  -- NEW
    end
    return 1.0
end
```

### Custom XP Formula

**Change the level curve:**
```lua
-- Linear: 100 XP per level
function Stats.getXPForNextLevel(level: number): number
    return level * 100
end

-- Exponential: Gets harder fast
function Stats.getXPForNextLevel(level: number): number
    return math.floor(100 * (1.5 ^ level))
end

-- Custom curve with cap
function Stats.getXPForNextLevel(level: number): number
    if level >= 50 then
        return 100000  -- Max level requires constant XP
    end
    return math.floor(100 * level^1.5 / 100) * 100
end
```

### Stat Synergies

**Add bonus when two stats are high:**
```lua
function Stats.getDerivedStats(stats: Stats): DerivedStats
    local base = {
        physicalDamageBonus = 1.0 + (stats.strength * 0.02),
        -- ... other stats ...
    }

    -- Synergy: High strength + high stamina = extra damage reduction
    if stats.strength >= 30 and stats.stamina >= 30 then
        base.defense = base.defense * 1.5  -- 50% more defense
    end

    -- Synergy: High accuracy + high strength = better crits
    if stats.accuracy >= 25 and stats.strength >= 25 then
        base.critMultiplier = base.critMultiplier * 1.2  -- 20% better crits
    end

    return base
end
```

### Entity XP Sharing

**Award XP to all attackers (not just last):**

Currently only the last attacker gets XP. To implement sharing:

1. **Track all attackers:** Modify `XPRewardManager.trackAttacker` to store a table of attackers
2. **Split XP on death:** Modify `XPRewardManager.awardXPForKill` to loop through all attackers
3. **Adjust XP amounts:** Divide XP by number of attackers or give partial credit

## Troubleshooting

### XP Not Being Awarded

**Check:**
1. Is damage going through `CombatSystem.applyDamageToEntity`?
2. Is the entity dying within 10s of last hit?
3. Is `entityCanEarnXP` enabled for this entity type?
4. Check server console for `[CombatSystem] Tracking attacker` logs

### Stats Not Affecting Damage

**Check:**
1. Are stats being loaded? Check `PlayerStats.getPlayerStats()`
2. Is damage calculator receiving stats? Check `DamageCalculator.calculateDamage` parameters
3. Are derived stats calculated correctly? Check `Stats.getDerivedStats()`

### Invulnerability Not Working

**Check:**
1. Is `bypassInvulnerability` set to `true` somewhere?
2. Is `invulnerabilityDuration` set correctly in GameConfig?
3. Are you using different weapon names? Invulnerability is per-weapon.

### Player Stats Not Saving

**Check:**
1. Is ProfileStore initialized? Look for "✓ PlayerStats initialized" in server console
2. Is DataStore enabled in Studio? (Game Settings → Security → Enable Studio Access to API Services)
3. Are you in a published game or local server? ProfileStore requires proper DataStore setup.

## Best Practices

### ✅ DO:
- Always use `CombatSystem.applyDamageToEntity()` for damage
- Configure balance values in `GameConfig.luau` and `Stats.luau`
- Test stat changes on a test server before publishing
- Use meaningful weapon names in config (referenced by `applyDamageToEntity`)
- Validate all client input on server

### ❌ DON'T:
- Call `Humanoid:TakeDamage()` directly (bypasses XP, stats, feedback)
- Modify player stats on client
- Award XP on client
- Use `bypassPvP` or `bypassInvulnerability` unless necessary
- Change `PROFILE_STORE_NAME` on production server (resets all data)

## Quick Reference

### Key Files

| File | Purpose |
|------|---------|
| `src/shared/CombatSystem.luau` | Centralized damage application |
| `src/shared/StatsProvider.luau` | **NEW:** Unified stats retrieval for all entities |
| `src/shared/Stats.luau` | Stat calculations and XP formulas |
| `src/shared/DamageCalculator.luau` | Hit/dodge/crit rolls and damage calculation |
| `src/server/PlayerStats.luau` | Player data persistence and stat allocation |
| `src/server/XPRewardManager.luau` | XP tracking and reward distribution |
| `src/shared/GameConfig.luau` | All configuration values |
| `src/client/StatsUI.client.luau` | XP bar and stats panel UI |

### Common Modifications

| What | Where | What to Change |
|------|-------|----------------|
| Starting stats | `GameConfig.stats.defaultStartingStats` | Change values |
| XP per kill | `GameConfig.stats.xpRewards` | Change entity XP values |
| Damage formulas | `Stats.getDerivedStats()` | Change multipliers |
| Level XP curve | `Stats.getXPForNextLevel()` | Change formula |
| Stat points per level | `GameConfig.stats.statPointsPerLevel` | Change number |
| Invuln duration | `GameConfig.combat.invulnerabilityDuration` | Change seconds |
| PvP enabled | `GameConfig.combat.pvpEnabled` | `true`/`false` |

---

**Need more help?** Check the other guides:
- [GUIDE_AOE.md](./GUIDE_AOE.md) - AOE attack system
- [GUIDE_COMBAT.md](./GUIDE_COMBAT.md) - General combat system (if exists)
