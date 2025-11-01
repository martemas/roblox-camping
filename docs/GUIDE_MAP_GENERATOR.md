# Map Generator Usage Guide

This guide explains how to integrate the Map Generator into your game initialization.

## Overview

The Map Generator creates procedurally generated worlds with configurable height generation modes:
- **Constrained**: Wave Function Collapse (WFC) with smooth height constraints between neighbors
- **Perlin**: WFC tile placement with Perlin noise heightmaps
- **Perlin Only**: Pure Perlin noise generation (no WFC) - fastest and simplest

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

    -- Height generation mode
    -- "constrained": WFC + smooth height constraints between neighbors
    -- "perlin": WFC tile placement + Perlin noise heightmap
    -- "perlin_only": Pure Perlin noise (no WFC) - fastest and simplest
    heightGenerationMode = "perlin_only",
    maxHeightDelta = 2,       -- Max height diff between adjacent tiles (constrained mode)
    perlinScale = 10,         -- Perlin noise scale (smaller = more detail)
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

    -- Height generation mode
    heightGenerationMode = "perlin_only",  -- "constrained", "perlin", or "perlin_only"
    maxHeightDelta = 2,        -- Max height difference between adjacent tiles
    perlinScale = 10,          -- Perlin noise scale/frequency (smaller = more detail)
    perlinOctaves = 3,         -- Number of noise octaves
}
```

**Tile Size Impact:**
- `tileSize = 8`: 128×128 grid (16384 tiles) - Very detailed, slower
- `tileSize = 16`: 64×64 grid (4096 tiles) - **Recommended**
- `tileSize = 32`: 32×32 grid (1024 tiles) - Fast, less detail

### Height Generation Modes

**Constrained Mode** (`heightGenerationMode = "constrained"`)
- Uses WFC for tile placement with adjacency rules
- Heights constrained to be within `maxHeightDelta` of neighbors
- Creates smooth rolling terrain without abrupt jumps
- Respects WFC adjacency constraints throughout

**Perlin Mode** (`heightGenerationMode = "perlin"`)
- Uses WFC for tile placement (respects adjacency rules)
- Heights generated from Perlin noise (smooth, continuous)
- Altitude biomes then converts tile types based on final height
- Combines structured WFC patterns with smooth Perlin heights

**Perlin Only Mode** (`heightGenerationMode = "perlin_only"`) - **Fastest & Recommended**
- Pure Perlin noise generation (no WFC at all)
- Directly converts height to tile types using altitude bands
- Guaranteed to succeed (no WFC contradictions)
- Naturally realistic terrain without adjacency constraints
- Simplest and fastest generation method

### Rendering Settings

```lua
MapConfig.rendering = {
    mode = "parts",              -- Rendering mode
    style = "smooth",            -- Height variation style
    heightQuantization = 1,      -- Height snapping
    heightOffset = 0,            -- Global Y offset for entire map
    useRobloxMaterials = true,   -- Material choice

    -- Altitude-based biome system
    useAltitudeBiomes = true,    -- Enable altitude-based terrain conversion
    altitudeBands = {
        { maxHeight = -8, tileType = 1 },  -- DeepWater
        { maxHeight = -2, tileType = 2 },  -- Water
        { maxHeight = 1, tileType = 3 },   -- Sand
        { maxHeight = 6, tileType = 4 },   -- Grass
        { maxHeight = 10, tileType = 5 },  -- Forest
        { maxHeight = 14, tileType = 6 },  -- Hill
        { maxHeight = 20, tileType = 7 },  -- Mountain
        { maxHeight = math.huge, tileType = 8 },  -- Snow
    },
}
```

**Mode Options:**
- `"terrain"`: Uses Roblox Terrain API (smooth, natural)
- `"parts"`: Uses individual Parts (Minecraft-style, blocky)

**Style Options:**
- `"smooth"`: Height varies within tile types (natural rolling hills)
- `"blocky"`: Uniform heights per tile type (flat layers)

**Height Quantization:**
- `0`: No snapping (smooth height transitions)
- `1`: Snap to 1-stud increments (subtle steps)
- `4`: Snap to 4-stud increments (terraced, Minecraft-like)
- `8`: Snap to 8-stud increments (more dramatic steps)

**Height Offset:**
- Positions the entire map vertically
- Positive values raise the map, negative values lower it
- Example: `heightOffset = 50` places the map 50 studs higher
- Works with all height generation modes

**Altitude Biomes System:**
- `useAltitudeBiomes`: Enable/disable altitude-based terrain conversion
- `altitudeBands`: Array defining height thresholds and tile types
- Creates realistic elevation zones (water → beaches → grass → hills → mountains → snow)
- Tile types: 1=DeepWater, 2=Water, 3=Sand, 4=Grass, 5=Forest, 6=Hill, 7=Mountain, 8=Snow
- Height thresholds account for `heightOffset` automatically
- Note: `perlin_only` always applies altitude biomes internally

---

## Height Generation Comparison

| Feature | Constrained | Perlin | Perlin Only |
|---------|-------------|--------|------------|
| Algorithm | WFC + constraints | WFC + Perlin | Pure Perlin |
| Adjacency Rules | Enforced | Enforced | None |
| Height Smoothness | Between neighbors | Noise-based | Noise-based |
| Speed | Slow | Slow | **Very Fast** |
| Failure Rate | Possible | Possible | **None** |
| Terrain Quality | Good | Excellent | **Excellent** |
| Recommended | Niche | General | **✓ Default** |

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
    heightGenerationMode = "perlin_only",
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

### Case 2: Minecraft Clone (Blocky Terrain with WFC)

```lua
MapConfig.generation = {
    mapSize = 512,
    tileSize = 16,
    seed = nil,
    heightGenerationMode = "constrained",  -- Show WFC patterns
    maxHeightDelta = 2,
}

MapConfig.rendering = {
    mode = "parts",
    style = "smooth",
    heightQuantization = 4,
    heightOffset = 0,
    useRobloxMaterials = false,
    useAltitudeBiomes = false,  -- Disable to see WFC tile patterns
}
```

### Case 3: Competitive PvP (Same Map, Fixed Seed)

```lua
MapConfig.generation = {
    mapSize = 512,
    tileSize = 16,
    seed = 99999,  -- Fixed seed for fairness
    heightGenerationMode = "perlin_only",
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
    heightGenerationMode = "perlin_only",  -- Fastest mode
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
2. Try `perlin_only` mode (cannot fail unlike WFC modes)
3. Try different seed
4. Reduce map size
5. Check if you have altitude biome mismatch

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

**Problem:** Not seeing water/mountains, only grass

**Solutions:**
1. Verify `useAltitudeBiomes = true`
2. Check `altitudeBands` table is defined correctly
3. Try `perlin_only` mode (always applies altitude biomes)
4. Verify heightmap is generating varied heights (not all flat)

---

## Advanced Usage

### Seeing WFC Patterns vs Pure Perlin

To observe the difference between modes:

```lua
-- Mode 1: See WFC tile patterns (ignore height)
MapConfig.generation.heightGenerationMode = "constrained"
MapConfig.rendering.useAltitudeBiomes = false

-- Mode 2: See Perlin patterns (ignore WFC)
MapConfig.generation.heightGenerationMode = "perlin_only"
MapConfig.rendering.useAltitudeBiomes = false

-- Mode 3: See final result (both combined with altitude biomes)
MapConfig.rendering.useAltitudeBiomes = true
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
