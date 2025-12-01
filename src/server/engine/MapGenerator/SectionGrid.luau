--!strict
-- SECTION GRID - Divides map into 9 equal sections for zone placement
-- Layout:
--   NW | N | NE
--   W  | C | E
--   SW | S | SE

local Types = require(script.Parent.Types)

local SectionGrid = {}

-- ═══════════════════════════════════════════════════
-- SECTION DEFINITIONS
-- ═══════════════════════════════════════════════════

local SECTION_ORDER = { "NW", "N", "NE", "W", "Center", "E", "SW", "S", "SE" }

local DIRECTION_ANGLES = {
	-- Cardinal and intercardinal directions (in degrees, 0 = east, 90 = north)
	E = 0,
	NE = 45,
	N = 90,
	NW = 135,
	W = 180,
	SW = 225,
	S = 270,
	SE = 315,
}

-- ═══════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════

--- Create section grid for a map
function SectionGrid.create(gridWidth: number, gridHeight: number): Types.SectionGrid
	local sectionWidth = math.floor(gridWidth / 3)
	local sectionHeight = math.floor(gridHeight / 3)

	local sections: { [string]: Types.Section } = {}

	-- Row 1: NW, N, NE
	sections.NW = SectionGrid._createSection("NW", 1, 1, sectionWidth, sectionHeight)
	sections.N = SectionGrid._createSection("N", 1, sectionWidth + 1, sectionWidth, sectionHeight)
	sections.NE = SectionGrid._createSection("NE", 1, sectionWidth * 2 + 1, gridWidth, gridHeight)

	-- Row 2: W, Center, E
	sections.W = SectionGrid._createSection("W", sectionHeight + 1, 1, sectionWidth, sectionHeight)
	sections.Center = SectionGrid._createSection("Center", sectionHeight + 1, sectionWidth + 1, sectionWidth, sectionHeight)
	sections.E = SectionGrid._createSection("E", sectionHeight + 1, sectionWidth * 2 + 1, gridWidth, gridHeight)

	-- Row 3: SW, S, SE
	sections.SW = SectionGrid._createSection("SW", sectionHeight * 2 + 1, 1, sectionWidth, sectionHeight)
	sections.S = SectionGrid._createSection("S", sectionHeight * 2 + 1, sectionWidth + 1, sectionWidth, sectionHeight)
	sections.SE = SectionGrid._createSection("SE", sectionHeight * 2 + 1, sectionWidth * 2 + 1, gridWidth, gridHeight)

	return {
		sections = sections,
		gridWidth = gridWidth,
		gridHeight = gridHeight,
	}
end

--- Get section by name
function SectionGrid.getSection(sectionGrid: Types.SectionGrid, sectionName: string): Types.Section?
	return sectionGrid.sections[sectionName]
end

--- Pick random center within section bounds
function SectionGrid.getRandomCenterInSection(
	section: Types.Section,
	random: any
): Types.GridCoord
	local minX = section.bounds.minX
	local maxX = section.bounds.maxX
	local minY = section.bounds.minY
	local maxY = section.bounds.maxY

	return {
		x = random.nextInt(minX, maxX),
		y = random.nextInt(minY, maxY),
	}
end

--- Get point at distance and direction from parent zone
function SectionGrid.getRelativePosition(
	parentCenter: Types.GridCoord,
	distance: number,
	section: string,
	random: any,
	tileSize: number
): Types.GridCoord
	-- Convert studs to tiles
	local distanceInTiles = distance / tileSize

	-- Get direction angle
	local angle = DIRECTION_ANGLES[section]
	if not angle then
		error(`Invalid relative section: {section}`)
	end

	-- Convert angle to radians
	local radians = math.rad(angle)

	-- Add some randomness (±45 degrees from the direction)
	local angleVariation = (random.nextFloat() - 0.5) * 90 -- ±45 degrees
	radians = radians + math.rad(angleVariation)

	-- Calculate offset from parent
	local offsetX = math.floor(math.cos(radians) * distanceInTiles)
	local offsetY = math.floor(math.sin(radians) * distanceInTiles)

	-- Calculate absolute position
	local x = parentCenter.x + offsetX
	local y = parentCenter.y + offsetY

	return {
		x = x,
		y = y,
	}
end

--- Check if position is within grid bounds
function SectionGrid.isWithinBounds(
	position: Types.GridCoord,
	gridWidth: number,
	gridHeight: number
): boolean
	return position.x >= 1 and position.x <= gridWidth and position.y >= 1 and position.y <= gridHeight
end

--- Get valid sections for placement
function SectionGrid.getValidSections(
	allowedSections: { string }?,
	sectionGrid: Types.SectionGrid
): { Types.Section }
	local validSections: { Types.Section } = {}

	if not allowedSections or #allowedSections == 0 then
		-- If no sections specified, allow any
		for _, sectionName in ipairs(SECTION_ORDER) do
			local section = sectionGrid.sections[sectionName]
			if section then
				table.insert(validSections, section)
			end
		end
	else
		-- Add only specified sections
		for _, sectionName in ipairs(allowedSections) do
			local section = sectionGrid.sections[sectionName]
			if section then
				table.insert(validSections, section)
			end
		end
	end

	return validSections
end

-- ═══════════════════════════════════════════════════
-- PRIVATE HELPERS
-- ═══════════════════════════════════════════════════

--- Internal: Create a single section
function SectionGrid._createSection(
	name: string,
	minX: number,
	minY: number,
	maxX: number,
	maxY: number
): Types.Section
	local boundsMinX = minX
	local boundsMaxX = math.min(maxX, maxX) -- Clamp to bounds
	local boundsMinY = minY
	local boundsMaxY = math.min(maxY, maxY)

	return {
		name = name,
		bounds = {
			minX = boundsMinX,
			maxX = boundsMaxX,
			minY = boundsMinY,
			maxY = boundsMaxY,
		},
		center = {
			x = math.floor((boundsMinX + boundsMaxX) / 2),
			y = math.floor((boundsMinY + boundsMaxY) / 2),
		},
	}
end

return SectionGrid
