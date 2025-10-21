--!strict

-- CLIENT-VISIBLE: UI/display settings only
-- No gameplay rules or balance values that could be exploited

local ClientSettings = {
	-- UI Display Settings
	ui = {
		maxInventorySlots = 5, -- For UI display/validation
		maxHealth = 100, -- For health bar max
		maxStamina = 100, -- For stamina bar max
		showDamageNumbers = true, -- UI preference
	},

	-- Targeting UI Settings
	targeting = {
		selectionRange = 80, -- Maximum distance to select a target
		autoDeselectRange = 100, -- Auto-deselect if target moves this far
		showOtherPlayersTargets = false, -- Show other players' target highlights
		otherPlayerHighlightOpacity = 0.3, -- Opacity for other players' highlights
		ownTargetColor = Color3.fromRGB(255, 200, 0), -- Yellow for own target
		otherPlayerTargetColor = Color3.fromRGB(100, 150, 255), -- Blue for others
	},

	-- Combat UI Settings
	combat = {
		-- Hit detection mode (shared with server)
		damageTargetOnly = false, -- False = projectiles hit all entities in path

		-- UI settings
		clickTargetSearchRadius = 10, -- Radius for click-targeting
		showFacingIndicator = true, -- Show visual feedback in target HUD
		facingAngleDegrees = 300, -- Total cone angle for UI display
	},
}

return ClientSettings
