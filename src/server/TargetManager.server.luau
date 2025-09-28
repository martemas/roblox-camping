--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TargetingSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TargetingSystem"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

-- Initialize the targeting system
TargetingSystem.initialize()

-- Handle target selection from clients
local function onSelectTarget(player: Player, targetModel: Model)
	print(`Server: {player.Name} attempting to target {targetModel and targetModel.Name or "nil"}`)

	if not targetModel or not targetModel.Parent then
		warn(`Invalid target model from {player.Name}`)
		return
	end

	-- Validate the target on server side
	local success = TargetingSystem.setTarget(player, targetModel)

	if success then
		print(`Server: {player.Name} successfully targeted {targetModel.Name}`)

		-- Send confirmation back to client (optional)
		-- RemoteEvents.Events.TargetUpdated:FireClient(player, targetModel)

		-- TODO: Optionally broadcast to other players if showing other players' targets is enabled
		-- if GameConfig.targeting.showOtherPlayersTargets then
		--     for _, otherPlayer in pairs(Players:GetPlayers()) do
		--         if otherPlayer ~= player then
		--             RemoteEvents.Events.TargetUpdated:FireClient(otherPlayer, targetModel, player)
		--         end
		--     end
		-- end
	else
		warn(`Server: Failed to set target for {player.Name}`)
	end
end

-- Handle target deselection from clients
local function onDeselectTarget(player: Player)
	print(`Server: {player.Name} deselecting target`)

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
	print(`Server: {player.Name} requesting closest target`)

	local closestTarget = TargetingSystem.findClosestTarget(player)
	if closestTarget then
		onSelectTarget(player, closestTarget)
	else
		print(`Server: No closest target found for {player.Name}`)
	end
end

-- Connect remote events
RemoteEvents.Events.SelectTarget.OnServerEvent:Connect(onSelectTarget)
RemoteEvents.Events.DeselectTarget.OnServerEvent:Connect(onDeselectTarget)
RemoteEvents.Events.RequestClosestTarget.OnServerEvent:Connect(onRequestClosestTarget)

-- Export to global for other systems to access
_G.TargetingSystem = TargetingSystem

print("TargetManager server initialized")