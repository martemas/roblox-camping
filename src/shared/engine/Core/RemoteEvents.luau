--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvents folder if it doesn't exist
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
	remoteEventsFolder = Instance.new("Folder")
	remoteEventsFolder.Name = "RemoteEvents"
	remoteEventsFolder.Parent = ReplicatedStorage
end

-- Create RemoteFunctions folder if it doesn't exist
local remoteFunctionsFolder = ReplicatedStorage:FindFirstChild("RemoteFunctions")
if not remoteFunctionsFolder then
	remoteFunctionsFolder = Instance.new("Folder")
	remoteFunctionsFolder.Name = "RemoteFunctions"
	remoteFunctionsFolder.Parent = ReplicatedStorage
end

-- Helper function to create RemoteEvent
local function createRemoteEvent(name: string): RemoteEvent
	local existing = remoteEventsFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = remoteEventsFolder
	return remoteEvent
end

-- Helper function to create RemoteFunction
local function createRemoteFunction(name: string): RemoteFunction
	local existing = remoteFunctionsFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end

	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = remoteFunctionsFolder
	return remoteFunction
end

-- Export RemoteEvents
local RemoteEvents = {
	-- Resource Management
	MineResource = createRemoteEvent("MineResource"),
	UpdateInventory = createRemoteEvent("UpdateInventory"),
	DepositResources = createRemoteEvent("DepositResources"),
	UpdateTeamResources = createRemoteEvent("UpdateTeamResources"),

	-- Tool Management
	EquipTool = createRemoteEvent("EquipTool"),
	SwingTool = createRemoteEvent("SwingTool"),
	SwingToolWithTarget = createRemoteEvent("SwingToolWithTarget"), -- Tool swing with optional click target

	-- Phase Management
	PhaseChanged = createRemoteEvent("PhaseChanged"),
	UpdatePhaseTimer = createRemoteEvent("UpdatePhaseTimer"),

	-- Combat
	TakeDamage = createRemoteEvent("TakeDamage"),
	EntityDied = createRemoteEvent("EntityDied"),

	-- UI Updates
	UpdateHealthBar = createRemoteEvent("UpdateHealthBar"),
	UpdateStamina = createRemoteEvent("UpdateStamina"),
	ShowNotification = createRemoteEvent("ShowNotification"),

	-- Shop System
	OpenShop = createRemoteEvent("OpenShop"),
	PurchaseItem = createRemoteEvent("PurchaseItem"),
	UpdateShopData = createRemoteEvent("UpdateShopData"),

	-- Building System
	StartBuildingMode = createRemoteEvent("StartBuildingMode"),
	ActivateBuildingTool = createRemoteEvent("ActivateBuildingTool"),
	PlaceBuilding = createRemoteEvent("PlaceBuilding"),
	CancelBuildingMode = createRemoteEvent("CancelBuildingMode"),

	-- Entity Targeting
	SelectTarget = createRemoteEvent("SelectTarget"),
	DeselectTarget = createRemoteEvent("DeselectTarget"),
	RequestClosestTarget = createRemoteEvent("RequestClosestTarget"),
	TargetUpdated = createRemoteEvent("TargetUpdated"), -- For real-time health updates

	-- Stats & Leveling System
	RequestStatIncrease = createRemoteEvent("RequestStatIncrease"),  -- Client → Server: Request stat allocation
	LevelUpNotification = createRemoteEvent("LevelUpNotification"),  -- Server → Client: Notify level-up
	XPUpdated = createRemoteEvent("XPUpdated"),                      -- Server → Client: Update XP bar
	StatsUpdated = createRemoteEvent("StatsUpdated"),                -- Server → Client: Update stats panel

	-- Mining System (Auto Mode)
	MiningStarted = createRemoteEvent("MiningStarted"),              -- Server → Client: Mining started
	MiningCancelled = createRemoteEvent("MiningCancelled"),          -- Server → Client: Mining cancelled
	MiningCompleted = createRemoteEvent("MiningCompleted"),          -- Server → Client: Mining completed
}

-- Export RemoteFunctions
local RemoteFunctions = {
	-- Data requests
	GetPlayerData = createRemoteFunction("GetPlayerData"),
	GetTeamResources = createRemoteFunction("GetTeamResources"),
	GetXPForNextLevel = createRemoteFunction("GetXPForNextLevel"),
	GetDerivedStats = createRemoteFunction("GetDerivedStats"),
	GetWeaponInfo = createRemoteFunction("GetWeaponInfo"), -- Client → Server: Get weapon display info
	GetInventorySize = createRemoteFunction("GetInventorySize"), -- Client → Server: Get player inventory size
}

return {
	Events = RemoteEvents,
	Functions = RemoteFunctions,
}