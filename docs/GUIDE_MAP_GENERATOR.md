# Map Generator Usage Guide

This guide explains how to integrate the Map Generator into your game initialization.

## Overview

The Map Generator creates procedurally generated worlds using **Perlin noise** for natural terrain height generation combined with **altitude-based biomes** for realistic biome distribution.

Supports two rendering modes:
- **Terrain Mode**: Smooth Roblox terrain (natural, organic look)
- **Parts Mode**: Minecraft-style blocky world using individual Parts

---

## Quick Start

### 1. Configure Map Settings

Edit `src/server/engine/Config/MapConfig.luau`:

```lua
-- Map size and generation
MapConfig.generation = {
    enabled = true,
    mapSize = 1024,           -- Total map size in studs (1024×1024)
    tileSize = 16,            -- Each tile = 16×16 studs (64×64 grid)
    seed = nil,               -- nil = random map, or set number for specific map

    -- Perlin noise settings
    perlinScale = 10,         -- Perlin noise scale (smaller = more detail, larger = smoother)
    perlinOctaves = 3,        -- Number of noise octaves (more = more detail)
}

-- Rendering mode
MapConfig.rendering = {
    mode = "terrain",              -- "terrain" or "parts"
    style = "smooth",              -- "smooth" or "blocky"
    heightQuantization = 1,        -- Snap heights to grid (0 = disabled)
    heightOffset = 0,              -- Global Y offset for entire map
    useRobloxMaterials = true,     -- true = use terrain materials, false = SmoothPlastic

    -- Altitude-based biome system
    useAltitudeBiomes = true,      -- Enable altitude-based terrain conversion
    altitudeBands = {
        { maxHeight = -8, tileType = 1 },  -- DeepWater
        { maxHeight = -2, tileType = 2 },  -- Water
        { maxHeight = 1, tileType = 3 },   -- Sand (beaches)
        { maxHeight = 6, tileType = 4 },   -- Grass (lowlands)
        { maxHeight = 10, tileType = 5 },  -- Forest (mid elevation)
        { maxHeight = 14, tileType = 6 },  -- Hill (barren/rocky)
        { maxHeight = 20, tileType = 7 },  -- Mountain (high peaks)
        { maxHeight = math.huge, tileType = 8 },  -- Snow (very high)
    },
}
```

### 2. Initialize in Your Game Script

Add to your game initialization (e.g., `src/server/games/alpha/GameInit.luau`):

```lua
-- Import the service
local MapGeneratorService = require(Engine.MapGenerator.MapGeneratorService)

-- Initialize the service
MapGeneratorService.initialize()
Framework.register("MapGeneratorService", MapGeneratorService)

-- Generate and build the world (creates 3D terrain in workspace)
print("Generating world...")
local mapData = MapGeneratorService.generateAndBuildWorld()

if mapData then
    print(`✓ World generated successfully (seed: {mapData.seed})`)

    -- Optional: Reposition or remove the default baseplate
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then
        baseplate.Position = Vector3.new(0, -12, 0)  -- Move down to avoid z-fighting
        -- Or destroy it:
        -- baseplate:Destroy()
    end
else
    warn("✗ Failed to generate world")
end
```

### 3. Integration Example

Full integration in your game init:

```lua
-- STEP 1: Initialize core systems
Framework.register("ProfileStore", ProfileStore)

-- STEP 2: Initialize Map Generator (BEFORE resources/spawning)
local MapGeneratorService = require(Engine.MapGenerator.MapGeneratorService)
MapGeneratorService.initialize()
Framework.register("MapGeneratorService", MapGeneratorService)

-- Generate the world
local mapData = MapGeneratorService.generateAndBuildWorld()
if not mapData then
    error("Failed to generate world - cannot continue")
end

-- STEP 3: Initialize other systems (resources will spawn on generated terrain)
local ResourceManager = require(Engine.ResourceManager)
Framework.register("ResourceManager", ResourceManager)
```

---

## Configuration Options

### Map Generation Settings

