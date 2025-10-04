--!strict

--[[
	UIConfig - Client UI Configuration

	Centralized configuration for all client-side UI elements.
	Enable/disable UI components and customize their appearance here.
]]

local UIConfig = {
	--[[
		XP Bar Configuration
	]]
	xpBar = {
		enabled = true,

		-- Position (UDim2)
		position = {
			scaleX = 0.3,    -- 30% from left
			offsetX = 0,
			scaleY = 0.88,   -- 88% from top (above hotbar)
			offsetY = 0,
		},

		-- Size (UDim2)
		size = {
			scaleX = 0.4,    -- 40% of screen width
			offsetX = 0,
			scaleY = 0.04,   -- 4% of screen height
			offsetY = 0,
		},

		-- Anchor point (Vector2)
		anchorPoint = {
			x = 0,
			y = 1,
		},

		-- Colors
		backgroundColor = Color3.fromRGB(30, 30, 30),      -- Dark gray background
		progressColor = Color3.fromRGB(100, 200, 100),     -- Green progress bar
		textColor = Color3.fromRGB(255, 255, 255),         -- White text

		-- Styling
		cornerRadius = 8,           -- Corner rounding in pixels
		textSize = 16,              -- Font size
		font = Enum.Font.GothamBold,
		textStrokeTransparency = 0.5,

		-- Animation
		animationDuration = 0.3,    -- Seconds for progress bar animation

		-- XP Popup
		showXPPopup = true,
		popupDuration = 2.0,        -- Seconds popup stays visible
		popupColor = Color3.fromRGB(100, 255, 100),  -- Bright green
	},

	--[[
		Stats Panel Configuration
	]]
	statsPanel = {
		enabled = true,

		-- Toggle key
		hotkey = Enum.KeyCode.C,

		-- Position (UDim2)
		position = {
			scaleX = 0.02,   -- 2% from left
			offsetX = 0,
			scaleY = 0.15,   -- 15% from top
			offsetY = 0,
		},

		-- Size (UDim2)
		size = {
			scaleX = 0.25,   -- 25% of screen width
			offsetX = 0,
			scaleY = 0.5,    -- 50% of screen height
			offsetY = 0,
		},

		-- Colors
		backgroundColor = Color3.fromRGB(30, 30, 30),
		headerColor = Color3.fromRGB(50, 50, 50),
		statRowColor = Color3.fromRGB(40, 40, 40),
		buttonColor = Color3.fromRGB(60, 180, 60),
		buttonHoverColor = Color3.fromRGB(80, 200, 80),
		textColor = Color3.fromRGB(255, 255, 255),
		descTextColor = Color3.fromRGB(200, 200, 200),

		-- Styling
		cornerRadius = 8,
		headerTextSize = 20,
		statTextSize = 16,
		descTextSize = 12,
		font = Enum.Font.Gotham,
		headerFont = Enum.Font.GothamBold,

		-- Spacing
		padding = 10,           -- Internal padding
		statRowSpacing = 5,     -- Space between stat rows

		-- Start visible or hidden
		startVisible = false,
	},

	--[[
		Level Up Modal Configuration
	]]
	levelUpModal = {
		enabled = true,

		-- Size (UDim2)
		size = {
			scaleX = 0.3,
			offsetX = 0,
			scaleY = 0.2,
			offsetY = 0,
		},

		-- Colors
		backgroundColor = Color3.fromRGB(40, 40, 40),
		textColor = Color3.fromRGB(255, 255, 255),
		levelColor = Color3.fromRGB(255, 215, 0),  -- Gold
		buttonColor = Color3.fromRGB(60, 180, 60),
		buttonHoverColor = Color3.fromRGB(80, 200, 80),

		-- Styling
		cornerRadius = 12,
		titleTextSize = 24,
		messageTextSize = 18,
		buttonTextSize = 16,
		font = Enum.Font.Gotham,
		titleFont = Enum.Font.GothamBold,

		-- Animation
		fadeInDuration = 0.3,
		displayDuration = 3.0,  -- Seconds before auto-close

		-- Auto-open stats panel on level up
		autoOpenStatsPanel = true,
	},

	--[[
		Inventory Configuration
	]]
	inventory = {
		enabled = true,

		-- Position (UDim2)
		position = {
			scaleX = 0,
			offsetX = 20,
			scaleY = 1,
			offsetY = -100,
		},

		-- Size (UDim2)
		size = {
			scaleX = 0,
			offsetX = 300,
			scaleY = 0,
			offsetY = 80,
		},

		-- Colors
		backgroundColor = Color3.fromRGB(50, 50, 50),
		slotEmptyColor = Color3.fromRGB(80, 80, 80),
		slotFilledColor = Color3.fromRGB(100, 150, 100),
		borderColor = Color3.fromRGB(100, 100, 100),
		textColor = Color3.fromRGB(255, 255, 255),

		-- Styling
		backgroundTransparency = 0.3,
		slotSize = 50,
		slotSpacing = 5,
		font = Enum.Font.PermanentMarker,
	},

	--[[
		Team Resources Configuration
	]]
	teamResources = {
		enabled = true,

		-- Position (UDim2)
		position = {
			scaleX = 0.5,
			offsetX = -150,
			scaleY = 0,
			offsetY = -50,
		},

		-- Size (UDim2)
		size = {
			scaleX = 0,
			offsetX = 300,
			scaleY = 0,
			offsetY = 60,
		},

		-- Colors
		backgroundColor = Color3.fromRGB(50, 50, 50),
		resourceBgColor = Color3.fromRGB(80, 80, 80),
		borderColor = Color3.fromRGB(100, 100, 100),
		textColor = Color3.fromRGB(255, 255, 255),

		-- Styling
		backgroundTransparency = 0.3,
		font = Enum.Font.PermanentMarker,

		-- Resource types to display
		resourceTypes = {"Wood", "Stone", "Metal"},
	},

	--[[
		Phase Timer Configuration
	]]
	phaseTimer = {
		enabled = false,

		-- Position (UDim2)
		position = {
			scaleX = 0.5,
			offsetX = -100,
			scaleY = 0,
			offsetY = 90,
		},

		-- Size (UDim2)
		size = {
			scaleX = 0,
			offsetX = 200,
			scaleY = 0,
			offsetY = 80,
		},

		-- Colors
		backgroundColor = Color3.fromRGB(50, 50, 50),
		borderColor = Color3.fromRGB(100, 100, 100),
		textColor = Color3.fromRGB(255, 255, 255),
		dayPhaseColor = Color3.fromRGB(255, 255, 0),    -- Yellow
		nightPhaseColor = Color3.fromRGB(255, 100, 100), -- Red
		prepPhaseColor = Color3.fromRGB(200, 200, 200),  -- Gray

		-- Styling
		backgroundTransparency = 0.3,
		font = Enum.Font.Creepster,
	},

	--[[
		Health Bar Configuration
	]]
	healthBar = {
		enabled = false,

		-- Position (UDim2)
		position = {
			scaleX = 0,
			offsetX = 20,
			scaleY = 0,
			offsetY = 20,
		},

		-- Size (UDim2)
		size = {
			scaleX = 0,
			offsetX = 200,
			scaleY = 0,
			offsetY = 40,
		},

		-- Colors
		backgroundColor = Color3.fromRGB(50, 50, 50),
		barBackgroundColor = Color3.fromRGB(100, 100, 100),
		borderColor = Color3.fromRGB(100, 100, 100),
		textColor = Color3.fromRGB(255, 255, 255),
		healthHighColor = Color3.fromRGB(0, 255, 0),    -- Green (>60%)
		healthMediumColor = Color3.fromRGB(255, 255, 0), -- Yellow (30-60%)
		healthLowColor = Color3.fromRGB(255, 0, 0),     -- Red (<30%)

		-- Styling
		backgroundTransparency = 0.3,
		font = Enum.Font.PermanentMarker,

		-- Update frequency
		updateInterval = 1.0,  -- Seconds
	},

	--[[
		Stamina Bar Configuration
	]]
	staminaBar = {
		enabled = true,

		-- Position (UDim2)
		position = {
			scaleX = 0,
			offsetX = 20,
			scaleY = 0,
			offsetY = 70,
		},

		-- Size (UDim2)
		size = {
			scaleX = 0,
			offsetX = 200,
			scaleY = 0,
			offsetY = 40,
		},

		-- Colors
		backgroundColor = Color3.fromRGB(50, 50, 50),
		barBackgroundColor = Color3.fromRGB(100, 100, 100),
		borderColor = Color3.fromRGB(100, 100, 100),
		textColor = Color3.fromRGB(255, 255, 255),
		staminaHighColor = Color3.fromRGB(0, 150, 255),   -- Blue (>60%)
		staminaMediumColor = Color3.fromRGB(255, 200, 0),  -- Orange (30-60%)
		staminaLowColor = Color3.fromRGB(255, 100, 100),  -- Light Red (<30%)

		-- Styling
		backgroundTransparency = 0.3,
		font = Enum.Font.PermanentMarker,
	},

	--[[
		Notification Configuration
	]]
	notification = {
		enabled = true,

		-- Position (UDim2)
		position = {
			scaleX = 0.5,
			offsetX = -200,
			scaleY = 0.3,
			offsetY = -100,
		},

		-- Size (UDim2)
		size = {
			scaleX = 0,
			offsetX = 400,
			scaleY = 0,
			offsetY = 60,
		},

		-- Colors
		backgroundColor = Color3.fromRGB(0, 0, 0),
		borderColor = Color3.fromRGB(255, 255, 255),
		textColor = Color3.fromRGB(255, 255, 255),

		-- Styling
		backgroundTransparency = 0.5,
		font = Enum.Font.PermanentMarker,

		-- Animation
		displayDuration = 3.0,     -- Seconds before fade
		fadeOutDuration = 0.5,     -- Fade animation duration
	},

	--[[
		Shop Configuration
	]]
	shop = {
		enabled = true,

		-- Shop Button Position (UDim2)
		buttonPosition = {
			scaleX = 1,
			offsetX = -100,
			scaleY = 0,
			offsetY = 20,
		},

		-- Shop Button Size (UDim2)
		buttonSize = {
			scaleX = 0,
			offsetX = 80,
			scaleY = 0,
			offsetY = 40,
		},

		-- Shop Frame Position (UDim2)
		framePosition = {
			scaleX = 0.5,
			offsetX = -250,
			scaleY = 0.5,
			offsetY = -200,
		},

		-- Shop Frame Size (UDim2)
		frameSize = {
			scaleX = 0,
			offsetX = 500,
			scaleY = 0,
			offsetY = 400,
		},

		-- Colors
		buttonBackgroundColor = Color3.fromRGB(100, 150, 100),
		buttonBorderColor = Color3.fromRGB(150, 200, 150),
		frameBackgroundColor = Color3.fromRGB(40, 40, 40),
		frameBorderColor = Color3.fromRGB(100, 100, 100),
		itemBackgroundColor = Color3.fromRGB(80, 80, 80),
		itemBorderColor = Color3.fromRGB(120, 120, 120),
		scrollBackgroundColor = Color3.fromRGB(60, 60, 60),
		closeButtonColor = Color3.fromRGB(200, 50, 50),
		closeButtonBorderColor = Color3.fromRGB(255, 100, 100),
		purchaseButtonColor = Color3.fromRGB(100, 200, 100),
		purchaseButtonBorderColor = Color3.fromRGB(150, 255, 150),
		purchaseButtonDisabledColor = Color3.fromRGB(100, 100, 100),
		textColor = Color3.fromRGB(255, 255, 255),
		descTextColor = Color3.fromRGB(200, 200, 200),
		costAffordColor = Color3.fromRGB(0, 255, 0),
		costCannotAffordColor = Color3.fromRGB(255, 0, 0),

		-- Styling
		font = Enum.Font.PermanentMarker,
		itemHeight = 80,
		itemSpacing = 10,
		scrollBarThickness = 8,
	},
}

-- Helper function to create UDim2 from config
function UIConfig.createUDim2(config: {scaleX: number, offsetX: number, scaleY: number, offsetY: number}): UDim2
	return UDim2.new(config.scaleX, config.offsetX, config.scaleY, config.offsetY)
end

-- Helper function to create Vector2 from config
function UIConfig.createVector2(config: {x: number, y: number}): Vector2
	return Vector2.new(config.x, config.y)
end

return UIConfig
