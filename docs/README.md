# Documentation Index

Welcome to the Roblox Camping Game documentation!

## 📚 Quick Navigation

### For UI Customization

| Document | Purpose | Use When |
|----------|---------|----------|
| **[GUIDE_UI.md](./GUIDE_UI.md)** | Complete UI guide | Customizing colors, positions, or creating components |
| **[UI_ARCHITECTURE.md](./UI_ARCHITECTURE.md)** | System architecture & diagrams | Understanding how the UI system works |
| **[EXAMPLE_GUI_EDITOR_INTEGRATION.md](./EXAMPLE_GUI_EDITOR_INTEGRATION.md)** | GUI editor integration | Building UI in Roblox Studio and integrating it |

### For Combat & Weapon Systems

| Document | Purpose | Use When |
|----------|---------|----------|
| **[GUIDE_DAMAGE_XP.md](./GUIDE_DAMAGE_XP.md)** | Stats, XP, and damage system | Understanding or modifying combat mechanics |
| **[GUIDE_PROJECTILE.md](./GUIDE_PROJECTILE.md)** | Projectile weapons & targeting | Setting up arrows, spells, or click-targeting |
| **[GUIDE_HITSCAN.md](./GUIDE_HITSCAN.md)** | Hitscan weapons | Setting up instant-hit weapons like guns |
| **[GUIDE_AOE.md](./GUIDE_AOE.md)** | AOE weapons & attacks | Setting up area-of-effect abilities |

### For Entity Spawning System

| Document | Purpose | Use When |
|----------|---------|----------|
| **[GUIDE_SPAWNER.md](./GUIDE_SPAWNER.md)** | Entity spawning and AI configuration | Adding entities, configuring AI behavior, or spawning waves |

## 🎯 Common Tasks