```lua
MapConfig.generation = {
    enabled = true,            -- Enable/disable procedural generation
    mapSize = 1024,            -- Map size in studs (creates mapSize × mapSize world)
    tileSize = 16,             -- Size of each tile (smaller = more detail, slower)
    seed = nil,                -- Seed for generation (nil = random)

    -- Perlin noise settings
    perlinScale = 10,          -- Perlin noise scale/frequency (smaller = more detail, larger = smoother)
    perlinOctaves = 3,         -- Number of noise octaves (more detail = more detail)
}
```

**Tile Size Impact:**
- `tileSize = 8`: 128×128 grid (16384 tiles) - Very detailed, slower
- `tileSize = 16`: 64×64 grid (4096 tiles) - **Recommended**
- `tileSize = 32`: 32×32 grid (1024 tiles) - Fast, less detail

### Height Generation

The map generator uses **Perlin noise** to create smooth, natural terrain heights:

- Pure Perlin noise generation (no constraints or failures)
- Heights are converted to tile types using altitude bands
- Fully deterministic with seeded random generation
- Naturally realistic terrain with varied elevation zones
- Fast and simple generation method

**Perlin Settings:**
- `perlinScale`: Controls the "zoom level" of the noise (smaller = more detailed/chaotic, larger = smoother/rolling)
  - Small (5-8): Chaotic, jagged terrain with lots of peaks
  - Large (15-20): Smooth, rolling hills
- `perlinOctaves`: Adds layered noise for more varied terrain (more = more detail)
  - Low (2-3): Smooth, simple terrain
  - High (4-6): Detailed, complex terrain with more variation

### Exponential Perlin Distribution (Optional)

For more dramatic terrain with extreme peaks and valleys, enable exponential Perlin mode:

```lua
MapConfig.generation = {
    -- ... other settings ...
    useExponentialPerlin = true,      -- Enable exponential amplitude modulation
    exponentialMode = "exp",          -- "exp", "quadratic", or "linear"
    exponentialAmplitude = 1.2,       -- Controls how dramatic the effect is
}
```

**Exponential Modes:**

| Mode | Formula | Effect | Range |
|------|---------|--------|-------|
| `"exp"` | e^(value * amplitude) | Most dramatic, exponential growth | [1.0, e^amplitude] |
| `"quadratic"` | 1 + (value² * amplitude) | Moderate, smoother curve | [1.0, 1 + amplitude] |
| `"linear"` | 1 + (value * amplitude) | Subtle, predictable | [1.0, 1 + amplitude] |

**Amplitude Examples:**
- `exponentialAmplitude = 0.5` with mode "linear": 1.5x max amplification (subtle)
- `exponentialAmplitude = 1.0` with mode "exp": 2.7x max amplification (moderate)
- `exponentialAmplitude = 2.0` with mode "exp": 7.4x max amplification (dramatic)
- `exponentialAmplitude = 3.0` with mode "exp": 20x max amplification (very dramatic)

**Recommended Presets:**
- Natural: `useExponentialPerlin = false`
- Balanced: `mode = "linear", amplitude = 0.5`
- Dramatic: `mode = "exp", amplitude = 2.0`

### Rendering Settings

```lua
MapConfig.rendering = {
    mode = "parts",              -- "terrain" (smooth) or "parts" (blocky)
    heightOffset = 0,            -- Global Y offset for entire map (positive = higher)
    useRobloxMaterials = true,   -- true = terrain materials, false = SmoothPlastic

    -- Altitude-based biome system (converts heights to terrain types)
    useAltitudeBiomes = true,    -- Enable altitude-based terrain conversion
    altitudeBands = {
        { maxHeight = 1, tileType = 3 },   -- Sand (lowest elevation, beaches)
        { maxHeight = 4, tileType = 4 },   -- Grass (lowlands)
        { maxHeight = 20, tileType = 5 },  -- Forest (mid elevation)
        { maxHeight = 32, tileType = 6 },  -- Hill (barren/rocky)
        { maxHeight = 64, tileType = 7 },  -- Mountain (high peaks)
        { maxHeight = math.huge, tileType = 8 },  -- Snow (very high)
    },

    -- Water plate settings (visual overlay, non-collidable)
    water = {
        enabled = true,
        height = -0.2,             -- Absolute Y position (0 = ground level, negative = below)
        material = Enum.Material.Water,
        transparency = 0.3,
    },
}
```

