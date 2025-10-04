--!strict

--[[
	HealthBarManager - Health Bar Attachment System

	Manages attaching health bars from ReplicatedStorage to player/entity models.
	The HealthBar BillboardGui is expected to exist in ReplicatedStorage/UI/HealthBar
	and contains a LocalScript that automatically updates based on Humanoid.Health changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HealthBarManager = {}

--[[
	Attach a health bar to a model's Head

	@param model - The character/entity model to attach health bar to
	@return boolean - Success status
]]
function HealthBarManager.attachHealthBar(model: Model): boolean
	if not model or not model:IsA("Model") then
		warn("[HealthBarManager] Invalid model provided")
		return false
	end

	-- Find the Head part (preferred) or HumanoidRootPart (fallback)
	local attachPart = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not attachPart or not attachPart:IsA("BasePart") then
		warn(`[HealthBarManager] No Head or HumanoidRootPart found in model {model.Name}`)
		return false
	end

	-- Check if health bar already exists
	if attachPart:FindFirstChild("HealthBar") then
		-- Already has a health bar, skip
		return true
	end

	-- Clone the HealthBar from ReplicatedStorage/UI
	local uiFolder = ReplicatedStorage:FindFirstChild("UI")
	if not uiFolder then
		warn("[HealthBarManager] UI folder not found in ReplicatedStorage")
		return false
	end

	local healthBarTemplate = uiFolder:FindFirstChild("HealthBar")
	if not healthBarTemplate then
		warn("[HealthBarManager] HealthBar template not found in ReplicatedStorage/UI")
		return false
	end

	local healthBar = healthBarTemplate:Clone()
	healthBar.Parent = attachPart

	-- Enable the LocalScript if it exists
	-- Note: LocalScripts cloned by server to Workspace may still not run
	-- This is a limitation of Roblox. For best performance, consider
	-- moving to full client-side health bar management.
	local updateScript = healthBar:FindFirstChild("UpdateHealth")
	if updateScript and updateScript:IsA("LocalScript") then
		updateScript.Enabled = true
	end

	return true
end

return HealthBarManager
