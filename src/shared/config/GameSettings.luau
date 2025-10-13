--!strict

-- Combat Mode Enum
export type CombatMode = "ACTION" | "TACTICAL"

local CombatMode = {
	ACTION = "ACTION" :: CombatMode, -- Can attack without target (shoots forward if no target)
	TACTICAL = "TACTICAL" :: CombatMode, -- Must select target to attack
}

local GameSettings = {
	-- Gameplay Settings
	gameplay = {
		miningInteraction = "hold", -- "tap" or "hold"
		miningHoldDuration = 1.0, -- seconds (if hold mode)
	},

	-- Player Settings
	player = {
		maxHealth = 100,
		inventorySize = 5,
		startingTools = {"Axe", "Pickaxe", "Bow", "MagicMissile", "Fireball"},
		healthRegenRate = 5, -- Percentage per interval
		healthRegenInterval = 5, -- Seconds
		respawnTimeout = 10, -- Seconds

		-- Movement settings
		walkSpeed = 16,
		sprintSpeed = 24,
		maxStamina = 100,
		staminaDrainRate = 20, -- Per second while sprinting
		staminaRegenRate = 30, -- Per second while not sprinting
	},

	-- Wildlife Settings
	wildlife = {
		maxActive = 20, -- Max total wildlife in world
		respawnInterval = 10, -- Seconds between spawn attempts
	},

	-- Combat System Settings
	combat = {
		-- Combat Mode
		combatMode = CombatMode.ACTION, -- ACTION = can attack without target, TACTICAL = must select target

		-- Hit Detection Mode
		damageTargetOnly = false, -- false = hit all entities in range, true = only hit targeted entity

		-- Auto-Aim System (applies to projectile AND hitscan)
		autoAim = false, -- true = aim at locked target automatically, false = free-aim (aim direction)
		-- When true: projectiles/hitscans aim at target regardless of look direction (skill-based, combat action)
		-- When false: projectiles/hitscans go in aim direction (precision, FPS-style)

		-- Click-Targeting System
		clickTargetSearchRadius = 10, -- Studs around click/tap point to search for targetable entities

		-- Invulnerability Frames (prevent weapon spam)
		invulnerabilityFrames = true,
		invulnerabilityDuration = 0.5, -- Seconds of immunity per weapon type

		-- Directional Combat
		requireFacingForDamage = false, -- Must be facing target to deal damage
		facingAngleDegrees = 300, -- Total cone angle (180 = full front hemisphere, 120 = narrow cone)
		showFacingIndicator = true, -- Show visual feedback in target HUD

		-- Entity AI Aggro
		chaseRangeMultiplier = 3, -- How many times aggroRange before entity gives up chase

		-- Game Modes
		pvpEnabled = true, -- Enable player vs player damage
		teamBased = false, -- Enable team-based combat (future)
		friendlyFire = false, -- Can teammates damage each other (future)

		-- Body Part Damage Multipliers
		bodyPartMultipliers = {
			-- Head (R15)
			Head = 2.0,

			-- Torso (R15)
			UpperTorso = 1.0,
			LowerTorso = 1.0,

			-- Arms (R15)
			LeftUpperArm = 0.75,
			RightUpperArm = 0.75,
			LeftLowerArm = 0.75,
			RightLowerArm = 0.75,
			LeftHand = 0.75,
			RightHand = 0.75,

			-- Legs (R15)
			LeftUpperLeg = 0.8,
			RightUpperLeg = 0.8,
			LeftLowerLeg = 0.8,
			RightLowerLeg = 0.8,
			LeftFoot = 0.75,
			RightFoot = 0.75,

			-- R6 compatibility
			Torso = 1.0,
			["Left Arm"] = 0.75,
			["Right Arm"] = 0.75,
			["Left Leg"] = 0.8,
			["Right Leg"] = 0.8,

			-- Default for any unlisted parts
			default = 1.0,
		},

		-- Future: Stats-based combat (Phase 2)
		baseHitChance = 0.95,              -- 95% base hit chance
		dexterityHitBonus = 0.01,          -- +1% hit per dexterity point
		evasionDodgeBonus = 0.01,          -- +1% dodge per evasion point

		criticalHitChance = 0.05,          -- 5% base crit chance
		criticalDamageMultiplier = 1.5,    -- 1.5x damage on crit

		strengthDamageBonus = 0.02,        -- +2% damage per strength point
		defenseReduction = 0.015,          -- -1.5% damage taken per defense point
	},

	-- Targeting System Settings
	targeting = {
		selectionRange = 80, -- Maximum distance to select a target
		autoDeselectRange = 100, -- Auto-deselect if target moves this far
		showOtherPlayersTargets = false, -- Show other players' target highlights
		otherPlayerHighlightOpacity = 0.3, -- Opacity for other players' highlights
		ownTargetColor = Color3.fromRGB(255, 200, 0), -- Yellow for own target
		otherPlayerTargetColor = Color3.fromRGB(100, 150, 255), -- Blue for others
	},

	-- Stats & Leveling System
	stats = {
		-- Starting stats (4-stat system: Strength, Magic, Stamina, Accuracy)
		defaultStartingStats = {
			strength = 5,
			magic = 5,
			stamina = 5,
			accuracy = 5,
		},

		-- Stat caps
		maxStatValue = 50,          -- Maximum value for any stat
		statPointsPerLevel = 2,     -- Points players get per level

		-- Entity scaling (automatic for NPCs)
		entityStatScalingPerLevel = 0.1,  -- 10% increase per level

		-- XP rewards (base values, scale with victim level)
		xpRewards = {
			Wolf = 15,
			Bear = 30,
			Zombie = 20,
			Player = 50,  -- PvP base XP
		},
		xpLevelMultiplier = 1.5,  -- XP = baseXP * (1 + victimLevel * multiplier)

		-- Entity XP earning (configurable per entity type)
		entityCanEarnXP = {
			Wolf = false,   -- Wildlife doesn't level up
			Bear = false,
			Zombie = true,  -- Zombies can level up over time
		},

		-- Last attacker tracking
		lastAttackerExpiry = 10,  -- Seconds before attacker credit expires
	},

	-- Map Settings
	map = {
		size = 600, -- 1000x1000 studs
		campRadius = 50, -- Radius around camp center for building
		resourceSpawnRadius = 400, -- Max distance from center for resources
	},

	-- Export CombatMode enum
	CombatMode = CombatMode,
}

return GameSettings
