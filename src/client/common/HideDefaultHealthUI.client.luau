--!strict

--[[
	HideDefaultHealthUI - Hides default Roblox health displays

	This script disables:
	1. The default health bar UI in the top right corner
	2. The overhead health bars that appear above entity heads by default
]]

local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

-- Hide the default health bar UI (top right corner)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- Function to hide overhead health bar for a humanoid
local function hideOverheadHealthBar(humanoid: Humanoid)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0
end

-- Hide overhead health bars for all existing humanoids in workspace
for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("Humanoid") then
		hideOverheadHealthBar(descendant)
	end
end

-- Hide overhead health bars for new humanoids added to workspace
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Humanoid") then
		-- Small delay to ensure humanoid is fully loaded
		task.wait()
		hideOverheadHealthBar(descendant)
	end
end)

-- Hide overhead health bar for player's own character
local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	hideOverheadHealthBar(humanoid)
end

if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

print("[HideDefaultHealthUI] Default health displays hidden")
