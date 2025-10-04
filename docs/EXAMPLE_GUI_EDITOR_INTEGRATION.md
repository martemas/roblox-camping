# Integrating GUI Editor Built UIs into the Framework

This guide shows how to integrate UIs built with Roblox's built-in GUI editor into the modular UI framework.

## Method 1: Clone Template Approach (Recommended)

### Step 1: Build Your GUI in Roblox Studio

1. Open Roblox Studio
2. Build your UI using the GUI editor in `StarterGui`
3. Create a complete UI hierarchy (Frame, TextLabels, Buttons, etc.)
4. Test it looks good

### Step 2: Store as Template

1. Move your finished GUI from `StarterGui` to `ReplicatedStorage`
2. Create a folder: `ReplicatedStorage > GUITemplates`
3. Place your GUI inside this folder
4. Rename it appropriately (e.g., "QuestLogTemplate")

**Why ReplicatedStorage?**
- Available to both client and server
- Not automatically replicated to PlayerGui
- Perfect for templates that get cloned

### Step 3: Create Component Wrapper

```lua
--!strict
-- src/client/ui/QuestLog.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIConfig = require(script.Parent.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("UIComponent"))

local QuestLog = UIComponent.new("QuestLog")

-- Component state
local questLogFrame: Frame? = nil
local questListContainer: ScrollingFrame? = nil

--[[
	Create the Quest Log UI by cloning the template
]]
function QuestLog.create(parent: ScreenGui): Frame
	local config = UIConfig.questLog

	-- Clone the pre-built GUI from ReplicatedStorage
	local templates = ReplicatedStorage:WaitForChild("GUITemplates")
	local template = templates:WaitForChild("QuestLogTemplate") :: Frame

	questLogFrame = template:Clone()
	questLogFrame.Parent = parent

	-- Apply config overrides (optional - override design-time values)
	if config.position then
		questLogFrame.Position = UIConfig.createUDim2(config.position)
	end

	if config.startVisible ~= nil then
		questLogFrame.Visible = config.startVisible
	end

	-- Cache important child elements
	questListContainer = questLogFrame:FindFirstChild("QuestList") :: ScrollingFrame?

	-- Setup interactions
	setupButtons()

	print("[QuestLog] Component created from template")
	return questLogFrame
end

--[[
	Update quest list with new data
]]
function QuestLog.update(quests: {any})
	if not questLogFrame or not questListContainer then
		warn("[QuestLog] Cannot update: component not created")
		return
	end

	-- Clear existing quests
	for _, child in questListContainer:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Create quest entries
	for i, quest in quests do
		local questEntry = createQuestEntry(quest, i)
		questEntry.Parent = questListContainer
	end

	-- Update canvas size
	local entryHeight = 60
	local spacing = 5
	questListContainer.CanvasSize = UDim2.new(0, 0, 0, #quests * (entryHeight + spacing))
end

--[[
	Create a quest entry (could also be a cloned template)
]]
local function createQuestEntry(questData: any, index: number): Frame
	local entry = Instance.new("Frame")
	entry.Name = `Quest{index}`
	entry.Size = UDim2.new(1, -10, 0, 55)
	entry.Position = UDim2.new(0, 5, 0, (index - 1) * 60)
	entry.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -10, 0.5, 0)
	titleLabel.Position = UDim2.new(0, 5, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = questData.title
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.Parent = entry

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.Size = UDim2.new(1, -10, 0.5, 0)
	descLabel.Position = UDim2.new(0, 5, 0.5, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = questData.description
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextScaled = true
	descLabel.Parent = entry

	return entry
end

--[[
	Setup button click handlers
]]
local function setupButtons()
	if not questLogFrame then return end

	-- Close button
	local closeButton = questLogFrame:FindFirstChild("CloseButton") :: TextButton?
	if closeButton then
		closeButton.Activated:Connect(function()
			QuestLog.hide()
		end)
	end

	-- Refresh button
	local refreshButton = questLogFrame:FindFirstChild("RefreshButton") :: TextButton?
	if refreshButton then
		refreshButton.Activated:Connect(function()
			-- Request quest data from server
			print("[QuestLog] Refresh requested")
			-- RemoteEvents.RequestQuestData:FireServer()
		end)
	end
end

--[[
	Show the quest log
]]
function QuestLog.show()
	if questLogFrame then
		questLogFrame.Visible = true
	end
end

--[[
	Hide the quest log
]]
function QuestLog.hide()
	if questLogFrame then
		questLogFrame.Visible = false
	end
end

--[[
	Toggle visibility
]]
function QuestLog.toggle()
	if questLogFrame then
		questLogFrame.Visible = not questLogFrame.Visible
	end
end

--[[
	Destroy the component
]]
function QuestLog.destroy()
	if questLogFrame then
		questLogFrame:Destroy()
		questLogFrame = nil
		questListContainer = nil
		print("[QuestLog] Component destroyed")
	end
end

--[[
	Check if enabled
]]
function QuestLog.isEnabled(): boolean
	return UIConfig.questLog.enabled
end

return QuestLog
```

### Step 4: Add Configuration