**Mode Options:**
- `"terrain"`: Uses Roblox Terrain API (smooth, natural look)
- `"parts"`: Uses individual Parts (Minecraft-style, blocky look)

**Height Offset:**
- Positions the entire map vertically
- Positive values raise the map, negative values lower it
- Example: `heightOffset = 50` places all terrain 50 studs higher
- 0 = ground level positioning

**Materials:**
- `useRobloxMaterials = true`: Uses Grass, Sand, Snow, Rock materials (realistic)
- `useRobloxMaterials = false`: Uses SmoothPlastic for all blocks (debug/uniform)

**Altitude Biomes System:**
- `useAltitudeBiomes`: Enable/disable altitude-based terrain conversion
- `altitudeBands`: Array defining height thresholds and tile types
- Creates realistic elevation zones automatically based on height
- Checked in order - first matching threshold wins
- Tile types: 3=Sand, 4=Grass, 5=Forest, 6=Hill, 7=Mountain, 8=Snow

**Water Plate:**
- Visual overlay of water at a specific height
- `height = 0`: Water at ground level
- `height = -0.2`: Water 0.2 studs below ground (subtle underwater effect)
- `height = -5`: Water 5 studs below ground
- Non-collidable (players can walk through it)
- Semi-transparent with configurable opacity
- **Note**: Water plate uses altitude bands OR separate overlay - not both

---

## Seed Management

### Random Maps (Different Each Time)

```lua
MapConfig.generation = {
    seed = nil,  -- Random seed every time
}
```

Every server start generates a completely new world.

### Deterministic Maps (Same Every Time)

```lua
MapConfig.generation = {
    seed = 12345,  -- Fixed seed
}
```

Same seed always produces identical maps. Useful for:
- Testing
- Competitive gameplay (same map for all players)
- Sharing specific worlds

### Programmatic Seed Control

```lua
-- Generate with specific seed
local mapData = MapGeneratorService.generateAndBuildWorld(99999)

-- Generate with random seed (ignores config)
local mapData = MapGeneratorService.generateAndBuildWorld(math.floor(tick() * 1000))

-- Use config seed
local mapData = MapGeneratorService.generateAndBuildWorld()
```

---

## Accessing Map Data

After generation, you can access map information:

```lua
local mapData = MapGeneratorService.getCurrentMapData()

if mapData then
    print(`Seed: {mapData.seed}`)
    print(`Grid Size: {mapData.gridWidth}x{mapData.gridHeight}`)
    print(`Map Size: {mapData.mapSize}x{mapData.mapSize} studs`)
    print(`Origin: {mapData.origin}`)

    -- Access tile at grid coordinates
    local tile = mapData.grid.tiles[y][x]
    print(`Tile type: {tile.tileType}`)
    print(`Height: {tile.height}`)
end
```

---

## Rendering Modes Comparison

### Terrain Mode (Smooth)

**Pros:**
- Natural, organic appearance
- Smooth transitions between tiles
- Built-in Roblox terrain features
- Better performance for large maps

**Cons:**
- Can't modify individual tiles easily
- Less control over appearance
- Not suitable for block-building games

**Use When:**
- Creating realistic landscapes
- Natural exploration worlds
- Don't need block manipulation

**Configuration:**
```lua
MapConfig.rendering = {
    mode = "terrain",
    style = "smooth",
    heightQuantization = 0,
    heightOffset = 0,
    useAltitudeBiomes = true,
}
```

### Parts Mode (Minecraft-style)

**Pros:**
- Blocky, Minecraft-like appearance
- Each tile is a clickable Part
- Can modify/destroy individual blocks
- Perfect for building games
- Easy to add custom properties

**Cons:**
- More parts = more memory (4096 parts for 64×64 grid)
- Slightly worse performance for huge maps
- Not as natural-looking

**Use When:**
- Building/crafting games
- Want block manipulation
- Minecraft-style aesthetics
- Need per-tile interaction

**Configuration:**
```lua
MapConfig.rendering = {
    mode = "parts",
    style = "smooth",
    heightQuantization = 4,
    heightOffset = 0,
    useAltitudeBiomes = true,
}
```

---

## Performance Considerations

### Map Size vs Generation Time

