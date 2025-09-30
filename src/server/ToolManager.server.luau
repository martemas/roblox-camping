--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
-- Removed unused Debris import

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local Utils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"))

type ToolType = Types.ToolType

local ToolManager = {}
local playerCooldowns: {[Player]: {[string]: number}} = {}

-- Track hitting state per player per swing
local swingHits: {[Player]: {[number]: boolean}} = {}

-- Pre-created animation object (create once, reuse many times)
local swingAnimation = Instance.new("Animation")
swingAnimation.AnimationId = "rbxassetid://117996568228908"

-- Play tool sound effect
local function playToolSound(player: Player, toolType: ToolType, soundType: string?, resourceType: string?)
	local character = player.Character
	if not character then return end

	local tool = character:FindFirstChild(toolType)
	if not tool or not tool:IsA("Tool") then return end

	local soundName: string
	if soundType == "resource" and resourceType then
		-- Resource-specific mining sounds
		if toolType == "Axe" and resourceType == "Wood" then
			-- Randomly select between Wood1 and Wood2
			soundName = math.random() > 0.5 and "Wood1" or "Wood2"
		elseif toolType == "Pickaxe" and resourceType == "Stone" then
			-- Randomly select between Stone1 and Stone2
			soundName = math.random() > 0.5 and "Stone1" or "Stone2"
		elseif toolType == "Pickaxe" and resourceType == "Metal" then
			soundName = "Metal"
		else
			-- Fallback to swing sound
			soundName = "Swing"
		end
	else
		-- Default swing sound for attacks/other actions
		soundName = "Swing"
	end

	local sound = tool:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		sound:Play()
		print(`Playing {toolType}.{soundName} sound`) -- DEBUG
	else
		print(`Sound {toolType}.{soundName} not found`) -- DEBUG
	end
end

-- Check if player is on cooldown for a specific action
local function isOnCooldown(player: Player, action: string): boolean
	local cooldowns = playerCooldowns[player]
	if not cooldowns then
		return false
	end

	local lastTime = cooldowns[action]
	if not lastTime then
		return false
	end

	return tick() - lastTime < 1.0 -- 1 second base cooldown
end

-- Set cooldown for player action
local function setCooldown(player: Player, action: string, duration: number?)
	local cooldowns = playerCooldowns[player]
	if not cooldowns then
		cooldowns = {}
		playerCooldowns[player] = cooldowns
	end

	cooldowns[action] = tick()
end


-- Find entity model by traversing up the parent hierarchy
local function findEntity(startPart: BasePart): (Model?, string?, string?)
	local current = startPart.Parent
	while current do
		if current:IsA("Model") then
			-- Check if this model has entity attributes
			local entityType = current:GetAttribute("EntityType")
			local entityCategory = current:GetAttribute("EntityCategory")
			if entityType and entityCategory then
				return current, tostring(entityType), tostring(entityCategory)
			end
		end
		current = current.Parent
		-- Stop at workspace to avoid infinite loop
		if current == workspace then
			break
		end
	end
	return nil, nil, nil
end

