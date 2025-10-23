--!strict

--[[
	Framework - Simple Service Registry

	Provides a lightweight service locator pattern for framework modules.

	Benefits:
	- Avoids circular dependencies
	- Eliminates _G pollution
	- Type-safe service access
	- Simple and explicit

	Usage:
		-- Register a service
		Framework.register("SpawnManager", SpawnManager)

		-- Get a service
		local SpawnManager = Framework.get("SpawnManager")
]]

local Framework = {}

-- Service registry
local services: {[string]: any} = {}

--[[
	Register a service with the framework

	@param serviceName - Unique name for the service
	@param serviceModule - The service module to register
]]
function Framework.register(serviceName: string, serviceModule: any)
	if services[serviceName] then
		warn(`[Framework] Service '{serviceName}' is already registered`)
		return
	end

	services[serviceName] = serviceModule
	print(`[Framework] ✓ Registered: {serviceName}`)
end

--[[
	Get a registered service

	@param serviceName - Name of the service to retrieve
	@return The service module, or nil if not found
]]
function Framework.get(serviceName: string): any?
	return services[serviceName]
end

--[[
	Check if a service is registered

	@param serviceName - Name of the service to check
	@return True if service is registered, false otherwise
]]
function Framework.has(serviceName: string): boolean
	return services[serviceName] ~= nil
end

--[[
	Get all registered service names (for debugging)

	@return Array of service names
]]
function Framework.getServiceNames(): {string}
	local names = {}
	for name, _ in services do
		table.insert(names, name)
	end
	return names
end

return Framework
