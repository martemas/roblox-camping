--!strict

--[[
	Team Resources UI Component

	Displays shared team resources (Wood, Stone, Metal).

	Usage:
		local TeamResources = require(...)
		TeamResources.create(screenGui)
		TeamResources.update(teamResourcesData)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))
local Types = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("Types"))

type TeamResourcesType = Types.TeamResources

local TeamResources = UIComponent.new("TeamResources")

-- Component state
local teamResourcesFrame: Frame? = nil

--[[
	Create the Team Resources UI

	@param parent - Parent ScreenGui
	@return The created Frame
]]
function TeamResources.create(parent: ScreenGui): Frame
	local config = UIConfig.teamResources

	-- Main Frame
	teamResourcesFrame = Instance.new("Frame")
	teamResourcesFrame.Name = "TeamResourcesFrame"
	teamResourcesFrame.Size = UIConfig.createUDim2(config.size)
	teamResourcesFrame.Position = UIConfig.createUDim2(config.position)
	teamResourcesFrame.BackgroundColor3 = config.backgroundColor
	teamResourcesFrame.BackgroundTransparency = config.backgroundTransparency
	teamResourcesFrame.BorderSizePixel = 2
	teamResourcesFrame.BorderColor3 = config.borderColor
	teamResourcesFrame.Parent = parent

	-- Title
	local teamTitle = Instance.new("TextLabel")
	teamTitle.Name = "Title"
	teamTitle.Size = UDim2.new(1, 0, 0, 20)
	teamTitle.Position = UDim2.new(0, 0, 0, 0)
	teamTitle.BackgroundTransparency = 1
	teamTitle.Text = "Team Resources"
	teamTitle.TextColor3 = config.textColor
	teamTitle.TextScaled = true
	teamTitle.Font = config.font
	teamTitle.Parent = teamResourcesFrame

	-- Resource displays
	local resourceTypes = config.resourceTypes
	for i, resourceType in resourceTypes do
		local resourceLabel = Instance.new("TextLabel")
		resourceLabel.Name = resourceType
		resourceLabel.Size = UDim2.new(0.33, -5, 0, 30)
		resourceLabel.Position = UDim2.new((i - 1) * 0.33, 5, 0, 25)
		resourceLabel.BackgroundColor3 = config.resourceBgColor
		resourceLabel.BorderSizePixel = 1
		resourceLabel.BorderColor3 = config.borderColor
		resourceLabel.Text = `{resourceType}: 0`
		resourceLabel.TextColor3 = config.textColor
		resourceLabel.TextScaled = true
		resourceLabel.Font = config.font
		resourceLabel.Parent = teamResourcesFrame
	end

	print("[TeamResources] Component created")
	return teamResourcesFrame
end

--[[
	Update the team resources display

	@param teamResources - Team resources data
]]
function TeamResources.update(teamResources: TeamResourcesType)
	if not teamResourcesFrame then
		warn("[TeamResources] Cannot update: component not created")
		return
	end

	for resourceType, amount in teamResources do
		local label = teamResourcesFrame:FindFirstChild(resourceType) :: TextLabel?
		if label then
			label.Text = `{resourceType}: {amount}`
		end
	end
end

--[[
	Destroy the component
]]
function TeamResources.destroy()
	if teamResourcesFrame then
		teamResourcesFrame:Destroy()
		teamResourcesFrame = nil
		print("[TeamResources] Component destroyed")
	end
end

--[[
	Check if component is enabled in UIConfig

	@return boolean
]]
function TeamResources.isEnabled(): boolean
	return UIConfig.teamResources.enabled
end

return TeamResources
