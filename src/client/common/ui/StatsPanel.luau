--!strict

--[[
	StatsPanel - Character Stats Panel UI Component

	Displays player's stats with allocation buttons.
	Toggle visibility with configured hotkey (default: C).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local Stats = require(ReplicatedStorage.Engine:WaitForChild("Combat"):WaitForChild("Stats"))
local RemoteEventsModule = require(ReplicatedStorage.Engine:WaitForChild("Core"):WaitForChild("RemoteEvents"))
local RemoteEvents = RemoteEventsModule.Events
local RemoteFunctions = RemoteEventsModule.Functions
local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))

local StatsPanel = {}

-- Private state
local panel: Frame? = nil
local statsContainer: ScrollingFrame? = nil

-- Stat configuration
local STAT_ORDER = {"strength", "magic", "stamina", "accuracy"}
local STAT_NAMES = {
	strength = "Strength",
	magic = "Magic",
	stamina = "Stamina",
	accuracy = "Accuracy"
}
local STAT_DESCRIPTIONS = {
	strength = "+2% Phys Dmg | +Defense | +Crit Dmg",
	magic = "+2% Magic Dmg | +Magic Resist",
	stamina = "+10 HP | +Defense",
	accuracy = "+1% Hit | +1% Dodge | +0.5% Crit"
}