| Map Size | Grid | Tiles | Generation Time |
|----------|------|-------|-----------------|
| 256×256  | 16×16 | 256 | <1s |
| 512×512  | 32×32 | 1024 | <5s |
| 1024×1024 | 64×64 | 4096 | <20s |

**Recommendations:**
- **Small maps (256×256)**: Testing, small arenas
- **Medium maps (512×512)**: Best balance of detail and speed
- **Large maps (1024×1024)**: Open world games (use `perlin_only` for speed)

**Tips:**
- Use `perlin_only` mode for fastest generation
- Larger `perlinScale` values = smoother, faster generation
- Higher `perlinOctaves` = more detail but slightly slower

---

## Common Use Cases

### Case 1: Survival Game (Random Maps with Altitude Biomes)

```lua
MapConfig.generation = {
    mapSize = 1024,
    tileSize = 16,
    seed = nil,  -- Different world each server
    perlinScale = 10,
    perlinOctaves = 3,
}

MapConfig.rendering = {
    mode = "terrain",
    style = "smooth",
    heightQuantization = 0,
    useAltitudeBiomes = true,
}
```

### Case 2: Minecraft Clone (Blocky Terrain)

```lua
MapConfig.generation = {
    mapSize = 512,
    tileSize = 16,
    seed = nil,
    perlinScale = 12,
    perlinOctaves = 4,
}

MapConfig.rendering = {
    mode = "parts",
    style = "smooth",
    heightQuantization = 4,
    heightOffset = 0,
    useRobloxMaterials = false,
    useAltitudeBiomes = true,
}
```

### Case 3: Competitive PvP (Same Map, Fixed Seed)

```lua
MapConfig.generation = {
    mapSize = 512,
    tileSize = 16,
    seed = 99999,  -- Fixed seed for fairness
    perlinScale = 10,
    perlinOctaves = 3,
}

MapConfig.rendering = {
    mode = "terrain",
    style = "smooth",
    heightQuantization = 0,
}
```

### Case 4: Fast Open World (Largest Possible)

```lua
MapConfig.generation = {
    mapSize = 2048,
    tileSize = 32,  -- Larger tiles = fewer, faster
    seed = nil,
    perlinScale = 20,  -- Smoother for performance
    perlinOctaves = 2,  -- Fewer octaves for speed
}

MapConfig.rendering = {
    mode = "terrain",
    style = "smooth",
    heightQuantization = 2,  -- Some quantization for faster rendering
}
```

---

## Troubleshooting

### Map Doesn't Generate

**Problem:** `generateAndBuildWorld()` returns `nil`

**Solutions:**
1. Check console for error messages
2. Try different seed
3. Reduce map size
4. Check if you have altitude biome mismatch

### Same Map Every Time (When Expecting Random)

**Problem:** Getting identical maps despite `seed = nil`

**Solutions:**
1. Verify `MapConfig.generation.seed = nil`
2. Check if you're passing a seed to `generateAndBuildWorld(seed)`
3. Rebuild with `rojo build` and reload place file

### Parts Not Appearing

**Problem:** `mode = "parts"` but no parts in workspace

**Solutions:**
1. Check `workspace.GeneratedWorld` exists in Explorer
2. Verify rendering mode in console output
3. Rebuild and reload place file
4. Check for errors in PartsBuilder

### Terrain Not Appearing

**Problem:** `mode = "terrain"` but no terrain visible

**Solutions:**
1. Check `workspace.Terrain` has voxels in Explorer
2. Zoom out - terrain might be far from camera
3. Check console for rendering errors
4. Try smaller map size

### Altitude Biomes Not Working

**Problem:** Not seeing varied terrain types (water/mountains), mostly grass

**Solutions:**
1. Verify `useAltitudeBiomes = true` in rendering config
2. Check `altitudeBands` thresholds match your heightmap range
3. Verify Perlin is generating varied heights: check console output for height range
4. Try different `perlinScale` (smaller = more variation)
5. Increase `perlinOctaves` for more terrain detail

### Water Plate Not Appearing

**Problem:** Water plate not visible or at wrong position

