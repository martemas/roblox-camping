--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local Utils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"))
local CombatSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatSystem"))
local TargetingSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TargetingSystem"))
local AnimationManager = require(script.Parent:WaitForChild("AnimationManager"))

type ToolType = Types.ToolType

local ToolManager = {}
local playerCooldowns: {[Player]: {[string]: number}} = {}

-- Track hitting state per player per swing
local swingHits: {[Player]: {[number]: boolean}} = {}

-- Note: We use the default Roblox character.Animate.toolslash animation instead of a pre-created one

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



-- Perform combat attack using unified CombatSystem
local function performCombatAttack(player: Player, toolType: ToolType)
	local character = player.Character
	if not character then
		return
	end

	-- Get weapon name: use weaponRef if available, otherwise use tool name directly
	local toolConfig = GameConfig.tools[toolType]
	local weaponName = (toolConfig and toolConfig.weaponRef) or toolType
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		warn(`DEBUG: No weapon config found for {weaponName}`)
		return
	end

	-- Get player's target
	local target = TargetingSystem.getTarget(player)

	-- Handle different weapon types
	if weaponConfig.type == "melee" then
		-- Wait for castDuration (telegraph window)
		task.wait(weaponConfig.castDuration)

		-- Determine hit detection mode
		if GameConfig.combat.damageTargetOnly then
			-- Mode A: Target-only mode - need a target selected
			if not target then
				-- No target selected - play miss sound
				playToolSound(player, toolType, "swing")
				print(`{player.Name} swung {toolType} but has no target selected`)
				return
			end

			-- Attempt attack on target
			local result = CombatSystem.attemptMeleeAttack(character, target, weaponName, player)

			if result.hit then
				-- Hit! Damage already applied by CombatSystem
				playToolSound(player, toolType, "attack")
				print(`{player.Name} hit {target.Name} for {result.damage} damage`)
			elseif result.wasDodged then
				-- Target dodged
				playToolSound(player, toolType, "swing")
				print(`{player.Name}'s attack on {target.Name} was dodged`)
			elseif result.blockedByInvulnerability then
				-- Blocked by invulnerability
				playToolSound(player, toolType, "swing")
				print(`{target.Name} is invulnerable to {weaponName}`)
			else
				-- Miss
				playToolSound(player, toolType, "swing")
			end
		else
			-- Mode B: AOE mode - hit all entities in range
			local result = CombatSystem.attemptMeleeAttack(character, target, weaponName, player)

			if result.hit then
				-- Hit at least one entity
				playToolSound(player, toolType, "attack")
				print(`{player.Name} hit entities for {result.damage} total damage`)
			else
				-- No hits - play swing sound
				playToolSound(player, toolType, "swing")
				print(`{player.Name} swung {toolType} but hit nothing`)
			end
		end

	elseif weaponConfig.type == "projectile" then
		-- Projectile weapons require a locked target
		if not target then
			playToolSound(player, toolType, "swing")
			print(`{player.Name} fired {weaponName} but has no target selected`)
			return
		end

		-- Wait for castDuration (draw/charge animation)
		task.wait(weaponConfig.castDuration)

		-- Verify character still exists and get root parts
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoidRootPart then
			return
		end

		local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso") :: BasePart?
		if not targetRoot or not targetRoot:IsA("BasePart") then
			playToolSound(player, toolType, "swing")
			print(`{player.Name} fired {weaponName} but target has no valid root part`)
			return
		end

		-- Check if player is facing the target
		if not CombatSystem.isFacingTarget(humanoidRootPart, targetRoot) then
			playToolSound(player, toolType, "swing")
			print(`{player.Name} fired {weaponName} but not facing target`)
			return
		end

		-- Calculate spawn position at chest height (no forward offset to reduce visual lag)
		local origin = humanoidRootPart.Position + Vector3.new(0, 1.5, 0)

		-- Aim at target's center (use their root position directly for accurate aiming)
		local targetPosition = targetRoot.Position
		local direction = (targetPosition - origin).Unit

		-- Spawn projectile via ProjectileManager
		local ProjectileManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectileManager"))
		local projectile = ProjectileManager.spawnProjectile(
			origin,
			direction,
			weaponName,
			character,
			player,
			target -- Locked target
		)

		if projectile then
			playToolSound(player, toolType, "attack")
			print(`{player.Name} fired {weaponName} at {target.Name}`)
		else
			playToolSound(player, toolType, "swing")
			print(`{player.Name} projectile attack blocked`)
		end

	else
		warn(`Weapon type {weaponConfig.type} not yet implemented`)
	end
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

	-- Create final placement CFrame with ground position, height offset, and preserve rotation
	local finalPosition = groundPosition + Vector3.new(0, heightOffset, 0)
	local adjustedCFrame = CFrame.new(finalPosition) * (placementCFrame - placementCFrame.Position)

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

	-- Get weapon name: use weaponRef if available, otherwise use tool name directly
	local weaponName = (toolConfig and toolConfig.weaponRef) or toolType

	-- Get weapon config for cooldown
	local weaponConfig = CombatSystem.getWeaponConfig(weaponName)
	if not weaponConfig then
		return
	end

	-- Set swing cooldown based on weapon
	setCooldown(player, "swing", weaponConfig.cooldown)

	-- Play custom tool animation or fallback to default
	local animationPlayed = AnimationManager.PlayNextAnimation(player, toolType)

	if not animationPlayed then
		-- Fallback to default Roblox toolslash animation
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
							print(`Playing fallback animation for {player.Name}`)
						else
							warn(`Failed to load swing animation for {player.Name}`)
						end
					else
						warn(`No Animator found for {player.Name}`)
					end
				else
					warn(`No Animation found in character.Animate.toolslash for {player.Name}`)
				end
			else
				warn(`No toolslash found in character.Animate for {player.Name}`)
			end
		else
			warn(`No Animate script found for {player.Name}`)
		end
	end

	-- Perform combat attack using CombatSystem (spawned so animation plays immediately)
	task.spawn(function()
		performCombatAttack(player, toolType)
	end)

	print(`{player.Name} swung {toolType}`)
