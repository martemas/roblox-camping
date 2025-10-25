--!strict

-- SERVER-ONLY: Gameplay rules (security-critical)
-- Combat Mode Enum
export type CombatMode = "ACTION" | "TACTICAL"

local CombatMode = {
	ACTION = "ACTION" :: CombatMode,
	TACTICAL = "TACTICAL" :: CombatMode,
}

-- Import Economy configuration
local Economy = require(script.Parent.Economy)

local GameConfig = {
	-- Gameplay Settings
	gameplay = {
		miningInteraction = "hold", -- "tap" or "hold"
		miningHoldDuration = 1.0, -- seconds (if hold mode)
	},
	-- Player Settings
	player = {
		maxHealth = 100,
		inventorySize = 5,
		startingTools = { "Axe", "Pickaxe", "Bow", "MagicMissile", "Fireball" },
		healthRegenRate = 5, -- Percentage per interval
		healthRegenInterval = 5, -- Seconds
		respawnTimeout = 10, -- Seconds
	},

	-- Wildlife Settings
	wildlife = {
		maxActive = 20, -- Max total wildlife in world
		respawnInterval = 10, -- Seconds between spawn attempts
	},

	-- Combat System Settings
	combat = {
		-- Combat Mode
		combatMode = CombatMode.ACTION,

		-- Hit Detection Mode
		damageTargetOnly = false,

		-- Auto-Aim System
		autoAim = false,

		-- Invulnerability Frames
		invulnerabilityFrames = true,
		invulnerabilityDuration = 0.5,

		-- Directional Combat
		requireFacingForDamage = false,
		facingAngleDegrees = 300,
		showFacingIndicator = true,

		-- Entity AI Aggro
		chaseRangeMultiplier = 3,

		-- Game Modes
		pvpEnabled = true,
		teamBased = false,
		friendlyFire = false,

		-- Body Part Damage Multipliers
		bodyPartMultipliers = {
			Head = 2.0,
			UpperTorso = 1.0,
			LowerTorso = 1.0,
			LeftUpperArm = 0.75,
			RightUpperArm = 0.75,
			LeftLowerArm = 0.75,
			RightLowerArm = 0.75,
			LeftHand = 0.75,
			RightHand = 0.75,
			LeftUpperLeg = 0.8,
			RightUpperLeg = 0.8,
			LeftLowerLeg = 0.8,
			RightLowerLeg = 0.8,
			LeftFoot = 0.75,
			RightFoot = 0.75,
			Torso = 1.0,
			["Left Arm"] = 0.75,
			["Right Arm"] = 0.75,
			["Left Leg"] = 0.8,
			["Right Leg"] = 0.8,
			default = 1.0,
		},

		-- Stats-based combat
		baseHitChance = 0.95,
		dexterityHitBonus = 0.01,
		evasionDodgeBonus = 0.01,
		criticalHitChance = 0.05,
		criticalDamageMultiplier = 1.5,
		strengthDamageBonus = 0.02,
		defenseReduction = 0.015,
	},

	-- Targeting System Settings
	targeting = {
		selectionRange = 80,
		autoDeselectRange = 100,
		showOtherPlayersTargets = false,
		otherPlayerHighlightOpacity = 0.3,
		ownTargetColor = Color3.fromRGB(255, 200, 0),
		otherPlayerTargetColor = Color3.fromRGB(100, 150, 255),
	},

	-- Stats & Leveling System
	stats = {
		defaultStartingStats = {
			strength = 5,
			magic = 5,
			stamina = 5,
			accuracy = 5,
		},
		maxStatValue = 50,
		statPointsPerLevel = 2,
		entityStatScalingPerLevel = 0.1,
		xpRewards = {
			Wolf = 15,
			Bear = 30,
			Zombie = 20,
			Player = 50,
		},
		xpLevelMultiplier = 1.5,
		entityCanEarnXP = {
			Wolf = false,
			Bear = false,
			Zombie = true,
		},
		lastAttackerExpiry = 10,
	},

	-- Map Settings
	map = {
		size = 1000,
		campRadius = 50,
		resourceSpawnRadius = 400,
	},

	-- Drop System Settings
	drops = {
		mode = "scatter",
		scatterRadius = 5,
		despawnTime = 300,
		containerDespawnTime = 300,
		containerDespawnAfterLoot = false,
		containerMaxDistance = 10,
	},

	-- Time/Day-Night Cycle Settings
	time = {
		dayDuration = 180, -- 5 minutes
		nightDuration = 180, -- 3 minutes
		transitionTime = 180, -- Seconds for dawn/dusk transition

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

	-- Item Interaction Settings
	itemInteraction = {
		maxDragDistance = 20,        -- Max distance to drag from player (studs)
		maxFinalDistance = 30,       -- Max distance for final throw landing
		maxThrowVelocity = 50,       -- Max throw speed (studs/sec)
		dragThreshold = 20,          -- Pixels to move before drag activates
		highlightColor = Color3.fromRGB(255, 220, 100),
		allowRelocation = true,      -- Toggle drag feature on/off
	},

	-- Export CombatMode enum
	CombatMode = CombatMode,

	-- Shop configuration (from Economy)
	shop = Economy.shop,
}

return GameConfig