--[[
	Create the stats panel UI

	@param parent - ScreenGui to parent the panel to
	@return Frame - The stats panel
]]
function StatsPanel.create(parent: ScreenGui): Frame
	local config = UIConfig.statsPanel

	-- Main panel frame
	panel = Instance.new("Frame")
	panel.Name = "StatsPanel"
	panel.Size = UIConfig.createUDim2(config.size)
	panel.Position = UIConfig.createUDim2(config.position)
	panel.BackgroundColor3 = config.backgroundColor
	panel.BorderSizePixel = 0
	panel.Visible = config.startVisible
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.cornerRadius)
	corner.Parent = panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.12, 0)
	title.BackgroundColor3 = config.headerColor
	title.Font = config.headerFont
	title.TextSize = config.headerTextSize
	title.TextColor3 = config.textColor
	title.Text = "Character Stats"
	title.Parent = panel

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, config.cornerRadius)
	titleCorner.Parent = title

	-- Stats container (scrolling frame)
	statsContainer = Instance.new("ScrollingFrame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Size = UDim2.new(1, -config.padding * 2, 0.8, 0)
	statsContainer.Position = UDim2.new(0, config.padding, 0.15, 0)
	statsContainer.BackgroundTransparency = 1
	statsContainer.BorderSizePixel = 0
	statsContainer.ScrollBarThickness = 6
	statsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	statsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	statsContainer.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, config.statRowSpacing)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = statsContainer

	-- Create stat rows
	for i, statKey in STAT_ORDER do
		local statRow = Instance.new("Frame")
		statRow.Name = statKey
		statRow.Size = UDim2.new(1, 0, 0, 70)
		statRow.BackgroundColor3 = config.statRowColor
		statRow.BorderSizePixel = 0
		statRow.LayoutOrder = i
		statRow.Parent = statsContainer

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, config.cornerRadius)
		rowCorner.Parent = statRow

		-- Stat name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(0.6, 0, 0.35, 0)
		nameLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = config.font
		nameLabel.TextSize = config.statTextSize
		nameLabel.TextColor3 = config.textColor
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = STAT_NAMES[statKey]
		nameLabel.Parent = statRow

		-- Stat value
		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = "ValueLabel"
		valueLabel.Size = UDim2.new(0.25, 0, 0.35, 0)
		valueLabel.Position = UDim2.new(0.65, 0, 0.05, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Font = config.headerFont
		valueLabel.TextSize = config.statTextSize + 2
		valueLabel.TextColor3 = config.buttonColor
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Text = "5"
		valueLabel.Parent = statRow

		-- Stat description
		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "DescLabel"
		descLabel.Size = UDim2.new(0.9, 0, 0.55, 0)
		descLabel.Position = UDim2.new(0.05, 0, 0.42, 0)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = config.font
		descLabel.TextSize = config.descTextSize
		descLabel.TextColor3 = config.descTextColor
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Text = STAT_DESCRIPTIONS[statKey]
		descLabel.Parent = statRow

		-- Plus button (will be added later when updating)
	end

	-- Help text
	local helpText = Instance.new("TextLabel")
	helpText.Name = "HelpText"
	helpText.Size = UDim2.new(1, 0, 0.08, 0)
	helpText.Position = UDim2.new(0, 0, 0.92, 0)
	helpText.BackgroundTransparency = 1
	helpText.Font = config.font
	helpText.TextSize = config.descTextSize
	helpText.TextColor3 = config.descTextColor
	helpText.Text = `Press {UIConfig.statsPanel.hotkey.Name} to close`
	helpText.Parent = panel

	return panel
end

--[[
	Update stats panel display

	@param stats - Current stats table
	@param unallocatedPoints - Number of unallocated stat points
]]
function StatsPanel.update(stats: {[string]: number}, unallocatedPoints: number)
	if not panel or not statsContainer then
		warn("[StatsPanel] UI not created yet!")
		return
	end

	local config = UIConfig.statsPanel

	-- Calculate derived bonuses once (outside the loop)
	local success, derived = pcall(function()
		return RemoteFunctions.GetDerivedStats:InvokeServer({
			strength = stats.strength,
			magic = stats.magic,
			stamina = stats.stamina,
			accuracy = stats.accuracy,
			level = 1,  -- Level not needed for derived stats
			xp = 0,
		})
	end)

	if not success then
		warn("ERROR - Unable to retrieve derived stats:", derived)
		return  -- Exit early if we can't get derived stats
	end

	-- Update each stat row
	for statKey, value in stats do
		local statRow = statsContainer:FindFirstChild(statKey)
		if statRow then
			local valueLabel = statRow:FindFirstChild("ValueLabel") :: TextLabel
			if valueLabel then
				valueLabel.Text = tostring(value)
			end

			-- Update description with actual values
			local descLabel = statRow:FindFirstChild("DescLabel") :: TextLabel
			if descLabel then
				if statKey == "strength" then
					descLabel.Text = `+{math.floor((derived.physicalDamageBonus - 1) * 100)}% Phys Dmg | +Defense | +{math.floor((derived.critMultiplier - 1.5) * 100)}% Crit Dmg`
				elseif statKey == "magic" then
					descLabel.Text = `+{math.floor((derived.magicDamageBonus - 1) * 100)}% Magic Dmg`
				elseif statKey == "stamina" then
					descLabel.Text = `+{derived.maxHealthBonus} Max HP | +{math.floor(derived.defense * 100)}% Defense`
				elseif statKey == "accuracy" then
					descLabel.Text = `+{math.floor(derived.hitChance * 100 - 95)}% Hit | +{math.floor(derived.dodgeChance * 100)}% Dodge | +{math.floor((derived.criticalChance - 0.05) * 100)}% Crit`
				end
			end

			-- Update or create plus button if there are unallocated points
			local plusButton = statRow:FindFirstChild("PlusButton") :: TextButton?
			if unallocatedPoints > 0 then
				if not plusButton then
					plusButton = Instance.new("TextButton")
					plusButton.Name = "PlusButton"
					plusButton.Size = UDim2.new(0, 25, 0, 25)
					plusButton.Position = UDim2.new(0.92, 0, 0.05, 0)
					plusButton.AnchorPoint = Vector2.new(0.5, 0)
					plusButton.BackgroundColor3 = config.buttonColor
					plusButton.Font = config.headerFont
					plusButton.TextSize = 18
					plusButton.TextColor3 = config.textColor
					plusButton.Text = "+"
					plusButton.Parent = statRow

					local buttonCorner = Instance.new("UICorner")
					buttonCorner.CornerRadius = UDim.new(0, 6)
					buttonCorner.Parent = plusButton

					-- Hover effect
					plusButton.MouseEnter:Connect(function()
						plusButton.BackgroundColor3 = config.buttonHoverColor
					end)
					plusButton.MouseLeave:Connect(function()
						plusButton.BackgroundColor3 = config.buttonColor
					end)

					-- Click handler
					plusButton.MouseButton1Click:Connect(function()
						RemoteEvents.RequestStatIncrease:FireServer(statKey)
					end)
				end
				plusButton.Visible = true
			elseif plusButton then
				plusButton.Visible = false
			end
		end
	end

	-- Update help text to show unallocated points
	local helpText = panel:FindFirstChild("HelpText") :: TextLabel?
	if helpText then
		if unallocatedPoints > 0 then
			helpText.Text = `{unallocatedPoints} points available | Click + to allocate | Press {UIConfig.statsPanel.hotkey.Name} to close`
		else
			helpText.Text = `Press {UIConfig.statsPanel.hotkey.Name} to close`
		end
	end
end

--[[
	Toggle stats panel visibility
]]
function StatsPanel.toggle()
	if panel then
		panel.Visible = not panel.Visible
	end
end

--[[
	Show stats panel
]]
function StatsPanel.show()
	if panel then
		panel.Visible = true
	end
end

--[[
	Hide stats panel
]]
function StatsPanel.hide()
	if panel then
		panel.Visible = false
	end
end

--[[
	Destroy the stats panel
]]
function StatsPanel.destroy()
	if panel then
		panel:Destroy()
		panel = nil
		statsContainer = nil
	end
end

--[[
	Check if stats panel is enabled in config

	@return boolean - Whether stats panel is enabled
]]
function StatsPanel.isEnabled(): boolean
	return UIConfig.statsPanel.enabled
end

--[[
	Get the configured hotkey for toggling the panel

	@return Enum.KeyCode - The hotkey
]]
function StatsPanel.getHotkey(): Enum.KeyCode
	return UIConfig.statsPanel.hotkey
end

return StatsPanel
