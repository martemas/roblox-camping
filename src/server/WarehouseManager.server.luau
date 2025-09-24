--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local Utils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"))

type TeamResources = Types.TeamResources
type PlayerInventory = Types.PlayerInventory

local WarehouseManager = {}
local warehouse: Model? = nil
local teamResources: TeamResources = {
	Wood = 0,
	Stone = 0,
	Metal = 0,
}

-- Reference to InventoryManager (will be set after initialization)
local InventoryManager = nil


-- Update all players with current team resources
local function broadcastTeamResources()
	RemoteEvents.Events.UpdateTeamResources:FireAllClients(teamResources)
end

-- Handle player touching the warehouse
local function onWarehouseTouched(hit: BasePart, player: Player)
	local character = player.Character
	if not character or hit.Parent ~= character then
		return
	end

	-- Get player's inventory
	if not InventoryManager then
		warn("InventoryManager not initialized yet")
		return
	end

	local playerInventory = InventoryManager.GetInventory(player)

	if not playerInventory then
		return
	end

	-- Check if player has any resources to deposit
	local hasResources = false
	for _, amount in pairs(playerInventory) do
		if amount > 0 then
			hasResources = true
			break
		end
	end

	-- if not hasResources then
	-- 	RemoteEvents.Events.ShowNotification:FireClient(player, "No resources to deposit!")
	-- 	return
	-- end

	-- Transfer all resources from player to team storage
	if hasResources then

		local deposited = {}
		for resourceType, amount in pairs(playerInventory) do
			if amount > 0 then
				teamResources[resourceType] += amount
				deposited[resourceType] = amount
			end
		end

		-- Clear player inventory
		InventoryManager.ClearInventory(player)

		-- Create deposit summary message
		local depositedList = {}
		for resourceType, amount in pairs(deposited) do
			table.insert(depositedList, `{amount} {resourceType}`)
		end

		local message = "Deposited: " .. table.concat(depositedList, ", ")
		RemoteEvents.Events.ShowNotification:FireClient(player, message)
	
	end

	-- TODO: Play deposit sound effect when sound assets are ready
	-- local depositSound = ReplicatedStorage.Sounds:FindFirstChild("WarehouseDeposit")
	-- if depositSound then
	--     depositSound:Play()
	-- end

	-- Update all players with new team resources
	broadcastTeamResources()

	print(`{player.Name} deposited resources. New totals: Wood={teamResources.Wood}, Stone={teamResources.Stone}, Metal={teamResources.Metal}`)
end

-- Create or find the warehouse building
local function setupWarehouse()
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return
	end

	local warehouseTemplate = modelsFolder:FindFirstChild("Warehouse")
	if not warehouseTemplate then
		warn("Warehouse model not found in Models folder")
		return
	end

	-- Check if warehouse already exists in workspace
	local existingWarehouse = workspace:FindFirstChild("Warehouse")
	if existingWarehouse and existingWarehouse:IsA("Model") then
		warehouse = existingWarehouse
	else
		local newWarehouse = warehouseTemplate:Clone()
		newWarehouse.Parent = workspace
		warehouse = newWarehouse

		-- Position at map center (camp location) using ground detection
		local groundPosition = Vector3.new(0, 0, 0)
		-- local groundPosition = Utils.findGroundLevel(centerPosition)
		-- Raise warehouse slightly higher than default for visibility
		groundPosition = groundPosition + Vector3.new(0, 0, 0)

		print(`Positioning warehouse at: {groundPosition}`) -- DEBUG

		-- Type assertion since we know warehouse exists at this point
		local warehouseModel = warehouse :: Model

		if warehouseModel.PrimaryPart then
			warehouseModel:MoveTo(groundPosition)
			print(`Used MoveTo positioning`) -- DEBUG
		else
			-- Fallback: move the first BasePart found
			local firstPart = warehouseModel:FindFirstChildOfClass("BasePart")
			if firstPart then
				firstPart.CFrame = CFrame.new(groundPosition)
				print(`Used first BasePart positioning`) -- DEBUG
			else
				warn("No BasePart found in Warehouse model for positioning")
			end
		end
	end

	if not warehouse then
		warn("Failed to create or find warehouse")
		return
	end

	-- Find the main part for touch detection
	local mainPart = warehouse.PrimaryPart or warehouse:FindFirstChildOfClass("BasePart")
	if not mainPart then
		warn("No BasePart found in Warehouse model")
		return
	end

	-- Set up touch detection
	local connections: {[BasePart]: RBXScriptConnection} = {}

	local function onTouched(hit)
		local character = hit.Parent
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		onWarehouseTouched(hit, player)
	end

	-- Connect touch events to all parts of the warehouse
	for _, part in pairs(warehouse:GetDescendants()) do
		if part.Name == "Hitbox" and part:IsA("BasePart") then
			local basePart = part :: BasePart
			connections[basePart] = basePart.Touched:Connect(onTouched)
		end
	end

	print("Warehouse set up with touch detection")
end

-- Handle remote function requests for team resources
local function onGetTeamResources(player: Player): TeamResources
	return teamResources
end

-- Handle deposit requests via RemoteEvent
local function onDepositResources(player: Player)
	onWarehouseTouched(player.Character and player.Character:FindFirstChildOfClass("BasePart") or Instance.new("Part"), player)
end

-- Public API
function WarehouseManager.GetTeamResources(): TeamResources
	return teamResources
end

function WarehouseManager.HasResources(resourceType: Types.ResourceType, amount: number): boolean
	return teamResources[resourceType] >= amount
end

function WarehouseManager.ConsumeResources(resourceType: Types.ResourceType, amount: number): boolean
	if teamResources[resourceType] < amount then
		return false
	end

	teamResources[resourceType] -= amount
	broadcastTeamResources()
	return true
end

function WarehouseManager.AddResources(resourceType: Types.ResourceType, amount: number)
	teamResources[resourceType] += amount
	broadcastTeamResources()
end

function WarehouseManager.GetWarehouse(): Model?
	return warehouse
end

-- Initialize warehouse manager
local function initialize()
	-- Get reference to InventoryManager after it's loaded
	task.spawn(function()
		-- Wait for InventoryManager to be available in global scope
		while not _G.InventoryManager do
			task.wait(0.1)
		end
		InventoryManager = _G.InventoryManager
		print("WarehouseManager connected to InventoryManager")
	end)

	-- Set up the warehouse building
	setupWarehouse()

	-- Connect remote events
	RemoteEvents.Functions.GetTeamResources.OnServerInvoke = onGetTeamResources
	RemoteEvents.Events.DepositResources.OnServerEvent:Connect(onDepositResources)

	-- Send initial team resources to all players
	Players.PlayerAdded:Connect(function(player)
		-- Wait a bit for client to load
		task.wait(2)
		RemoteEvents.Events.UpdateTeamResources:FireClient(player, teamResources)
	end)

	-- Handle existing players
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(function()
			task.wait(2)
			RemoteEvents.Events.UpdateTeamResources:FireClient(player, teamResources)
		end)
	end

	print("WarehouseManager initialized")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.WarehouseManager = WarehouseManager

return WarehouseManager