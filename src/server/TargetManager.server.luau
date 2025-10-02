--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TargetingSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TargetingSystem"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

-- Initialize the targeting system
TargetingSystem.initialize()

-- Handle target selection from clients
local function onSelectTarget(player: Player, targetModel: Model)
	if not targetModel or not targetModel.Parent then
		warn(`Invalid target model from {player.Name}`)
		return
	end

	-- Validate the target on server side
	local success = TargetingSystem.setTarget(player, targetModel)

	if success then
		print(`{player.Name} targeted {targetModel.Name}`)
	else
		warn(`Failed to set target for {player.Name} - validation failed`)
	end
end

-- Handle target deselection from clients
local function onDeselectTarget(player: Player)
	TargetingSystem.setTarget(player, nil)

	-- TODO: Optionally broadcast to other players
	-- if GameConfig.targeting.showOtherPlayersTargets then
	--     for _, otherPlayer in pairs(Players:GetPlayers()) do
	--         if otherPlayer ~= player then
	--             RemoteEvents.Events.TargetUpdated:FireClient(otherPlayer, nil, player)
	--         end
	--     end
	-- end
end

-- Handle closest target requests from clients
local function onRequestClosestTarget(player: Player)
	local closestTarget = TargetingSystem.findClosestTarget(player)
	if closestTarget then
		onSelectTarget(player, closestTarget)
	end
end

-- Connect remote events
RemoteEvents.Events.SelectTarget.OnServerEvent:Connect(onSelectTarget)
RemoteEvents.Events.DeselectTarget.OnServerEvent:Connect(onDeselectTarget)
RemoteEvents.Events.RequestClosestTarget.OnServerEvent:Connect(onRequestClosestTarget)

-- Export to global for other systems to access
_G.TargetingSystem = TargetingSystem

print("TargetManager server initialized")