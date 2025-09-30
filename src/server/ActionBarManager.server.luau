--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local WeaponDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))

-- Player data tracking
local playerCooldowns: {[Player]: {[number]: number}} = {} -- Cooldown end times per slot
local playerLastActivation: {[Player]: number} = {} -- Anti-spam tracking

-- Configuration
local ACTION_SLOTS = 4 -- Configurable number of action bar slots
local MIN_ACTIVATION_INTERVAL = 0.1 -- Minimum time between any activations (anti-spam)
local COOLDOWN_UPDATE_INTERVAL = 0.1 -- How often to send cooldown updates to client

-- Get tool in specific slot for player
local function getPlayerToolInSlot(player: Player, slotNumber: number): Tool?
	local character = player.Character
	if not character then return nil end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return nil end

	-- Get all tools (equipped + in backpack)
	local allTools = {}
	for _, tool in pairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			table.insert(allTools, tool)
		end
	end
	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			table.insert(allTools, tool)
		end
	end

	-- Return tool in specified slot (simplified mapping)
	return allTools[slotNumber]
end

-- Check if a tool is currently equipped on the character
local function isToolEquipped(player: Player, tool: Tool): boolean
	local character = player.Character
	if not character then return false end

	-- Check if the tool is in the character (equipped)
	return tool.Parent == character
end

-- Equip a tool from backpack to character
local function equipTool(player: Player, tool: Tool): boolean
	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return false end

	-- Only equip if tool is in backpack
	if tool.Parent == player:FindFirstChild("Backpack") then
		humanoid:EquipTool(tool)
		print(`Equipped tool {tool.Name} for {player.Name}`)
		return true
	end

	return false
end

-- Get tool cooldown time
local function getToolCooldown(tool: Tool): number
	-- Check if tool has weapon definition with cooldown
	local weapon = WeaponDefinitions.getWeapon(tool.Name)
	if weapon and weapon.cooldown then
		return weapon.cooldown
	end

	-- Default cooldowns based on tool type/name
	local toolName = tool.Name:lower()
	if toolName:find("sword") or toolName:find("axe") then
		return 1.2 -- Melee weapons
	elseif toolName:find("spell") or toolName:find("magic") then
		return 3.0 -- Magic spells
	elseif toolName:find("potion") or toolName:find("item") then
		return 0.5 -- Consumable items
	end

	return 1.0 -- Default cooldown
end

-- Check if player can activate a tool
local function canActivateTool(player: Player, slotNumber: number): boolean
	-- Check slot bounds
	if slotNumber < 1 or slotNumber > ACTION_SLOTS then
		return false
	end

	-- Check anti-spam
	local lastActivation = playerLastActivation[player] or 0
	if tick() - lastActivation < MIN_ACTIVATION_INTERVAL then
		return false
	end

	-- Check tool-specific cooldown
	local cooldowns = playerCooldowns[player]
	if cooldowns then
		local cooldownEnd = cooldowns[slotNumber]
		if cooldownEnd and tick() < cooldownEnd then
			return false
		end
	end

	-- Check if player has a tool in that slot
	local tool = getPlayerToolInSlot(player, slotNumber)
	if not tool then
		return false
	end

	return true
end

-- Execute tool activation (returns true if action was performed, false if only equipped)
local function executeTool(player: Player, slotNumber: number, tool: Tool): boolean
	print(`Executing tool {tool.Name} for {player.Name} in slot {slotNumber}`)

	-- Check if tool is equipped, if not equip it first
	if not isToolEquipped(player, tool) then
		-- Tool not equipped, equip it first
		if equipTool(player, tool) then
			print(`Tool {tool.Name} equipped for {player.Name} in slot {slotNumber}`)
			return false -- Only equipped, no action performed
		else
			warn(`Failed to equip tool {tool.Name} for {player.Name}`)
			return false
		end
	end

	-- Tool is equipped, perform the action
	print(`Performing action with {tool.Name} for {player.Name}`)

	-- Activate the tool (this triggers the default Roblox tool behavior including animations)
	if tool:FindFirstChild("LocalScript") or tool:FindFirstChild("Script") then
		-- Tool has scripts, fire the Activated event to trigger its functionality
		if tool.Activated then
			tool.Activated:Fire()
			print(`Fired Activated event for {tool.Name}`)
		end
	end

	-- Also call Activate method if it exists (some tools use this)
	local success, error = pcall(function()
		if tool.Activate then
			tool:Activate()
			print(`Called Activate method for {tool.Name}`)
		end
	end)

	if not success then
		print(`Tool activation method failed for {tool.Name}: {error}`)
	end

	-- Handle different tool types for additional functionality
	if slotNumber == 1 then
		-- Slot 1: Primary weapon - integrate with combat system
		if _G.PlayerCombat then
			-- Trigger manual attack with primary weapon
			print(`Manual attack with primary weapon: {tool.Name}`)
			-- TODO: Integrate with existing combat system
		end
	else
		-- Slots 2-4: Special tools (magic, items, etc.)
		if tool.Name:lower():find("spell") or tool.Name:lower():find("magic") then
			-- Magic spell
			print(`Casting spell: {tool.Name}`)
			-- TODO: Implement magic system
		elseif tool.Name:lower():find("potion") or tool.Name:lower():find("item") then
			-- Consumable item
			print(`Using item: {tool.Name}`)
			-- TODO: Implement item usage
		else
			-- Other tools
			print(`Activating tool: {tool.Name}`)
			-- TODO: Handle other tool types
		end
	end

	return true -- Action was performed
