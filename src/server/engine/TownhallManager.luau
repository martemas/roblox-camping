--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Engine = ServerScriptService:WaitForChild("Engine")

local Framework = require(Engine.Framework)
local Types = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))
local Utils = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("Utils"))

type TeamResources = Types.TeamResources
type PlayerInventory = Types.PlayerInventory

local TownhallManager = {}
local isInitialized = false
local townhall: Model? = nil
local teamResources: TeamResources = {
	Wood = 0,
	Stone = 0,
	Metal = 0,
	Gem = 0
}


-- Update all players with current team resources
local function broadcastTeamResources()
	RemoteEvents.Events.UpdateTeamResources:FireAllClients(teamResources)
end

-- Handle player touching the townhall
local function onTownhallTouched(hit: BasePart, player: Player)
	local character = player.Character
	if not character or hit.Parent ~= character then
		return
	end

	-- Get player's inventory
	local InventoryManager = Framework.get("InventoryManager")
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
local function setupTownhall()
	local modelsFolder = ServerStorage:FindFirstChild("Assets")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return
	end

	local buildingsFolder = modelsFolder:FindFirstChild("Buildings")
	if not buildingsFolder then
		warn("Buildings folder not found in Models folder")
		return
	end

	local townhallTemplate = buildingsFolder:FindFirstChild("Townhall-L1")
	if not townhallTemplate then
		warn("Townhall-L1 model not found in Models/Buildings folder")
		return
	end

	-- Check if townhall already exists in workspace
	local existingTownhall = workspace:FindFirstChild("Townhall-L1")
	if existingTownhall and existingTownhall:IsA("Model") then
		townhall = existingTownhall
	else
		local newTownhall = townhallTemplate:Clone()
		newTownhall.Parent = workspace
		townhall = newTownhall

		-- Position at map center (camp location) using ground detection
		local groundPosition = vector.create(0, 0, 0)
		-- local groundPosition = Utils.findGroundLevel(centerPosition)
		-- Raise townhall slightly higher than default for visibility
		groundPosition = groundPosition + vector.create(0, 0, 0)

		print(`Positioning townhall at: {groundPosition}`) -- DEBUG

		-- Type assertion since we know townhall exists at this point
		local townhallModel = townhall :: Model

		if townhallModel.PrimaryPart then
			townhallModel:MoveTo(groundPosition)
			print(`Used MoveTo positioning`) -- DEBUG
		else
			-- Fallback: move the first BasePart found
			local firstPart = townhallModel:FindFirstChildOfClass("BasePart")
			if firstPart then
				firstPart.CFrame = CFrame.new(groundPosition)
				print(`Used first BasePart positioning`) -- DEBUG
			else
				warn("No BasePart found in Townhall model for positioning")
			end
		end
	end

	if not townhall then
		warn("Failed to create or find townhall")
		return
	end

	-- Find the main part for touch detection
	local mainPart = townhall.PrimaryPart or townhall:FindFirstChildOfClass("BasePart")
	if not mainPart then
		warn("No BasePart found in Townhall model")
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

		onTownhallTouched(hit, player)
	end

	-- Connect touch events to all parts of the townhall
	for _, part in pairs(townhall:GetDescendants()) do
		if part.Name == "Hitbox" and part:IsA("BasePart") then
			local basePart = part :: BasePart
			connections[basePart] = basePart.Touched:Connect(onTouched)
		end
	end

	print("Townhall set up with touch detection")
end

-- Handle remote function requests for team resources
local function onGetTeamResources(player: Player): TeamResources
	return teamResources
end

-- Handle deposit requests via RemoteEvent
local function onDepositResources(player: Player)
	onTownhallTouched(player.Character and player.Character:FindFirstChildOfClass("BasePart") or Instance.new("Part"), player)
end

-- Public API
function TownhallManager.GetTeamResources(): TeamResources
	return teamResources
end

function TownhallManager.HasResources(resourceType: string, amount: number): boolean
	return teamResources[resourceType] >= amount
end

function TownhallManager.ConsumeResources(resourceType: string, amount: number): boolean
	if teamResources[resourceType] < amount then
		return false
	end

	teamResources[resourceType] -= amount
	broadcastTeamResources()
	return true
end

function TownhallManager.AddResources(resourceType: string, amount: number)
	teamResources[resourceType] += amount
	broadcastTeamResources()
end

function TownhallManager.GetTownhall(): Model?
	return townhall
end

-- Initialize townhall manager
function TownhallManager.initialize()
	if isInitialized then
		warn("[TownhallManager] Already initialized")
		return
	end

	isInitialized = true

	-- Set up the townhall building
	setupTownhall()

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

	print("[TownhallManager] ✓ Initialized")
end

return TownhallManager