-- Enable hit detection for tool swing
local function enableToolHitDetection(player: Player, toolType: ToolType)
	-- Create unique swing ID for this player's swing
	local swingId = tick()

	-- Initialize player's swing tracking if needed
	if not swingHits[player] then
		swingHits[player] = {}
	end
	swingHits[player][swingId] = false
	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChild(toolType)
	if not tool or not tool:IsA("Tool") then
		return
	end

	local handle = tool:FindFirstChild("Hitbox")
	if not handle or not handle:IsA("BasePart") then
		warn(`Tool {toolType} has no Handle or Handle is not a BasePart`)
		return
	end

	print(`Enabling hit detection for {toolType}`) -- DEBUG

	-- Create temporary hit detection
	local connection
	connection = handle.Touched:Connect(function(hit)
		print(`Tool handle touched: {hit.Name} (parent: {hit.Parent and hit.Parent.Name or "nil"})`) -- DEBUG

		-- Check if this swing has already registered a hit
		if swingHits[player][swingId] then
			print('Swing already registered a hit...')
			return
		else
			swingHits[player][swingId] = true
		end

		-- First try to find entity model by traversing up the hierarchy
		local entityModel, entityType, entityCategory = findEntity(hit)

		if entityModel and entityType and entityCategory then
			-- Handle entity combat using generic system
			print(`Tool hit {entityType} ({entityCategory})!`) -- DEBUG

			-- Get entity configuration
			local entityConfig = GameConfig.entities[entityType]
			if not entityConfig then
				print(`No configuration found for entity: {entityType}`) -- DEBUG
				return
			end

			-- Check if this entity can take damage
			if not entityConfig.canTakeDamage then
				print(`{entityType} cannot be damaged`) -- DEBUG
				RemoteEvents.Events.ShowNotification:FireClient(player, `{entityType} cannot be damaged`)
				return
			end

			-- Check if this tool can damage this entity
			if not table.find(entityConfig.damageableBy, toolType) then
				print(`{toolType} cannot damage {entityType}`) -- DEBUG
				RemoteEvents.Events.ShowNotification:FireClient(player, `{toolType} cannot damage {entityType}`)
				return
			end

			-- Play attack swing sound
			playToolSound(player, toolType, "attack")

			local toolConfig = GameConfig.tools[toolType]
			local damage = toolConfig and toolConfig.damage or 0
			print(`Dealing {damage} damage to {entityType} with {toolType}`) -- DEBUG

			-- Route to appropriate manager
			local managerName = entityConfig.manager

			-- Handle entity damage through centralized EntityController for wildlife/enemies
			if entityCategory == "wildlife" or entityCategory == "enemy" then
				local EntityController = _G.EntityController
				if EntityController and EntityController.handleDamage then
					print(`Calling EntityController.handleDamage for {entityType}`) -- DEBUG
					EntityController.handleDamage(entityModel, damage, toolType, player)
				else
					print(`EntityController not available or missing handleDamage method`) -- DEBUG
				end
			else
				-- Handle other entities (resources, buildings) through their specific managers
				local manager = _G[managerName]
				if manager and manager.HandleToolHit then
					print(`Calling {managerName}.HandleToolHit`) -- DEBUG

					-- For resources, pass the resourceType; for others, pass the entityType
					if entityCategory == "resource" and entityConfig.resourceType then
						manager.HandleToolHit(player, hit, entityConfig.resourceType)
					else
						manager.HandleToolHit(player, entityModel, damage, entityType)
					end
				else
					print(`{managerName} not available in _G or missing HandleToolHit`) -- DEBUG
				end
			end
		else
			print(`{hit.Name} is not recognized as an entity`) -- DEBUG
		end
	end)

	-- Disable hit detection after swing duration and clean up tracking
	task.spawn(function()
		task.wait(0.5) -- Hit detection window
		connection:Disconnect()

		-- If no hit was registered, play default swing sound (swinging at air)
		if swingHits[player] and not swingHits[player][swingId] then
			playToolSound(player, toolType, "swing")
		end

		-- Clean up swing tracking
		if swingHits[player] then
			swingHits[player][swingId] = nil

			-- Clean up empty player entries
			local hasEntries = false
			for _ in pairs(swingHits[player]) do
				hasEntries = true
				break
			end
			if not hasEntries then
				swingHits[player] = nil
			end
		end

		print(`Hit detection disabled for {toolType}`) -- DEBUG
	end)
end

-- Building tools are now handled by ShopManager via tool.Equipped
-- This function is no longer used
local function onBuildingToolActivated(player: Player, tool: Tool)
	-- Building mode is now started when tool is equipped, not activated
	warn("onBuildingToolActivated should not be called - building tools start on equip")
end

