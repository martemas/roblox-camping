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

-- Scalar hash function for exponential Perlin (generates value in range [0, 1])
local function hashScalar(rng: Types.SeededRandom, ix: number, iy: number): number
	-- Different offset than gradient hash to generate independent scalar values
	local baseSeed = rng.getSeed()
	local cellSeed = baseSeed + ix * 50332299 + iy * 92837111  -- Different prime offsets
	local cellRng = require(script.Parent.SeededRandom).new(math.floor(cellSeed))

	-- Return scalar value [0, 1]
	return cellRng.nextFloat()
end

-- Apply exponential transformation based on mode
-- scalarValue is in range [0, 1], so output ranges are:
-- "exp": [e^0, e^amplitude] = [1.0, e^amplitude]
-- "quadratic": [1.0, 1 + amplitude]
-- "linear": [1.0, 1 + amplitude]
local function applyExponentialTransform(scalarValue: number, mode: string, amplitude: number): number
	if mode == "exp" then
		-- Exponential: e^(value * amplitude)
		-- For amplitude=1.0: output range [1.0, 2.718] (2.7x)
		-- For amplitude=2.0: output range [1.0, 7.39] (7.4x)
		-- For amplitude=3.0: output range [1.0, 20.09] (20x)
		return math.exp(scalarValue * amplitude)
	elseif mode == "quadratic" then
		-- Quadratic: 1.0 + (value^2 * amplitude)
		-- For amplitude=1.0: output range [1.0, 2.0] (2x)
		-- For amplitude=2.0: output range [1.0, 3.0] (3x)
		-- Smoother than exponential, good middle ground
		return 1.0 + (scalarValue * scalarValue * amplitude)
	else -- "linear"
		-- Linear: 1.0 + (value * amplitude)
		-- For amplitude=0.5: output range [1.0, 1.5] (1.5x, subtle)
		-- For amplitude=1.0: output range [1.0, 2.0] (2x)
		-- Most predictable, gentle effect
		return 1.0 + (scalarValue * amplitude)
	end
end

-- Dot product of gradient and distance vector
local function dotGridGradient(rng: Types.SeededRandom, ix: number, iy: number, x: number, y: number, useExponential: boolean?, exponentialMode: string?, exponentialAmplitude: number?): number
	-- Generate consistent "random" gradient based on grid position
	-- Combine grid coordinates with the base seed for deterministic gradients
	-- This ensures same seed produces same map, but different seeds produce different maps
	local baseSeed = rng.getSeed() -- Get the underlying seed value
	local cellSeed = baseSeed + ix * 73856093 + iy * 19349663
	local cellRng = require(script.Parent.SeededRandom).new(math.floor(cellSeed))

	local angle = cellRng.nextFloat() * math.pi * 2
	local dx = math.cos(angle)
	local dy = math.sin(angle)

	-- Compute dot product
	local distX = x - ix
	local distY = y - iy
	local dotProduct = dx * distX + dy * distY

	-- Apply exponential distribution if enabled
	-- Multiply by scalar hash h'(p) for exponential variant
	if useExponential then
		local scalarHash = hashScalar(rng, ix, iy)
		-- Use configurable transformation for amplitude modulation
		exponentialMode = exponentialMode or "exp"
		exponentialAmplitude = exponentialAmplitude or 1.0
		local amplitude = applyExponentialTransform(scalarHash, exponentialMode, exponentialAmplitude)
		dotProduct = dotProduct * amplitude
	end

	return dotProduct
end

-- ═══════════════════════════════════════════════════
-- PERLIN NOISE GENERATION
-- ═══════════════════════════════════════════════════

-- Generate Perlin noise value at position (x, y)
function PerlinNoise.generateValue(
	x: number,
	y: number,
	rng: Types.SeededRandom,
	scale: number,
	useExponential: boolean?,
	exponentialMode: string?,
	exponentialAmplitude: number?
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
	local n00 = dotGridGradient(rng, xi0, yi0, xi, yi, useExponential, exponentialMode, exponentialAmplitude)
	local n10 = dotGridGradient(rng, xi1, yi0, xi, yi, useExponential, exponentialMode, exponentialAmplitude)
	local n01 = dotGridGradient(rng, xi0, yi1, xi, yi, useExponential, exponentialMode, exponentialAmplitude)
	local n11 = dotGridGradient(rng, xi1, yi1, xi, yi, useExponential, exponentialMode, exponentialAmplitude)

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
	persistence: number,
	useExponential: boolean?,
	exponentialMode: string?,
	exponentialAmplitude: number?
): number
	persistence = persistence or 0.5
	local value = 0
	local amplitude = 1
	local frequency = 1
	local maxValue = 0

	for _ = 1, octaves do
		value = value + PerlinNoise.generateValue(x * frequency, y * frequency, rng, scale, useExponential, exponentialMode, exponentialAmplitude) * amplitude
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
	heightScale: number,
	useExponential: boolean?,
	exponentialMode: string?,
	exponentialAmplitude: number?
): { { number } }
	local heightmap = {}

	for y = 1, height do
		heightmap[y] = {}
		for x = 1, width do
			-- Generate noise value (-1 to 1)
			local noise = PerlinNoise.generateFBM(x, y, rng, scale, octaves, 0.5, useExponential, exponentialMode, exponentialAmplitude)

			-- Scale and offset noise to height range
			-- Noise is roughly -0.5 to 0.5, scale it to our desired range
			local finalHeight = baseHeight + (noise * heightScale)
			heightmap[y][x] = finalHeight
		end
	end

	return heightmap
end

return PerlinNoise
