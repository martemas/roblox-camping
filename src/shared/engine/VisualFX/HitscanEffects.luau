--!strict

--[[
	HitscanEffects - Visual Effects for Hitscan Weapons

	Provides beam and impact visual effects for hitscan weapons.
	Effects are optional based on weapon config (visualEffect = "beam" | "none").

	Uses template models from ReplicatedStorage.Models.Effects.Hitscan.
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local HitscanEffects = {}

-- Cache for effect templates
local beamTemplate: Model? = nil
local impactTemplate: Model? = nil

--[[
	Get beam template from ReplicatedStorage

	@return Model? - Beam effect template or nil
]]
local function getBeamTemplate(): Model?
	if beamTemplate then
		return beamTemplate
	end

	local modelsFolder = ServerStorage:FindFirstChild("Assets")
	if not modelsFolder then
		warn("ReplicatedStorage.Models not found")
		return nil
	end

	local effectsFolder = modelsFolder:FindFirstChild("Effects")
	if not effectsFolder then
		warn("ReplicatedStorage.Models.Effects not found")
		return nil
	end

	local hitscanFolder = effectsFolder:FindFirstChild("Hitscan")
	if not hitscanFolder then
		warn("ReplicatedStorage.Models.Effects.Hitscan not found")
		return nil
	end

	local template = hitscanFolder:FindFirstChild("BeamEffect")
	if template and template:IsA("Model") then
		beamTemplate = template
		return beamTemplate
	end

	warn("BeamEffect template not found in Effects.Hitscan")
	return nil
end

--[[
	Get impact template from ReplicatedStorage

	@return Model? - Impact effect template or nil
]]
local function getImpactTemplate(): Model?
	if impactTemplate then
		return impactTemplate
	end

	local modelsFolder = ServerStorage:FindFirstChild("Assets")
	if not modelsFolder then
		return nil
	end

	local effectsFolder = modelsFolder:FindFirstChild("Effects")
	if not effectsFolder then
		return nil
	end

	local hitscanFolder = effectsFolder:FindFirstChild("Hitscan")
	if not hitscanFolder then
		return nil
	end

	local template = hitscanFolder:FindFirstChild("ImpactEffect")
	if template and template:IsA("Model") then
		impactTemplate = template
		return template
	end

	return nil
end

--[[
	Show beam effect from origin to hit point

	@param origin - Start position of beam
	@param hitPoint - End position of beam
	@param weaponName - Name of weapon (for config lookup)
	@param duration - How long beam lasts (default 0.1s)
	@param isHealing - If true, color beam green (healing), else damage color
]]
function HitscanEffects.showBeam(
	origin: Vector3,
	hitPoint: Vector3,
	weaponName: string,
	duration: number?,
	isHealing: boolean?
)
	local effectDuration = duration or 0.1

	-- Try to use template, fallback to procedural
	local template = getBeamTemplate()

	if template then
		-- Use template model
		local beam = template:Clone()
		beam.Parent = workspace

		-- Position and orient beam
		local distance = (hitPoint - origin).Magnitude
		local midpoint = (origin + hitPoint) / 2

		if beam.PrimaryPart then
			beam:PivotTo(CFrame.new(midpoint, hitPoint) * CFrame.new(0, 0, -distance / 2))

			-- Scale to distance
			local scale = distance / (beam.PrimaryPart.Size.Z or 1)
			for _, descendant in beam:GetDescendants() do
				if descendant:IsA("BasePart") then
					local currentSize = descendant.Size
					descendant.Size = Vector3.new(currentSize.X, currentSize.Y, currentSize.Z * scale)
				end
			end

			-- Color based on healing/damage
			for _, descendant in beam:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Color = if isHealing
						then Color3.fromRGB(100, 255, 100) -- Green for healing
						else Color3.fromRGB(100, 200, 255) -- Cyan for damage
				end
			end
		end

		-- Fade out and destroy
		local tweenInfo = TweenInfo.new(effectDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		for _, descendant in beam:GetDescendants() do
			if descendant:IsA("BasePart") then
				local tween = TweenService:Create(descendant, tweenInfo, { Transparency = 1 })
				tween:Play()
			end
		end

		Debris:AddItem(beam, effectDuration)
	else
		-- Fallback: Create procedural beam
		local beamPart = Instance.new("Part")
		beamPart.Anchored = true
		beamPart.CanCollide = false
		beamPart.Size = Vector3.new(0.2, 0.2, (hitPoint - origin).Magnitude)
		beamPart.CFrame = CFrame.new(origin, hitPoint) * CFrame.new(0, 0, -beamPart.Size.Z / 2)
		beamPart.Material = Enum.Material.Neon
		beamPart.Color = if isHealing
			then Color3.fromRGB(100, 255, 100)
			else Color3.fromRGB(100, 200, 255)
		beamPart.Transparency = 0.3
		beamPart.Parent = workspace

		-- Fade out
		local tweenInfo = TweenInfo.new(effectDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		local tween = TweenService:Create(beamPart, tweenInfo, { Transparency = 1 })
		tween:Play()

		Debris:AddItem(beamPart, effectDuration)
	end
end

--[[
	Show impact effect at hit location

	@param position - Where the hit occurred
	@param normal - Surface normal at hit point
	@param weaponName - Name of weapon
	@param isHealing - If true, show healing effect (green), else damage (default)
]]
function HitscanEffects.showHitEffect(
	position: Vector3,
	normal: Vector3,
	weaponName: string,
	isHealing: boolean?
)
	local template = getImpactTemplate()

	if template then
		-- Use template model
		local impact = template:Clone()
		impact.Parent = workspace

		if impact.PrimaryPart then
			-- Orient to surface normal
			local upVector = normal
			local rightVector = if math.abs(upVector.Y) < 0.9
				then upVector:Cross(Vector3.new(0, 1, 0)).Unit
				else upVector:Cross(Vector3.new(1, 0, 0)).Unit
			local lookVector = rightVector:Cross(upVector)

			impact:PivotTo(CFrame.fromMatrix(position, rightVector, upVector, lookVector))

			-- Color particles based on healing/damage
			for _, descendant in impact:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					descendant.Color = if isHealing
						then ColorSequence.new(Color3.fromRGB(100, 255, 100))
						else ColorSequence.new(Color3.fromRGB(255, 255, 200))

					-- Emit burst
					descendant:Emit(20)
				end
			end
		end

		Debris:AddItem(impact, 1.0)
	else
		-- Fallback: Create procedural impact effect
		local impactPart = Instance.new("Part")
		impactPart.Anchored = true
		impactPart.CanCollide = false
		impactPart.Size = Vector3.new(0.1, 0.1, 0.1)
		impactPart.Position = position
		impactPart.Transparency = 1
		impactPart.Parent = workspace

		-- Create particle emitter
		local particles = Instance.new("ParticleEmitter")
		particles.Rate = 0 -- Burst only
		particles.Lifetime = NumberRange.new(0.2, 0.5)
		particles.Speed = NumberRange.new(5, 10)
		particles.SpreadAngle = Vector2.new(45, 45)
		particles.Color = if isHealing
			then ColorSequence.new(Color3.fromRGB(100, 255, 100))
			else ColorSequence.new(Color3.fromRGB(255, 255, 200))
		particles.Transparency = NumberSequence.new(0, 1)
		particles.Size = NumberSequence.new(0.3, 0)
		particles.EmissionDirection = Enum.NormalId.Top
		particles.Parent = impactPart

		-- Emit burst
		particles:Emit(20)

		Debris:AddItem(impactPart, 1.0)
	end

	-- Play hit sound (optional, could be weapon-specific)
	-- TODO: Add sound support from weapon config
end

return HitscanEffects
