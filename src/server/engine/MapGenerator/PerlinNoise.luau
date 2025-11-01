--!strict
-- PERLIN NOISE
-- Simplified Perlin noise implementation for smooth terrain heightmap generation

local Types = require(script.Parent.Types)
local PerlinNoise = {}

-- ═══════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════

-- Fade function (smooth interpolation)
local function fade(t: number): number
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Linear interpolation
local function lerp(t: number, a: number, b: number): number
	return a + t * (b - a)
end

-- Dot product of gradient and distance vector
local function dotGridGradient(rng: Types.SeededRandom, ix: number, iy: number, x: number, y: number): number
	-- Generate consistent "random" gradient based on grid position
	-- Use seeded RNG to get same gradient for same grid cell
	local seed = math.floor(ix * 73856093 + iy * 19349663)
	local tempRng = require(script.Parent.SeededRandom).new(seed)

	local angle = tempRng.nextFloat() * math.pi * 2
	local dx = math.cos(angle)
	local dy = math.sin(angle)

	-- Compute dot product
	local distX = x - ix
	local distY = y - iy
	return dx * distX + dy * distY
end

-- ═══════════════════════════════════════════════════
-- PERLIN NOISE GENERATION
-- ═══════════════════════════════════════════════════

-- Generate Perlin noise value at position (x, y)
function PerlinNoise.generateValue(
	x: number,
	y: number,
	rng: Types.SeededRandom,
	scale: number
): number
	-- Scale the coordinates
	local xi = x / scale
	local yi = y / scale

	-- Get integer grid cell coordinates
	local xi0 = math.floor(xi)
	local xi1 = xi0 + 1
	local yi0 = math.floor(yi)
	local yi1 = yi0 + 1

	-- Get fractional parts
	local xf = xi - xi0
	local yf = yi - yi0

	-- Fade curves
	local u = fade(xf)
	local v = fade(yf)

	-- Calculate dot products at grid corners
	local n00 = dotGridGradient(rng, xi0, yi0, xi, yi)
	local n10 = dotGridGradient(rng, xi1, yi0, xi, yi)
	local n01 = dotGridGradient(rng, xi0, yi1, xi, yi)
	local n11 = dotGridGradient(rng, xi1, yi1, xi, yi)

	-- Interpolate
	local nx0 = lerp(u, n00, n10)
	local nx1 = lerp(u, n01, n11)
	local nxy = lerp(v, nx0, nx1)

	return nxy
end

-- Generate multi-octave Perlin noise (Fractional Brownian Motion)
function PerlinNoise.generateFBM(
	x: number,
	y: number,
	rng: Types.SeededRandom,
	scale: number,
	octaves: number,
	persistence: number
): number
	persistence = persistence or 0.5
	local value = 0
	local amplitude = 1
	local frequency = 1
	local maxValue = 0

	for _ = 1, octaves do
		value = value + PerlinNoise.generateValue(x * frequency, y * frequency, rng, scale) * amplitude
		maxValue = maxValue + amplitude
		amplitude = amplitude * persistence
		frequency = frequency * 2
	end

	return value / maxValue
end

-- ═══════════════════════════════════════════════════
-- HEIGHTMAP GENERATION
-- ═══════════════════════════════════════════════════

-- Generate smooth heightmap using Perlin noise
function PerlinNoise.generateHeightmap(
	width: number,
	height: number,
	rng: Types.SeededRandom,
	scale: number,
	octaves: number,
	baseHeight: number,
	heightScale: number
): { { number } }
	local heightmap = {}

	for y = 1, height do
		heightmap[y] = {}
		for x = 1, width do
			-- Generate noise value (-1 to 1)
			local noise = PerlinNoise.generateFBM(x, y, rng, scale, octaves, 0.5)

			-- Scale and offset noise to height range
			-- Noise is roughly -0.5 to 0.5, scale it to our desired range
			local finalHeight = baseHeight + (noise * heightScale)
			heightmap[y][x] = finalHeight
		end
	end

	return heightmap
end

return PerlinNoise