**Solutions:**
1. Verify `water.enabled = true`
2. Check `water.height` value - use 0 for ground level, negative for below ground
3. Verify `water.transparency` is not 1.0 (fully transparent)
4. Check console output - PartsBuilder should log "Creating water plate at height X"
5. Try `water.transparency = 0.5` for more visibility

### Terrain Looks Flat

**Problem:** All terrain is at same height, no peaks or valleys

**Solutions:**
1. Increase `perlinOctaves` (default 4, try 6-8)
2. Decrease `perlinScale` (default 10, try 5-8 for more chaotic terrain)
3. Increase `heightScale` (default 40, try 60-80 for taller mountains)
4. Try enabling exponential Perlin for more dramatic variation

---

## Advanced Usage

### Adjusting Terrain Detail

Control terrain complexity with Perlin settings:

```lua
-- Smooth, rolling hills (fewer details)
MapConfig.generation.perlinScale = 20   -- Larger scale
MapConfig.generation.perlinOctaves = 2  -- Fewer layers

-- Chaotic, detailed terrain (more features)
MapConfig.generation.perlinScale = 5    -- Smaller scale
MapConfig.generation.perlinOctaves = 5  -- More layers
```

### Custom Altitude Bands

Define custom elevation zones for your game:

```lua
altitudeBands = {
    { maxHeight = -10, tileType = 1 },  -- Deep ocean
    { maxHeight = 0, tileType = 2 },    -- Shallow ocean
    { maxHeight = 2, tileType = 3 },    -- Beach
    { maxHeight = 5, tileType = 4 },    -- Plains
    { maxHeight = 10, tileType = 5 },   -- Forest
    { maxHeight = 15, tileType = 6 },   -- Hills
    { maxHeight = 25, tileType = 7 },   -- Mountains
    { maxHeight = math.huge, tileType = 8 },  -- Snow peaks
}
```

### Regenerate World

```lua
-- Regenerate with new seed
local newMapData = MapGeneratorService.generateAndBuildWorld(math.random(1, 999999))

-- Regenerate with same seed
local sameMapData = MapGeneratorService.generateAndBuildWorld(mapData.seed)
```

### Custom Tile Placement

```lua
local MapData = require(Engine.MapGenerator.MapData)

-- Get tile at world position
local gridCoord = MapData.worldToGrid(worldX, worldZ, mapData.tileSize, mapData.origin)
local tile = mapData.grid.tiles[gridCoord.y][gridCoord.x]

-- Modify tile (Parts mode only)
if tile then
    local part = workspace.GeneratedWorld:FindFirstChild(`Tile_{gridCoord.x}_{gridCoord.y}_*`)
    if part then
        part.Color = Color3.new(1, 0, 0) -- Make it red
    end
end
```

---

## API Reference

### MapGeneratorService

#### `initialize()`
Initialize the map generator service. Call once at game start.

#### `generateAndBuildWorld(seed: number?): MapData?`
Generate 2D map and build 3D world in one step.
- **Parameters:** `seed` (optional) - Seed for generation
- **Returns:** `MapData` or `nil` if failed

#### `generate(seed: number?): MapData?`
Generate 2D map only (no 3D building).
- **Parameters:** `seed` (optional) - Seed for generation
- **Returns:** `MapData` or `nil` if failed

#### `getCurrentMapData(): MapData?`
Get the currently generated map data.
- **Returns:** `MapData` or `nil` if no map generated

### MapData Structure

```lua
type MapData = {
    seed: number,              -- Seed used for generation
    mapSize: number,           -- Total map size in studs
    tileSize: number,          -- Size of each tile
    gridWidth: number,         -- Grid width in tiles
    gridHeight: number,        -- Grid height in tiles
    grid: MapGrid,             -- 2D tile grid
    zones: { PlacedZone },     -- Placed zones (future feature)
    bounds: MapBounds,         -- World coordinate bounds
    origin: Vector3,           -- World origin point
}
```

---

## Next Steps

- **Phase 4**: Zones & Biome Constraints (player town, castle placement)
- **Phase 5**: Serialization & Persistence (save/load maps)
- **Phase 6**: 2D Map Rendering & Player Tool
- **Phase 7**: Structure & Decoration Placement

See [MAP_GENERATOR_PLAN.md](MAP_GENERATOR_PLAN.md) for full roadmap.
