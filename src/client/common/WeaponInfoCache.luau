--!strict

--[[
	WeaponInfoCache - Client-side cache for weapon display information

	Fetches weapon info from server when needed and caches it locally.
	Used by TargetHUD and other UI systems for range/requirement checks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

export type WeaponDisplayInfo = {
	weaponType: string,
	range: number,
	requireFacingForDamage: boolean?,
	requiresLineOfSight: boolean?,
	requiresTarget: boolean?,
	targetFilter: string?,
}

local WeaponInfoCache = {}

-- Cache storage
local cache: {[string]: WeaponDisplayInfo} = {}

-- Pending requests (to avoid duplicate requests)
local pendingRequests: {[string]: {thread}} = {}

--[[
	Get weapon info (from cache or server)

	@param weaponId - Name of weapon
	@return WeaponDisplayInfo or nil
]]
function WeaponInfoCache.getWeaponInfo(weaponId: string): WeaponDisplayInfo?
	-- Check cache first
	if cache[weaponId] then
		return cache[weaponId]
	end

	-- Check if request is pending
	if pendingRequests[weaponId] then
		-- Wait for pending request to complete
		local thread = coroutine.running()
		table.insert(pendingRequests[weaponId], thread)
		coroutine.yield()
		return cache[weaponId]
	end

	-- Start new request
	pendingRequests[weaponId] = {}

	-- Fetch from server
	local success, result = pcall(function()
		return RemoteEvents.Functions.GetWeaponInfo:InvokeServer(weaponId)
	end)

	if success and result then
		-- Cache the result
		cache[weaponId] = result

		-- Resume waiting threads
		for _, thread in pendingRequests[weaponId] do
			task.spawn(thread)
		end
		pendingRequests[weaponId] = nil

		return result
	else
		warn(`[WeaponInfoCache] Failed to fetch weapon info for {weaponId}`)
		pendingRequests[weaponId] = nil
		return nil
	end
end

--[[
	Preload weapon info (optional, for performance)

	@param weaponId - Name of weapon
]]
function WeaponInfoCache.preloadWeapon(weaponId: string)
	if not cache[weaponId] and not pendingRequests[weaponId] then
		-- Fetch asynchronously
		task.spawn(function()
			WeaponInfoCache.getWeaponInfo(weaponId)
		end)
	end
end

--[[
	Clear cache for a specific weapon

	@param weaponId - Name of weapon
]]
function WeaponInfoCache.clearWeapon(weaponId: string)
	cache[weaponId] = nil
end

--[[
	Clear entire cache
]]
function WeaponInfoCache.clearAll()
	cache = {}
end

return WeaponInfoCache
