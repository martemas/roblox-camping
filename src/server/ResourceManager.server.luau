--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local Utils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"))

type ResourceNode = Types.ResourceNode
type ResourceType = Types.ResourceType

local ResourceManager = {}
local resourceNodes: {[BasePart]: ResourceNode} = {}
local playerInventories: {[Player]: Types.PlayerInventory} = {}
local activeMiningTasks: {[Player]: Types.MiningSession} = {}


-- Initialize empty inventory for a player
local function createEmptyInventory(): Types.PlayerInventory
	return {
		Wood = 0,
		Stone = 0,
		Metal = 0,
	}
end

-- Get player's current inventory count
local function getInventoryCount(player: Player): number
	local inventory = playerInventories[player]
	if not inventory then
		return 0
	end

	local count = 0
	for _, amount in pairs(inventory) do
		count += amount
	end
	return count
end

-- Check if player has any tool in the required category
local function hasRequiredToolCategory(player: Player, category: string): (boolean, Types.ToolType?)
	local character = player.Character
	if not character then
		return false, nil
	end

	local toolsInCategory = GameConfig.toolCategories[category]
	if not toolsInCategory then
		warn(`Tool category {category} not found in GameConfig.toolCategories`)
		return false, nil
	end

	for _, toolName in toolsInCategory do
		local tool = character:FindFirstChild(toolName)
		if tool and tool:IsA("Tool") then
			return true, toolName :: Types.ToolType -- Return tool name for miningSpeed lookup
		end
	end

	return false, nil
end

-- Create a resource node
local function createResourceNode(resourceType: ResourceType, position: vector): ResourceNode?
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return nil
	end

	local nodeModelName = resourceType .. "Node"
	local nodeTemplate = modelsFolder:FindFirstChild(nodeModelName)
	if not nodeTemplate then
		warn(`Resource node template '{nodeModelName}' not found in Models folder`)
		return nil
	end

	local nodeModel = nodeTemplate:Clone()
	nodeModel.Parent = workspace

	-- Position the model safely
	if nodeModel.PrimaryPart then
		nodeModel:SetPrimaryPartCFrame(CFrame.new(position))
	else
		-- Fallback: move the first BasePart found
		local firstPart = nodeModel:FindFirstChildOfClass("BasePart")
		if firstPart then
			firstPart.CFrame = CFrame.new(position)
		else
			warn(`No BasePart found in {nodeModelName} model for positioning`)
			nodeModel:Destroy()
			return nil
		end
	end

	-- Find the main part for the resource node
	local mainPart = nodeModel.PrimaryPart or nodeModel:FindFirstChildOfClass("BasePart")
	if not mainPart then
		warn(`No BasePart found in {nodeModelName}`)
		nodeModel:Destroy()
		return nil
	end

	local maxHits = GameConfig.resources[resourceType].hitsRequired
	local resourceNode: ResourceNode = {
		resourceType = resourceType,
		currentHits = 0,
		maxHits = maxHits,
		isActive = true,
		part = mainPart,
	}

	-- Set generic entity attributes for tool interaction system
	local entityNodeName = resourceType .. "Node"
	local entityConfig = GameConfig.entities[entityNodeName]
	if entityConfig then
		nodeModel:SetAttribute("EntityType", entityNodeName)
		nodeModel:SetAttribute("EntityCategory", entityConfig.category)
		nodeModel:SetAttribute("CanTakeDamage", entityConfig.canTakeDamage)
		nodeModel:SetAttribute("MaxHealth", entityConfig.health)
		nodeModel:SetAttribute("CurrentHealth", entityConfig.health)
	else
		warn(`No entity configuration found for {entityNodeName}`)
	end

	-- TODO: Create HP indicator GUI when UI assets are ready
	-- TODO: Add particle emitter when particle assets are ready

	-- Add ProximityPrompt for mining
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MiningPrompt"
	prompt.ActionText = `Mine {resourceType}`
	prompt.ObjectText = resourceType
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10

	-- Set hold duration based on config
	if GameConfig.gameplay.miningInteraction == "tap" then
		prompt.HoldDuration = 0
	else
		prompt.HoldDuration = GameConfig.gameplay.miningHoldDuration
	end

	prompt.RequiresLineOfSight = false
	prompt.Parent = mainPart

	print(`Created ProximityPrompt for {resourceType} node`) -- DEBUG

	resourceNodes[mainPart] = resourceNode
	return resourceNode
