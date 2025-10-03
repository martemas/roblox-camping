--!strict

--[[
	AOETelegraph - Visual Warning System for AOE Attacks

	Shows circular telegraph on ground during castDuration to warn players of incoming AOE attacks.
	Provides clear visual feedback for counterplay (dodging).

	Integration:
	- Called by CombatSystem before AOE attack executes
	- Called by EntityController during NPC AOE casting
	- Auto-destroys after duration
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AOETelegraph = {}

-- Telegraph template cache
local telegraphTemplate: Model? = nil
local templateSearched = false

--[[
	Get or create telegraph template

	Tries to load from ReplicatedStorage.Models.Effects.AOE.CircleTelegraph
	Falls back to procedural creation if not found

	@return Model - Telegraph template
]]
local function getTelegraphTemplate(): Model
	if telegraphTemplate then
		return telegraphTemplate
	end

	if not templateSearched then
		templateSearched = true

		-- Try to load template from ReplicatedStorage
		local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
		if modelsFolder then
			local effectsFolder = modelsFolder:FindFirstChild("Effects")
			if effectsFolder then
				local aoeFolder = effectsFolder:FindFirstChild("AOE")
				if aoeFolder then
					local template = aoeFolder:FindFirstChild("CircleTelegraph")
					if template and template:IsA("Model") then
						telegraphTemplate = template
						print("AOETelegraph: Using template from ReplicatedStorage")
						return template
					end
				end
			end
		end

		print("AOETelegraph: Template not found, using procedural fallback")
	end

	-- Procedural fallback: Create simple cylinder telegraph
	local template = Instance.new("Model")
	template.Name = "CircleTelegraph"

	local cylinder = Instance.new("Part")
	cylinder.Name = "Telegraph"
	cylinder.Shape = Enum.PartType.Cylinder
	cylinder.Size = Vector3.new(0.2, 10, 10) -- Will be scaled based on radius
	cylinder.Anchored = true
	cylinder.CanCollide = false
	cylinder.Transparency = 0.5
	cylinder.Material = Enum.Material.Neon
	cylinder.Color = Color3.fromRGB(255, 100, 100) -- Default red (damage)
	cylinder.Parent = template

	template.PrimaryPart = cylinder

	telegraphTemplate = template
	return template
end

--[[
	Show circular telegraph on ground

	@param position - Center position of AOE
	@param radius - Radius of AOE effect
	@param duration - How long to show telegraph (castDuration)
	@param attackType - "damage" or "heal" (affects color)
	@return Instance - Telegraph instance (auto-destroys after duration)
]]
function AOETelegraph.showCircleTelegraph(
	position: Vector3,
	radius: number,
	duration: number,
	attackType: "damage" | "heal"
): Instance
	-- Get template
	local template = getTelegraphTemplate()
	if not template then
		warn("AOETelegraph: Could not create template")
		return Instance.new("Folder") -- Return dummy instance
	end

	-- Clone template
	local telegraph = template:Clone()

	-- Scale to radius
	-- Cylinder is oriented along X axis when shape is Cylinder
	local scale = (radius * 2) / 10 -- Template size is 10x10
	if telegraph.PrimaryPart then
		telegraph.PrimaryPart.Size = Vector3.new(0.2, radius * 2, radius * 2)
	end

	-- Position at ground level, rotate to lay flat
	-- Cylinder default orientation: X-axis is length
	-- We want it flat on ground, so rotate 90 degrees around Z axis
	local groundPosition = Vector3.new(position.X, position.Y + 0.1, position.Z)
	telegraph:PivotTo(CFrame.new(groundPosition) * CFrame.Angles(0, 0, math.rad(90)))

	-- Color based on attack type
	local color = attackType == "heal" and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)

	for _, descendant in telegraph:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = color
		end
	end

	-- Parent to workspace
	telegraph.Parent = workspace

	-- Pulse animation (transparency)
	if telegraph.PrimaryPart then
		local tweenInfo = TweenInfo.new(
			0.5, -- Duration of one pulse
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1, -- Repeat infinitely
			true -- Reverse
		)

		local tween = TweenService:Create(
			telegraph.PrimaryPart,
			tweenInfo,
			{ Transparency = 0.8 }
		)
		tween:Play()
	end

	-- Destroy after duration
	Debris:AddItem(telegraph, duration)

	return telegraph
end

return AOETelegraph