end

-- Create a tool for the player
local function createTool(toolType: ToolType): Tool?
	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	if not modelsFolder then
		warn("Models folder not found in ReplicatedStorage")
		return nil
	end

	-- Check both Models/ and Models/Tools/ for backwards compatibility
	local toolTemplate = modelsFolder:FindFirstChild(toolType)
	if not toolTemplate or not toolTemplate:IsA("Tool") then
		local toolsFolder = modelsFolder:FindFirstChild("Tools")
		if toolsFolder then
			toolTemplate = toolsFolder:FindFirstChild(toolType)
		end
	end

	if not toolTemplate or not toolTemplate:IsA("Tool") then
		warn(`Tool template '{toolType}' not found in Models folder`)
		return nil
	end

	local tool = toolTemplate:Clone()

	-- Optional: Stop animation when tool unequipped
	-- Commented out as it may interrupt animations too aggressively
	-- Uncomment if you want animations to stop immediately when tool is put away
	--[[
	tool.Unequipped:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if player then
			AnimationManager.StopAllAnimations(player, toolType)
		end
	end)
	]]--

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
	player.CharacterAdded:Connect(function(character)
		-- Hook character lifecycle for animations
		AnimationManager.OnCharacterAdded(player, character)

		-- Wait a bit for character to fully load
		task.wait(1)
		giveStartingTools(player)
	end)

	-- Handle existing character
	if player.Character then
		AnimationManager.OnCharacterAdded(player, player.Character)
		giveStartingTools(player)
	end
end

-- Handle player leaving
local function onPlayerRemoving(player: Player)
	playerCooldowns[player] = nil
	swingHits[player] = nil
	AnimationManager.ClearPlayerData(player)
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