end

-- Handle resource node mining
-- local function _onResourceNodeClicked(player: Player, part: BasePart)
-- 	print(`{player.Name} clicked on {part.Name}`) -- DEBUG

-- 	local node = resourceNodes[part]
-- 	if not node then
-- 		print(`No node found for part {part.Name}`) -- DEBUG
-- 		return
-- 	end

-- 	if not node.isActive then
-- 		print(`Node {part.Name} is not active`) -- DEBUG
-- 		return
-- 	end

-- 	print(`Checking tool for {node.resourceType}...`) -- DEBUG

-- 	-- Check if player has required tool
-- 	if not hasRequiredTool(player, node.resourceType) then
-- 		local requiredTool = GameConfig.resources[node.resourceType].requiredTool
-- 		print(`{player.Name} doesn't have {requiredTool} for {node.resourceType}`) -- DEBUG
-- 		RemoteEvents.Events.ShowNotification:FireClient(player, `You need a {requiredTool} to mine {node.resourceType}`)
-- 		return
-- 	end

-- 	print(`{player.Name} has correct tool, mining {node.resourceType}...`) -- DEBUG

-- 	-- Get resource configuration
-- 	local resourceConfig = GameConfig.resources[node.resourceType]

-- 	-- Check inventory space
-- 	local InventoryManager = _G.InventoryManager
-- 	if InventoryManager then
-- 		if not InventoryManager.HasSpace(player, resourceConfig.yieldPerHit) then
-- 			RemoteEvents.Events.ShowNotification:FireClient(player, "Inventory full! Deposit resources at the warehouse.")
-- 			return
-- 		end
-- 	else
-- 		local currentCount = getInventoryCount(player)
-- 		if currentCount >= GameConfig.player.inventorySize then
-- 			RemoteEvents.Events.ShowNotification:FireClient(player, "Inventory full! Deposit resources at the warehouse.")
-- 			return
-- 		end
-- 	end

-- 	-- Mine the resource
-- 	node.currentHits += 1

-- 	-- TODO: Play mining sound effect when sound assets are ready
-- 	-- TODO: Show mining particles when particle assets are ready

-- 	-- Give resource to player via InventoryManager
-- 	local InventoryManager = _G.InventoryManager
-- 	if InventoryManager then
-- 		local success = InventoryManager.AddItem(player, node.resourceType, resourceConfig.yieldPerHit)
-- 		if not success then
-- 			print(`Failed to add {node.resourceType} to {player.Name}'s inventory - might be full`) -- DEBUG
-- 		end
-- 	else
-- 		warn("InventoryManager not available - falling back to local inventory")
-- 		-- Fallback to local inventory
-- 		local inventory = playerInventories[player]
-- 		if not inventory then
-- 			inventory = createEmptyInventory()
-- 			playerInventories[player] = inventory
-- 		end
-- 		inventory[node.resourceType] += resourceConfig.yieldPerHit
-- 		RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)
-- 	end

-- 	-- Trigger tool swing animation
-- 	RemoteEvents.Events.SwingTool:FireClient(player, resourceConfig.requiredTool)

-- 	-- Check if node is depleted
-- 	if node.currentHits >= node.maxHits then
-- 		node.isActive = false
-- 		node.part.Transparency = 0.7 -- Visual feedback for depletion

-- 		-- TODO: Stop mining particles when assets are ready

-- 		-- Schedule respawn
-- 		task.wait(resourceConfig.respawnTime)
-- 		if node.part.Parent then -- Check if still exists
-- 			node.currentHits = 0
-- 			node.isActive = true
-- 			node.part.Transparency = 0
-- 			-- TODO: Restart mining particles when assets are ready
-- 		end
-- 	end
-- end

