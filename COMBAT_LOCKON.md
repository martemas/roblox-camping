# Combat Lock-On System

## Overview

The target lock-on system allows players to lock onto a selected target, automatically rotating their upper body (torso) to face the target while maintaining full movement control. This enhances combat by keeping enemies in view and ensuring directional attacks land consistently.

## Features

- **Toggle Lock-On**: Press Q (configurable) to lock onto your current target
- **Upper Body Rotation**: Player's torso smoothly rotates to face the locked target
- **Movement Freedom**: Full movement control while locked on
- **Natural Limits**: Rotation clamped to prevent unnatural poses
- **Visual Feedback**: HUD border changes to gold when locked, with "🔒 LOCKED" indicator
- **Auto-Unlock**: Automatically unlocks if target dies, despawns, or moves too far

## Configuration

All settings are in `GameConfig.luau` under `targeting.lockOn`:

```lua
targeting = {
	lockOn = {
		enabled = true,                    -- Enable/disable lock-on system
		maxYawAngle = 75,                  -- Max rotation left/right (degrees, 0-180)
		maxPitchAngle = 25,                -- Max rotation up/down (degrees, 0-90)
		rotationSpeed = 0.2,               -- Smoothing factor (0.1=slow, 0.5=fast)
		autoUnlockDistance = 120,          -- Auto-unlock distance (studs)
		toggleKey = Enum.KeyCode.Q,        -- Key binding for toggle
		showLockIndicator = true,          -- Show "LOCKED" text in HUD
	}
}
```

### Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | boolean | `true` | Master toggle for lock-on system |
| `maxYawAngle` | number | `75` | Maximum horizontal rotation (left/right). 0-180 degrees |
| `maxPitchAngle` | number | `25` | Maximum vertical rotation (up/down). 0-90 degrees |
| `rotationSpeed` | number | `0.2` | Lerp smoothing factor. Lower = smoother, Higher = snappier |
| `autoUnlockDistance` | number | `120` | Distance in studs before auto-unlock |
| `toggleKey` | KeyCode | `Q` | Keyboard key to toggle lock-on |
| `showLockIndicator` | boolean | `true` | Show visual "LOCKED" indicator in HUD |

## Usage

### Player Controls

1. **Select a Target**: Click on an enemy or use the targeting system
2. **Lock On**: Press **Q** to toggle lock-on
3. **Combat**: Your upper body will track the target automatically
4. **Unlock**: Press **Q** again or move too far away

### Visual Indicators

The target HUD border color indicates your lock-on state:

- 🟢 **Green**: In range, facing target, can attack
- 🟡 **Gold**: Locked onto target
- 🔴 **Red**: Out of range or not facing

When locked on:
- HUD shows "🔒 LOCKED" text
- Border color changes to gold
- Upper body visibly rotates to face target

## Technical Implementation

### Architecture

The system consists of four main components:

1. **GameConfig.luau**: Configuration settings
2. **TargetingSystem.luau**: Lock-on state management
3. **TargetLockOn.client.luau**: Waist rotation logic
4. **TargetHUD.client.luau**: Visual feedback

### How It Works

#### 1. Character Rigging (R15)

The system manipulates the **Waist Motor6D** joint that connects the LowerTorso to the UpperTorso:

```
HumanoidRootPart
  └── LowerTorso
        └── Waist (Motor6D) ← We modify this
              └── UpperTorso
                    └── Head, Arms, etc.
```

#### 2. Rotation Calculation

```lua
-- Calculate direction to target in local space
local toTarget = (targetPos - rootPos).Unit
local localTarget = rootCFrame:VectorToObjectSpace(toTarget)

-- Calculate yaw (left/right) and pitch (up/down)
local yaw = math.atan2(-localTarget.X, -localTarget.Z)
local pitch = math.asin(localTarget.Y)

-- Clamp to configured limits
yaw = math.clamp(math.deg(yaw), -maxYawAngle, maxYawAngle)
pitch = math.clamp(math.deg(pitch), -maxPitchAngle, maxPitchAngle)
```

#### 3. Smooth Application

```lua
-- Apply rotation with lerp for smoothness
local desiredRotation = CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
local targetC0 = originalWaistC0 * desiredRotation
waist.C0 = waist.C0:Lerp(targetC0, rotationSpeed)
```

### State Management

Lock-on state is tracked per-player in `TargetingSystem.luau`:

```lua
type PlayerTargetState = {
	currentTarget: Model?,
	isLockedOn: boolean,  -- Lock-on state
	-- ... other fields
}
```

