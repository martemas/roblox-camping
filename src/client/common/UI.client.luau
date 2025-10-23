--!strict

--[[
	UI - Unified Client UI Orchestrator

	Manages ALL UI components through UIManager and connects server data flow.

	Architecture:
	- UIManager: Component lifecycle & registry
	- UI.client (this file): Event routing & initialization
	- Components (ui/*): Pure UI implementations

	Responsibilities:
	1. Initialize UIManager (creates all enabled components)
	2. Connect RemoteEvents (server → components)
	3. Handle user input (hotkeys)
	4. Request initial data from server

	Components managed:
	- Stats System: XPBar, StatsPanel, LevelUpModal
	- Game UI: Inventory, TeamResources, PhaseTimer, HealthBar, StaminaBar, Notification, Shop
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")

local Common = StarterPlayer.StarterPlayerScripts:WaitForChild("Common")
local ClientFramework = require(Common:WaitForChild("ClientFramework"))
local UIManager = require(Common:WaitForChild("UIManager"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

-- State for tracking XP gains (for popup)
local currentXP = 0

--[[
	Connect Stats System RemoteEvents
]]
local function connectStatsEvents()
	-- XP Updated
	RemoteEvents.Events.XPUpdated.OnClientEvent:Connect(function(newXP: number, newLevel: number)
		local xpGained = newXP - currentXP
		currentXP = newXP

		-- Update XP bar
		local xpBar = UIManager.getComponent("XPBar")
		if xpBar then
			xpBar.update(newXP, newLevel)

			-- Show XP gain popup if XP increased
			if xpGained > 0 then
				xpBar.showXPGainPopup(xpGained)
			end
		end
	end)

	-- Level-Up Notification
	RemoteEvents.Events.LevelUpNotification.OnClientEvent:Connect(function(newLevel: number, newPoints: number)
		print(`[UI] Level up! New level: {newLevel}, Points: {newPoints}`)

		local levelUpModal = UIManager.getComponent("LevelUpModal")
		local statsPanel = UIManager.getComponent("StatsPanel")

		-- Show level-up modal
		if levelUpModal then
			levelUpModal.show(newLevel, newPoints)
		elseif statsPanel then
			-- If modal is disabled, just open stats panel
			statsPanel.show()
		end
	end)

	-- Stats Updated
	RemoteEvents.Events.StatsUpdated.OnClientEvent:Connect(function(stats: any, points: number)
		local statsPanel = UIManager.getComponent("StatsPanel")
		if statsPanel then
			statsPanel.update(stats, points)
		end
	end)

	print("[UI] ✓ Stats events connected")
end

--[[
	Connect Game UI RemoteEvents
]]
local function connectGameEvents()
	-- Inventory updates
	RemoteEvents.Events.UpdateInventory.OnClientEvent:Connect(function(inventory)
		UIManager.updateComponent("Inventory", inventory)
	end)

	-- Team resources updates
	RemoteEvents.Events.UpdateTeamResources.OnClientEvent:Connect(function(teamResources)
		UIManager.updateComponent("TeamResources", teamResources)
	end)

	-- Phase timer updates
	RemoteEvents.Events.UpdatePhaseTimer.OnClientEvent:Connect(function(phase, remainingTime)
		local phaseTimer = UIManager.getComponent("PhaseTimer")
		if phaseTimer then
			phaseTimer.update(phase, remainingTime)
		end
	end)

	-- Phase change notifications
	RemoteEvents.Events.PhaseChanged.OnClientEvent:Connect(function(phase)
		local notification = UIManager.getComponent("Notification")
		if notification then
			notification.show(`{phase} phase has begun!`)
		end
	end)

	-- Stamina updates
	RemoteEvents.Events.UpdateStamina.OnClientEvent:Connect(function(currentStamina, maxStamina)
		UIManager.updateComponent("StaminaBar", currentStamina, maxStamina)
	end)

	-- Shop updates
	RemoteEvents.Events.UpdateShopData.OnClientEvent:Connect(function(shopData, teamResources)
		local shop = UIManager.getComponent("Shop")
		if shop then
			shop.update(shopData, teamResources)
		end
	end)

	-- Generic notifications
	RemoteEvents.Events.ShowNotification.OnClientEvent:Connect(function(message)
		local notification = UIManager.getComponent("Notification")
		if notification then
			notification.show(message)
		end
	end)

	print("[UI] ✓ Game events connected")
end

--[[
	Handle user input (hotkeys)
]]
local function setupInputHandling()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- Stats panel hotkey
		local statsPanel = UIManager.getComponent("StatsPanel")
		if statsPanel and input.KeyCode == statsPanel.getHotkey() then
			statsPanel.toggle()
		end
	end)

	print("[UI] ✓ Input handling connected")
end

--[[
	Setup component callbacks
]]
local function setupComponentCallbacks()
	-- LevelUpModal callback to open stats panel
	local levelUpModal = UIManager.getComponent("LevelUpModal")
	local statsPanel = UIManager.getComponent("StatsPanel")

	if levelUpModal and statsPanel then
		levelUpModal.setOpenStatsPanelCallback(function()
			statsPanel.show()
		end)
	end

	print("[UI] ✓ Component callbacks setup")
end

--[[
	Request initial data from server
]]
local function requestInitialData()
	task.spawn(function()
		task.wait(2) -- Wait for server to initialize

		-- Request player inventory
		local success, inventory = pcall(function()
			return RemoteEvents.Functions.GetPlayerData:InvokeServer()
		end)

		if success and inventory then
			UIManager.updateComponent("Inventory", inventory)
		end

		-- Request team resources
		local success2, teamResources = pcall(function()
			return RemoteEvents.Functions.GetTeamResources:InvokeServer()
		end)

		if success2 and teamResources then
			UIManager.updateComponent("TeamResources", teamResources)
		end

		print("[UI] ✓ Initial data loaded")
	end)
end

--[[
	Initialize the entire UI system
]]
local function initialize()
	print("[UI] Initializing unified UI system...")

	-- Wait for player to spawn
	if not player.Character then
		player.CharacterAdded:Wait()
	end

	-- Initialize UIManager (creates all enabled components)
	UIManager.initialize()

	-- Connect RemoteEvents
	connectStatsEvents()
	connectGameEvents()

	-- Setup input handling
	setupInputHandling()

	-- Setup component callbacks
	setupComponentCallbacks()

	-- Request initial data
	requestInitialData()

	print("[UI] ✓ Unified UI system initialized successfully")
end

--[[
	Public API for legacy compatibility
	(StaminaController uses _G.GameUI.updateStaminaUI)
]]
local UI = {}

function UI.updateStaminaUI(currentStamina: number, maxStamina: number)
	UIManager.updateComponent("StaminaBar", currentStamina, maxStamina)
end

-- Start the UI system
initialize()

-- Register with ClientFramework
ClientFramework.register("UI", UI)

return UI