-- Hide resource node (make it invisible and disable collisions)
local function hideResourceNode(node: ResourceNode)
	local model = node.part.Parent
	if not model then return end

	-- Hide all parts in the model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		end
	end

	-- Hide ProximityPrompt
	local prompt = node.part:FindFirstChild("MiningPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end

	print(`Hid {node.resourceType} node`) -- DEBUG
end

-- Show resource node (make it visible and enable collisions)
local function showResourceNode(node: ResourceNode)
	local model = node.part.Parent
	if not model then return end

	-- Show all parts in the model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 0
			descendant.CanCollide = true
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 0
		end
	end

	-- Show ProximityPrompt
	local prompt = node.part:FindFirstChild("MiningPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = true
	end

	print(`Showed {node.resourceType} node`) -- DEBUG
end

-- Create progress bar BillboardGui above resource node
local function createProgressBar(node: ResourceNode): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MiningProgress"
	billboard.Size = UDim2.new(4, 0, 0.5, 0)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = node.part

	-- Background frame
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	background.BorderSizePixel = 2
	background.BorderColor3 = Color3.fromRGB(0, 0, 0)
	background.Parent = billboard

	-- Progress bar
	local progressBar = Instance.new("Frame")
	progressBar.Name = "Bar"
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
	progressBar.BorderSizePixel = 0
	progressBar.Parent = background

	-- Progress text
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "0%"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = background

	return billboard
end

-- Play tool swing animation during mining
local function playToolAnimation(player: Player, toolName: Types.ToolType)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Use default toolslash animation
	local animateScript = character:FindFirstChild("Animate")
	if animateScript then
		local toolSlashAnim = animateScript:FindFirstChild("toolslash")
		if toolSlashAnim then
			local slashAnimation = toolSlashAnim:FindFirstChildOfClass("Animation")
			if slashAnimation then
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if animator then
					local success, animationTrack = pcall(function()
						local track = animator:LoadAnimation(slashAnimation)
						track.Priority = Enum.AnimationPriority.Action
						return track
					end)

					if success and animationTrack then
						animationTrack:Play()
					end
				end
			end
		end
	end
end

-- Start auto-mining on a resource node
local function startAutoMining(player: Player, node: ResourceNode)
	-- Hide ProximityPrompt immediately
	local prompt = node.part:FindFirstChild("MiningPrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = false
	end

	-- Check if player already mining
	if activeMiningTasks[player] then
		RemoteEvents.Events.ShowNotification:FireClient(player, "Already mining!")
		-- Re-enable prompt
		if prompt then
			prompt.Enabled = true
		end
		return
	end

	if not node.isActive then
		RemoteEvents.Events.ShowNotification:FireClient(player, "Resource depleted!")
		-- Re-enable prompt
		if prompt then
			prompt.Enabled = true
		end
		return
	end

	-- Get resource config
	local resourceConfig = GameConfig.resources[node.resourceType]

	-- Check inventory space FIRST before touching tools
	local InventoryManager = _G.InventoryManager
	local availableSpace = 0

	if InventoryManager then
		local maxSize = InventoryManager.GetMaxSize()
		local currentCount = InventoryManager.GetInventoryCount(player)
		availableSpace = maxSize - currentCount
	else
		availableSpace = GameConfig.player.inventorySize - getInventoryCount(player)
	end

	if availableSpace <= 0 then
		RemoteEvents.Events.ShowNotification:FireClient(player, "Inventory full!")
		-- Re-enable prompt
		if prompt then
			prompt.Enabled = true
		end
		return -- Return BEFORE touching any tools
	end

	-- Calculate how much we can actually mine (partial fill allowed)
	local amountToMine = math.min(resourceConfig.yieldPerMine, availableSpace)

	-- Check if player has required tool category
	local hasTool, equippedToolName = hasRequiredToolCategory(player, resourceConfig.requiredToolCategory)
	local previousTool: Types.ToolType? = nil

	-- Get character for tool manipulation
	local character = player.Character
	if not character then return end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	if not hasTool then
		-- Auto-equip a tool from the category
		local ToolManager = _G.ToolManager
		if not ToolManager then
			RemoteEvents.Events.ShowNotification:FireClient(player, `Need a {resourceConfig.requiredToolCategory} to mine!`)
			return
		end

		local toolsInCategory = GameConfig.toolCategories[resourceConfig.requiredToolCategory]
		local foundTool = false

		-- Save currently equipped tool BEFORE unequipping
		previousTool = ToolManager.GetEquippedTool(player)

		-- Unequip ALL current tools (move them back to backpack)
		if previousTool then
			local currentTool = character:FindFirstChild(previousTool)
			if currentTool and currentTool:IsA("Tool") then
				currentTool.Parent = backpack
				task.wait(0.1) -- Wait for Roblox to process the unequip
				print(`Unequipped {previousTool} for {player.Name}`) -- DEBUG
			end
		end

		-- Also check for any other tools in character and unequip them
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				child.Parent = backpack
				task.wait(0.1)
				print(`Force-unequipped {child.Name} from {player.Name}`) -- DEBUG
			end
		end

		-- Find and equip mining tool
		for _, toolName in toolsInCategory do
			if ToolManager.HasTool(player, toolName :: Types.ToolType) then
				local miningTool = backpack:FindFirstChild(toolName)
				if miningTool and miningTool:IsA("Tool") then
					task.wait(0.1) -- Wait before equipping
					miningTool.Parent = character
					equippedToolName = toolName :: Types.ToolType
					foundTool = true
					print(`Auto-equipped {toolName} for {player.Name}`) -- DEBUG
					break
				end
			end
		end

		if not foundTool then
			RemoteEvents.Events.ShowNotification:FireClient(player, `Need a {resourceConfig.requiredToolCategory} to mine!`)
			-- Restore previous tool if we unequipped it
			if previousTool then
				local toolToRestore = backpack:FindFirstChild(previousTool)
				if toolToRestore and toolToRestore:IsA("Tool") then
					toolToRestore.Parent = character
				end
			end
			return
		end
	else
		-- Already have correct tool equipped, just save it as previous
		previousTool = equippedToolName
	end

	-- Get tool config for miningSpeed
	local toolConfig = GameConfig.tools[equippedToolName]
	local miningSpeed = (toolConfig and toolConfig.miningSpeed) or 1.0

	-- Calculate mining duration
	local duration = resourceConfig.miningDuration / miningSpeed

	-- Get character and starting position
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local startPosition = hrp.Position

	-- Make player face the resource node
	local nodePosition = node.part.Position
	local targetCFrame = CFrame.lookAt(hrp.Position, nodePosition)
	hrp.CFrame = targetCFrame

	-- Create progress bar
	local progressBar = createProgressBar(node)

	-- Create mining session
	local session: Types.MiningSession = {
		player = player,
		resourceNode = node,
		startPosition = startPosition,
		previousTool = previousTool,
		task = nil :: any, -- Will be set below
		cancelled = false,
	}
	activeMiningTasks[player] = session

	print(`{player.Name} started mining {node.resourceType} with {equippedToolName} (duration: {duration}s)`) -- DEBUG
	RemoteEvents.Events.MiningStarted:FireClient(player, node.resourceType)

	-- Start mining task
	session.task = task.spawn(function()
		local startTime = tick()
		local animationInterval = 0.5
		local lastAnimTime = 0
		local progressUpdateInterval = 0.1

		-- Play initial animation
		if equippedToolName then
			playToolAnimation(player, equippedToolName)
		end

		-- Monitor position and play animations during mining
		while tick() - startTime < duration do
			-- Check if player moved
			local currentHrp = character:FindFirstChild("HumanoidRootPart")
			if not currentHrp then
				session.cancelled = true
				break
			end

			local currentPos = currentHrp.Position
			if (currentPos - startPosition).Magnitude > 0.1 then
				session.cancelled = true
				RemoteEvents.Events.MiningCancelled:FireClient(player, "Mining cancelled - you moved!")
				RemoteEvents.Events.ShowNotification:FireClient(player, "Mining cancelled - you moved!")
				print(`{player.Name} moved during mining, cancelled`) -- DEBUG
				break
			end

			-- Check if player switched tools
			local currentTool: Tool? = nil
			for _, child in character:GetChildren() do
				if child:IsA("Tool") then
					currentTool = child
					break
				end
			end

			-- If tool changed or tool was unequipped, cancel mining
			if not currentTool or currentTool.Name ~= equippedToolName then
				session.cancelled = true
				RemoteEvents.Events.MiningCancelled:FireClient(player, "Mining cancelled - you switched tools!")
				RemoteEvents.Events.ShowNotification:FireClient(player, "Mining cancelled - you switched tools!")
				print(`{player.Name} switched tools during mining, cancelled`) -- DEBUG
				break
			end

			-- Play animation periodically
			if tick() - lastAnimTime >= animationInterval and equippedToolName then
				playToolAnimation(player, equippedToolName)
				lastAnimTime = tick()
			end

			-- Update progress bar
			local elapsed = tick() - startTime
			local progress = math.clamp(elapsed / duration, 0, 1)
			local progressPercent = math.floor(progress * 100)

			if progressBar and progressBar.Parent then
				local bar = progressBar:FindFirstChild("Background"):FindFirstChild("Bar") :: Frame?
				local text = progressBar:FindFirstChild("Background"):FindFirstChild("Text") :: TextLabel?
				if bar then
					bar.Size = UDim2.new(progress, 0, 1, 0)
				end
				if text then
					text.Text = `{progressPercent}%`
				end
			end

			task.wait(0.05) -- Check position every 50ms
		end

		-- Mining completed or cancelled
		if not session.cancelled and node.isActive then
			-- Give resources (same logic as HandleToolHit)
			node.currentHits += 1

			local InventoryManager = _G.InventoryManager
			if InventoryManager then
				local success = InventoryManager.AddItem(player, node.resourceType, amountToMine)
				if success then
					print(`{player.Name} mined {node.resourceType}, added {amountToMine} to inventory`) -- DEBUG
					RemoteEvents.Events.MiningCompleted:FireClient(player, node.resourceType, amountToMine)
					if amountToMine < resourceConfig.yieldPerMine then
						RemoteEvents.Events.ShowNotification:FireClient(player, `Inventory nearly full! Only added {amountToMine} {node.resourceType}`)
					end
				else
					print(`Failed to add {node.resourceType} to {player.Name}'s inventory`) -- DEBUG
				end
			else
				-- Fallback to local inventory
				local inventory = playerInventories[player]
				if not inventory then
					inventory = createEmptyInventory()
					playerInventories[player] = inventory
				end
				inventory[node.resourceType] += amountToMine
				RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)
				RemoteEvents.Events.MiningCompleted:FireClient(player, node.resourceType, amountToMine)
				if amountToMine < resourceConfig.yieldPerMine then
					RemoteEvents.Events.ShowNotification:FireClient(player, `Inventory nearly full! Only added {amountToMine} {node.resourceType}`)
				end
				print(`{player.Name} mined {node.resourceType}, now has {inventory[node.resourceType]}`) -- DEBUG
			end

			-- Check if node is depleted
			if node.currentHits >= node.maxHits then
				node.isActive = false
				hideResourceNode(node)
				print(`{node.resourceType} node depleted, will respawn in {resourceConfig.respawnTime} seconds`) -- DEBUG

				-- Schedule respawn
				task.spawn(function()
					task.wait(resourceConfig.respawnTime)
					if node.part.Parent then
						node.currentHits = 0
						node.isActive = true
						showResourceNode(node)
						print(`{node.resourceType} node respawned`) -- DEBUG
					end
				end)
			end
		end

		-- Restore previous tool
		if session.previousTool and session.previousTool ~= equippedToolName then
			local character = player.Character
			if character then
				local backpack = player:FindFirstChild("Backpack")
				if backpack then
					-- Unequip ALL tools from character first
					for _, child in character:GetChildren() do
						if child:IsA("Tool") then
							child.Parent = backpack
							task.wait(0.05)
							print(`Unequipped {child.Name} from {player.Name}`) -- DEBUG
						end
					end

					-- Wait for unequip to process
					task.wait(0.1)

					-- Re-equip previous tool
					local previousToolInstance = backpack:FindFirstChild(session.previousTool)
					if previousToolInstance and previousToolInstance:IsA("Tool") then
						previousToolInstance.Parent = character
						task.wait(0.05)
						print(`Restored {session.previousTool} for {player.Name}`) -- DEBUG
					end
				end
			end
		end

		-- Destroy progress bar
		if progressBar and progressBar.Parent then
			progressBar:Destroy()
		end

		-- Re-enable ProximityPrompt
		if prompt and node.isActive then
			prompt.Enabled = true
			prompt.ObjectText = node.resourceType
		end

		activeMiningTasks[player] = nil
	end)
end

-- Spawn resource nodes around the map
local function spawnResourceNodes()
	local mapSize = GameConfig.map.size
	local spawnRadius = GameConfig.map.resourceSpawnRadius
	local centerPosition = vector.create(0, 0, 0) -- Map center

	for resourceType, config in pairs(GameConfig.resources) do
		-- Only spawn nodes with spawnMode = "random"
		if config.spawnMode == "random" then
			for i = 1, config.nodesCount do
				-- Generate random position with ground detection
				local position = Utils.getRandomGroundPosition(centerPosition, 50, spawnRadius)
				local node = createResourceNode(resourceType :: ResourceType, position)

				if not node then
					warn(`Failed to create {resourceType} node {i}`)
				end
			end
		else
			print(`Skipping {resourceType} - spawnMode is {config.spawnMode}`) -- DEBUG
		end
	end
end

-- Initialize player inventory when they join
local function onPlayerAdded(player: Player)
	playerInventories[player] = createEmptyInventory()

	-- Send initial inventory to client
	RemoteEvents.Events.UpdateInventory:FireClient(player, playerInventories[player])
end

-- Clean up when player leaves
local function onPlayerRemoving(player: Player)
	playerInventories[player] = nil
end

-- Public functions
function ResourceManager.GetPlayerInventory(player: Player): Types.PlayerInventory?
	return playerInventories[player]
end

function ResourceManager.RemoveFromInventory(player: Player, resourceType: ResourceType, amount: number): boolean
	local inventory = playerInventories[player]
	if not inventory or inventory[resourceType] < amount then
		return false
	end

	inventory[resourceType] -= amount
	RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)
	return true
end

function ResourceManager.GetInventoryCount(player: Player): number
	return getInventoryCount(player)
end

-- Handle tool hit on resource node (called from ToolManager)
function ResourceManager.HandleToolHit(player: Player, hitPart: BasePart, resourceType: Types.ResourceType)
	print(`HandleToolHit called for {player.Name} hitting {resourceType}`) -- DEBUG

	-- Find the resource node
	local node = resourceNodes[hitPart]
	if not node then
		-- Try to find node by searching all nodes (in case hitPart is not the exact registered part)
		for part, nodeData in pairs(resourceNodes) do
			if part.Parent == hitPart.Parent then
				node = nodeData
				break
			end
		end
	end

	if not node then
		print(`No resource node found for hit part`) -- DEBUG
		return
	end

	if not node.isActive then
		print(`Node is not active (depleted)`) -- DEBUG
		return
	end

	-- Get resource configuration
	local resourceConfig = GameConfig.resources[resourceType]

	-- Check inventory space
	local InventoryManager = _G.InventoryManager
	if InventoryManager then
		if not InventoryManager.HasSpace(player, resourceConfig.yieldPerMine) then
			RemoteEvents.Events.ShowNotification:FireClient(player, "Inventory full! Deposit resources at the warehouse.")
			return
		end
	else
		local currentCount = getInventoryCount(player)
		if currentCount >= GameConfig.player.inventorySize then
			RemoteEvents.Events.ShowNotification:FireClient(player, "Inventory full! Deposit resources at the warehouse.")
			return
		end
	end

	-- Mine the resource
	node.currentHits += 1

	-- TODO: Play mining sound effect when sound assets are ready
	-- TODO: Show mining particles when particle assets are ready

	-- Give resource to player via InventoryManager
	local InventoryManager = _G.InventoryManager
	if InventoryManager then
		local success = InventoryManager.AddItem(player, resourceType, resourceConfig.yieldPerMine)
		if success then
			print(`{player.Name} mined {resourceType}, added {resourceConfig.yieldPerMine} to inventory`) -- DEBUG
		else
			print(`Failed to add {resourceType} to {player.Name}'s inventory - might be full`) -- DEBUG
		end
	else
		warn("InventoryManager not available - falling back to local inventory")
		-- Fallback to local inventory
		local inventory = playerInventories[player]
		if not inventory then
			inventory = createEmptyInventory()
			playerInventories[player] = inventory
		end
		inventory[resourceType] += resourceConfig.yieldPerMine
		RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)
		print(`{player.Name} mined {resourceType}, now has {inventory[resourceType]}`) -- DEBUG
	end

	-- Check if node is depleted
	if node.currentHits >= node.maxHits then
		node.isActive = false
		hideResourceNode(node)
		print(`{resourceType} node depleted, will respawn in {resourceConfig.respawnTime} seconds`) -- DEBUG

		-- TODO: Stop mining particles when assets are ready

		-- Schedule respawn
		task.spawn(function()
			task.wait(resourceConfig.respawnTime)
			if node.part.Parent then -- Check if still exists
				node.currentHits = 0
				node.isActive = true
				showResourceNode(node)
				print(`{resourceType} node respawned`) -- DEBUG
				-- TODO: Restart mining particles when assets are ready
			end
		end)
	end
