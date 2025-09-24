--!strict

-- Shared utility functions for the camping game

local Utils = {}

-- Raycast to find ground level at a given position
function Utils.findGroundLevel(position: Vector3): Vector3
	-- Create raycast params
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {} -- Empty exclude list means ray all parts

	-- Cast ray from high above the position down to find ground
	local rayOrigin = Vector3.new(position.X, 1000, position.Z) -- Start high above
	local rayDirection = Vector3.new(0, -2000, 0) -- Cast downward for 2000 studs

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if raycastResult then
		-- Found ground, place slightly above it
		return raycastResult.Position + Vector3.new(0, 1, 0)
	else
		-- No ground found, use default height
		warn(`No ground found at position {position}, using default height`)
		return Vector3.new(position.X, 10, position.Z)
	end
end

-- Get a random position within a radius, with ground detection
function Utils.getRandomGroundPosition(center: Vector3, minRadius: number, maxRadius: number): Vector3
	local angle = math.random() * math.pi * 2
	local distance = math.random(minRadius, maxRadius)
	local x = center.X + math.cos(angle) * distance
	local z = center.Z + math.sin(angle) * distance

	local roughPosition = Vector3.new(x, 0, z)
	return Utils.findGroundLevel(roughPosition)
end

return Utils