--!strict

--[[
	HealthBarAttacher - Client-side Health Bar Management

	This script runs on each client and monitors workspace for entities (players and NPCs).
	When it detects an entity without a health bar, it clones one from ReplicatedStorage
	and attaches it locally. This approach provides optimal performance because:

	1. UI updates are purely local (no network replication)
	2. Each client only renders what they can see
	3. Server doesn't need to manage UI at all
	4. LocalScripts in the HealthBar will execute properly when cloned client-side

	The health bars are automatically cleaned up when entities are removed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Cache the HealthBar template
local uiFolder = ReplicatedStorage:WaitForChild("UI")
local healthBarTemplate = uiFolder:WaitForChild("HealthBar")

-- Track which models already have health bars attached (client-side only)
local attachedHealthBars: {[Model]: boolean} = {}

--[[
	Set up health bar update logic (replaces LocalScript functionality)
	This is necessary because LocalScripts don't always execute when cloned at runtime

	@param healthBar - The BillboardGui health bar
	@param model - The character/entity model
	@param humanoid - The humanoid instance
]]
local function setupHealthBarUpdates(healthBar: BillboardGui, model: Model, humanoid: Humanoid)
	-- Find UI elements
	local mainFrame = healthBar:FindFirstChild("Main")
	if not mainFrame then
		warn(`[HealthBarAttacher] No Main frame found in HealthBar for {model.Name}`)
		return
	end

	local frameContainer = mainFrame:FindFirstChild("Frame")
	local levelLabel = frameContainer and frameContainer:FindFirstChild("TextLabel")
	local nameLabel = mainFrame:FindFirstChild("TextLabel")
	local barContainer = mainFrame:FindFirstChild("Bar")
	local healthBarInner = barContainer and barContainer:FindFirstChild("Inner")

	-- Update level display
	local function updateLevel()
		if levelLabel then
			local level = model:GetAttribute("Level") or 1
			levelLabel.Text = tostring(level)
		end
	end

	-- Update name display
	local function updateName()
		if nameLabel then
			local name = humanoid.DisplayName
			if not name or name == "" then
				name = model.Name
			end
			nameLabel.Text = name
		end
	end

	-- Update health bar
	local function updateHealth()
		if healthBarInner then
			local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
			healthBarInner.Size = UDim2.new(healthPercent, 0, 1, 0)

			-- Update color based on health percentage
			if healthPercent <= 0.25 then
				-- Below 25% - Red
				healthBarInner.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
			elseif healthPercent <= 0.5 then
				-- Below 50% - Orange
				healthBarInner.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
			else
				-- Above 50% - Green
				healthBarInner.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
			end
		end
	end

	-- Initial updates
	updateLevel()
	updateName()
	updateHealth()

	-- Connect listeners
	humanoid:GetPropertyChangedSignal("Health"):Connect(updateHealth)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
	humanoid:GetPropertyChangedSignal("DisplayName"):Connect(updateName)
	model:GetAttributeChangedSignal("Level"):Connect(updateLevel)
end

--[[
	Attach a health bar to a model's Head

	@param model - The character/entity model to attach health bar to
	@return boolean - Success status
]]
local function attachHealthBar(model: Model): boolean
	-- Check if we already attached a health bar to this model
	if attachedHealthBars[model] then
		return true
	end

	-- Validate model
	if not model or not model:IsA("Model") then
		return false
	end

	-- Check if model has a Humanoid (must be an entity)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	-- Find the Head part (preferred) or HumanoidRootPart (fallback)
	local attachPart = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not attachPart or not attachPart:IsA("BasePart") then
		print(`[HealthBarAttacher] No Head/HumanoidRootPart found for {model.Name}`)
		return false
	end

	-- Check if health bar already exists (server might have added one)
	if attachPart:FindFirstChild("HealthBar") then
		attachedHealthBars[model] = true
		return true
	end

	-- Clone the HealthBar from ReplicatedStorage (client-side cloning!)
	local healthBar = healthBarTemplate:Clone()
	healthBar.Parent = attachPart

	-- Set up health bar update logic directly (instead of relying on LocalScript)
	-- This ensures it works for all entities, regardless of how they're spawned
	setupHealthBarUpdates(healthBar, model, humanoid)

	-- Mark as attached
	attachedHealthBars[model] = true

	-- Clean up tracking when model is destroyed
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			attachedHealthBars[model] = nil
		end
	end)

	return true
end

--[[
	Scan workspace for entities and attach health bars
]]
local function scanForEntities()
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
			attachHealthBar(descendant)
		end
	end
end

--[[
	Handle new entities added to workspace
]]
local function onDescendantAdded(descendant: Instance)
	-- If it's a model with a humanoid, attach health bar
	if descendant:IsA("Model") then
		-- Wait a moment for the model to fully load
		task.wait(0.1)
		if descendant:FindFirstChildOfClass("Humanoid") then
			attachHealthBar(descendant)
		end
	end
end

-- Initialize: Scan existing entities
scanForEntities()

-- Monitor for new entities
Workspace.DescendantAdded:Connect(onDescendantAdded)

-- Periodic check (every 2 seconds) to catch any missed entities
RunService.Heartbeat:Connect(function()
	local currentTime = tick()
	if currentTime % 2 < 0.1 then -- Roughly every 2 seconds
		scanForEntities()
	end
end)

print("[HealthBarAttacher] Client-side health bar system initialized")
