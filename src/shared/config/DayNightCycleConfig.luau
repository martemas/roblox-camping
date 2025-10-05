--!strict

local DayNightCycleConfig = {
	-- Time Settings
	time = {
		dayDuration = 60, -- 5 minutes
		nightDuration = 180, -- 3 minutes
		transitionTime = 5, -- Seconds for dawn/dusk transition

		-- Lighting Configuration
		dayBrightness = 2, -- Day ambient brightness (0-3)
		nightBrightness = 1.5, -- Night ambient brightness (0-3, higher = less dark)
		dayOutdoorAmbient = Color3.fromRGB(140, 140, 140), -- Day ambient color
		nightOutdoorAmbient = Color3.fromRGB(120, 120, 150), -- Night ambient color (bluish tint, brighter)
		dayColorShiftTop = Color3.fromRGB(0, 0, 0), -- Day color shift top
		dayColorShiftBottom = Color3.fromRGB(0, 0, 0), -- Day color shift bottom
		nightColorShiftTop = Color3.fromRGB(76, 76, 127), -- Night color shift top
		nightColorShiftBottom = Color3.fromRGB(0, 0, 0), -- Night color shift bottom
		dayClockTime = 12, -- Time of day during day (0-24)
		nightClockTime = 0, -- Time of day during night (0-24)
	},

	-- Night Wave Settings
	nightWaves = {
		baseZombieCount = 5,
		waveInterval = 60, -- Increased from 20 to 60 seconds between waves
		difficultyIncrease = 0.2, -- Reduced from 0.2 to 0.1 (10% increase per night)
	},
}

return DayNightCycleConfig
