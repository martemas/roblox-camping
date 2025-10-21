--!strict

--[[
	WeaponInfoProvider - Server-side provider for weapon display information

	Provides client-safe weapon info (range, type, requirements) without exposing damage values.
	Called via RemoteFunction when client equips a weapon.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Core"):WaitForChild("RemoteEvents"))
local Items = require(ServerScriptService:WaitForChild("Engine"):WaitForChild("Data"):WaitForChild("Items"))

-- Client-safe weapon info structure
export type WeaponDisplayInfo = {
	weaponType: string,
	range: number,
	requireFacingForDamage: boolean?,
	requiresLineOfSight: boolean?,
	requiresTarget: boolean?,
	targetFilter: string?,
}

--[[
	Get client-safe weapon info

	@param weaponId - Name of weapon
	@return WeaponDisplayInfo or nil
]]
local function getWeaponInfo(player: Player, weaponId: string): WeaponDisplayInfo?
	-- Validate weapon exists
	local item = Items.getItem(weaponId)
	if not item or not item.Stats then
		warn(`[WeaponInfoProvider] Invalid weapon: {weaponId}`)
		return nil
	end

	local stats = item.Stats

	-- Return only client-safe properties (no damage values)
	return {
		weaponType = stats.type,
		range = stats.range,
		requireFacingForDamage = stats.requireFacingForDamage,
		requiresLineOfSight = stats.requiresLineOfSight,
		requiresTarget = stats.requiresTarget,
		targetFilter = stats.targetFilter,
	}
end

-- Register RemoteFunction handler
RemoteEvents.Functions.GetWeaponInfo.OnServerInvoke = getWeaponInfo

print("[WeaponInfoProvider] Initialized")
