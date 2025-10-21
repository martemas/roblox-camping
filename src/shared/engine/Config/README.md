# Game Configuration Files

This directory contains the modular configuration system for the Roblox Camping Game. The monolithic `GameConfig.luau` has been split into organized, focused config files for better maintainability and clarity.

## Structure

### Entry Point
- **[init.luau](init.luau)** - Main entry point that re-exports all configs maintaining identical API to the original `GameConfig.luau`

### Core Framework (Stable)
These files contain core framework settings that rarely change:

- **[GameSettings.luau](GameSettings.luau)** - Core game mechanics and framework settings
  - `gameplay` - Mining interaction settings
  - `player` - Player stats, inventory, health, movement, stamina
  - `combat` - Combat mode, damage detection, auto-aim, invulnerability, body part multipliers
  - `targeting` - Target selection and highlight settings
  - `stats` - Leveling system, XP rewards, stat scaling
  - `map` - Map size and spawn radius settings
  - `CombatMode` - Enum defining ACTION vs TACTICAL combat modes

### Gameplay-Specific (This Game)
Configuration specific to the camping/survival game mode:

- **[DayNightCycleConfig.luau](DayNightCycleConfig.luau)** - Day/night cycle and wave mechanics
  - `time` - Day/night duration, lighting configuration
  - `nightWaves` - Zombie wave settings, difficulty scaling

### Extensible Content (Frequently Modified)
These files contain game content that is frequently added to or modified:

- **[WeaponsConfig.luau](WeaponsConfig.luau)** - All weapon definitions
  - Melee weapons (Axe, Pickaxe, WolfClaw, BearClaw, ZombieBite)
  - Projectile weapons (Bow, SpiderWeb, Fireball)
  - Hitscan weapons (Crossbow, MagicMissile, DirectHeal, ExplosiveBolt)
  - AOE weapons (GroundSlam, HealingCircle, PoisonCloud)

- **[ToolsConfig.luau](ToolsConfig.luau)** - Tool definitions for mining and gathering
  - `toolCategories` - Tool category mappings
  - `tools` - Mining tools (axes, pickaxes) with speed and weapon references

- **[ResourcesConfig.luau](ResourcesConfig.luau)** - Resource node definitions
  - Wood, Stone, Metal, RockyHill
  - Spawn modes, hit requirements, respawn times, yields

- **[WildlifeConfig.luau](WildlifeConfig.luau)** - Wildlife entity types
  - Wolf, Bear
  - Health, speeds, AI behavior, drops, animations

- **[EnemiesConfig.luau](EnemiesConfig.luau)** - Enemy entity types
  - Zombie (and future enemy types)
  - Health, speeds, AI behavior, stats, animations

- **[EntitiesConfig.luau](EntitiesConfig.luau)** - Entity system definitions
  - Wildlife entities (Wolf, Bear)
  - Enemy entities (Zombie)
  - Resource entities (WoodNode, StoneNode, MetalNode)
  - Building entities (WoodenWall)

- **[ShopConfig.luau](ShopConfig.luau)** - Shop item definitions
  - Building items (WoodenWall, BarrackL1)
  - Costs, categories, descriptions

## Usage

Import the config in your code:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.config)

-- Access config values just like before
local maxHealth = GameConfig.player.maxHealth
local combatMode = GameConfig.combat.combatMode
local weaponDamage = GameConfig.weapons.Axe.damage
```

The API is identical to the original monolithic `GameConfig.luau`, so existing code requires no changes beyond updating the import path from `GameConfig` to `config`.

## Benefits

1. **Separation of Concerns** - Core framework vs gameplay content vs extensible content
2. **Easier Navigation** - Find specific configs quickly without scrolling through 660+ lines
3. **Reduced Merge Conflicts** - Multiple developers can modify different config files
4. **Better Performance** - Only load configs you need (when using individual modules)
5. **Clear Ownership** - Framework devs own core files, content designers own extensible files
6. **Easier Testing** - Test individual config modules in isolation

## Migration Notes

- Old path: `require(ReplicatedStorage.GameConfig)`
- New path: `require(ReplicatedStorage.config)`
- All original keys and structure are preserved
- No breaking changes to existing code (except import path)