```lua
-- UIConfig.luau
questLog = {
	enabled = true,

	-- Override template position if needed
	position = {
		scaleX = 0.7,
		offsetX = 0,
		scaleY = 0.2,
		offsetY = 0,
	},

	-- Start visible or hidden
	startVisible = false,

	-- Custom settings
	maxQuests = 10,
	refreshInterval = 30, -- seconds
},
```

### Step 5: Register Component

```lua
-- UIManager.luau
local COMPONENT_MODULES = {
	-- Game UI
	Inventory = "ui/Inventory",
	QuestLog = "ui/QuestLog",  -- Add here
	-- ...
}
```

### Step 6: Use It

```lua
-- Show quest log
UIManager.showComponent("QuestLog")

-- Update with quest data
UIManager.updateComponent("QuestLog", {
	{
		title = "Gather Wood",
		description = "Collect 50 wood"
	},
	{
		title = "Defeat Zombies",
		description = "Kill 10 zombies"
	}
})

-- Hide it
UIManager.hideComponent("QuestLog")
```

## Method 2: Hook Into Existing StarterGui UI

If your UI is already in StarterGui and auto-replicates:

```lua
function QuestLog.create(parent: ScreenGui): Frame?
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Find the GUI that was auto-replicated from StarterGui
	local existingGui = playerGui:WaitForChild("QuestLogUI", 5)

	if existingGui then
		questLogFrame = existingGui :: ScreenGui

		-- Cache important elements
		questListContainer = questLogFrame:FindFirstChild("QuestList", true) :: ScrollingFrame?

		-- Apply config settings
		if config.startVisible ~= nil then
			questLogFrame.Enabled = config.startVisible
		end

		-- Setup interactions
		setupButtons()

		print("[QuestLog] Hooked into existing GUI")
		return questLogFrame
	else
		warn("[QuestLog] Could not find existing GUI in PlayerGui")
		return nil
	end
end

-- For show/hide, use Enabled instead of Visible
function QuestLog.show()
	if questLogFrame then
		questLogFrame.Enabled = true
	end
end

function QuestLog.hide()
	if questLogFrame then
		questLogFrame.Enabled = false
	end
end
```

## Method 3: Hybrid Approach

Use GUI editor for static layout, code for dynamic elements:

```lua
function QuestLog.create(parent: ScreenGui): Frame
	local config = UIConfig.questLog

	-- Clone the container/shell from template
	local template = ReplicatedStorage:WaitForChild("GUITemplates"):WaitForChild("QuestLogShell")
	questLogFrame = template:Clone()
	questLogFrame.Parent = parent

	-- Find the container where we'll add dynamic content
	questListContainer = questLogFrame:FindFirstChild("QuestList") :: ScrollingFrame

	-- Create dynamic elements programmatically
	createDynamicElements()

	setupButtons()

	return questLogFrame
end

local function createDynamicElements()
	-- Add elements that change frequently via code
	-- Keep static layout in the GUI editor template
end
```

## Best Practices

### 1. **Separation of Concerns**
- **GUI Editor**: Static layout, containers, base styling
- **Code**: Dynamic content, interactions, data binding

### 2. **Name Your Elements Clearly**
```
QuestLogFrame
├── Header (Frame)
│   ├── TitleLabel (TextLabel)
│   └── CloseButton (TextButton)
├── QuestList (ScrollingFrame)
└── Footer (Frame)
    └── RefreshButton (TextButton)
```

Use `FindFirstChild()` to reference these by name.

### 3. **Use Configuration for Overrides**
- Build initial look in GUI editor
- Use UIConfig for runtime customization
- Don't hardcode values in the component

### 4. **Cache Important References**
```lua
-- Cache on create
local titleLabel: TextLabel? = nil
local closeButton: TextButton? = nil

function MyUI.create(parent: ScreenGui): Frame
	-- ...
	titleLabel = myFrame:FindFirstChild("TitleLabel") :: TextLabel?
	closeButton = myFrame:FindFirstChild("CloseButton") :: TextButton?
	-- ...
end

-- Use cached references
function MyUI.update(data: any)
	if titleLabel then
		titleLabel.Text = data.title
	end
end
```

### 5. **Handle Missing Elements Gracefully**
```lua
local button = frame:FindFirstChild("ActionButton") :: TextButton?
if button then
	button.Activated:Connect(onClick)
else
	warn("[MyUI] ActionButton not found in template")
end
```

## Advantages of This Approach

✅ **Visual Design**: Use Roblox's GUI editor for layout
✅ **Code Control**: Manage behavior and data in code
✅ **Reusability**: Clone templates for multiple instances
✅ **Configuration**: Override values via UIConfig
✅ **Integration**: Works seamlessly with UIManager
✅ **Maintainability**: Separate design from logic

## Common Patterns

### Pattern 1: Template + Dynamic Content
- Build container in GUI editor
- Clone and populate with data in code

### Pattern 2: Complete Template Clone
- Build entire UI in GUI editor
- Clone and wire up events in code

### Pattern 3: Reference Existing
- UI lives in StarterGui
- Component just references and controls it

Choose based on your needs!
