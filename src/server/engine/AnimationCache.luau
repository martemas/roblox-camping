--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Types = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("Types"))

type ToolType = Types.ToolType

local AnimationCache = {}

-- Cache structure: {[ToolType]: {Animation}[]}
local cache: {[string]: {Animation}} = {}

-- Extract number from animation name (e.g., "anim3" -> 3)
local function extractAnimationNumber(name: string): number?
	local match = string.match(name, "^anim(%d+)$")
	if match then
		return tonumber(match)
	end
	return nil
end

-- Load animations from a tool instance
local function loadAnimationsFromTool(tool: Tool): {Animation}
	local animations: {Animation} = {}
	local animationData: {{number: number, animation: Animation}} = {}

	-- Find all children matching "anim#" pattern
	for _, child in tool:GetChildren() do
		if child:IsA("Animation") then
			local animNumber = extractAnimationNumber(child.Name)
			if animNumber then
				-- Validate animation has asset ID
				if child.AnimationId and child.AnimationId ~= "" then
					table.insert(animationData, {
						number = animNumber,
						animation = child
					})
				else
					warn(`[AnimationCache] Animation {child.Name} in {tool.Name} has no AnimationId`)
				end
			end
		end
	end

	-- Sort by animation number
	table.sort(animationData, function(a, b)
		return a.number < b.number
	end)

	-- Extract sorted animations
	for _, data in animationData do
		table.insert(animations, data.animation)
	end

	return animations
end

-- Pre-warm the cache by loading all tool animations
function AnimationCache.Initialize(): ()

	-- Find Models.Tools folder
	local modelsFolder = ServerStorage:FindFirstChild("Assets")
	if not modelsFolder then
		warn("[AnimationCache] Models folder not found in ReplicatedStorage")
		return
	end

	local toolsFolder = modelsFolder:FindFirstChild("Tools")
	if not toolsFolder then
		warn("[AnimationCache] Models.Tools folder not found - creating it")
		-- Create the folder for user to populate
		local newToolsFolder = Instance.new("Folder")
		newToolsFolder.Name = "Tools"
		newToolsFolder.Parent = modelsFolder
		print("[AnimationCache] Created Models.Tools folder - please add tool instances with animations")
		return
	end

	local toolCount = 0
	local totalAnimations = 0

	-- Iterate all tools in the folder
	for _, child in toolsFolder:GetChildren() do
		if child:IsA("Tool") then
			local toolName = child.Name

			-- Load animations for this tool
			local animations = loadAnimationsFromTool(child)

			if #animations > 0 then
				cache[toolName] = animations
				toolCount = toolCount + 1
				totalAnimations = totalAnimations + #animations

				-- Log animation names for debugging
				local animNames = {}
				for i, anim in animations do
					-- Find the original name by looking at the tool's children
					for _, toolChild in child:GetChildren() do
						if toolChild == anim then
							table.insert(animNames, toolChild.Name)
							break
						end
					end
				end
				print(`[AnimationCache] Loaded {#animations} animations for {toolName}: {table.concat(animNames, ", ")}`)
			else
				print(`[AnimationCache] No valid animations found for {toolName} (will use fallback)`)
			end
		end
	end

	print(`[AnimationCache] Pre-warming complete: {toolCount} tools, {totalAnimations} total animations`)
end

-- Get cached animations for a tool type
function AnimationCache.GetToolAnimations(toolType: ToolType): {Animation}?
	return cache[toolType]
end

-- Get the number of animations for a tool
function AnimationCache.GetAnimationCount(toolType: ToolType): number
	local animations = cache[toolType]
	return animations and #animations or 0
end

-- Clear cache (for testing/debugging)
function AnimationCache.ClearCache(toolType: ToolType?): ()
	if toolType then
		cache[toolType] = nil
		print(`[AnimationCache] Cleared cache for {toolType}`)
	else
		cache = {}
		print("[AnimationCache] Cleared entire cache")
	end
end

return AnimationCache
