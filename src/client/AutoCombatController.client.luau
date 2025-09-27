--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

local AutoCombatController = {
	isActive = false,
	currentTool = nil :: Tool?,
	targetingSystem = nil,
	updateConnection = nil :: RBXScriptConnection?,
	lastAttackTime = 0,
}

-- Reference to TargetingSystem (will be set after initialization)
local TargetingSystem = nil

-- Check if tool is compatible with current target
local function isToolCompatibleWithTarget(tool: Tool, target: Model): boolean
	local toolName = tool.Name
	local toolConfig = GameConfig.tools[toolName]

	if not toolConfig or not toolConfig.autoTargetCompatible then
		return false
	end

	local targetEntityType = target:GetAttribute("EntityType")
	local targetCategory = target:GetAttribute("EntityCategory")

	if not targetEntityType or not targetCategory then
		return false
	end

	-- Check if tool can damage this entity type
	local entityConfig = GameConfig.entities[targetEntityType]
	if entityConfig and entityConfig.damageableBy then
		for _, compatibleTool in pairs(entityConfig.damageableBy) do
			if compatibleTool == toolName then
				return true
			end
		end
	end

	return false
end

-- Calculate distance to target
local function getDistanceToTarget(target: Model): number?
	local character = player.Character
	if not character or not character.PrimaryPart then
		return nil
	end

	local targetPart = target.PrimaryPart or target:FindFirstChildOfClass("BasePart")
	if not targetPart then
		return nil
	end

	return (character.PrimaryPart.Position - targetPart.Position).Magnitude
end

-- Check if target is in range for current tool
local function isTargetInRange(target: Model, tool: Tool): boolean
	local distance = getDistanceToTarget(target)
	if not distance then
		return false
	end

	local toolConfig = GameConfig.tools[tool.Name]
	if not toolConfig then
		return false
	end

	return distance <= toolConfig.effectiveRange
end

-- Move player closer to target (for melee weapons)
local function moveToTarget(target: Model)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local targetPart = target.PrimaryPart or target:FindFirstChildOfClass("BasePart")

	if humanoid and targetPart then
		-- Move to a position slightly closer than effective range
		local toolConfig = GameConfig.tools[AutoCombatController.currentTool.Name]
		local optimalDistance = toolConfig.effectiveRange * 0.8 -- Get 80% of max range

		local direction = (targetPart.Position - character.PrimaryPart.Position).Unit
		local targetPosition = targetPart.Position - (direction * optimalDistance)

		humanoid:MoveTo(targetPosition)
	end
end

-- Attempt to attack the target
local function attackTarget(target: Model, tool: Tool)
	local currentTime = tick()
	local toolConfig = GameConfig.tools[tool.Name]

	if not toolConfig then
		return
	end

	-- Check cooldown
	if currentTime - AutoCombatController.lastAttackTime < toolConfig.swingCooldown then
		return
	end

	-- Check if target is still valid and alive
	local currentHealth = target:GetAttribute("CurrentHealth")
	local humanoid = target:FindFirstChildOfClass("Humanoid")

	if (currentHealth and currentHealth <= 0) or (humanoid and humanoid.Health <= 0) then
		-- Target is dead, stop attacking
		return
	end

	-- Check if tool is still equipped
	local character = player.Character
	if not character or character:FindFirstChild(tool.Name) ~= tool then
		return
	end

	-- Activate the tool (trigger swing)
	tool:Activate()
	AutoCombatController.lastAttackTime = currentTime

	print(`Auto-attacking {target.Name} with {tool.Name}`) -- DEBUG
end

