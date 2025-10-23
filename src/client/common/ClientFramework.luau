--!strict

--[[
	ClientFramework - Simple Service Registry (Client-Side)

	Provides a lightweight service locator pattern for client-side modules.

	Benefits:
	- Avoids circular dependencies
	- Eliminates _G pollution
	- Type-safe service access
	- Simple and explicit

	Usage:
		-- Register a service
		ClientFramework.register("UI", UI)

		-- Get a service
		local UI = ClientFramework.get("UI")
]]

local ClientFramework = {}

-- Service registry
local services: {[string]: any} = {}

--[[
	Register a service with the client framework

	@param serviceName - Unique name for the service
	@param serviceModule - The service module to register
]]
function ClientFramework.register(serviceName: string, serviceModule: any)
	if services[serviceName] then
		warn(`[ClientFramework] Service '{serviceName}' is already registered`)
		return
	end

	services[serviceName] = serviceModule
	print(`[ClientFramework] ✓ Registered: {serviceName}`)
end

--[[
	Get a registered service

	@param serviceName - Name of the service to retrieve
	@return The service module, or nil if not found
]]
function ClientFramework.get(serviceName: string): any?
	return services[serviceName]
end

--[[
	Check if a service is registered

	@param serviceName - Name of the service to check
	@return True if service is registered, false otherwise
]]
function ClientFramework.has(serviceName: string): boolean
	return services[serviceName] ~= nil
end

--[[
	Get all registered service names (for debugging)

	@return Array of service names
]]
function ClientFramework.getServiceNames(): {string}
	local names = {}
	for name, _ in services do
		table.insert(names, name)
	end
	return names
end

return ClientFramework
