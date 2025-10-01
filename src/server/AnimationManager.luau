--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local AnimationCache = require(script.Parent:WaitForChild("AnimationCache"))

type ToolType = Types.ToolType

local AnimationManager = {}

-- Per-player loaded AnimationTracks
local playerTracks: {[Player]: {[string]: {AnimationTrack}}} = {}

-- Per-player animation sequence indices (1-based)
local playerIndices: {[Player]: {[string]: number}} = {}

-- Character connections for cleanup
local characterConnections: {[Player]: {ancestryConnection: RBXScriptConnection?}} = {}

-- Load AnimationTracks for a specific tool for a player
local function loadTracksForTool(player: Player, toolType: ToolType): boolean
	local character = player.Character
	if not character then
		warn(`[AnimationManager] No character for {player.Name}`)
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`[AnimationManager] No humanoid for {player.Name}`)
		return false
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn(`[AnimationManager] No animator for {player.Name}`)
		return false
	end

	-- Get pre-cached Animation objects
	local animations = AnimationCache.GetToolAnimations(toolType)
	if not animations or #animations == 0 then
		-- No custom animations for this tool, will use fallback
		return false
	end

	-- Initialize player's track storage
	if not playerTracks[player] then
		playerTracks[player] = {}
	end

	playerTracks[player][toolType] = {}

	print(`[AnimationManager] Loading tracks for {player.Name}: {toolType} ({#animations} animations)`)

	-- Load all tracks for this tool
	local successCount = 0
	for i, animation in animations do
		local success, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		if success and track then
			playerTracks[player][toolType][i] = track
			successCount = successCount + 1
		else
			warn(`[AnimationManager] Failed to load animation {i} for {toolType} (player: {player.Name})`)
		end
	end

	return successCount > 0
end

-- Stop all animations for a player (optionally filter by tool)
function AnimationManager.StopAllAnimations(player: Player, toolType: ToolType?): ()
	local tracks = playerTracks[player]
	if not tracks then return end

	if toolType then
		-- Stop specific tool's animations
		local toolTracks = tracks[toolType]
		if toolTracks then
			for _, track in toolTracks do
				if track.IsPlaying then
					track:Stop(0) -- Stop immediately (0 fade time)
				end
			end
		end
	else
		-- Stop ALL animations for player
		for _, toolTracks in tracks do
			for _, track in toolTracks do
				if track.IsPlaying then
					track:Stop(0)
				end
			end
		end
	end
end

-- Destroy all AnimationTracks for a player
local function destroyPlayerTracks(player: Player): ()
	local tracks = playerTracks[player]
	if not tracks then return end

	for toolType, toolTracks in tracks do
		for i, track in toolTracks do
			-- Stop if playing
			if track.IsPlaying then
				track:Stop(0)
			end

			-- Destroy the track
			track:Destroy()
			toolTracks[i] = nil
		end
		tracks[toolType] = nil
	end

	playerTracks[player] = nil
end

-- Play the next animation in sequence for a player/tool
function AnimationManager.PlayNextAnimation(player: Player, toolType: ToolType): boolean
	-- Get or initialize animation index for this player/tool
	if not playerIndices[player] then
		playerIndices[player] = {}
	end

	if not playerIndices[player][toolType] then
		playerIndices[player][toolType] = 1
	end

	-- Get current index
	local currentIndex = playerIndices[player][toolType]

	-- Check if tracks are already loaded
	local tracks = playerTracks[player] and playerTracks[player][toolType]

	-- If not loaded, load them now (lazy loading)
	if not tracks then
		local success = loadTracksForTool(player, toolType)
		if not success then
			return false -- No animations available, use fallback
		end
		tracks = playerTracks[player][toolType]
	end

	-- Validate we have tracks
	if not tracks or #tracks == 0 then
		return false
	end

	-- Wrap index if necessary
	if currentIndex > #tracks then
		currentIndex = 1
		playerIndices[player][toolType] = 1
	end

	-- Get the animation track to play
	local track = tracks[currentIndex]
	if not track then
		warn(`[AnimationManager] No track at index {currentIndex} for {player.Name}: {toolType}`)
		return false
	end

	-- Stop any currently playing animation for this tool first
	for _, t in tracks do
		if t.IsPlaying then
			t:Stop(0.1) -- Small fade out to prevent jarring transitions
		end
	end

	-- Set animation priority to ensure it plays
	track.Priority = Enum.AnimationPriority.Action

	-- Play the animation with no fade time (immediate start)
	track:Play(0, 1, 1) -- fadeTime=0, weight=1, speed=1
	print(`[AnimationManager] Playing animation {currentIndex}/{#tracks} for {player.Name}: {toolType}`)

	-- Increment index for next time (wrap around)
	playerIndices[player][toolType] = (currentIndex % #tracks) + 1

	return true
end

-- Called when character is being removed (death/despawn)
function AnimationManager.OnCharacterRemoving(player: Player): ()
	print(`[AnimationManager] Character removing: {player.Name} (stopping all animations)`)

	-- Stop and destroy all tracks
	destroyPlayerTracks(player)

	-- Disconnect character connections
	local connections = characterConnections[player]
	if connections and connections.ancestryConnection then
		connections.ancestryConnection:Disconnect()
		connections.ancestryConnection = nil
	end
end

-- Called when character is added (spawn/respawn)
function AnimationManager.OnCharacterAdded(player: Player, character: Model): ()
	-- Clear old character's tracks if any
	destroyPlayerTracks(player)

	-- Set up character removal detection
	local connection = character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			-- Character removed (died/despawned)
			AnimationManager.OnCharacterRemoving(player)
		end
	end)

	-- Store connection for cleanup
	if not characterConnections[player] then
		characterConnections[player] = {}
	end
	characterConnections[player].ancestryConnection = connection

	print(`[AnimationManager] Character added: {player.Name}`)
end

-- Called when player leaves the server
function AnimationManager.ClearPlayerData(player: Player): ()
	print(`[AnimationManager] Player data cleared: {player.Name}`)

	-- Stop and destroy tracks
	destroyPlayerTracks(player)

	-- Clear indices
	playerIndices[player] = nil

	-- Disconnect all connections
	local connections = characterConnections[player]
	if connections then
		if connections.ancestryConnection then
			connections.ancestryConnection:Disconnect()
		end
		characterConnections[player] = nil
	end
end

return AnimationManager