-- Main update loop for auto-combat
local function updateAutoCombat()
	if not AutoCombatController.isActive or not AutoCombatController.currentTool then
		return
	end

	if not TargetingSystem then
		return
	end

	local target = TargetingSystem.GetCurrentTarget()
	if not target then
		return
	end

	-- Verify tool is still compatible with target
	if not isToolCompatibleWithTarget(AutoCombatController.currentTool, target) then
		return
	end

	-- Check if target is in range
	if isTargetInRange(target, AutoCombatController.currentTool) then
		-- In range - attack
		attackTarget(target, AutoCombatController.currentTool)
	else
		-- Out of range - move closer if it's a melee weapon
		local toolConfig = GameConfig.tools[AutoCombatController.currentTool.Name]
		if toolConfig and toolConfig.rangeType == "melee" then
			moveToTarget(target)
		end
	end
end

-- Start auto-combat with current tool
local function startAutoCombat(tool: Tool)
	AutoCombatController.currentTool = tool
	AutoCombatController.isActive = true

	-- Start update loop
	if not AutoCombatController.updateConnection then
		AutoCombatController.updateConnection = RunService.Heartbeat:Connect(updateAutoCombat)
	end

	print(`Auto-combat started with {tool.Name}`) -- DEBUG
end

-- Stop auto-combat
local function stopAutoCombat()
	AutoCombatController.isActive = false
	AutoCombatController.currentTool = nil

	if AutoCombatController.updateConnection then
		AutoCombatController.updateConnection:Disconnect()
		AutoCombatController.updateConnection = nil
	end

	print("Auto-combat stopped") -- DEBUG
end

-- Handle tool equipped
local function onToolEquipped(tool: Tool)
	local toolConfig = GameConfig.tools[tool.Name]
	if not toolConfig or not toolConfig.autoTargetCompatible then
		return
	end

	if not TargetingSystem then
		return
	end

	local target = TargetingSystem.GetCurrentTarget()
	if target and isToolCompatibleWithTarget(tool, target) then
		startAutoCombat(tool)
	end
end

-- Handle tool unequipped
local function onToolUnequipped(tool: Tool)
	if AutoCombatController.currentTool == tool then
		stopAutoCombat()
	end
end

-- Monitor character for tool changes
local function setupCharacterMonitoring(character: Model)
	-- Monitor for tools being added (equipped)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onToolEquipped(child)
		end
	end)

	-- Monitor for tools being removed (unequipped)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			onToolUnequipped(child)
		end
	end)

	-- Check for existing tools
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Tool") then
			onToolEquipped(child)
		end
	end
end

-- Handle manual input to cancel auto-combat
local function onUserInput(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	-- Cancel auto-combat on manual movement or tool activation
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local keysToCancel = {
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
			Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right
		}

		for _, key in pairs(keysToCancel) do
			if input.KeyCode == key then
				-- Manual movement detected - temporarily pause auto-combat
				-- (Don't fully stop it, just pause until movement stops)
				if AutoCombatController.isActive then
					AutoCombatController.isActive = false

					-- Re-enable after a short delay
					task.spawn(function()
						task.wait(1)
						if AutoCombatController.currentTool and TargetingSystem and TargetingSystem.GetCurrentTarget() then
							AutoCombatController.isActive = true
						end
					end)
				end
				break
			end
		end
	end
end

-- Public API
function AutoCombatController.IsActive(): boolean
	return AutoCombatController.isActive
end

function AutoCombatController.GetCurrentTool(): Tool?
	return AutoCombatController.currentTool
end

function AutoCombatController.Stop()
	stopAutoCombat()
end

-- Initialize auto-combat system
local function initialize()
	-- Wait for TargetingSystem to be available
	task.spawn(function()
		while not _G.TargetingSystem do
			task.wait(0.1)
		end
		TargetingSystem = _G.TargetingSystem
		print("AutoCombatController connected to TargetingSystem")
	end)

	-- Set up character monitoring
	if player.Character then
		setupCharacterMonitoring(player.Character)
	end

	player.CharacterAdded:Connect(setupCharacterMonitoring)

	-- Monitor for manual input
	UserInputService.InputBegan:Connect(onUserInput)

	print("AutoCombatController initialized")
end

-- Start the system
initialize()

-- Export to global for other scripts to access
_G.AutoCombatController = AutoCombatController

return AutoCombatController