**API Functions**:
- `TargetingSystem.setLockedOn(player, locked)` - Set lock state
- `TargetingSystem.isLockedOn(player)` - Check lock state
- `TargetingSystem.toggleLockOn(player)` - Toggle lock on/off

### Auto-Unlock Conditions

The system automatically unlocks when:
1. Target's health reaches 0 (dies)
2. Target model is removed from workspace (despawns)
3. Distance to target exceeds `autoUnlockDistance`
4. Player clears their target

### Performance

- **Client-Side Only**: All rotation calculations run on the client for responsiveness
- **60 FPS Updates**: Uses `RunService.RenderStepped` for smooth animation
- **Minimal Overhead**: Only processes when locked on and target exists

## Compatibility

### Supported Character Types
- ✅ **R15**: Full support with Waist manipulation
- ❌ **R6**: Gracefully disabled (no Waist joint exists)

### Works With
- All existing targeting features
- Movement (walk, run, jump)
- Combat system (directional attacks)
- Camera controls
- Mobile, keyboard, and gamepad inputs

## Limitations

1. **R15 Only**: System requires the Waist Motor6D (R15 rig)
2. **Upper Body Only**: Does not rotate legs or camera
3. **Angle Limits**: Cannot rotate beyond configured limits (prevents unnatural poses)
4. **Single Target**: Can only lock onto one target at a time

## Design Decisions

### Why Upper Body Only?

Rotating only the upper body (via Waist joint) provides:
- Natural looking animation while moving
- Full movement control (legs still face movement direction)
- No interference with Roblox's humanoid locomotion
- Maintains player's sense of camera control

### Why Client-Side?

Lock-on is purely visual/client-side because:
- Server doesn't need to know which direction player is facing
- Combat hit detection already happens on server with proper validation
- Reduces network traffic
- Provides instant, responsive feedback

### Rotation Limits Rationale

**Yaw (left/right) = 75°**:
- Allows seeing targets to either side
- Prevents "owl neck" effect (180° rotation)
- Still maintains forward movement coherence

**Pitch (up/down) = 25°**:
- Minimal vertical rotation to avoid weird poses
- Enough to aim at flying or elevated enemies
- Prevents extreme upward/downward bending

## Integration with Directional Combat

Lock-on synergizes with the directional combat system:

1. **Facing Requirement**: Lock-on ensures you're always facing the target
2. **Attack Success**: Green/gold border indicates when attacks will land
3. **Auto-Tracking**: No need to manually aim during combat

When locked on:
- Border is **gold** if in range and facing (locked + can attack)
- Directional attacks automatically succeed (facing requirement met)
- Player can focus on movement and timing

## Troubleshooting

### Lock-On Doesn't Work

**Check**:
1. Is `targeting.lockOn.enabled = true` in GameConfig?
2. Is your character R15 (not R6)?
3. Do you have a target selected?
4. Check console for "Waist Motor6D not found" warning

### Rotation Looks Unnatural

**Adjust**:
- Reduce `maxYawAngle` (try 60° instead of 75°)
- Reduce `maxPitchAngle` (try 15° instead of 25°)
- Decrease `rotationSpeed` for smoother rotation

### Target Unlocks Too Often

**Adjust**:
- Increase `autoUnlockDistance` (try 150 instead of 120)

### Rotation Too Slow/Fast

**Adjust**:
- Modify `rotationSpeed`:
  - `0.1` = Very smooth, slow
  - `0.2` = Balanced (default)
  - `0.3-0.5` = Fast, snappy

## Future Enhancements

Potential additions for future versions:

1. **Camera Lock-On**: Optional camera rotation to follow target
2. **Cycle Targets**: Next/Previous target while locked on
3. **Mobile UI**: Touch button for lock-on toggle
4. **Lock-On Reticle**: Crosshair that follows locked target
5. **Enemy Lock Indicator**: Show enemies that you're locked on
6. **Break Lock Conditions**: Obstacles blocking line of sight
7. **R6 Support**: Alternative implementation for R6 characters

## Files Modified/Created

### New Files
- `src/client/TargetLockOn.client.luau` - Main lock-on logic

### Modified Files
- `src/shared/GameConfig.luau` - Added `targeting.lockOn` config
- `src/shared/TargetingSystem.luau` - Added lock-on state management
- `src/client/TargetHUD.client.luau` - Added visual indicators

## Related Systems

- [Targeting System](./docs/targeting.md)
- [Combat System](./docs/combat.md)
- [Directional Combat](./docs/directional-combat.md)
