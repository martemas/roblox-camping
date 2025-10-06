--!strict

local BuildingsConfig = {
	-- Entity System - defines all objects that can be interacted with
	buildings = {
		WoodenWall = {
			category = "defensive",
			health = 100,
            cost = {Wood = 10},
			damageableBy = {},
		},
	},
}

return BuildingsConfig