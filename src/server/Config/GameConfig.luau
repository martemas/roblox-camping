--!strict

-- SERVER-ONLY: Gameplay rules (security-critical)
-- Combat Mode Enum
export type CombatMode = "ACTION" | "TACTICAL"

local CombatMode = {
	ACTION = "ACTION" :: CombatMode,
	TACTICAL = "TACTICAL" :: CombatMode,
}

local GameConfig = {
	-- Gameplay Settings
	gameplay = {
		miningInteraction = "hold", -- "tap" or "hold"
		miningHoldDuration = 1.0, -- seconds (if hold mode)
	},
	-- Player Settings
	player = {
		maxHealth = 100,
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

	-- Export CombatMode enum
	CombatMode = CombatMode,
}

return GameConfig
