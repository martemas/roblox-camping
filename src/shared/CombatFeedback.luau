--!strict

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local PlayerSettingsManager = require(script.Parent:WaitForChild("PlayerSettingsManager"))

local CombatFeedback = {}

-- Damage type for color coding
export type DamageType = "self" | "other_player" | "incoming" | "dodge" | "miss" | "blocked" | "critical"

-- Create floating damage/feedback text above any entity (player or NPC)
function CombatFeedback.showDamage(
	targetModel: Model,
	damage: number?,
	damageSource: string?,
	damageType: DamageType?,
	attackerModel: Model? -- Changed from attackingPlayer to support all entity types
)
	local humanoidRootPart = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	-- Determine color and text based on damage type
	local textColor: Color3
	local displayText: string
	local isCritical = damageType == "critical"

	if isCritical then
		-- CRITICAL HIT! (special display)
		textColor = Color3.fromRGB(255, 215, 0) -- Gold
		displayText = "CRITICAL! -" .. tostring(math.floor(damage or 0))
	elseif damageType == "dodge" then
		-- Target dodged the attack
		textColor = Color3.fromRGB(255, 255, 100) -- Yellow
		displayText = "DODGED!"
	elseif damageType == "blocked" then
		-- Attack blocked due to facing requirement
		textColor = Color3.fromRGB(255, 150, 0) -- Orange
		displayText = "NOT FACING"
	elseif damageType == "miss" then
		-- Attack missed
		textColor = Color3.fromRGB(200, 200, 200) -- Gray
		displayText = "MISS"
	elseif damageType == "self" then
		-- Damage you dealt (your attacks on entities)
		textColor = Color3.fromRGB(255, 255, 100) -- Yellow
		displayText = "-" .. tostring(math.floor(damage or 0))
	elseif damageType == "other_player" then
		-- Damage dealt by another player
		textColor = Color3.fromRGB(150, 150, 150) -- Gray
		displayText = "-" .. tostring(math.floor(damage or 0))
	elseif damageType == "incoming" then
		-- Damage dealt to you
		textColor = Color3.fromRGB(255, 100, 100) -- Red
		displayText = "-" .. tostring(math.floor(damage or 0))
	else
		-- Default damage color (fallback)
		textColor = Color3.fromRGB(255, 150, 150) -- Light red
		displayText = "-" .. tostring(math.floor(damage or 0))
	end

	-- Derive attacking player from attacker model (if it's a player character)
	local attackingPlayer: Player? = nil
	if attackerModel then
		attackingPlayer = Players:GetPlayerFromCharacter(attackerModel)
	end

	-- Check visibility settings for all players
	for _, player in Players:GetPlayers() do
		local settings = PlayerSettingsManager.getPlayerSettings(player)
		if not settings then
			continue
		end

		local shouldShow = false

		-- Check if player should see this damage number
		if not settings.ui.damage.showDamageNumbers then
			-- Player has damage numbers disabled completely
			continue
		end

		-- Determine if this damage should be shown to this player
		if damageType == "incoming" then
			-- Always show damage to the player being hit
			if targetModel == player.Character then
				shouldShow = true
			end
		elseif damageType == "dodge" then
			-- Always show dodge to the player who dodged
			if targetModel == player.Character then
				shouldShow = true
			end
		elseif damageType == "blocked" then
			-- Show blocked to the attacking player
			if attackingPlayer == player then
				shouldShow = true
			end
		elseif damageType == "self" then
			-- Show damage dealt by this player
			if attackingPlayer == player and settings.ui.damage.showOwnDamage then
				shouldShow = true
			end
		elseif damageType == "other_player" then
			-- Show damage dealt by other players (if enabled)
			if attackingPlayer ~= player and settings.ui.damage.showOtherPlayerDamage then
				shouldShow = true
			end
		elseif damageType == "miss" then
			-- Show miss to the attacking player
			if attackingPlayer == player then
				shouldShow = true
			end
		end

		if not shouldShow then
			continue
		end

		-- Create BillboardGui for damage display (client-side only for this player)
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Size = UDim2.new(0, 200, 0, 50)
		billboardGui.StudsOffset = vector.create(0, 2, 0)
		billboardGui.Adornee = humanoidRootPart
		billboardGui.Parent = player:WaitForChild("PlayerGui")

		-- Create damage text label
		local damageLabel = Instance.new("TextLabel")
		damageLabel.Size = UDim2.new(1, 0, 1, 0)
		damageLabel.BackgroundTransparency = 1
		damageLabel.Text = displayText
		damageLabel.TextColor3 = textColor
		damageLabel.TextScaled = true
		damageLabel.Font = Enum.Font.SourceSansBold
		damageLabel.TextStrokeTransparency = 0
		damageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		damageLabel.Parent = billboardGui

		-- Get animation duration from player settings
		local animDuration = settings.ui.damage.animationDuration or 1.5
		local scale = settings.ui.damage.damageNumberScale or 1.0

		-- Make critical hits 50% larger
		if isCritical then
			scale = scale * 1.5
		end

		-- Adjust size based on scale
		billboardGui.Size = UDim2.new(0, 200 * scale, 0, 50 * scale)

		-- Animate the damage number
		local tweenInfo = TweenInfo.new(
			animDuration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

		-- Tween upward movement and fade
		local tween = TweenService:Create(billboardGui, tweenInfo, {
			StudsOffset = vector.create(math.random(-1, 1), 4, math.random(-1, 1))
		})

		local fadeTween = TweenService:Create(damageLabel, tweenInfo, {
			TextTransparency = 1,
			TextStrokeTransparency = 1
		})

		-- Start animations
		tween:Play()
		fadeTween:Play()

		-- Clean up after animation
		Debris:AddItem(billboardGui, animDuration)
	end
end

-- Play hit sound effect on target
function CombatFeedback.playHitSound(targetModel: Model, soundName: string?)
	local humanoidRootPart = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	local sound = humanoidRootPart:FindFirstChild(soundName or "Hit")
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = 1 + (math.random() * 0.2 - 0.1) -- Slight pitch variation
		sound:Play()
	end
end

-- Show attack telegraph (visual indicator for incoming attacks)
-- For Phase 1, this is a placeholder - we rely on animation visibility
function CombatFeedback.showAttackTelegraph(
	attackerModel: Model,
	targetModel: Model,
	weaponName: string,
	duration: number
)
	-- Phase 1: Rely on animation visibility
	-- Phase 2+: Add particle effects, ground decals, etc.
	-- This function exists for future expansion
end

return CombatFeedback