# Client-Side Projectile Prediction

## Overview

Client-side projectile prediction provides instant visual feedback when firing projectile weapons, eliminating the perceived lag caused by network latency and cast duration delays.

## Problem

Previously, projectiles experienced visible lag when firing while moving because:
1. Client sends fire request to server
2. Network latency (client → server)
3. Server validates and waits for `castDuration`
4. Server spawns projectile
5. Network latency (server → client replication)

**Total delay = 2 × network latency + castDuration (0.25-0.6s)**

During this delay, the player moves forward, making the projectile appear to spawn "behind" them.

## Solution

**Dual Projectile System:**
- **Client Visual**: Spawns immediately for instant feedback (visual only, no collision/damage)
- **Server Authoritative**: Handles physics, hit detection, and damage (slightly delayed)

## Architecture

### Client Side

**Files:**
- `src/client/combat/ProjectileVisual.client.luau` - Visual projectile renderer
- `src/client/common/ToolClickHandler.client.luau` - Spawns client projectiles on weapon activation
- `src/shared/engine/Combat/WeaponConfig.luau` - Client-safe weapon configurations

**Flow:**
1. Player clicks to fire
2. Client immediately spawns visual projectile after castDuration
3. Client sends RemoteEvent to server
4. Visual projectile animates using `RenderStepped`
5. Visual projectile auto-destroys at max range or 10s timeout

### Server Side

**Files:**
- `src/server/engine/Combat/ProjectileManager.luau` - Authoritative projectile spawning
- `src/server/engine/Combat/ProjectilePhysics.luau` - Hit detection and damage
- `src/shared/engine/Combat/ProjectileConfig.luau` - Shared model access

**Flow:**
1. Server receives fire request
2. Server validates attack (range, LOS, facing, etc.)
3. Server waits castDuration (animation time)
4. Server spawns authoritative projectile
5. Server handles physics, collisions, and damage

### Shared Components

**`ProjectileConfig.luau`:**
- Provides access to projectile models from storage
- `getProjectileModel()` - Clone model from ServerStorage (server) or ReplicatedStorage (client)
- `setupVisualProjectile()` - Configure for client rendering
- `setupServerProjectile()` - Configure for server physics

**`WeaponConfig.luau`:**
- Client-safe weapon properties (no damage values)
- Exposes only visual/timing data: speed, castDuration, range, model paths
- Prevents client from knowing damage values or exploiting gameplay data

## Security

✅ **Client has NO authority over:**
- Hit detection
- Damage calculation
- Target validation
- Physics simulation

✅ **Client only controls:**
- Visual projectile rendering
- Timing of visual spawn (matches server timing)
- Model animation

✅ **Server validates:**
- All weapon usage
- Line of sight
- Range checks
- Cooldowns
- Hit detection via raycasts

## Configuration

### Adding New Projectile Weapons

1. **Add to `WeaponStats.luau` (server):**
```lua
MyWeapon = {
	type = "projectile",
	projectileSpeed = 60,
	castDuration = 0.3,
	range = 80,
	projectileConfig = {
		modelPath = "MyProjectileModel",
		trailEnabled = true,
		trailColor = Color3.fromRGB(0, 255, 0),
	},
}
```

2. **Add to `WeaponConfig.luau` (client-safe):**
```lua
MyWeapon = {
	type = "projectile",
	projectileSpeed = 60,
	castDuration = 0.3,
	range = 80,
	projectileConfig = {
		modelPath = "MyProjectileModel",
		trailEnabled = true,
		trailColor = Color3.fromRGB(0, 255, 0),
	},
},
```

3. **Add projectile model:**
- ServerStorage: `Assets/Tools/Projectiles/MyWeapon/MyProjectileModel`
- ReplicatedStorage: `Assets/Tools/Projectiles/MyWeapon/MyProjectileModel`

## Benefits

✅ **Instant Visual Feedback** - Projectile spawns immediately (after castDuration)
✅ **No Perceived Lag** - Eliminates network delay perception
✅ **Server Authority Maintained** - All gameplay logic remains server-side
✅ **Simple Implementation** - Dual projectiles coexist without complex sync
✅ **Secure** - Client cannot manipulate damage or hit detection

## Tradeoffs

⚠️ **Minor Visual Duplication** - Two projectiles exist briefly (visual + authoritative)
⚠️ **Memory Overhead** - Client stores duplicate projectile models
⚠️ **Configuration Duplication** - Weapon configs must be synced between client and server

These tradeoffs are acceptable because:
- Projectiles move fast, duplication is barely noticeable
- Models are lightweight
- Configuration duplication is minimal and isolated

## Testing

To test the feature:
1. Equip a projectile weapon (Bow, SpiderWeb, Fireball)
2. Run while firing
3. Observe projectile spawns at current position (no lag)
4. Verify server projectile still handles damage correctly

## Future Enhancements

- **Predictive Hit Markers**: Show client-predicted hits before server confirmation
- **Trajectory Prediction**: Show arc/path before firing
- **Impact Effects**: Client-predicted impact visuals
- **Sound Prediction**: Immediate sound feedback on firing