end

-- Register manually placed resource nodes (e.g., RockyHill)
local function registerManualNodes()
	-- Scan workspace for manually placed resource nodes
	for _, model in workspace:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute("ResourceType") then
			local resourceType = model:GetAttribute("ResourceType") :: ResourceType
			local config = GameConfig.resources[resourceType]

			if config and config.spawnMode == "manual" then
				local mainPart = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
				if mainPart then
					local node: ResourceNode = {
						resourceType = resourceType,
						currentHits = 0,
						maxHits = config.hitsRequired,
						isActive = true,
						part = mainPart,
					}

					-- Add ProximityPrompt for mining
					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = "MiningPrompt"
					prompt.ActionText = `Mine {resourceType}`
					prompt.ObjectText = resourceType
					prompt.KeyboardKeyCode = Enum.KeyCode.E
					prompt.MaxActivationDistance = 10

					-- Set hold duration based on config
					if GameConfig.gameplay.miningInteraction == "tap" then
						prompt.HoldDuration = 0
					else
						prompt.HoldDuration = GameConfig.gameplay.miningHoldDuration
					end

					prompt.RequiresLineOfSight = false
					prompt.Parent = mainPart

					-- Connect ProximityPrompt event
					prompt.Triggered:Connect(function(player)
						startAutoMining(player, node)
					end)

					print(`Created ProximityPrompt for manual {resourceType} node`) -- DEBUG

					resourceNodes[mainPart] = node
					print(`Registered manual node: {resourceType}`) -- DEBUG
				else
					warn(`Manual {resourceType} node has no BasePart`)
				end
			end
		end
	end
end

-- Connect ProximityPrompt.Triggered events for all nodes (called after spawning)
local function connectProximityPrompts()
	for part, node in resourceNodes do
		local prompt = part:FindFirstChild("MiningPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(player)
				startAutoMining(player, node)
			end)
			print(`Connected ProximityPrompt for {node.resourceType}`) -- DEBUG
		end
	end
end

-- Initialize the resource manager
local function initialize()
	-- Connect player events
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already in game
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Spawn resource nodes (only random spawns)
	spawnResourceNodes()

	-- Register manually placed nodes
	registerManualNodes()

	-- Connect ProximityPrompt events (if auto mode)
	connectProximityPrompts()

	print("ResourceManager initialized")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.ResourceManager = ResourceManager

return ResourceManager