-- Handle building placement from client
local function onPlaceBuilding(player: Player, buildingItemId: string, placementCFrame: CFrame)
	local position = placementCFrame.Position
	print(`{player.Name} placing {buildingItemId} at {position}`) -- DEBUG

	-- Validate the building item exists
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		RemoteEvents.Events.ShowNotification:FireClient(player, "Models folder not found")
		return
	end

	local shopItemsFolder = modelsFolder:FindFirstChild("ShopItems")
	if not shopItemsFolder then
		RemoteEvents.Events.ShowNotification:FireClient(player, "ShopItems folder not found")
		return
	end

	local itemTemplate = shopItemsFolder:FindFirstChild(buildingItemId)
	if not itemTemplate then
		RemoteEvents.Events.ShowNotification:FireClient(player, `{buildingItemId} template not found`)
		return
	end

	-- Use ground detection to ensure proper placement
	local groundPosition = Utils.findGroundLevel(vector.create(position.X, 0, position.Z))
	
	-- Create final placement CFrame with ground position but preserve rotation
	local finalCFrame = placementCFrame - placementCFrame.Position + groundPosition

	-- Clone and place the building
	local building = itemTemplate:Clone()
	building.Parent = workspace
	building.Name = buildingItemId .. "_" .. tostring(tick()) -- Unique name

	-- Calculate height offset to position bottom of building on ground
	local heightOffset = 0
	if building:IsA("Model") then
		if building.PrimaryPart then
			heightOffset = building.PrimaryPart.Size.Y / 2
		else
			local firstPart = building:FindFirstChildOfClass("BasePart")
			if firstPart then
				heightOffset = firstPart.Size.Y / 2
			end
		end
	elseif building:IsA("BasePart") then
		heightOffset = building.Size.Y / 2
	end

	-- Adjust final CFrame to position building properly on ground
	local adjustedCFrame = finalCFrame + vector.create(0, heightOffset, 0)

	-- Position and rotate the building
	if building:IsA("Model") then
		if building.PrimaryPart then
			building.PrimaryPart.CFrame = adjustedCFrame
		else
			-- Use MoveTo for Models without PrimaryPart, then rotate first part
			building:MoveTo(groundPosition + vector.create(0, heightOffset, 0))
			local firstPart = building:FindFirstChildOfClass("BasePart")
			if firstPart then
				firstPart.CFrame = adjustedCFrame
			end
		end
	elseif building:IsA("BasePart") then
		-- Handle single part case - include rotation and height adjustment
		building.CFrame = adjustedCFrame
	else
		-- Fallback: find first BasePart and position/rotate it
		local firstPart = building:FindFirstChildOfClass("BasePart")
		if firstPart then
			firstPart.CFrame = adjustedCFrame
		end
	end

	print(`Placed {buildingItemId} at {groundPosition}`) -- DEBUG
	RemoteEvents.Events.ShowNotification:FireClient(player, `Placed {buildingItemId}!`)
end

-- Handle tool swing animation and effects
local function onToolSwing(player: Player, toolType: ToolType)
	print('Swinging tool...')
	if isOnCooldown(player, "swing") then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local toolConfig = GameConfig.tools[toolType]
	if not toolConfig then
		return
	end

	-- Set swing cooldown
	setCooldown(player, "swing", toolConfig.swingCooldown)

	-- Enable tool hit detection for a short time
	enableToolHitDetection(player, toolType)

	-- Play swing animation
	-- Note: Specific sounds are played in the hit detection based on what is hit
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local success, animationTrack = pcall(function()
			local track = animator:LoadAnimation(swingAnimation)
			track.Priority = Enum.AnimationPriority.Action4
			return track
		end)

		if success and animationTrack then
			animationTrack:Play()
			print(`Playing swing animation for {player.Name}`) -- DEBUG
		else
			warn(`Failed to load swing animation for {player.Name}`)
		end
	else
		warn(`No Animator found for {player.Name}`)
	end

	-- TODO: Play swing sound effect when sound assets are ready
	-- local swingSound = ReplicatedStorage.Sounds:FindFirstChild(toolType .. "Swing")
	-- if swingSound then
	--     swingSound:Play()
	-- end

	print(`{player.Name} swung {toolType}`)
end

