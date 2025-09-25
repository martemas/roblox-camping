--!strict

-- Shared utility functions for the camping game

local Utils = {}

-- Raycast to find ground level at a given position
function Utils.findGroundLevel(position: vector): vector
	-- Create raycast params
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {} -- Empty exclude list means ray all parts
	raycastParams.RespectCanCollide = true

	-- Cast ray from high above the position down to find ground
	local rayOrigin = vector.create(position.X, 2000, position.Z) -- Start high above
	local rayDirection = vector.create(0, -5000, 0) -- Cast downward for 5000 studs

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if raycastResult then
		print(`Ground found at position: {raycastResult.Position.Y}`) -- DEBUG
		-- Found ground, place slightly above it
		return raycastResult.Position + vector.create(0, 1, 0)
	else
		-- No ground found, use default height
		warn(`No ground found at position {position}, using default height`)
		return vector.create(position.X, 10, position.Z)
	end
end

-- Get a random position within a radius, with ground detection
function Utils.getRandomGroundPosition(center: vector, minRadius: number, maxRadius: number): vector
	local angle = math.random() * math.pi * 2
	local distance = math.random(minRadius, maxRadius)
	local x = center.X + math.cos(angle) * distance
	local z = center.Z + math.sin(angle) * distance

	local roughPosition = vector.create(x, 0, z)
	return Utils.findGroundLevel(roughPosition)
end

return Utils