# Map Generator Usage Guide

This guide explains how to integrate the Map Generator into your game initialization.

## Overview

The Map Generator creates procedurally generated worlds using the Wave Function Collapse (WFC) algorithm. It supports two rendering modes:
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
    mapSize = 512,      -- Total map size in studs (512×512)
    tileSize = 16,      -- Each tile = 16×16 studs (32×32 grid)
    seed = nil,         -- nil = random map, or set number for specific map
}

-- Rendering mode
MapConfig.rendering = {
    mode = "parts",              -- "terrain" or "parts"
    style = "blocky",            -- "smooth" or "blocky"
    heightQuantization = 4,      -- Snap heights to 4-stud grid (0 = disabled)
    useRobloxMaterials = false,  -- true = use terrain materials, false = SmoothPlastic
}
```

### 2. Initialize in Your Game Script

Add to your game initialization (e.g., `src/server/Games/alpha/GameInit.luau`):

```lua
-- Import the service
local MapGeneratorService = require(Engine.MapGenerator.MapGeneratorService)

-- Initialize the service
MapGeneratorService.initialize()
Framework.register("MapGeneratorService", MapGeneratorService)

-- Generate the world
print("Generating world...")
local mapData = MapGeneratorService.generateAndBuildWorld()

if mapData then
    print(`✓ World generated successfully (seed: {mapData.seed})`)
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
    enabled = true,      -- Enable/disable procedural generation
    mapSize = 512,       -- Map size in studs (creates mapSize × mapSize world)
    tileSize = 16,       -- Size of each tile (smaller = more detail, slower)
    seed = nil,          -- Seed for generation (nil = random)
}
```

**Tile Size Impact:**
- `tileSize = 8`: 64×64 grid (4096 tiles) - Very detailed, slower
- `tileSize = 16`: 32×32 grid (1024 tiles) - **Recommended**
- `tileSize = 32`: 16×16 grid (256 tiles) - Fast, less detail

### Rendering Settings

```lua
MapConfig.rendering = {
    mode = "parts",              -- Rendering mode
    style = "blocky",            -- Height variation style
    heightQuantization = 4,      -- Height snapping
    useRobloxMaterials = false,  -- Material choice
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
- `4`: Snap to 4-stud increments (terraced, Minecraft-like)
- `8`: Snap to 8-stud increments (more dramatic steps)

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
- Smooth transitions
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
- More parts = more memory (1024 parts for default config)
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
    style = "blocky",
    heightQuantization = 4,
}
```

---

## Performance Considerations

### Map Size vs Performance

| Map Size | Grid (16×16 tiles) | Tiles | Parts (if using parts mode) | Generation Time |
|----------|-------------------|-------|----------------------------|-----------------|
| 256×256  | 16×16            | 256   | 256 parts                  | <2s             |
| 512×512  | 32×32            | 1024  | 1024 parts                 | <15s            |
| 1024×1024| 64×64            | 4096  | 4096 parts                 | <60s            |

**Recommendations:**
- **Small maps (256×256)**: Testing, small arenas
- **Medium maps (512×512)**: **Default**, best balance
- **Large maps (1024×1024)**: Open world games, enable progressive generation

### Optimization Settings

```lua
MapConfig.performance = {
    progressiveGeneration = false,  -- Set true for large maps (slower but prevents timeout)
    chunkSize = 64,                -- Chunk size for progressive generation
    useWriteVoxels = true,         -- Use faster terrain API (terrain mode only)
}
```

---

## Common Use Cases

### Case 1: Survival Game (Random Maps)

```lua
-- MapConfig.luau
generation = {
    mapSize = 512,
    tileSize = 16,
    seed = nil,  -- Different world each server
}

rendering = {
    mode = "terrain",
    style = "smooth",
    heightQuantization = 0,
}
```

### Case 2: Minecraft Clone (Blocky Terrain)

```lua
-- MapConfig.luau
generation = {
    mapSize = 512,
    tileSize = 16,
    seed = nil,
}

rendering = {
    mode = "parts",
    style = "blocky",
    heightQuantization = 4,
    useRobloxMaterials = false,
}
```

### Case 3: Competitive PvP (Same Map)

```lua
-- MapConfig.luau
generation = {
    mapSize = 512,
    tileSize = 16,
    seed = 99999,  -- Fixed seed for fairness
}

rendering = {
    mode = "terrain",
    style = "smooth",
    heightQuantization = 0,
}
```

---

## Troubleshooting

### Map Doesn't Generate

**Problem:** `generateAndBuildWorld()` returns `nil`

**Solutions:**
1. Check WFC failed - try different seed
2. Check console for error messages
3. Increase `maxRetries` in WaveFunctionCollapse.luau
4. Try smaller map size

### Same Map Every Time (When Expecting Random)

**Problem:** Getting identical maps despite `seed = nil`

**Solutions:**
1. Verify `MapConfig.generation.seed = nil`
2. Check if you're passing a seed to `generateAndBuildWorld(seed)`
3. Rebuild with `rojo build` and reload place file

### Parts Not Appearing

**Problem:** `mode = "parts"` but no parts in workspace

**Solutions:**
1. Check `workspace.GeneratedWorld` exists
2. Verify rendering mode: Check console for "Using Parts rendering mode"
3. Rebuild and reload place file
4. Check if `PartsBuilder.luau` is properly required

### Terrain Not Appearing

**Problem:** `mode = "terrain"` but no terrain visible

**Solutions:**
1. Check `workspace.Terrain` in Explorer
2. Verify terrain region is cleared correctly
3. Check rendering mode in console output
4. Zoom out - terrain might be far from camera

---

## Advanced Usage

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

### Regenerate World

```lua
-- Regenerate with new seed
local newMapData = MapGeneratorService.generateAndBuildWorld(math.random(1, 999999))

-- Regenerate with same seed
local sameMapData = MapGeneratorService.generateAndBuildWorld(mapData.seed)
```

### Integration with Spawn System

```lua
-- After generating world
if MapConfig.spawn.spawnAtPlayerTown then
    -- Find player town location (if zones are enabled)
    local playerTown = nil
    for _, zone in mapData.zones do
        if zone.id == "playerTown" then
            playerTown = zone
            break
        end
    end

    if playerTown then
        -- Convert grid coords to world position
        local spawnPos = MapData.gridToWorld(
            playerTown.center.x,
            playerTown.center.y,
            mapData.tileSize,
            mapData.origin
        )

        -- Set spawn location
        workspace.SpawnLocation.Position = Vector3.new(spawnPos.x, 10, spawnPos.z)
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
