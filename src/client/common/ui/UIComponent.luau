--!strict

--[[
	UIComponent - Base Interface for UI Components

	All UI components should implement this interface for consistency.
	This ensures uniform behavior across the UI system.
]]

export type UIComponentInterface = {
	-- Create the UI component
	create: (parent: ScreenGui) -> Instance,

	-- Update the component with new data
	update: (data: any?) -> (),

	-- Show the component
	show: () -> (),

	-- Hide the component
	hide: () -> (),

	-- Toggle visibility
	toggle: () -> (),

	-- Destroy the component and clean up
	destroy: () -> (),

	-- Check if component is enabled in config
	isEnabled: () -> boolean,

	-- Get component name
	getName: () -> string,
}

--[[
	UIComponent Base Class

	Provides default implementations for common UI component methods.
	Components can extend this to avoid code duplication.
]]

local UIComponent = {}
UIComponent.__index = UIComponent

type UIComponentData = {
	name: string,
	container: Instance?,
	enabled: boolean,
	visible: boolean,
}

--[[
	Create a new UI component base

	@param name - Component name
	@param enabled - Whether component is enabled
	@return UIComponent instance
]]
function UIComponent.new(name: string, enabled: boolean): UIComponentData
	local self = setmetatable({}, UIComponent)

	self.name = name
	self.container = nil
	self.enabled = enabled
	self.visible = false

	return self :: any
end

--[[
	Show the component
]]
function UIComponent:show()
	if self.container then
		self.container.Visible = true
		self.visible = true
	end
end

--[[
	Hide the component
]]
function UIComponent:hide()
	if self.container then
		self.container.Visible = false
		self.visible = false
	end
end

--[[
	Toggle visibility
]]
function UIComponent:toggle()
	if self.visible then
		self:hide()
	else
		self:show()
	end
end

--[[
	Destroy the component
]]
function UIComponent:destroy()
	if self.container then
		self.container:Destroy()
		self.container = nil
	end
	self.visible = false
end

--[[
	Check if enabled
]]
function UIComponent:isEnabled(): boolean
	return self.enabled
end

--[[
	Get component name
]]
function UIComponent:getName(): string
	return self.name
end

--[[
	Check if component is visible
]]
function UIComponent:isVisible(): boolean
	return self.visible
end

return UIComponent
