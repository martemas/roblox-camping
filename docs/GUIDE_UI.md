# UI System Guide

> **📐 Architecture Overview**: See [UI_ARCHITECTURE.md](./UI_ARCHITECTURE.md) for complete system architecture, diagrams, and data flow.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [UIConfig Reference](#uiconfig-reference)
- [Component Reference](#component-reference)
  - [Stats System Components](#stats-system-components)
  - [Game UI Components](#game-ui-components)
- [Common Customizations](#common-customizations)
- [Creating Custom Components](#creating-custom-components)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The Roblox Camping game uses a **modular UI framework** where each component is:
- ✅ **Independent** - Can be enabled/disabled separately
- ✅ **Configurable** - All settings in one central file (`UIConfig.luau`)
- ✅ **Themeable** - Colors, fonts, sizes easily customized
- ✅ **Extensible** - Easy to add new UI components

### UI System Components

| Component | Purpose | Default Key |
|-----------|---------|-------------|
| **XP Bar** | Level and XP progress | Always visible |
| **Stats Panel** | View/allocate stats | `C` to toggle |
| **Level-Up Modal** | Level-up notification | Auto-shows |
| **Inventory** | Player inventory slots | Always visible |
| **Team Resources** | Shared resources (Wood/Stone/Metal) | Always visible |
| **Phase Timer** | Day/Night phase countdown | Always visible |
| **Health Bar** | Player health display | Always visible |
| **Stamina Bar** | Player stamina display | Always visible |
| **Notification** | Centered messages | Event-driven |
| **Shop** | Purchase items | Button toggle |

All components managed by the unified UI system (UIManager + UI.client).

### Key Files

```
src/client/
├── UIConfig.luau           ← ALL SETTINGS (edit this!)
├── UI.client.luau          ← Unified orchestrator (RemoteEvents & input)
├── UIManager.luau          ← Component lifecycle & registry
└── ui/                     ← Component modules
    ├── UIComponent.luau    ← Base interface
    ├── XPBar.luau
    ├── StatsPanel.luau
    ├── LevelUpModal.luau
    ├── Inventory.luau
    ├── TeamResources.luau
    ├── PhaseTimer.luau
    ├── HealthBar.luau
    ├── StaminaBar.luau
    ├── Notification.luau
    └── Shop.luau
```

**3 Layers:**
1. **UIConfig** - Configuration
2. **UI.client + UIManager** - Orchestration
3. **Components** - Implementation

## Quick Start

### Disable a Component

```lua
-- src/client/UIConfig.luau

-- Disable XP bar
xpBar = {
    enabled = false,
}

-- Disable shop
shop = {
    enabled = false,
}
```

### Change Colors

```lua
-- Make health bar red-themed
healthBar = {
    enabled = true,
    backgroundColor = Color3.fromRGB(60, 20, 20),
    healthHighColor = Color3.fromRGB(255, 50, 50),
    healthMediumColor = Color3.fromRGB(255, 150, 0),
    healthLowColor = Color3.fromRGB(150, 0, 0),
}
```

### Change Position

```lua
-- Move inventory to top-left
inventory = {
    enabled = true,
    position = {
        scaleX = 0,
        offsetX = 20,
        scaleY = 0,      -- Top instead of bottom
        offsetY = 20,
    },
}
```

### Create Minimal UI

```lua
local UIConfig = {
    -- STATS SYSTEM - Disable all
    xpBar = { enabled = false },
    statsPanel = { enabled = false },
    levelUpModal = { enabled = false },

    -- GAME UI - Keep essentials only
    inventory = { enabled = true },
    teamResources = { enabled = false },
    phaseTimer = { enabled = true },
    healthBar = { enabled = true },
    staminaBar = { enabled = true },
    notification = { enabled = true },
    shop = { enabled = false },
}
```

## UIConfig Reference

### Structure

Every component configuration follows this pattern:

```lua
componentName = {
    enabled = true,          -- Show/hide component

    position = {             -- Screen position (UDim2)
        scaleX = 0.5,        -- 0-1 (percentage)
        offsetX = 0,         -- Pixel offset
        scaleY = 0.5,
        offsetY = 0,
    },

    size = {                 -- Component size (UDim2)
        scaleX = 0.3,
        offsetX = 0,
        scaleY = 0.2,
        offsetY = 0,
    },

    -- Colors
    backgroundColor = Color3.fromRGB(50, 50, 50),
    textColor = Color3.fromRGB(255, 255, 255),

    -- Styling
    font = Enum.Font.Gotham,

    -- Component-specific settings...
}
```

### Helper Functions

```lua
-- Create UDim2 from config table
UIConfig.createUDim2({ scaleX = 0.5, offsetX = 0, scaleY = 0.5, offsetY = 0 })
-- Returns: UDim2.new(0.5, 0, 0.5, 0)

-- Create Vector2 from config table
UIConfig.createVector2({ x = 0.5, y = 0.5 })
-- Returns: Vector2.new(0.5, 0.5)
```

### Common Color3 Values

```lua
-- Grayscale
Color3.fromRGB(0, 0, 0)         -- Black
Color3.fromRGB(50, 50, 50)      -- Dark Gray
Color3.fromRGB(128, 128, 128)   -- Gray
Color3.fromRGB(200, 200, 200)   -- Light Gray
Color3.fromRGB(255, 255, 255)   -- White

-- Common Colors
Color3.fromRGB(255, 0, 0)       -- Red
Color3.fromRGB(0, 255, 0)       -- Green
Color3.fromRGB(0, 0, 255)       -- Blue
Color3.fromRGB(255, 255, 0)     -- Yellow
Color3.fromRGB(255, 165, 0)     -- Orange
Color3.fromRGB(128, 0, 128)     -- Purple
```

### Font Options

```lua
Enum.Font.Legacy
Enum.Font.Arial
Enum.Font.ArialBold
Enum.Font.SourceSans
Enum.Font.SourceSansBold
Enum.Font.Gotham
Enum.Font.GothamBold
Enum.Font.GothamBlack
Enum.Font.PermanentMarker
Enum.Font.Creepster
-- See: https://create.roblox.com/docs/reference/engine/enums/Font
```

## Component Reference

### Stats System Components

#### XP Bar

**Purpose**: Displays player level and XP progress

**Key Settings**:
```lua
xpBar = {
    enabled = true,
    showXPPopup = true,              -- Show "+X XP" popup on gain
    animationDuration = 0.3,         -- Progress bar animation speed
    progressColor = Color3.fromRGB(100, 200, 100),  -- Green progress
}
```

**API**:
- `XPBar.create(parent)` - Create the component
- `XPBar.update(currentXP, currentLevel)` - Update display
- `XPBar.showXPGainPopup(amount)` - Show "+X XP" popup

#### Stats Panel

**Purpose**: Display stats with allocation buttons

**Key Settings**:
```lua
statsPanel = {
    enabled = true,
    hotkey = Enum.KeyCode.C,         -- Toggle key
    startVisible = false,             -- Start hidden
    buttonColor = Color3.fromRGB(60, 180, 60),
}
```

**Stats Displayed**:
- **Strength**: Increases physical damage and crit damage
- **Magic**: Reserved for future magic system
- **Stamina**: Increases max health
- **Accuracy**: Improves hit chance, dodge, and crit chance

**API**:
- `StatsPanel.create(parent)` - Create the component
- `StatsPanel.update(stats, unallocatedPoints)` - Update display
- `StatsPanel.show()` - Show panel
- `StatsPanel.hide()` - Hide panel
- `StatsPanel.toggle()` - Toggle visibility

#### Level-Up Modal

**Purpose**: Notification when player levels up

**Key Settings**:
```lua
levelUpModal = {
    enabled = true,
    displayDuration = 3.0,           -- Auto-close after 3 seconds (0 = manual)
    autoOpenStatsPanel = true,       -- Open stats panel when closed
    levelColor = Color3.fromRGB(255, 215, 0),  -- Gold
}
```

**API**:
- `LevelUpModal.create(parent)` - Create the component
- `LevelUpModal.show(newLevel, statPoints)` - Show notification
- `LevelUpModal.hide()` - Hide modal

### Game UI Components

#### Inventory

**Purpose**: Display player inventory slots

**Key Settings**:
```lua
inventory = {
    enabled = true,
    slotSize = 50,                   -- Slot size in pixels
    slotSpacing = 5,                 -- Space between slots
    slotEmptyColor = Color3.fromRGB(80, 80, 80),
    slotFilledColor = Color3.fromRGB(100, 150, 100),
}
```

**API**:
- `Inventory.create(parent)` - Create the component
- `Inventory.update(inventoryData)` - Update slots with inventory data

#### Team Resources

**Purpose**: Display shared team resources

**Key Settings**:
```lua
teamResources = {
    enabled = true,
    resourceTypes = {"Wood", "Stone", "Metal"},
    resourceBgColor = Color3.fromRGB(80, 80, 80),
}
```

**API**:
- `TeamResources.create(parent)` - Create the component
- `TeamResources.update(teamResourcesData)` - Update resource displays

#### Phase Timer

**Purpose**: Display current game phase and countdown

**Key Settings**:
```lua
phaseTimer = {
    enabled = true,
    dayPhaseColor = Color3.fromRGB(255, 255, 0),     -- Yellow
    nightPhaseColor = Color3.fromRGB(255, 100, 100), -- Red
    prepPhaseColor = Color3.fromRGB(200, 200, 200),  -- Gray
    font = Enum.Font.Creepster,      -- Spooky font
}
```

**API**:
- `PhaseTimer.create(parent)` - Create the component
- `PhaseTimer.update(phase, remainingTime)` - Update phase and timer

#### Health Bar

**Purpose**: Display player health with color coding

**Key Settings**:
```lua
healthBar = {
    enabled = true,
    updateInterval = 1.0,            -- Auto-update every 1 second
    healthHighColor = Color3.fromRGB(0, 255, 0),    -- Green (>60%)
    healthMediumColor = Color3.fromRGB(255, 255, 0), -- Yellow (30-60%)
    healthLowColor = Color3.fromRGB(255, 0, 0),     -- Red (<30%)
}
```

**API**:
- `HealthBar.create(parent)` - Create the component (auto-starts updating)
- `HealthBar.update(currentHealth, maxHealth)` - Manual update
- `HealthBar.startUpdating()` - Start auto-updates
- `HealthBar.stopUpdating()` - Stop auto-updates

#### Stamina Bar

**Purpose**: Display player stamina with color coding

**Key Settings**:
```lua
staminaBar = {
    enabled = true,
    staminaHighColor = Color3.fromRGB(0, 150, 255),   -- Blue (>60%)
    staminaMediumColor = Color3.fromRGB(255, 200, 0),  -- Orange (30-60%)
    staminaLowColor = Color3.fromRGB(255, 100, 100),  -- Light Red (<30%)
}
```

**API**:
- `StaminaBar.create(parent)` - Create the component
- `StaminaBar.update(currentStamina, maxStamina)` - Update display

#### Notification

**Purpose**: Display centered temporary messages

**Key Settings**:
```lua
notification = {
    enabled = true,
    displayDuration = 3.0,           -- Show for 3 seconds
    fadeOutDuration = 0.5,           -- Fade animation duration
}
```

**API**:
- `Notification.create(parent)` - Create the component
- `Notification.show(message)` - Show notification
- `Notification.hide()` - Hide immediately

#### Shop

**Purpose**: Display shop interface with purchasable items

**Key Settings**:
```lua
shop = {
    enabled = true,
    itemHeight = 80,                 -- Height of each shop item
    itemSpacing = 10,                -- Space between items
    costAffordColor = Color3.fromRGB(0, 255, 0),
    costCannotAffordColor = Color3.fromRGB(255, 0, 0),
}
```

**API**:
- `Shop.create(parent)` - Create shop button and frame
- `Shop.update(shopData, teamResources)` - Update shop items
- `Shop.open()` - Open shop
- `Shop.close()` - Close shop
- `Shop.toggle()` - Toggle shop visibility

## Common Customizations

### Dark Theme

```lua
local darkTheme = {
    -- Base colors
    backgroundColor = Color3.fromRGB(15, 15, 15),
    textColor = Color3.fromRGB(220, 220, 220),
    borderColor = Color3.fromRGB(50, 50, 50),
}

-- Apply to components
xpBar = {
    backgroundColor = darkTheme.backgroundColor,
    progressColor = Color3.fromRGB(80, 80, 80),
    textColor = darkTheme.textColor,
}

healthBar = {
    backgroundColor = darkTheme.backgroundColor,
    textColor = darkTheme.textColor,
    borderColor = darkTheme.borderColor,
}

shop = {
    frameBackgroundColor = darkTheme.backgroundColor,
    textColor = darkTheme.textColor,
    -- ...
}
```

### Colorful Theme

```lua
local purpleTheme = {
    primary = Color3.fromRGB(150, 100, 255),
    secondary = Color3.fromRGB(50, 20, 80),
    accent = Color3.fromRGB(255, 200, 100),
}

xpBar = {
    backgroundColor = purpleTheme.secondary,
    progressColor = purpleTheme.primary,
    textColor = Color3.fromRGB(255, 255, 255),
}

statsPanel = {
    backgroundColor = purpleTheme.secondary,
    buttonColor = purpleTheme.primary,
    buttonHoverColor = Color3.fromRGB(180, 130, 255),
}
```

### Larger UI for Accessibility

```lua
-- Increase all sizes by 50%
xpBar = {
    size = {
        scaleX = 0.6,    -- Was 0.4
        scaleY = 0.06,   -- Was 0.04
    },
    textSize = 24,       -- Was 16
}

healthBar = {
    size = {
        scaleX = 0,
        offsetX = 300,   -- Was 200
        scaleY = 0,
        offsetY = 60,    -- Was 40
    },
}

inventory = {
    slotSize = 75,       -- Was 50
    slotSpacing = 8,     -- Was 5
}
```

### Compact UI

```lua
-- Minimize UI footprint
healthBar = { enabled = false },
staminaBar = { enabled = false },
inventory = { enabled = false },
teamResources = {
    size = {
        scaleX = 0,
        offsetX = 200,   -- Smaller
        scaleY = 0,
        offsetY = 40,    -- Smaller
    },
}
```

## Creating Custom Components

See [EXAMPLE_GUI_EDITOR_INTEGRATION.md](./EXAMPLE_GUI_EDITOR_INTEGRATION.md) for detailed examples.

### Basic Template

```lua
--!strict
-- src/client/ui/MyComponent.luau

local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))

local MyComponent = UIComponent.new("MyComponent")

-- Component state
local componentFrame: Frame? = nil

function MyComponent.create(parent: ScreenGui): Frame
    local config = UIConfig.myComponent

    -- Create your GUI
    componentFrame = Instance.new("Frame")
    componentFrame.Size = UIConfig.createUDim2(config.size)
    componentFrame.Position = UIConfig.createUDim2(config.position)
    componentFrame.BackgroundColor3 = config.backgroundColor
    componentFrame.Parent = parent

    -- Setup interactions...

    return componentFrame
end

function MyComponent.update(data: any)
    if not componentFrame then return end
    -- Update GUI with data...
end

function MyComponent.isEnabled(): boolean
    return UIConfig.myComponent.enabled
end

return MyComponent
```

### Register Component

```lua
-- UIManager.luau
local COMPONENT_MODULES = {
    MyComponent = "ui/MyComponent",
    -- ...
}
```

### Add Configuration

```lua
-- UIConfig.luau
myComponent = {
    enabled = true,
    position = { scaleX = 0.5, offsetX = 0, scaleY = 0.5, offsetY = 0 },
    size = { scaleX = 0.3, offsetX = 0, scaleY = 0.2, offsetY = 0 },
    backgroundColor = Color3.fromRGB(50, 50, 50),
    textColor = Color3.fromRGB(255, 255, 255),
},
```

## Best Practices

### ✅ DO

- **Use UIConfig for all settings** - Never hardcode values in components
- **Use scale for responsive UI** - `scaleX/scaleY` adapts to screen size
- **Cache child references** - Find elements once in `create()`, store in variables
- **Handle missing elements gracefully** - Use optional types and nil checks
- **Clean up resources** - Disconnect events, destroy instances in `destroy()`
- **Follow naming conventions** - Clear, descriptive names for GUI elements
- **Test on different screen sizes** - Use scale-based positioning

### ❌ DON'T

- **Don't hardcode colors/positions** - Use UIConfig
- **Don't create multiple instances** - Components should be singletons
- **Don't forget nil checks** - Always validate data before using
- **Don't use fixed pixel sizes for major layout** - Use scale when possible
- **Don't directly manipulate other component's GUI** - Use UIManager API
- **Don't create circular dependencies** - Components should be independent

## Troubleshooting

### Component Not Showing

1. **Check enabled flag** - `UIConfig.componentName.enabled = true`
2. **Check position** - Make sure it's on screen (scale 0-1)
3. **Check parent** - Is the component being created properly?
4. **Check console** - Look for error messages or warnings
5. **Check z-index** - Is another UI element covering it?

### Component Not Updating

1. **Check RemoteEvent connection** - Is the event being fired?
2. **Check data format** - Does it match what component expects?
3. **Check component state** - Is componentFrame nil?
4. **Add debug prints** - Log when update() is called
5. **Check server** - Is server actually sending updates?

### Colors Not Applying

1. **Check Color3 format** - Use `Color3.fromRGB(r, g, b)`
2. **Check spelling** - `backgroundColor` not `BackgroundColor`
3. **Check configuration** - Is it in the right component section?
4. **Rebuild** - Run `rojo build` to apply changes
5. **Check component creation** - Does component use the config value?

### Position/Size Wrong

1. **Check UDim2 format** - `{scaleX, offsetX, scaleY, offsetY}`
2. **Check scale vs offset** - Scale is 0-1, offset is pixels
3. **Check anchor point** - Does component set AnchorPoint?
4. **Test different screens** - UI might look different on other resolutions
5. **Check parent size** - Size is relative to parent

### Performance Issues

1. **Disable unused components** - Set `enabled = false`
2. **Reduce update frequency** - Increase `updateInterval` for auto-updating components
3. **Optimize loops** - Avoid creating/destroying GUI frequently
4. **Check for memory leaks** - Ensure `destroy()` is called properly
5. **Profile in Studio** - Use Microprofiler to find bottlenecks

### Build Errors

```bash
# Common error: Module not found
# Fix: Check file paths in UIManager COMPONENT_MODULES

# Common error: Syntax error in UIConfig
# Fix: Check for missing commas, brackets, or quotes

# Common error: Type mismatch
# Fix: Ensure data types match function signatures
```

### Getting Help

1. Check console for errors
2. Review [UI_ARCHITECTURE.md](./UI_ARCHITECTURE.md) for system overview
3. Look at existing components for examples
4. Check RemoteEvents are firing (`print` statements)
5. Verify UIConfig syntax is correct

## Related Documentation

- **[UI Architecture](./UI_ARCHITECTURE.md)** - Complete system architecture and diagrams
- **[Quick Start Guide](./UI_CUSTOMIZATION_QUICK_START.md)** - Fast customization examples
- **[GUI Editor Integration](./EXAMPLE_GUI_EDITOR_INTEGRATION.md)** - Using Roblox GUI editor with the framework
- **[Stats & XP Guide](./GUIDE_DAMAGE_XP.md)** - Backend stats and XP system

---

**The UI system is designed to be flexible and easy to customize. Happy coding!** 🎨
