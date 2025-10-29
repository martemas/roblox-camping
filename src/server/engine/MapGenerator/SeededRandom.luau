--!strict
-- SEEDED RANDOM NUMBER GENERATOR
-- Provides deterministic random numbers using Roblox's Random class

local Types = require(script.Parent.Types)

local SeededRandom = {}

-- ═══════════════════════════════════════════════════
-- CONSTRUCTOR
-- ═══════════════════════════════════════════════════

function SeededRandom.new(seed: number?): Types.SeededRandom
	local self = {}
	local actualSeed = seed or tick()
	local rng = Random.new(actualSeed)

	-- Store the seed for later retrieval
	self._seed = actualSeed
	self._rng = rng

	-- ═══════════════════════════════════════════════════
	-- PUBLIC METHODS
	-- ═══════════════════════════════════════════════════

	-- Generate random integer between min and max (inclusive)
	function self.nextInt(min: number, max: number): number
		return rng:NextInteger(min, max)
	end

	-- Generate random float between 0 and 1
	function self.nextFloat(): number
		return rng:NextNumber()
	end

	-- Generate random boolean
	function self.nextBool(): boolean
		return rng:NextInteger(0, 1) == 1
	end

	-- Shuffle an array in place using Fisher-Yates algorithm
	function self.shuffle<T>(array: { T }): { T }
		for i = #array, 2, -1 do
			local j = rng:NextInteger(1, i)
			array[i], array[j] = array[j], array[i]
		end
		return array
	end

	-- Get the current seed
	function self.getSeed(): number
		return actualSeed
	end

	return self :: any
end

return SeededRandom
