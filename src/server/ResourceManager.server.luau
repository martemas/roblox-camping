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

-- Check if player has the required tool equipped
local function hasRequiredTool(player: Player, resourceType: ResourceType): boolean
	local character = player.Character
	if not character then
		print(`{player.Name} has no character`) -- DEBUG
		return false
	end

	local requiredTool = GameConfig.resources[resourceType].requiredTool
	local tool = character:FindFirstChild(requiredTool)

	print(`Looking for {requiredTool} in {player.Name}'s character...`) -- DEBUG
	if tool then
		print(`Found {requiredTool}, checking if it's a Tool...`) -- DEBUG
		local isValidTool = tool:IsA("Tool")
		print(`{requiredTool} is valid tool: {isValidTool}`) -- DEBUG
		return isValidTool
	else
		print(`{requiredTool} not found in character`) -- DEBUG
		-- Also check backpack
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			local backpackTool = backpack:FindFirstChild(requiredTool)
			if backpackTool and backpackTool:IsA("Tool") then
				print(`{requiredTool} found in backpack but not equipped`) -- DEBUG
			end
		end
		return false
	end
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

-- Spawn resource nodes around the map
local function spawnResourceNodes()
	local mapSize = GameConfig.map.size
	local spawnRadius = GameConfig.map.resourceSpawnRadius
	local centerPosition = vector.create(0, 0, 0) -- Map center

	for resourceType, config in pairs(GameConfig.resources) do
		for i = 1, config.nodesCount do
			-- Generate random position with ground detection
			local position = Utils.getRandomGroundPosition(centerPosition, 50, spawnRadius)
			local node = createResourceNode(resourceType :: ResourceType, position)

			if not node then
				warn(`Failed to create {resourceType} node {i}`)
			end
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
		if not InventoryManager.HasSpace(player, resourceConfig.yieldPerHit) then
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
		local success = InventoryManager.AddItem(player, resourceType, resourceConfig.yieldPerHit)
		if success then
			print(`{player.Name} mined {resourceType}, added {resourceConfig.yieldPerHit} to inventory`) -- DEBUG
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
		inventory[resourceType] += resourceConfig.yieldPerHit
		RemoteEvents.Events.UpdateInventory:FireClient(player, inventory)
		print(`{player.Name} mined {resourceType}, now has {inventory[resourceType]}`) -- DEBUG
	end

	-- Check if node is depleted
	if node.currentHits >= node.maxHits then
		node.isActive = false
		node.part.Transparency = 0.7 -- Visual feedback for depletion
		print(`{resourceType} node depleted, will respawn in {resourceConfig.respawnTime} seconds`) -- DEBUG

		-- TODO: Stop mining particles when assets are ready

		-- Schedule respawn
		task.spawn(function()
			task.wait(resourceConfig.respawnTime)
			if node.part.Parent then -- Check if still exists
				node.currentHits = 0
				node.isActive = true
				node.part.Transparency = 0
				print(`{resourceType} node respawned`) -- DEBUG
				-- TODO: Restart mining particles when assets are ready
			end
		end)
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

	-- Spawn resource nodes
	spawnResourceNodes()

	print("ResourceManager initialized")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.ResourceManager = ResourceManager

return ResourceManager