-- Create a tool for the player
local function createTool(toolType: ToolType): Tool?
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return nil
	end

	local toolTemplate = modelsFolder:FindFirstChild(toolType)
	if not toolTemplate or not toolTemplate:IsA("Tool") then
		warn(`Tool template '{toolType}' not found in Models folder`)
		return nil
	end

	local tool = toolTemplate:Clone()

	-- TODO: Add tool icons when UI assets are ready
	-- tool.TextureId = "rbxasset://path/to/icon"

	return tool
end

-- Give starting tools to player
local function giveStartingTools(player: Player)
	local backpack = player:WaitForChild("Backpack")

	-- Clear existing tools
	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end

	-- Give starting tools
	for _, toolName in pairs(GameConfig.player.startingTools) do
		local tool = createTool(toolName :: ToolType)
		if tool then
			-- Connect tool activation to swing
			tool.Activated:Connect(function()
				onToolSwing(player, toolName :: ToolType)
			end)

			tool.Parent = backpack
			print(`Gave {toolName} to {player.Name}`)
		else
			warn(`Failed to create tool: {toolName}`)
		end
	end
end

-- Handle tool equipping
local function onToolEquip(player: Player, toolType: ToolType)
	local character = player.Character
	if not character then
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	-- Find and equip the tool
	local tool = backpack:FindFirstChild(toolType)
	if tool and tool:IsA("Tool") then
		tool.Parent = character
		print(`{player.Name} equipped {toolType}`)
	end
end

-- Get the currently equipped tool type
local function getEquippedTool(player: Player): ToolType?
	local character = player.Character
	if not character then
		return nil
	end

	for _, toolType in pairs(GameConfig.player.startingTools) do
		if character:FindFirstChild(toolType) then
			return toolType :: ToolType
		end
	end

	return nil
end

-- Auto-equip appropriate tool for resource type
local function autoEquipTool(player: Player, resourceType: Types.ResourceType)
	local requiredTool = GameConfig.resources[resourceType].requiredTool
	local currentTool = getEquippedTool(player)

	if currentTool ~= requiredTool then
		onToolEquip(player, requiredTool :: ToolType)
	end
end

-- Handle player joining
local function onPlayerAdded(player: Player)
	playerCooldowns[player] = {}

	-- Give tools when character spawns
	player.CharacterAdded:Connect(function()
		-- Wait a bit for character to fully load
		task.wait(1)
		giveStartingTools(player)
	end)

	-- Handle existing character
	if player.Character then
		giveStartingTools(player)
	end
end

-- Handle player leaving
local function onPlayerRemoving(player: Player)
	playerCooldowns[player] = nil
	swingHits[player] = nil
end

-- Public API
function ToolManager.GetEquippedTool(player: Player): ToolType?
	return getEquippedTool(player)
end

function ToolManager.HasTool(player: Player, toolType: ToolType): boolean
	local character = player.Character
	if not character then
		return false
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end

	return character:FindFirstChild(toolType) ~= nil or backpack:FindFirstChild(toolType) ~= nil
end

function ToolManager.EquipTool(player: Player, toolType: ToolType)
	onToolEquip(player, toolType)
end

function ToolManager.AutoEquipForResource(player: Player, resourceType: Types.ResourceType)
	autoEquipTool(player, resourceType)
end

function ToolManager.GetToolDamage(toolType: ToolType): number
	local config = GameConfig.tools[toolType]
	return config and config.damage or 0
end

function ToolManager.IsOnCooldown(player: Player): boolean
	return isOnCooldown(player, "swing")
end

function ToolManager.HandleBuildingToolActivation(player: Player, tool: Tool)
	onBuildingToolActivated(player, tool)
end

-- Initialize the tool manager
local function initialize()
	-- Connect player events
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already in game
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Connect remote events
	RemoteEvents.Events.EquipTool.OnServerEvent:Connect(onToolEquip)
	RemoteEvents.Events.SwingTool.OnServerEvent:Connect(onToolSwing)
	RemoteEvents.Events.PlaceBuilding.OnServerEvent:Connect(onPlaceBuilding)

	print("ToolManager initialized")
end

-- Start the system
initialize()

-- Export to global _G for other servers to access
_G.ToolManager = ToolManager

return ToolManager