end

-- Set cooldown for tool slot
local function setCooldown(player: Player, slotNumber: number, cooldownTime: number)
	if not playerCooldowns[player] then
		playerCooldowns[player] = {}
	end

	playerCooldowns[player][slotNumber] = tick() + cooldownTime
	playerLastActivation[player] = tick()

	print(`Set cooldown for {player.Name} slot {slotNumber}: {cooldownTime}s`)
end

-- Handle tool activation request from client
local function onActivateTool(player: Player, slotNumber: number)
	print(`Tool activation request from {player.Name} for slot {slotNumber}`)

	-- Validate activation
	if not canActivateTool(player, slotNumber) then
		warn(`Tool activation denied for {player.Name} slot {slotNumber}`)
		return
	end

	-- Get the tool
	local tool = getPlayerToolInSlot(player, slotNumber)
	if not tool then
		warn(`No tool found in slot {slotNumber} for {player.Name}`)
		return
	end

	-- Execute the tool (returns true if action was performed, false if only equipped)
	local actionPerformed = executeTool(player, slotNumber, tool)

	-- Only set cooldown if an action was performed (not just equipping)
	if actionPerformed then
		local cooldownTime = getToolCooldown(tool)
		setCooldown(player, slotNumber, cooldownTime)
	end
end

-- Send cooldown updates to client
local function updatePlayerCooldowns(player: Player)
	local cooldowns = playerCooldowns[player]
	if not cooldowns then return end

	-- Prepare cooldown data for client
	local cooldownData = {}
	local currentTime = tick()

	for slotNumber, cooldownEnd in pairs(cooldowns) do
		if currentTime < cooldownEnd then
			cooldownData[slotNumber] = cooldownEnd
		else
			-- Clean up expired cooldowns
			cooldowns[slotNumber] = nil
		end
	end

	-- Send to client if there are active cooldowns
	if next(cooldownData) then
		RemoteEvents.Events.UpdateToolCooldowns:FireClient(player, cooldownData)
	end
end

-- Initialize player data
local function initializePlayer(player: Player)
	playerCooldowns[player] = {}
	playerLastActivation[player] = 0
	print(`ActionBarManager: Initialized for {player.Name}`)
end

-- Clean up player data
local function cleanupPlayer(player: Player)
	playerCooldowns[player] = nil
	playerLastActivation[player] = nil
end

-- Main update loop
local function updateCooldowns()
	for player, _ in pairs(playerCooldowns) do
		updatePlayerCooldowns(player)
	end
end

-- Initialize the action bar manager
local function initialize()
	-- Connect remote events
	RemoteEvents.Events.ActivateTool.OnServerEvent:Connect(onActivateTool)

	-- Initialize existing players
	for _, player in pairs(Players:GetPlayers()) do
		initializePlayer(player)
	end

	-- Handle new players
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	-- Start cooldown update loop
	task.spawn(function()
		while true do
			updateCooldowns()
			task.wait(COOLDOWN_UPDATE_INTERVAL)
		end
	end)

	print("ActionBarManager initialized")
end

-- Public API for other systems
local ActionBarManager = {
	canActivateTool = canActivateTool,
	getPlayerToolInSlot = getPlayerToolInSlot,
	setCooldown = setCooldown,
}

-- Start the system
initialize()

-- Export to global for other systems
_G.ActionBarManager = ActionBarManager

return ActionBarManager