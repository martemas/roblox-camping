--!strict

-- Shop Manager - Handles item purchases using team resources

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("core"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("core"):WaitForChild("RemoteEvents"))

local ShopManager = {}

-- Reference to TownhallManager (will be set after initialization)
local TownhallManager = nil

-- Check if team has enough resources for an item
local function canAffordItem(itemId: string): boolean
	local itemConfig = GameConfig.shop[itemId]
	if not itemConfig then
		return false
	end

	if not TownhallManager then
		warn("TownhallManager not available")
		return false
	end

	local teamResources = TownhallManager.GetTeamResources()

	-- Check each required resource
	for resourceType, requiredAmount in itemConfig.cost do
		if requiredAmount > 0 and (teamResources[resourceType] or 0) < requiredAmount then
			return false
		end
	end

	return true
end

-- Deduct resources from team storage
local function deductResources(itemId: string): boolean
	local itemConfig = GameConfig.shop[itemId]
	if not itemConfig or not TownhallManager then
		return false
	end

	-- Deduct each resource cost
	for resourceType, cost in itemConfig.cost do
		if cost > 0 then
			local success = TownhallManager.ConsumeResources(resourceType, cost)
			if not success then
				warn(`Failed to deduct {cost} {resourceType} for {itemId}`)
				return false
			end
		end
	end

	return true
end

-- Make all parts semi-transparent and non-collidable
local function makeTransparent(obj: Instance)
	if obj:IsA("BasePart") then
		obj.Transparency = 0.5
		obj.CanCollide = false
		obj.Material = Enum.Material.ForceField
		obj.Massless = true
		obj.BrickColor = BrickColor.new("Bright green") -- Green for valid placement
	end
	for _, child in obj:GetChildren() do
		makeTransparent(child)
	end
end

-- Create building tool for player
local function createBuildingTool(player: Player, itemId: string): Tool?
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return nil
	end

	local shopItemsFolder = modelsFolder:FindFirstChild("ShopItems")
	if not shopItemsFolder then
		warn("ShopItems folder not found in Models folder")
		return nil
	end

	local itemTemplate = shopItemsFolder:FindFirstChild(itemId)
	if not itemTemplate then
		warn(`Shop item template '{itemId}' not found in Models/ShopItems folder`)
		return nil
	end

	-- Create tool from the shop item model
	local tool = Instance.new("Tool")
	tool.Name = itemId
	tool.RequiresHandle = true
	tool.CanBeDropped = false -- Prevent dropping the building tool

	-- Create a visible handle for the tool - not necessary but helps with debugging
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = vector.create(0.1, 0.1, 0.1) -- Larger size so it's visible
	handle.Material = Enum.Material.Neon
	handle.BrickColor = BrickColor.new("Bright blue")
	handle.CanCollide = false
	handle.Shape = Enum.PartType.Block
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	-- Set tool properties
	local itemConfig = GameConfig.shop[itemId]
	tool.ToolTip = `{itemConfig.description or itemConfig.name} - Click to place`

	-- Add building tool attributes
	tool:SetAttribute("BuildingItem", itemId)
	tool:SetAttribute("IsBuilder", true)

	return tool
end

-- Handle purchase request
local function onPurchaseItem(player: Player, itemId: string)
	print(`{player.Name} attempting to purchase {itemId}`) -- DEBUG

	-- Validate item exists
	local itemConfig = GameConfig.shop[itemId]
	if not itemConfig then
		RemoteEvents.Events.ShowNotification:FireClient(player, `Invalid item: {itemId}`)
		return
	end

	-- Check if team can afford it
	if not canAffordItem(itemId) then
		RemoteEvents.Events.ShowNotification:FireClient(player, `Not enough resources for {itemConfig.name}`)
		return
	end

	-- Deduct resources
	if not deductResources(itemId) then
		RemoteEvents.Events.ShowNotification:FireClient(player, `Failed to purchase {itemConfig.name}`)
		return
	end

	-- Create building tool and add to player's backpack
	local tool = createBuildingTool(player, itemId)
	if tool then
		-- Connect building tool equip to start building mode
		tool.Equipped:Connect(function()
			-- Start building mode when tool is equipped
			RemoteEvents.Events.StartBuildingMode:FireClient(player, itemId)
			-- Hide the tool handle but keep the tool active
			-- local handle = tool:FindFirstChild("Handle")
			-- if handle then
			-- 	handle.Transparency = 1
			-- 	handle.CanCollide = false
			-- end
		end)

		-- Connect building tool activation for placement
		tool.Activated:Connect(function()
			-- Signal the client to place the building
			RemoteEvents.Events.ActivateBuildingTool:FireClient(player, itemId)
		end)

		tool.Parent = player:FindFirstChild("Backpack")
		RemoteEvents.Events.ShowNotification:FireClient(player, `Purchased {itemConfig.name}! Equip to start building mode.`)
		print(`{player.Name} successfully purchased {itemId}`) -- DEBUG
	else
		RemoteEvents.Events.ShowNotification:FireClient(player, `Failed to create {itemConfig.name} tool`)
		-- Refund resources if tool creation failed
		-- TODO: Implement refund logic if needed
	end
end

-- Send shop data to client
local function onOpenShop(player: Player)
	-- Get current team resources
	local teamResources = TownhallManager and TownhallManager.GetTeamResources() or {Wood = 0, Stone = 0, Metal = 0}

	-- Send shop data and current resources to client
	RemoteEvents.Events.UpdateShopData:FireClient(player, GameConfig.shop, teamResources)

	print(`Sent shop data to {player.Name}`) -- DEBUG
end

-- Public API
function ShopManager.GetShopData()
	return GameConfig.shop
end

function ShopManager.CanAfford(itemId: string): boolean
	return canAffordItem(itemId)
end

-- Initialize shop manager
local function initialize()
	-- Get reference to TownhallManager after it's loaded
	task.spawn(function()
		-- Wait for TownhallManager to be available in global scope
		while not _G.TownhallManager do
			task.wait(0.1)
		end
		TownhallManager = _G.TownhallManager
		print("ShopManager connected to TownhallManager")
	end)

	-- Connect remote events
	RemoteEvents.Events.OpenShop.OnServerEvent:Connect(onOpenShop)
	RemoteEvents.Events.PurchaseItem.OnServerEvent:Connect(onPurchaseItem)

	print("ShopManager initialized")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.ShopManager = ShopManager

return ShopManager