# Dynamic Map Generator - Comprehensive Implementation Plan

## Executive Summary

This plan implements a **procedural map generation system** using **Wave Function Collapse (WFC)** algorithm that:
- Generates 2D tile grid first (with zones/biomes/height), then builds 3D terrain from it
- Uses Roblox **Terrain API** for performance (no individual parts per tile)
- **Dynamically places zones** (castle, player town) at random valid locations during generation
- Provides players with a **map tool** showing overhead view + real-time position
- Saves/loads maps deterministically using **seed-based generation**
- Places **structures and decorations** procedurally

---

## Project Context

### Existing Architecture
- **Framework Pattern**: Uses modular initialization via `Framework.register()`
- **Entry Point**: `src/server/Games/alpha/GameInit.luau` initializes all systems
- **Config System**: Server-side configs in `src/server/engine/Config/`
  - `GameConfig.luau` - General gameplay settings (line 136-141 has basic map settings)
  - Will create new `MapConfig.luau` for map generation settings
- **Folder Structure**:
  - Server code: `src/server/engine/`
  - Shared code: `src/shared/engine/`
  - Client code: `src/client/`
- **Rojo Mapping**: `default.project.json` maps folders to Roblox services

### Integration Point
MapGeneratorService should be initialized in [GameInit.luau:76-96](src/server/Games/alpha/GameInit.luau#L76-L96) during "STEP 3: Initialize Game Systems", before ResourceManager (so resources can spawn based on generated terrain).

---

## Project Structure

```
src/
├── server/
│   └── engine/
│       ├── Config/
│       │   ├── GameConfig.luau             # Existing gameplay config
│       │   └── MapConfig.luau              # NEW: Map generation config
│       └── MapGenerator/
│           ├── Types.luau                  # All type definitions
│           ├── TileConfig.luau             # Tile types, biomes, adjacency rules
│           ├── ZonePlacer.luau             # NEW: Dynamic zone positioning logic
│           ├── MapData.luau                # Grid structure, coordinate utilities
│           ├── SeededRandom.luau           # Deterministic RNG wrapper
│           ├── MapSerializer.luau          # Save/load, compression (RLE + bit packing)
│           ├── WaveFunctionCollapse.luau   # WFC algorithm implementation
│           ├── TerrainBuilder.luau         # 3D terrain generation via Terrain API
│           ├── MapRenderer.luau            # 2D texture generation (EditableImage)
│           ├── StructurePlacement.luau     # Prefab/decoration placement
│           └── MapGeneratorService.luau    # Main orchestrator (Framework module)
├── client/
│   └── common/
│       └── MapTool.luau                    # Map GUI + position tracking
└── server/
    └── tests/
        ├── TestMapGenerator.server.luau          # Phase 1-7 tests
        └── TestMapGeneratorFull.server.luau      # Phase 8 integration test
```

**Key Design Decisions:**
- **Server-only generation**: All generation code in server/, clients only display map
- **Separate MapConfig**: Dedicated config file for map settings (not in MapGenerator/)
- **Dynamic zone placement**: Positions determined at runtime, not hardcoded
- **Two-pass WFC**: Base terrain generation, then zone refinement

---

## Configuration Files

### 1. MapConfig.luau (NEW - in Config folder)

**Location**: `src/server/engine/Config/MapConfig.luau`

```lua
--!strict
-- MAP GENERATION CONFIGURATION (SERVER-ONLY)

local MapConfig = {}

-- ═══════════════════════════════════════════════════
-- GENERATION SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.generation = {
	enabled = true,                -- Enable procedural generation
	mapSize = 512,                 -- Total map size in studs (512×512)
	tileSize = 16,                 -- Each tile = 16×16 studs (32×32 grid)
	seed = nil,                    -- nil = random, or set specific number for deterministic map
}

-- ═══════════════════════════════════════════════════
-- PERSISTENCE SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.persistence = {
	useSavedMaps = true,           -- Load from DataStore if available
	saveGeneratedMaps = true,      -- Auto-save after generation
	mapName = "AlphaWorld",        -- DataStore key
	allowRegeneration = true,      -- Can regenerate from seed via admin command
}

-- ═══════════════════════════════════════════════════
-- ZONE DEFINITIONS (Size-only, positions determined at runtime)
-- ═══════════════════════════════════════════════════

MapConfig.zones = {
	-- Player starting town zone
	playerTown = {
		enabled = true,
		radius = 40,               -- Radius in studs (80×80 area)
		biome = "plains",
		constraints = {
			requireFlat = true,    -- Must be flat terrain
			noWater = true,        -- No water tiles allowed
			minDistanceFromEdge = 60,  -- Must be at least 60 studs from map edge
		},
		-- Assets to place in this zone
		structures = {
			{
				name = "Townhall",
				assetPath = "ReplicatedStorage.MapAssets.Structures.Townhall",
				position = "center",   -- "center" or offset like {x=10, z=5}
				rotation = 0,          -- Degrees
			},
			{
				name = "StartingCamp",
				assetPath = "ReplicatedStorage.MapAssets.Structures.Camp",
				position = {x = 15, z = 0},
				rotation = 90,
			}
		}
	},

	-- Enemy castle zone
	castle = {
		enabled = true,
		radius = 64,               -- Larger area for castle grounds
		biome = "plains",
		constraints = {
			requireFlat = true,
			noWater = true,
			minDistanceFromEdge = 80,
			minDistanceFromOtherZones = 150,  -- Must be far from player town
		},
		structures = {
			{
				name = "EnemyCastle",
				assetPath = "ReplicatedStorage.MapAssets.Structures.Castle",
				position = "center",
				rotation = 0,
			},
		}
	},

	-- Optional: Desert biome zone (position randomized)
	desert = {
		enabled = true,
		radius = 80,
		biome = "desert",
		constraints = {
			requireFlat = false,   -- Can have hills
			noWater = true,
			minDistanceFromEdge = 40,
			minDistanceFromOtherZones = 60,
		},
		structures = {}  -- No structures, just biome
	},

	-- Optional: Mountain range (edge of map)
	mountains = {
		enabled = true,
		radius = 60,
		biome = "mountains",
		constraints = {
			requireFlat = false,
			noWater = true,
			preferEdge = true,     -- Prefers to be near map edge
			minDistanceFromEdge = 0,
		},
		structures = {}
	}
}

-- ═══════════════════════════════════════════════════
-- DECORATION SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.decorations = {
	enabled = true,
	density = 0.15,                -- 15% of eligible tiles get decorations
	useVariety = true,             -- Use multiple models per decoration type
	scaleVariation = 0.2,          -- ±20% size variation
}

-- ═══════════════════════════════════════════════════
-- PERFORMANCE SETTINGS
-- ═══════════════════════════════════════════════════

MapConfig.performance = {
	progressiveGeneration = false, -- Generate in chunks with yields (slower but prevents timeout)
	chunkSize = 64,                -- Studs per chunk (if progressive)
	useWriteVoxels = true,         -- Use bulk WriteVoxels (faster) vs FillBlock
	maxDecorations = 2000,         -- Cap total decorations for performance
}

-- ═══════════════════════════════════════════════════
-- SPAWN INTEGRATION
-- ═══════════════════════════════════════════════════

MapConfig.spawn = {
	-- Link player spawn to generated town
	spawnAtPlayerTown = true,      -- Place player spawn at town center
	spawnRadius = 10,              -- Random spawn within radius of town center
}

return MapConfig
```

### 2. TileConfig.luau (NEW - in MapGenerator folder)

**Location**: `src/server/engine/MapGenerator/TileConfig.luau`

```lua
--!strict
-- TILE TYPES AND CONFIGURATION

local TileConfig = {}

-- ═══════════════════════════════════════════════════
-- TILE TYPE ENUM
-- ═══════════════════════════════════════════════════

TileConfig.TileType = {
	DeepWater = 1,
	Water = 2,
	Sand = 3,
	Grass = 4,
	Forest = 5,
	Hill = 6,
	Mountain = 7,
	Snow = 8,
}

-- ═══════════════════════════════════════════════════
-- TILE PROPERTIES
-- ═══════════════════════════════════════════════════

TileConfig.TileProperties = {
	[TileConfig.TileType.DeepWater] = {
		name = "DeepWater",
		baseHeight = -8,
		terrain = Enum.Material.Water,
		color = Color3.fromRGB(0, 50, 100),
		heightVariation = 2,
		decorations = {},
		weight = 0.05,  -- 5% of map (rare)
		isWalkable = false,
	},
	[TileConfig.TileType.Water] = {
		name = "Water",
		baseHeight = -4,
		terrain = Enum.Material.Water,
		color = Color3.fromRGB(50, 100, 200),
		heightVariation = 1,
		decorations = {"Lily", "Reed"},
		weight = 0.10,
		isWalkable = false,
	},
	[TileConfig.TileType.Sand] = {
		name = "Sand",
		baseHeight = 0,
		terrain = Enum.Material.Sand,
		color = Color3.fromRGB(220, 200, 150),
		heightVariation = 1,
		decorations = {"Shell", "Driftwood"},
		weight = 0.08,
		isWalkable = true,
	},
	[TileConfig.TileType.Grass] = {
		name = "Grass",
		baseHeight = 0,
		terrain = Enum.Material.Grass,
		color = Color3.fromRGB(100, 200, 100),
		heightVariation = 2,
		decorations = {"Tree", "Bush", "Rock", "Flower"},
		weight = 0.40,  -- 40% of map (most common)
		isWalkable = true,
	},
	[TileConfig.TileType.Forest] = {
		name = "Forest",
		baseHeight = 0,
		terrain = Enum.Material.Grass,
		color = Color3.fromRGB(50, 150, 50),
		heightVariation = 2,
		decorations = {"TreeDense", "Bush", "Log"},
		weight = 0.15,
		isWalkable = true,
	},
	[TileConfig.TileType.Hill] = {
		name = "Hill",
		baseHeight = 4,
		terrain = Enum.Material.Ground,
		color = Color3.fromRGB(150, 150, 100),
		heightVariation = 3,
		decorations = {"Rock", "Bush"},
		weight = 0.12,
		isWalkable = true,
	},
	[TileConfig.TileType.Mountain] = {
		name = "Mountain",
		baseHeight = 12,
		terrain = Enum.Material.Rock,
		color = Color3.fromRGB(100, 100, 100),
		heightVariation = 5,
		decorations = {"RockLarge", "Boulder"},
		weight = 0.08,
		isWalkable = false,
	},
	[TileConfig.TileType.Snow] = {
		name = "Snow",
		baseHeight = 16,
		terrain = Enum.Material.Snow,
		color = Color3.fromRGB(255, 255, 255),
		heightVariation = 4,
		decorations = {"SnowPine", "IceRock"},
		weight = 0.02,  -- 2% (rare, only high elevations)
		isWalkable = true,
	}
}

-- ═══════════════════════════════════════════════════
-- ADJACENCY RULES (Which tiles can be next to each other)
-- ═══════════════════════════════════════════════════

TileConfig.AdjacencyRules = {
	[TileConfig.TileType.DeepWater] = {
		TileConfig.TileType.DeepWater,
		TileConfig.TileType.Water
	},
	[TileConfig.TileType.Water] = {
		TileConfig.TileType.DeepWater,
		TileConfig.TileType.Water,
		TileConfig.TileType.Sand,
		TileConfig.TileType.Grass
	},
	[TileConfig.TileType.Sand] = {
		TileConfig.TileType.Water,
		TileConfig.TileType.Sand,
		TileConfig.TileType.Grass
	},
	[TileConfig.TileType.Grass] = {
		TileConfig.TileType.Sand,
		TileConfig.TileType.Grass,
		TileConfig.TileType.Forest,
		TileConfig.TileType.Hill
	},
	[TileConfig.TileType.Forest] = {
		TileConfig.TileType.Grass,
		TileConfig.TileType.Forest,
		TileConfig.TileType.Hill
	},
	[TileConfig.TileType.Hill] = {
		TileConfig.TileType.Grass,
		TileConfig.TileType.Forest,
		TileConfig.TileType.Hill,
		TileConfig.TileType.Mountain
	},
	[TileConfig.TileType.Mountain] = {
		TileConfig.TileType.Hill,
		TileConfig.TileType.Mountain,
		TileConfig.TileType.Snow
	},
	[TileConfig.TileType.Snow] = {
		TileConfig.TileType.Mountain,
		TileConfig.TileType.Snow
	}
}

-- ═══════════════════════════════════════════════════
-- BIOME DEFINITIONS (Used for zone constraints)
-- ═══════════════════════════════════════════════════

TileConfig.Biomes = {
	plains = {
		name = "Plains",
		allowedTiles = {
			TileConfig.TileType.Grass,
			TileConfig.TileType.Forest
		},
		heightRange = {-2, 4},
		description = "Flat grasslands suitable for settlements"
	},
	desert = {
		name = "Desert",
		allowedTiles = {
			TileConfig.TileType.Sand,
			TileConfig.TileType.Hill
		},
		heightRange = {-1, 6},
		description = "Sandy terrain with occasional hills"
	},
	mountains = {
		name = "Mountains",
		allowedTiles = {
			TileConfig.TileType.Hill,
			TileConfig.TileType.Mountain,
			TileConfig.TileType.Snow
		},
		heightRange = {4, 20},
		description = "High elevation rocky terrain"
	},
	forest = {
		name = "Forest",
		allowedTiles = {
			TileConfig.TileType.Grass,
			TileConfig.TileType.Forest
		},
		heightRange = {-2, 4},
		description = "Dense woodland"
	},
	water = {
		name = "Water",
		allowedTiles = {
			TileConfig.TileType.Water,
			TileConfig.TileType.DeepWater
		},
		heightRange = {-10, -2},
		description = "Lakes and deep water"
	}
}

-- ═══════════════════════════════════════════════════
-- HEIGHT VALIDATION
-- ═══════════════════════════════════════════════════

function TileConfig.isValidHeightTransition(tile1: number, tile2: number): boolean
	local h1 = TileConfig.TileProperties[tile1].baseHeight
	local h2 = TileConfig.TileProperties[tile2].baseHeight
	local heightDiff = math.abs(h1 - h2)

	-- Max height difference of 8 studs between adjacent tiles (prevents cliffs)
	return heightDiff <= 8
end

return TileConfig
```

---

## Implementation Phases

### Phase 1: Foundation & Basic Grid Generation
**Goal**: Create data structures and generate simple random 2D grid
**Testable**: Print/visualize a grid of random tiles
**Time Estimate**: ~2-3 hours

**Tasks:**
1. Create `Types.luau` with all type definitions including PlacedZone
2. Create `TileConfig.luau` with tile types, properties, adjacency rules, and biomes
3. Create `MapConfig.luau` in Config folder with generation/persistence/zones settings
4. Create `SeededRandom.luau` wrapper for deterministic RNG
5. Create `MapData.luau` with grid utilities and coordinate conversion
6. Create `MapGeneratorService.luau` with initialization and simple random generation
7. Create test script `TestMapGenerator.server.luau` and verify output

**Key Files to Create:**
- `src/server/engine/MapGenerator/Types.luau`
- `src/server/engine/MapGenerator/TileConfig.luau`
- `src/server/engine/Config/MapConfig.luau`
- `src/server/engine/MapGenerator/SeededRandom.luau`
- `src/server/engine/MapGenerator/MapData.luau`
- `src/server/engine/MapGenerator/MapGeneratorService.luau`
- `src/server/tests/TestMapGenerator.server.luau`

**Verification:**
- Run `rojo build` - no compilation errors
- Run test script - see tile distribution printed
- Same seed produces identical grid (determinism test)

---

### Phase 2: WFC Algorithm Implementation
**Goal**: Implement Wave Function Collapse with adjacency rules
**Testable**: Generate maps where tiles follow rules (grass connects to water, mountains cluster)
**Time Estimate**: ~4-6 hours

**Tasks:**
1. Create `WaveFunctionCollapse.luau` with full algorithm implementation
   - Cell state management (superposition of possible tiles)
   - Entropy calculation
   - Wave collapse logic
   - Constraint propagation
2. Update `MapGeneratorService.luau` to add `generate()` method using WFC
3. Update test script to test WFC generation and verify adjacency rules

**Key Files:**
- `src/server/engine/MapGenerator/WaveFunctionCollapse.luau` (NEW)
- Update `MapGeneratorService.luau`
- Update test script

**Verification:**
- WFC generates complete maps without contradictions (or fallback works)
- Adjacency rules are respected (no water next to mountains)
- Same seed = identical WFC map
- Test various grid sizes (8×8, 32×32, 64×64)

---

### Phase 3: Height System & Terrain Building
**Goal**: Add elevation to tiles and generate actual 3D Roblox terrain
**Testable**: See 3D terrain in Roblox Studio matching 2D grid
**Time Estimate**: ~3-4 hours

**Tasks:**
1. Update `TileConfig.luau` to add height transition validation
2. Update `WaveFunctionCollapse.luau` to enforce height constraints during propagation
3. Create `TerrainBuilder.luau` with Terrain API integration (FillBlock/WriteVoxels)
4. Update `MapGeneratorService.luau` to add `generateAndBuildWorld()` pipeline
5. Test in Studio - verify 3D terrain generation

**Key Files:**
- `src/server/engine/MapGenerator/TerrainBuilder.luau` (NEW)
- Update `TileConfig.luau`
- Update `WaveFunctionCollapse.luau`
- Update `MapGeneratorService.luau`

**Verification:**
- See actual 3D terrain in workspace.Terrain
- Water tiles are low, mountains are high
- Smooth height transitions (no sudden cliffs unless intended)
- Performance test: measure generation time for 512×512 map

---

### Phase 4: Zones & Biome Constraints
**Goal**: Reserve map regions for specific biomes with dynamic positioning
**Testable**: Castle and player town appear at random valid locations, properly spaced
**Time Estimate**: ~3-4 hours

**Tasks:**
1. Create `ZonePlacer.luau` module with dynamic positioning logic
2. Update `WaveFunctionCollapse.luau` to support zone pre-marking and two-pass generation
3. Update `MapGeneratorService.luau` to integrate zone placement
4. Test with playerTown and castle zones - verify distance constraints

**Key Files:**
- `src/server/engine/MapGenerator/ZonePlacer.luau` (NEW)
- Update `WaveFunctionCollapse.luau`
- Update `MapGeneratorService.luau`

**Generation Flow:**
1. Generate base terrain with WFC (pass 1)
2. Use ZonePlacer to find valid positions for zones
3. Apply zone constraints to grid
4. Re-run WFC in zone areas with biome constraints (pass 2)
5. Build 3D terrain

**Verification:**
- Player town and castle appear at different locations each seed
- Distance between zones meets minimum requirements
- Zones respect constraints (flat, no water, etc.)
- Zone boundaries transition smoothly

---

### Phase 5: Serialization & Persistence
**Goal**: Save generated maps and reload them exactly
**Testable**: Generate map, save to DataStore, restart server, load identical map
**Time Estimate**: ~3-4 hours

**Tasks:**
1. Create `MapSerializer.luau` with hybrid RLE + bit packing compression
2. Add save/load/regenerate methods to `MapGeneratorService.luau`
3. Test save/load cycle with DataStore and verify data integrity

**Key Files:**
- `src/server/engine/MapGenerator/MapSerializer.luau` (NEW)
- Update `MapGeneratorService.luau`

**Verification:**
- Map saves successfully to DataStore
- Loaded map is identical to saved map (tiles, heights, zones)
- Seed regeneration produces identical map
- Compressed data fits within 4MB DataStore limit

---

### Phase 6: 2D Map Rendering & Player Tool
**Goal**: Create visual map texture and player tool to view it
**Testable**: Player equips map tool, sees overhead map view with real-time position marker
**Time Estimate**: ~4-5 hours

**Tasks:**
1. Create `MapRenderer.luau` with EditableImage rendering
2. Create `MapTool.luau` client script with GUI and position tracking
3. Update `MapGeneratorService.luau` to create and distribute map tools
4. Test in Studio - verify map tool works with position tracking

**Key Files:**
- `src/server/engine/MapGenerator/MapRenderer.luau` (NEW)
- `src/client/common/MapTool.luau` (NEW)
- Update `MapGeneratorService.luau`

**Verification:**
- Player receives map tool on spawn
- Equipping map shows overhead view of world
- Red marker shows player position and updates in real-time
- Map colors match terrain types

---

### Phase 7: Structure & Decoration Placement
**Goal**: Place castles, buildings, and scatter props on terrain
**Testable**: Castle appears in castle zone, townhall in player town, trees on grass
**Time Estimate**: ~3-4 hours

**Tasks:**
1. Create `StructurePlacement.luau` for structure and decoration placement
2. Create placeholder asset folders in ReplicatedStorage (Structures/, Decorations/)
3. Update `MapGeneratorService.luau` to integrate structure placement
4. Test structure placement in zones with decorations scattered

**Key Files:**
- `src/server/engine/MapGenerator/StructurePlacement.luau` (NEW)
- Update `MapGeneratorService.luau`
- Create asset folders in Studio

**Asset Structure:**
```
ReplicatedStorage/
  └── MapAssets/
      ├── Structures/
      │   ├── Castle
      │   ├── Townhall
      │   └── Camp
      └── Decorations/
          ├── Tree
          ├── Rock
          ├── Bush
          └── Cactus
```

**Verification:**
- Structures appear in correct zones (castle in castle zone, townhall in player town)
- Structures positioned at "center" or specified offsets
- Decorations scattered on appropriate terrain (trees on grass, cacti in desert)
- No overlapping structures or floating decorations

---

### Phase 8: Polish & Integration
**Goal**: Integrate with existing game framework and optimize
**Testable**: Full playable experience - server starts, generates/loads map, players spawn with map tool
**Time Estimate**: ~3-4 hours

**Tasks:**
1. Integrate MapGeneratorService into `GameInit.luau` initialization sequence
2. Add performance optimizations (progressive generation, error handling)
3. Add LuaDoc comments to all modules
4. Create full integration test script
5. Run complete end-to-end test

**Integration Code** (add to GameInit.luau after ResourceManager):
```lua
-- Map Generator
local MapGeneratorService = require(Engine.MapGenerator.MapGeneratorService)
MapGeneratorService.initialize()
Framework.register("MapGeneratorService", MapGeneratorService)

-- Generate or load world
local mapData = MapGeneratorService.initializeWorld()
if mapData then
	print(`✓ World ready (seed: {mapData.seed})`)
else
	warn("✗ Failed to initialize world - using empty map")
end
```

**Verification:**
- Server starts and initializes map generation
- Map loads from DataStore if exists, otherwise generates new
- Players spawn at player town location
- Players receive map tools
- All systems work together without errors
- Performance is acceptable (<30s for 512×512 map)

---

## Key Design Patterns

### Two-Pass WFC Generation
```
Pass 1: Base Terrain
├─ Generate full map with WFC
├─ Use standard adjacency rules
└─ Create natural-looking base terrain

Pass 2: Zone Refinement
├─ ZonePlacer finds valid positions for zones
├─ Apply zone constraints to grid cells
├─ Re-run WFC only in zone areas
└─ Ensures zones match biome requirements
```

### Dynamic Zone Positioning
```
Priority Order: playerTown → castle → desert → mountains
├─ playerTown placed first (so castle can be far from it)
├─ Each zone validates:
│   ├─ Distance from map edge
│   ├─ Distance from other zones
│   ├─ Terrain flatness (if required)
│   └─ No water (if required)
└─ Up to 100 attempts per zone, skip if no valid position
```

### Coordinate Systems
```
Grid Coordinates (tile indices)
├─ Origin: (1, 1) top-left
├─ Size: gridWidth × gridHeight (e.g., 32×32 for 512÷16)
└─ Used by: WFC, ZonePlacer, grid storage

World Coordinates (3D studs)
├─ Origin: configurable (e.g., -256, 0, -256 for centered 512×512 map)
├─ Size: mapSize × mapSize (e.g., 512×512 studs)
└─ Used by: TerrainBuilder, StructurePlacement, player spawn

Pixel Coordinates (2D map texture)
├─ Origin: (0, 0) top-left
├─ Size: textureSize × textureSize (e.g., 512×512 pixels)
└─ Used by: MapRenderer, MapTool position marker
```

---

## Configuration Examples

### Small Map for Testing
```lua
-- MapConfig.luau
generation = {
	mapSize = 256,
	tileSize = 8,  -- 32×32 grid
}

zones = {
	playerTown = {enabled = true, radius = 30},
	castle = {enabled = false},  -- Disable for small map
}
```

### Large Map with Distant Castle
```lua
generation = {
	mapSize = 1024,
	tileSize = 16,  -- 64×64 grid
}

zones = {
	playerTown = {
		radius = 50,
		constraints = {minDistanceFromEdge = 100}
	},
	castle = {
		radius = 80,
		constraints = {
			minDistanceFromEdge = 100,
			minDistanceFromOtherZones = 300  -- Force far apart
		}
	}
}
```

---

## Performance Targets

| Map Size | Grid Size | Target Time | Notes |
|----------|-----------|-------------|-------|
| 256×256 | 16×16 | <2s | Testing/dev |
| 512×512 | 32×32 | <15s | Default |
| 1024×1024 | 64×64 | <60s | Large maps |

**Optimization Tips:**
- Use `WriteVoxels` instead of `FillBlock` for bulk terrain
- Enable `progressiveGeneration` for very large maps
- Limit decoration count with `maxDecorations`
- Reduce zone count for faster generation

---

## Troubleshooting

### WFC Fails (Returns nil)
- **Cause**: Contradictions due to restrictive adjacency rules or zone constraints
- **Fix**: Relax adjacency rules, reduce zone constraints, or increase max iterations

### Zones Too Close/Overlapping
- **Cause**: Map too small or zone radii too large
- **Fix**: Increase `mapSize`, reduce zone `radius`, or adjust `minDistanceFromOtherZones`

### No Valid Zone Position Found
- **Cause**: Constraints too restrictive (e.g., requireFlat + noWater + large radius)
- **Fix**: Relax constraints, reduce radius, or increase map size

### Terrain Not Appearing
- **Cause**: Map origin miscalculation or terrain cleared incorrectly
- **Fix**: Verify `mapOrigin` calculation, check `Terrain:Clear()` region

### Map Tool Shows Wrong Position
- **Cause**: Bounds attributes incorrect or coordinate conversion off
- **Fix**: Verify tool attributes match `mapData.bounds`, check `gridToPixel` math

### DataStore Save Fails
- **Cause**: Data too large (>4MB), DataStore API disabled
- **Fix**: Reduce map size, enable DataStore in Studio settings

---

## Testing Workflow

### Per-Phase Testing
After each phase, run the phase-specific test script:
```lua
-- src/server/tests/TestMapGenerator.server.luau
-- Contains tests for Phases 1-7
```

### Final Integration Test
After Phase 8:
```lua
-- src/server/tests/TestMapGeneratorFull.server.luau
-- Full end-to-end test of all systems
```

### Manual Testing Checklist
- [ ] Server starts without errors
- [ ] Map generates or loads from DataStore
- [ ] Player spawns at town location
- [ ] Map tool is in player's backpack
- [ ] Equipping map shows overhead view
- [ ] Position marker updates as player moves
- [ ] Castle is visible and far from town
- [ ] Decorations are present on terrain
- [ ] Performance is acceptable

---

## Future Enhancements (Post Phase 8)

1. **Path Generation**: Procedural roads/paths connecting zones
2. **Cave Systems**: Underground generation
3. **Dynamic Rivers**: Water flow simulation
4. **Biome Blending**: Smooth transitions between biomes
5. **Structure Interiors**: Procedural rooms inside buildings
6. **Seasonal Variations**: Different decoration sets
7. **Client Preview**: Show generation progress to players
8. **Manual Editing**: Allow tweaking generated maps
9. **Multi-level Structures**: Buildings with multiple floors
10. **Custom Brushes**: Paint terrain types manually

---

## Summary

**Total Implementation Time**: 25-35 hours across 8 phases

**Priority Order**:
- **P0 (Critical)**: Phases 1-3 (foundation, WFC, terrain) - ~9-13 hours
- **P1 (High)**: Phases 4-5 (zones, persistence) - ~6-8 hours
- **P2 (Medium)**: Phases 6-7 (map tool, structures) - ~7-9 hours
- **P3 (Polish)**: Phase 8 (integration, optimization) - ~3-4 hours

**Key Features**:
✅ 2D grid generated first, then 3D terrain built from it
✅ Dynamic zone placement (castle/town positions randomized)
✅ Seed-based deterministic generation
✅ DataStore persistence
✅ Player map tool with position tracking
✅ Structure and decoration placement
✅ Performance optimized with Terrain API

**Next Steps**: Begin with Phase 1, work sequentially through all phases. Each phase is independently testable to ensure progress.
