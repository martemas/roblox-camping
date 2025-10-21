# Migration Issues & Fixes

## Issues Encountered During Refactoring

### ✅ Issue 1: PlayerStats.luau - Index nil with 'strength'
**Error:**
```
ServerScriptService.Server.PlayerStats:36: attempt to index nil with 'strength'
```

**Cause:**
PlayerStats was using `require(ReplicatedStorage.Engine.config)` which now returns a client-safe config without the `stats` field.

**Fix:**
```lua
-- BEFORE (wrong - using client config)
local GameConfig = require(ReplicatedStorage.Engine:WaitForChild("Config"))

-- AFTER (correct - using server config)
local GameConfig = require(script.Parent.Config:WaitForChild("GameConfig"))
```

**Result:** ✅ Server file now correctly uses server-side GameConfig with all stats

---

### ✅ Issue 2: TargetingSystem.luau - Index nil with 'BearClaw'
**Error:**
```
ReplicatedStorage.Engine.player.TargetingSystem:120: attempt to index nil with 'BearClaw'
```

**Cause:**
Client-side TargetingSystem was trying to access `GameConfig.weapons[config.primaryWeapon]` to display damage in target HUD, but weapons are now server-only.

**Fix:**
```lua
-- BEFORE (trying to access weapons)
local weaponConfig = GameConfig.weapons[config.primaryWeapon]
damage = weaponConfig and weaponConfig.damage or nil

// AFTER (don't show damage on client)
-- Don't show damage to client (security - prevents damage exploits)
-- Damage is server-only information
damage = nil
```

**Result:** ✅ Client no longer tries to access weapon stats. Damage is hidden from client (more secure).

---

### ✅ Issue 3: CombatSystem.getWeaponConfig() - Shared file accessing removed config
**Error:**
Multiple files calling `CombatSystem.getWeaponConfig()` but `GameConfig.weapons` doesn't exist

**Cause:**
CombatSystem.luau is in `shared/` (runs on both client and server) but was accessing `GameConfig.weapons` which was removed for security.

**Fix:**
```lua
-- Lazy load WeaponStats (server-only)
local WeaponStats
local function getWeaponStats()
	if not WeaponStats and RunService:IsServer() then
		local success, weaponStatsModule = pcall(function()
			return ServerScriptService:WaitForChild("Data"):WaitForChild("Items"):WaitForChild("WeaponStats", 5)
		end)
		if success and weaponStatsModule then
			WeaponStats = require(weaponStatsModule)
		end
	end
	return WeaponStats
end

function CombatSystem.getWeaponConfig(weaponName: string): WeaponConfig?
	if RunService:IsServer() then
		local stats = getWeaponStats()
		if stats then
			return stats.Stats[weaponName]
		end
	else
		-- Client doesn't get weapon stats (security)
		return nil
	end
end
```

**Result:** ✅ Server gets weapon stats, client gets nil. All calling code handles nil gracefully.

---

### ✅ Issue 4: TownhallManager - WaitForChild("ResourcesConfig")
**Error:**
```
Infinite yield possible on 'ReplicatedStorage.Engine.config:WaitForChild("ResourcesConfig")'
```

**Cause:**
TownhallManager was importing ResourcesConfig which was removed during refactoring.

**Fix:**
```lua
-- BEFORE (importing removed config)
local ResourcesConfig = require(ReplicatedStorage:WaitForChild("Engine"):WaitForChild("Config"):WaitForChild("ResourcesConfig"))
type ResourceType = ResourcesConfig.ResourceType

// AFTER (using string type directly)
-- No ResourcesConfig import needed
-- Functions use string for resourceType

function TownhallManager.HasResources(resourceType: string, amount: number): boolean
function TownhallManager.ConsumeResources(resourceType: string, amount: number): boolean
function TownhallManager.AddResources(resourceType: string, amount: number)
```

**Result:** ✅ TownhallManager works without ResourcesConfig. Uses string item IDs like the new inventory system.

---

### ✅ Issue 5: CombatSystem.getPlayerWeapon() - Index nil with 'Bow'
**Error:**
```
ReplicatedStorage.Engine.combat.CombatSystem:182: attempt to index nil with 'Bow'
```

**Cause:**
Client-side code in CombatSystem was trying to access `GameConfig.tools[toolName]` to find the weapon reference, but tools config is now server-only.

**Fix:**
```lua
-- BEFORE (accessing removed tools config)
local toolConfig = GameConfig.tools[toolName]
if toolConfig and toolConfig.weaponRef then
	return toolConfig.weaponRef
else
	return toolName
end

// AFTER (using Items database)
-- Check Items database for weapon reference
local itemData = Items.Database[toolName]
if itemData and itemData.weaponData then
	-- Item has weapon data (e.g., BasicAxe → Axe)
	return itemData.weaponData
else
	-- Pure weapon (e.g., Bow → Bow)
	return toolName
end
```

**Result:** ✅ Client uses Items database to find weapon references. Items database is shared (client-safe).

---

## Security Architecture Confirmed

All fixes maintain proper security:

### ✅ Client (ReplicatedStorage)
- Display data only (names, icons, sounds)
- UI settings (colors, max values for bars)
- Visual effects
- **No damage, prices, or gameplay stats**

### ✅ Server (ServerScriptService)
- All gameplay stats (damage, range, cooldown)
- All prices and costs
- All balance values
- Game rules and mechanics

### ✅ Shared Files (run on both)
- Use `RunService:IsServer()` to conditionally load server-only data
- Client path returns nil or safe defaults
- Server path loads full stats

## Pattern for Future Updates

When updating files that reference old configs:

1. **Identify the file's location:**
   - `src/server/` → Use server configs
   - `src/client/` → Use client configs only
   - `src/shared/` → Use conditional loading

2. **Replace old imports:**
   ```lua
   -- ❌ OLD (removed files)
   local GameConfig = require(ReplicatedStorage.Engine.config)
   local ResourcesConfig = require(...)
   local WeaponsConfig = require(...)
   local ToolsConfig = require(...)
   local ShopConfig = require(...)

   -- ✅ NEW (server files)
   local GameConfig = require(ServerScriptService.Config.GameConfig)
   local WeaponStats = require(ServerScriptService.Data.Items.WeaponStats)
   local ToolStats = require(ServerScriptService.Data.Items.ToolStats)
   local ResourceStats = require(ServerScriptService.Data.Items.ResourceStats)
   local Economy = require(ServerScriptService.Config.Economy)

   -- ✅ NEW (client files)
   local Items = require(ReplicatedStorage.Engine.Data.Items.Items)
   local ClientSettings = require(ReplicatedStorage.Engine.config.ClientSettings)
   ```

3. **Update type annotations:**
   ```lua
   -- ❌ OLD
   type ResourceType = ResourcesConfig.ResourceType

   -- ✅ NEW
   -- Just use string (itemId)
   ```

4. **Test the file:**
   - Check if it's server-only, client-only, or shared
   - Ensure it only accesses appropriate data
   - Verify nil handling for shared files

## Build Status

✅ **All issues resolved**
✅ **Rojo build succeeds**
✅ **No old config imports remaining**
✅ **Security maintained throughout**

## Next Steps

1. Test in-game to verify all systems work correctly
2. Check UI displays for any missing data
3. Verify combat damage calculations work (server-side)
4. Confirm inventory handles all item types
5. Test mining with new ResourceStats
