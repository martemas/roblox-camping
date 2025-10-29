--!strict
-- MAP GENERATOR TYPE DEFINITIONS

local Types = {}

-- ═══════════════════════════════════════════════════
-- GRID TYPES
-- ═══════════════════════════════════════════════════

export type GridCoord = {
	x: number,
	y: number,
}

export type WorldCoord = {
	x: number,
	y: number,
	z: number,
}

export type Tile = {
	tileType: number,
	height: number,
	zoneId: string?,
}

export type MapGrid = {
	width: number,
	height: number,
	tiles: { { Tile } },
}

-- ═══════════════════════════════════════════════════
-- ZONE TYPES
-- ═══════════════════════════════════════════════════

export type ZoneConstraints = {
	requireFlat: boolean?,
	noWater: boolean?,
	minDistanceFromEdge: number?,
	minDistanceFromOtherZones: number?,
	preferEdge: boolean?,
}

export type ZoneStructure = {
	name: string,
	assetPath: string,
	position: string | { x: number, z: number },
	rotation: number,
}

export type ZoneConfig = {
	enabled: boolean,
	radius: number,
	biome: string,
	constraints: ZoneConstraints,
	structures: { ZoneStructure },
}

export type PlacedZone = {
	id: string,
	config: ZoneConfig,
	center: GridCoord,
	radius: number,
	biome: string,
}

-- ═══════════════════════════════════════════════════
-- MAP DATA TYPES
-- ═══════════════════════════════════════════════════

export type MapBounds = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

export type MapData = {
	seed: number,
	mapSize: number,
	tileSize: number,
	gridWidth: number,
	gridHeight: number,
	grid: MapGrid,
	zones: { PlacedZone },
	bounds: MapBounds,
	origin: vector,
}

-- ═══════════════════════════════════════════════════
-- WFC TYPES
-- ═══════════════════════════════════════════════════

export type CellState = {
	collapsed: boolean,
	possibleTiles: { number },
	entropy: number,
}

export type WFCGrid = {
	width: number,
	height: number,
	cells: { { CellState } },
}

-- ═══════════════════════════════════════════════════
-- SERIALIZATION TYPES
-- ═══════════════════════════════════════════════════

export type SerializedMap = {
	version: number,
	seed: number,
	mapSize: number,
	tileSize: number,
	compressedData: string,
	zones: { PlacedZone },
}

-- ═══════════════════════════════════════════════════
-- RANDOM TYPES
-- ═══════════════════════════════════════════════════

export type SeededRandom = {
	nextInt: (min: number, max: number) -> number,
	nextFloat: () -> number,
	nextBool: () -> boolean,
	shuffle: <T>(array: { T }) -> { T },
	getSeed: () -> number,
}

return Types
