--!strict

--[[
	UIManager - Central UI System Orchestrator

	Manages all UI components in the game:
	- Creates and initializes components based on UIConfig
	- Provides centralized access to all UI elements
	- Handles UI lifecycle (create, update, destroy)
	- Manages UI layers and z-indexing

	Usage:
		local UIManager = require(script.Parent.UIManager)
		UIManager.initialize()
		UIManager.showComponent("StatsPanel")
		UIManager.updateComponent("XPBar", {xp = 100, level = 5})
]]

local Players = game:GetService("Players")

local UIConfig = require(script.Parent:WaitForChild("UIConfig"))
local UIComponent = require(script.Parent:WaitForChild("ui"):WaitForChild("UIComponent"))

local UIManager = {}

-- State
local player = Players.LocalPlayer
local playerGui: PlayerGui? = nil
local screenGui: ScreenGui? = nil
local components: {[string]: any} = {}
local initialized = false

-- Component registry (add new components here)
local COMPONENT_MODULES = {
	-- Stats System
	XPBar = "ui/XPBar",
	StatsPanel = "ui/StatsPanel",
	LevelUpModal = "ui/LevelUpModal",

	-- Game UI
	Inventory = "ui/Inventory",
	TeamResources = "ui/TeamResources",
	PhaseTimer = "ui/PhaseTimer",
	HealthBar = "ui/HealthBar",
	StaminaBar = "ui/StaminaBar",
	Notification = "ui/Notification",
	Shop = "ui/Shop",

	-- Combat UI (to be modularized)
	-- TargetHUD = "ui/TargetHUD",

	-- Building UI (to be modularized)
	-- BuildingMenu = "ui/BuildingMenu",
}

--[[
	Initialize the UI Manager

	Creates the root ScreenGui and initializes all enabled components.
]]
function UIManager.initialize()
	if initialized then
		warn("[UIManager] Already initialized")
		return
	end

	print("[UIManager] Initializing UI system...")

	-- Get PlayerGui
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	-- Create root ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MasterUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Initialize each component
	for componentName, modulePath in COMPONENT_MODULES do
		local success, component = pcall(function()
			-- Parse the path (e.g., "ui/XPBar" -> ui folder, then XPBar module)
			local pathParts = string.split(modulePath, "/")
			local current = script.Parent

			for i, part in pathParts do
				current = current:WaitForChild(part, 5)
				if not current then
					error(`Failed to find '{part}' in path '{modulePath}'`)
				end
			end

			return require(current)
		end)

		if success then
			if component.isEnabled() then
				component.create(screenGui)
				components[componentName] = component
				print(`[UIManager] ✓ {componentName} initialized`)
			else
				print(`[UIManager] ✗ {componentName} disabled`)
			end
		else
			warn(`[UIManager] ✗ Failed to load {componentName}: {component}`)
		end
	end

	initialized = true
	print("[UIManager] ✓ UI system initialized successfully")
end

--[[
	Get a component by name

	@param componentName - Name of the component
	@return Component module or nil
]]
function UIManager.getComponent(componentName: string): any?
	return components[componentName]
end

--[[
	Check if a component exists and is enabled

	@param componentName - Name of the component
	@return boolean
]]
function UIManager.hasComponent(componentName: string): boolean
	return components[componentName] ~= nil
end

--[[
	Show a component

	@param componentName - Name of the component
]]
function UIManager.showComponent(componentName: string)
	local component = components[componentName]
	if component and component.show then
		component.show()
	else
		warn(`[UIManager] Component '{componentName}' not found or doesn't support show()`)
	end
end

--[[
	Hide a component

	@param componentName - Name of the component
]]
function UIManager.hideComponent(componentName: string)
	local component = components[componentName]
	if component and component.hide then
		component.hide()
	else
		warn(`[UIManager] Component '{componentName}' not found or doesn't support hide()`)
	end
end

--[[
	Toggle a component's visibility

	@param componentName - Name of the component
]]
function UIManager.toggleComponent(componentName: string)
	local component = components[componentName]
	if component and component.toggle then
		component.toggle()
	else
		warn(`[UIManager] Component '{componentName}' not found or doesn't support toggle()`)
	end
end

--[[
	Update a component with new data

	@param componentName - Name of the component
	@param ... - Variable arguments to pass to component's update function
]]
function UIManager.updateComponent(componentName: string, ...)
	local component = components[componentName]
	if component and component.update then
		component.update(...)
	else
		warn(`[UIManager] Component '{componentName}' not found or doesn't support update()`)
	end
end

--[[
	Destroy a component

	@param componentName - Name of the component
]]
function UIManager.destroyComponent(componentName: string)
	local component = components[componentName]
	if component and component.destroy then
		component.destroy()
		components[componentName] = nil
		print(`[UIManager] Destroyed {componentName}`)
	else
		warn(`[UIManager] Component '{componentName}' not found or doesn't support destroy()`)
	end
end

--[[
	Destroy all components and clean up
]]
function UIManager.destroyAll()
	for componentName, component in components do
		if component.destroy then
			component.destroy()
		end
	end

	components = {}

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end

	initialized = false
	print("[UIManager] All UI components destroyed")
end

--[[
	Get the root ScreenGui

	@return ScreenGui or nil
]]
function UIManager.getScreenGui(): ScreenGui?
	return screenGui
end

--[[
	Check if UI Manager is initialized

	@return boolean
]]
function UIManager.isInitialized(): boolean
	return initialized
end

--[[
	Get all active component names

	@return Array of component names
]]
function UIManager.getActiveComponents(): {string}
	local active = {}
	for name, _ in components do
		table.insert(active, name)
	end
	return active
end

--[[
	Register a new component dynamically

	@param componentName - Name of the component
	@param componentModule - The component module
]]
function UIManager.registerComponent(componentName: string, componentModule: any)
	if components[componentName] then
		warn(`[UIManager] Component '{componentName}' already registered`)
		return
	end

	if not screenGui then
		warn("[UIManager] Cannot register component before initialization")
		return
	end

	if componentModule.isEnabled and componentModule.isEnabled() then
		componentModule.create(screenGui)
		components[componentName] = componentModule
		print(`[UIManager] ✓ Dynamically registered {componentName}`)
	else
		print(`[UIManager] ✗ {componentName} is disabled`)
	end
end

return UIManager
