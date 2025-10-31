--!strict
-- ALTITUDE BIOMES
-- Post-processes generated terrain to apply altitude-based biome zones
-- Creates realistic elevation transitions (grass → hills → mountains → snow)

local Types = require(script.Parent.Types)
local TileConfig = require(script.Parent.TileConfig)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)

local AltitudeBiomes = {}

-- ═══════════════════════════════════════════════════
-- ALTITUDE-BASED TILE CONVERSION
-- ═══════════════════════════════════════════════════

-- Apply altitude-based biome conversion to generated map
function AltitudeBiomes.applyAltitudeBiomes(mapData: Types.MapData): Types.MapData
	local renderConfig = MapConfig.rendering

	-- Check if altitude biomes are enabled
	if not renderConfig.useAltitudeBiomes then
		return mapData
	end

	print("[AltitudeBiomes] Applying altitude-based biome conversion...")

	local grid = mapData.grid
	local altitudeBands = renderConfig.altitudeBands
	local conversions = 0

	-- Process each tile
	for y = 1, grid.height do
		for x = 1, grid.width do
			local tile = grid.tiles[y][x]
			local originalType = tile.tileType

			-- Calculate effective height (tile height + global offset)
			local effectiveHeight = tile.height + renderConfig.heightOffset

			-- Find appropriate altitude band for this tile's effective height
			for _, band in altitudeBands do
				if effectiveHeight <= band.maxHeight then
					-- Convert tile type based on altitude
					tile.tileType = band.tileType

					if originalType ~= tile.tileType then
						conversions = conversions + 1
					end
					break
				end
			end
		end
	end

	print(`[AltitudeBiomes] ✓ Converted {conversions} tiles based on altitude`)
	return mapData
end

-- ═══════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════

-- Get biome statistics for debugging
function AltitudeBiomes.getBiomeStats(mapData: Types.MapData): { [string]: number }
	local stats = {}
	local grid = mapData.grid

	-- Initialize counts
	for tileType, props in TileConfig.TileProperties do
		stats[props.name] = 0
	end

	-- Count tiles
	for y = 1, grid.height do
		for x = 1, grid.width do
			local tile = grid.tiles[y][x]
			local props = TileConfig.TileProperties[tile.tileType]
			stats[props.name] = stats[props.name] + 1
		end
	end

	return stats
end

return AltitudeBiomes