### "I want to change UI colors/positions"
→ Read [GUIDE_UI.md - Quick Start](./GUIDE_UI.md#quick-start)

### "I want to add a new UI component"
→ Read [GUIDE_UI.md - Creating Custom Components](./GUIDE_UI.md#creating-custom-components)

### "I want to understand the UI system architecture"
→ Read [UI_ARCHITECTURE.md](./UI_ARCHITECTURE.md)

### "I want to build UI in Roblox Studio"
→ Read [EXAMPLE_GUI_EDITOR_INTEGRATION.md](./EXAMPLE_GUI_EDITOR_INTEGRATION.md)

### "I want to modify damage calculations"
→ Read [GUIDE_DAMAGE_XP.md - Damage System](./GUIDE_DAMAGE_XP.md#damage-calculation-system)

### "I want to change XP or leveling"
→ Read [GUIDE_DAMAGE_XP.md - XP System](./GUIDE_DAMAGE_XP.md#xp--leveling-system)

### "I want to add new stats"
→ Read [GUIDE_DAMAGE_XP.md - Customization](./GUIDE_DAMAGE_XP.md#customization)

### "I want to add projectile weapons (bow, arrows, spells)"
→ Read [GUIDE_PROJECTILE.md - Quick Start](./GUIDE_PROJECTILE.md#quick-start)

### "I want to configure click-targeting or auto-aim"
→ Read [GUIDE_PROJECTILE.md - Auto-aim Configuration](./GUIDE_PROJECTILE.md#quick-start)

### "I want to spawn entities or configure AI"
→ Read [GUIDE_SPAWNER.md - Quick Start](./GUIDE_SPAWNER.md#quick-start)

### "I want to add a new creature/wildlife type"
→ Read [GUIDE_SPAWNER.md - Configuring Entities](./GUIDE_SPAWNER.md#configuring-entities)

## 📖 Documentation Overview

### UI System

The UI system is fully modular - all components can be enabled/disabled and customized through a single configuration file.

**Key Features**:
- 10 modular UI components (XP Bar, Stats Panel, Inventory, Shop, etc.)
- Single configuration file ([UIConfig.luau](../src/client/UIConfig.luau))
- Easy theming and customization
- Component-based architecture with UIManager

**Main Components**:
- **Stats System**: XP Bar, Stats Panel, Level-Up Modal
- **Game UI**: Inventory, Team Resources, Phase Timer, Health Bar, Stamina Bar, Notification, Shop

### Stats & Combat System

Server-authoritative stats and XP system with centralized damage calculation.

**Key Features**:
- 4 core stats: Strength, Magic, Stamina, Accuracy
- Derived stats calculated from core stats
- Centralized damage system (all damage flows through one function)
- XP rewards with level scaling
- Stats affect damage, health, hit chance, dodge, crit

### Entity Spawning System

Unified spawning system with custom AI behaviors and flexible spawn configurations.

**Key Features**:
- Stateless spawning architecture
- Custom AI behavior profiles per entity
- Priority-based targeting (Player, Structure, Wildlife, etc.)
- Flexible spawn locations (point, area, perimeter, random)
- Spawn memory (entities return to spawn when idle)
- Auto-population maintenance for wildlife
- Wave-based spawning for night creatures

## 🗂️ File Organization

```
docs/
├── README.md                              ← YOU ARE HERE
├── GUIDE_UI.md                            ← Complete UI guide
├── UI_ARCHITECTURE.md                     ← UI system architecture
├── EXAMPLE_GUI_EDITOR_INTEGRATION.md      ← GUI editor integration
├── GUIDE_DAMAGE_XP.md                     ← Stats & combat guide
└── GUIDE_SPAWNER.md                       ← Entity spawning & AI guide

src/
├── client/
│   ├── init.client.luau                   ← Client entry point
│   ├── UI.client.luau                     ← UI orchestrator
│   ├── UIConfig.luau                      ← ALL UI SETTINGS
│   ├── UIManager.luau                     ← Component lifecycle & registry
│   ├── BuildingController.client.luau     ← Building placement
│   ├── EntityTargeting.client.luau        ← Entity selection & targeting
│   ├── HealthBarAttacher.client.luau      ← Entity health bar display
│   ├── MovementController.client.luau     ← Player movement
│   ├── TargetHUD.client.luau              ← Target display UI
│   ├── ToolClickHandler.client.luau       ← Tool interaction handler
│   └── ui/                                ← UI components
│       ├── UIComponent.luau               ← Base component class
│       ├── XPBar.luau
│       ├── StatsPanel.luau
│       ├── LevelUpModal.luau
│       ├── Inventory.luau
│       ├── TeamResources.luau
│       ├── PhaseTimer.luau
│       ├── HealthBar.luau
│       ├── StaminaBar.luau
│       ├── TargetHUD.luau
│       ├── Notification.luau
│       └── Shop.luau
│
├── server/
│   ├── init.server.luau                   ← Server entry point
│   ├── Config/
│   │   ├── GameConfig.luau                ← Server-side game rules
│   │   └── Economy.luau                   ← Prices & costs
│   ├── Data/
│   │   ├── Items/
│   │   │   ├── init.luau                  ← Item stats aggregator
│   │   │   ├── WeaponStats.luau           ← Weapon stats (server-only)
│   │   │   ├── ToolStats.luau             ← Tool stats (server-only)
│   │   │   └── ConsumableStats.luau       ← Consumable effects (server-only)
│   │   └── Entities/
│   │       ├── init.luau                  ← Entity stats aggregator
│   │       ├── WildlifeStats.luau         ← Wildlife stats (server-only)
│   │       ├── CreatureStats.luau         ← Creature stats (server-only)
│   │       ├── NPCStats.luau              ← NPC stats (server-only)
│   │       ├── StructureStats.luau        ← Structure stats (server-only)
│   │       └── ResourceStats.luau         ← Resource node stats (server-only)
│   ├── Combat/
│   │   ├── CombatSystem.luau              ← Central damage system
│   │   ├── DamageCalculator.luau          ← Damage calculations
│   │   ├── Stats.luau                     ← Stats calculations
│   │   ├── StatsProvider.luau             ← Entity stats provider
│   │   ├── ProjectileManager.luau         ← Projectile weapon handling
│   │   ├── ProjectilePhysics.luau         ← Projectile physics
│   │   ├── ProjectileLOS.luau             ← Line-of-sight checks
│   │   ├── HitscanManager.luau            ← Hitscan weapon handling
│   │   └── AOEZoneManager.luau            ← AOE damage zones
│   ├── Entities/
│   │   ├── EntitySpawner.luau             ← Entity spawning facade
│   │   └── EntityController.luau          ← AI & entity management
│   ├── PlayerStats.luau                   ← Player stats & XP backend
│   ├── XPRewardManager.luau               ← XP tracking & rewards
│   ├── SpawnManager.server.luau           ← Spawn orchestration
│   ├── EntityAIManager.server.luau        ← AI behavior management
│   ├── TargetManager.server.luau          ← Target selection backend
│   ├── InventoryManager.server.luau       ← Inventory backend
│   ├── ShopManager.server.luau            ← Shop transactions
│   ├── ToolManager.server.luau            ← Tool equipping & usage
│   ├── DropSystem.luau                    ← Item drops & loot
│   ├── ResourceManager.server.luau        ← Resource node management
│   ├── TownhallManager.server.luau        ← Townhall/base management
│   ├── DayNightCycle.server.luau          ← Day/night system
│   ├── HealthBarManager.luau              ← Health bar replication
│   ├── AnimationManager.luau              ← Animation handling
│   └── ProfileStore.luau                  ← Data persistence
│
└── shared/
    ├── Core/
    │   ├── Types.luau                     ← Type definitions
    │   ├── RemoteEvents.luau              ← Client-server events
    │   └── Utils.luau                     ← Utility functions
    ├── Config/
    │   ├── init.luau                      ← Config aggregator
    │   ├── ClientSettings.luau            ← UI/display settings
    │   ├── DayNightCycleConfig.luau       ← Day/night settings
    │   └── SpawnConfig.luau               ← Spawn configuration
    ├── Data/
    │   ├── Items/
    │   │   ├── Items.luau                 ← Master item registry
    │   │   ├── Weapons.luau               ← Weapon display data
    │   │   ├── Tools.luau                 ← Tool display data
    │   │   ├── Consumables.luau           ← Consumable display data
    │   │   └── Resources.luau             ← Resource item data
    │   └── Entities/
    │       ├── Entities.luau              ← Master entity registry
    │       ├── Wildlife.luau              ← Wildlife display data
    │       ├── Creatures.luau             ← Creature display data
    │       ├── NPCs.luau                  ← NPC display data
    │       ├── Structures.luau            ← Structure display data
    │       └── Resources.luau             ← Resource node display data
    ├── Systems/
    │   └── Inventory/
    │       └── ItemValidator.luau         ← Item validation logic
    ├── Player/
    │   ├── PlayerSettings.luau            ← Player preferences
    │   ├── PlayerSettingsManager.luau     ← Settings management
    │   └── TargetingSystem.luau           ← Targeting utilities
    ├── Combat/
    │   └── CombatUtils.luau               ← Combat utility functions
    └── VisualFX/
        ├── AOETelegraph.luau              ← AOE visual indicators
        ├── HitscanEffects.luau            ← Hitscan visual effects
        └── CombatFeedback.luau            ← Combat feedback visuals
```

## 🚀 Getting Started

### First Time Setup

1. **Understand the architecture**:
   - Read [UI_ARCHITECTURE.md](./UI_ARCHITECTURE.md) for overview
   - Review file structure above

2. **Make your first customization**:
   - Open `src/client/UIConfig.luau`
   - Change a color or position
   - Run `rojo build -o "roblox-camping.rbxlx"`
   - Test in Roblox Studio

3. **Learn the systems**:
   - Read [GUIDE_UI.md](./GUIDE_UI.md) for UI system
   - Read [GUIDE_DAMAGE_XP.md](./GUIDE_DAMAGE_XP.md) for combat system
   - Read [GUIDE_SPAWNER.md](./GUIDE_SPAWNER.md) for spawning system

### Quick Examples

**Disable a UI component**:
```lua
-- UIConfig.luau
xpBar = {
    enabled = false,
}
```

**Change colors**:
```lua
-- UIConfig.luau
healthBar = {
    backgroundColor = Color3.fromRGB(60, 20, 20),
    healthHighColor = Color3.fromRGB(255, 50, 50),
}
```

**Adjust damage calculation**:
```lua
-- Stats.luau
function Stats.getDerivedStats(stats: Stats): DerivedStats
    return {
        physicalDamageBonus = 1.0 + (stats.strength * 0.03),  -- Changed from 0.02
        -- ...
    }
end
```

**Add a new entity**:
```lua
-- EntitiesConfig.luau
Deer = {
    category = "Wildlife",
    health = 40,
    primaryWeapon = "DeerHoof",
    ai = {
        behaviors = { idle = "wander" },
        targetPriority = {},  -- Passive
        wanderRadius = 60,
    },
}
```

## 🔧 Common Workflows

### Adding a New UI Component

1. Create component module: `src/client/ui/MyComponent.luau`
2. Add configuration to `UIConfig.luau`
3. Register in `UIManager.luau`
4. Use with `UIManager.updateComponent("MyComponent", data)`

See [GUIDE_UI.md - Creating Custom Components](./GUIDE_UI.md#creating-custom-components) for details.

### Modifying Stats

1. Edit `src/shared/Stats.luau` for calculations
2. Edit `src/shared/GameConfig.luau` for values
3. Test with `rojo build`

See [GUIDE_DAMAGE_XP.md - Customization](./GUIDE_DAMAGE_XP.md#customization) for details.

### Creating Themes

1. Define theme colors in `UIConfig.luau`
2. Apply to all components
3. Test visually in Studio

See [GUIDE_UI.md - Common Customizations](./GUIDE_UI.md#common-customizations) for examples.

## 💡 Tips

- **Start small**: Make one change at a time and test
- **Use existing code**: Look at similar components for examples
- **Check console**: Most errors show up in Output window
- **Read comments**: Code has helpful inline documentation
- **Ask for help**: Check Troubleshooting sections in guides

## 🐛 Troubleshooting

See individual guides for detailed troubleshooting:
- [UI Troubleshooting](./GUIDE_UI.md#troubleshooting)
- [Combat Troubleshooting](./GUIDE_DAMAGE_XP.md#troubleshooting)

**Common Issues**:
- Component not showing → Check `enabled = true` in UIConfig
- Colors not applying → Run `rojo build` after changes
- Stats not working → Check server console for errors
- UI position wrong → Verify scale values are 0-1

## 📞 Getting Help

1. Check the appropriate guide (UI or Combat)
2. Look at existing code for examples
3. Review error messages in console
4. Search for similar patterns in codebase
5. Check Roblox documentation for APIs

## 🎓 Learning Path

**Beginner**:
1. Understand the file structure
2. Make simple color/position changes
3. Enable/disable components
4. Read through existing components

**Intermediate**:
1. Create a simple custom component
2. Modify stat calculations
3. Create a theme
4. Understand RemoteEvents flow

**Advanced**:
1. Build complex UI components
2. Integrate GUI editor templates
3. Modify core combat system
4. Create new game mechanics

---

**Happy coding! 🚀**

For questions or issues, refer to the specific guides above.
