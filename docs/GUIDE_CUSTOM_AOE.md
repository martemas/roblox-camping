# Custom AOE Weapons - Advanced Setup Guide

## Overview

Custom AOE weapons allow you to create **non-circular damage areas** with custom shapes and mechanics. This guide covers how to implement cone attacks, rectangular zones, chain lightning, and other complex AOE patterns.

**What are Custom AOE Weapons?**
- **Custom shapes** - Cone, rectangle, line, wall, etc. (not just circles)
- **Custom mechanics** - Chain lightning, bouncing attacks, dynamic scaling
- **Full control** - You define hitbox detection and visual effects
- **Integrated damage** - Uses core combat system for validation and feedback

**When to Use:**
- ❌ Standard circular AOE → Use config-driven AOE (see GUIDE_AOE.md)
- ✅ Non-circular shapes (cone, rectangle, line)
- ✅ Chain/bounce mechanics
- ✅ Custom damage calculations
- ✅ Special visual effects
- ✅ Complex targeting logic

---

## Architecture Overview

### Two-Tier AOE System

**Tier 1: Standard AOE** (90% of weapons)
```lua
-- Config-driven, circular radius
Fireball = {
    type = "aoe",
    aoeRadius = 15,
    aoeDamage = 50,
    -- CombatSystem.performAOEAttack() handles everything
}
```

**Tier 2: Custom AOE** (complex weapons)
```
Tool (DragonBreathSpell)
  ├── Handle (visual mesh)
  ├── CustomAOEScript (Script) ← Your custom detection logic
  └── Configuration (weapon stats in GameConfig)
```

### How Custom AOE Works

```
┌─────────────────────────────────────────┐
│ Your Custom Tool Script                 │
├─────────────────────────────────────────┤
│ 1. Define hitbox shape (cone/rect/etc) │
│ 2. Show custom telegraph visual         │
│ 3. Wait castDuration (dodge window)     │
│ 4. Find entities in custom shape        │
│ 5. Call applyDamageToEntity() for each  │
└─────────────────────────────────────────┘
                    ↓
     ┌──────────────────────────────┐
     │ CombatSystem.applyDamageToEntity │
     ├──────────────────────────────┤
     │ ✅ Validates PvP              │
     │ ✅ Checks invulnerability     │
     │ ✅ Calculates damage          │
     │ ✅ Shows feedback             │
     │ ✅ Sets invulnerability       │
     └──────────────────────────────┘
```

---

## Core API: applyDamageToEntity()

### Purpose

Low-level API for applying damage to a single entity. All custom AOE weapons use this.

### Signature

```lua
function CombatSystem.applyDamageToEntity(
    attacker: Model,
    target: Model,
    weaponName: string,
    options: {
        damageOverride: number?,        -- Custom damage per entity
        hitPosition: Vector3?,          -- Where target was hit
        bypassInvulnerability: boolean?, -- Skip invuln check (use carefully)
    }?
): boolean
```

### What It Does ✅

- Validates PvP rules
- Checks invulnerability frames
- Calculates damage via DamageCalculator
- Shows CombatFeedback (damage numbers, effects)
- Sets invulnerability frames
- Returns true if damage applied

### What It Does NOT Do ❌

- Find targets (your script does this)
- Create visual effects (your script does this)
- Handle telegraphs (your script does this)

### Example Usage

```lua
-- Apply 50 damage to entity
CombatSystem.applyDamageToEntity(
    attacker,
    targetEntity,
    "DragonBreath",
    {
        damageOverride = 50,
        hitPosition = targetEntity.HumanoidRootPart.Position,
    }
)
```

---

## Implementation Guide: Cone Attack

### Step 1: Create Weapon Config

Add to `GameConfig.weapons`:

```lua
DragonBreath = {
    type = "aoe",              -- Still type "aoe" for classification
    name = "Dragon Breath",
    customDetection = true,    -- Flag as custom AOE

    -- Custom shape properties
    coneRange = 25,           -- How far cone extends
    coneAngle = 60,           -- Total cone angle (degrees)
    aoeDamage = 40,

    -- Standard properties
    castDuration = 1.5,
    cooldown = 10.0,
}
```

### Step 2: Create Tool Structure

```
ReplicatedStorage/Tools/
└── DragonBreathSpell (Tool)
    ├── Handle (MeshPart - dragon head visual)
    └── DragonBreathScript (Script)
```

### Step 3: Implement Custom Detection Script

**File:** `DragonBreathScript.luau` (inside Tool)

```lua
--!strict

local Tool = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatSystem = require(ReplicatedStorage.Engine.CombatSystem)
local GameConfig = require(ReplicatedStorage.Engine.GameConfig)

local weaponName = "DragonBreath"
local weaponConfig = GameConfig.weapons[weaponName]

-- Helper: Find entity from part
local function findEntityFromPart(part: BasePart): Model?
    local current = part.Parent
    while current and current ~= workspace do
        if current:IsA("Model") then
            -- Check if it's a player character
            local player = Players:GetPlayerFromCharacter(current)
            if player then
                return current
            end

            -- Check if it's an NPC with EntityType attribute
            local entityType = current:GetAttribute("EntityType")
            if entityType then
                return current
            end
        end
        current = current.Parent
    end
    return nil
end

-- Custom cone detection
local function findEntitiesInCone(
    origin: Vector3,
    direction: Vector3,
    range: number,
    angleDegrees: number
): {Model}
    local entitiesHit: {Model} = {}

    -- Get all entities in sphere first (optimization)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Tool.Parent} -- Exclude player

    local parts = workspace:GetPartBoundsInRadius(origin, range, params)

    -- Filter to cone shape
    local seenEntities: {[Model]: boolean} = {}
    local angleThreshold = math.cos(math.rad(angleDegrees / 2))

    for _, part in parts do
        local entity = findEntityFromPart(part)

        if entity and not seenEntities[entity] then
            seenEntities[entity] = true

            local entityRoot = entity:FindFirstChild("HumanoidRootPart")
            if entityRoot then
                -- Check if entity is within cone angle
                local toEntity = (entityRoot.Position - origin).Unit
                local dotProduct = direction:Dot(toEntity)

                if dotProduct >= angleThreshold then
                    -- Entity is in cone, check distance
                    local distance = (entityRoot.Position - origin).Magnitude
                    if distance <= range then
                        table.insert(entitiesHit, entity)
                    end
                end
            end
        end
    end

    return entitiesHit
end

-- Show cone telegraph
local function showConeTelegraph(
    origin: Vector3,
    direction: Vector3,
    range: number,
    angleDegrees: number,
    duration: number
)
    -- Create wedge Part to visualize cone
    local wedge = Instance.new("WedgePart")
    wedge.Anchored = true
    wedge.CanCollide = false
    wedge.Transparency = 0.5
    wedge.Material = Enum.Material.Neon
    wedge.Color = Color3.fromRGB(255, 100, 50) -- Orange/red for fire

    -- Calculate wedge dimensions
    local width = range * math.tan(math.rad(angleDegrees / 2)) * 2
    wedge.Size = Vector3.new(width, 1, range)

    -- Position and orient wedge
    local cframe = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -range / 2)
    wedge.CFrame = cframe * CFrame.Angles(0, math.rad(180), 0) -- Flip wedge
    wedge.Parent = workspace

    -- Pulse animation
    local tween = TweenService:Create(
        wedge,
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Transparency = 0.8}
    )
    tween:Play()

    -- Add particle effect
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
    particles.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0))
    particles.Size = NumberSequence.new(2)
    particles.Transparency = NumberSequence.new(0.5)
    particles.Lifetime = NumberRange.new(0.5)
    particles.Rate = 50
    particles.Parent = wedge

    Debris:AddItem(wedge, duration)
end

-- Tool activation
Tool.Activated:Connect(function()
    local player = Players:GetPlayerFromCharacter(Tool.Parent)
    local character = Tool.Parent
    if not character then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    -- Get attack parameters
    local origin = humanoidRootPart.Position + Vector3.new(0, 2, 0) -- Chest height
    local direction = humanoidRootPart.CFrame.LookVector

    -- Show telegraph (warning for targets to dodge)
    showConeTelegraph(
        origin,
        direction,
        weaponConfig.coneRange,
        weaponConfig.coneAngle,
        weaponConfig.castDuration
    )

    -- Wait for cast duration (dodge window)
    task.wait(weaponConfig.castDuration)

    -- Find entities in cone
    local entitiesHit = findEntitiesInCone(
        origin,
        direction,
        weaponConfig.coneRange,
        weaponConfig.coneAngle
    )

    -- Apply damage to each entity via central system
    for _, entity in entitiesHit do
        CombatSystem.applyDamageToEntity(
            character,
            entity,
            weaponName,
            {
                damageOverride = weaponConfig.aoeDamage,
                hitPosition = entity:FindFirstChild("HumanoidRootPart").Position,
            }
        )
    end

    print(`DragonBreath hit {#entitiesHit} entities in cone`)
end)
```

---

## Custom Shape Examples

### Example 1: Rectangle (Wall of Fire)

**Use Case:** Create a wall of fire perpendicular to aim direction

**Config:**
```lua
WallOfFire = {
    type = "aoe",
    name = "Wall of Fire",
    customDetection = true,
    wallLength = 20,      -- Length of wall
    wallWidth = 2,        -- Width (thickness)
    aoeDamage = 15,
    duration = 6.0,       -- Wall lasts 6 seconds
    tickRate = 0.5,       -- Damage every 0.5 seconds
    castDuration = 1.0,
    cooldown = 12.0,
}
```

**Detection Function:**
```lua
local function findEntitiesInRectangle(
    position: Vector3,
    direction: Vector3,
    length: number,
    width: number
): {Model}
    local entitiesHit: {Model} = {}

    -- Create oriented bounding box
    local rightVector = direction:Cross(Vector3.new(0, 1, 0)).Unit
    local halfLength = length / 2
    local halfWidth = width / 2

    -- Get entities in area
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Tool.Parent}

    local parts = workspace:GetPartBoundsInRadius(position, math.max(length, width), params)

    local seenEntities: {[Model]: boolean} = {}

    for _, part in parts do
        local entity = findEntityFromPart(part)
        if entity and not seenEntities[entity] then
            seenEntities[entity] = true

            local entityRoot = entity:FindFirstChild("HumanoidRootPart")
            if entityRoot then
                -- Convert to local space
                local toEntity = entityRoot.Position - position
                local forwardDist = toEntity:Dot(direction)
                local rightDist = toEntity:Dot(rightVector)

                -- Check if within rectangle bounds
                if math.abs(forwardDist) <= halfLength and math.abs(rightDist) <= halfWidth then
                    table.insert(entitiesHit, entity)
                end
            end
        end
    end

    return entitiesHit
end
```

**Telegraph Visual:**
```lua
local function showRectangleTelegraph(position, direction, length, width, duration)
    local part = Instance.new("Part")
    part.Size = Vector3.new(width, 0.5, length)
    part.CFrame = CFrame.new(position, position + direction) * CFrame.new(0, 0, -length / 2)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.5
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(255, 100, 0)
    part.Parent = workspace

    Debris:AddItem(part, duration)
end
```

---

### Example 2: Line (Piercing Laser)

**Use Case:** Laser beam that pierces through multiple enemies

**Config:**
```lua
PiercingLaser = {
    type = "aoe",
    name = "Piercing Laser",
    customDetection = true,
    lineRange = 50,
    lineWidth = 2,
    maxPierceTargets = 5,
    aoeDamage = 35,
    castDuration = 0.8,
    cooldown = 4.0,
}
```

**Detection Function:**
```lua
local function findEntitiesInLine(
    origin: Vector3,
    direction: Vector3,
    range: number,
    width: number,
    maxTargets: number
): {Model}
    local entitiesHit: {Model} = {}
    local hitCount = 0

    -- Step along line checking for entities
    local step = width / 2
    local steps = math.ceil(range / step)

    local seenEntities: {[Model]: boolean} = {}

    for i = 1, steps do
        if hitCount >= maxTargets then break end

        local checkPos = origin + (direction * (step * i))

        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {Tool.Parent}

        local parts = workspace:GetPartBoundsInRadius(checkPos, width, params)

        for _, part in parts do
            local entity = findEntityFromPart(part)
            if entity and not seenEntities[entity] then
                seenEntities[entity] = true
                table.insert(entitiesHit, entity)
                hitCount = hitCount + 1

                if hitCount >= maxTargets then break end
            end
        end
    end

    return entitiesHit
end
```

---

### Example 3: Chain Lightning

**Use Case:** Lightning that bounces between enemies with decreasing damage

**Config:**
```lua
ChainLightning = {
    type = "aoe",
    name = "Chain Lightning",
    customDetection = true,
    initialDamage = 50,
    bounceCount = 3,
    bounceRange = 15,
    damageFalloff = 0.7,  -- Each bounce does 70% of previous
    castDuration = 0.8,
    cooldown = 6.0,
}
```

**Detection Logic:**
```lua
Tool.Activated:Connect(function()
    local character = Tool.Parent
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    local origin = humanoidRootPart.Position + Vector3.new(0, 2, 0)
    local direction = humanoidRootPart.CFrame.LookVector

    -- Find first target
    local firstTarget = findClosestEnemy(origin, direction, 30)
    if not firstTarget then
        print("No initial target found")
        return
    end

    -- Hit initial target
    local hitTargets: {[Model]: boolean} = {}
    CombatSystem.applyDamageToEntity(
        character,
        firstTarget,
        weaponName,
        {damageOverride = weaponConfig.initialDamage}
    )
    hitTargets[firstTarget] = true

    -- Show lightning to first target
    showLightningBeam(origin, firstTarget.HumanoidRootPart.Position)

    -- Chain to nearby enemies
    local previousTarget = firstTarget
    local currentDamage = weaponConfig.initialDamage * weaponConfig.damageFalloff

    for i = 1, weaponConfig.bounceCount do
        task.wait(0.1) -- Brief delay between bounces

        -- Find next target (closest enemy not hit yet)
        local nextTarget = findClosestEnemyExcluding(
            previousTarget.HumanoidRootPart.Position,
            weaponConfig.bounceRange,
            hitTargets
        )

        if nextTarget then
            -- Apply damage
            CombatSystem.applyDamageToEntity(
                character,
                nextTarget,
                weaponName,
                {damageOverride = currentDamage}
            )
            hitTargets[nextTarget] = true

            -- Show lightning beam
            showLightningBeam(
                previousTarget.HumanoidRootPart.Position,
                nextTarget.HumanoidRootPart.Position
            )

            previousTarget = nextTarget
            currentDamage = currentDamage * weaponConfig.damageFalloff
        else
            break -- No more targets in range
        end
    end
end)

-- Helper: Find closest enemy excluding already hit targets
local function findClosestEnemyExcluding(
    position: Vector3,
    range: number,
    excludeList: {[Model]: boolean}
): Model?
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Tool.Parent}

    local parts = workspace:GetPartBoundsInRadius(position, range, params)

    local closestEntity: Model? = nil
    local closestDistance = math.huge

    local seenEntities: {[Model]: boolean} = {}

    for _, part in parts do
        local entity = findEntityFromPart(part)
        if entity and not seenEntities[entity] and not excludeList[entity] then
            seenEntities[entity] = true

            local entityRoot = entity:FindFirstChild("HumanoidRootPart")
            if entityRoot then
                local distance = (entityRoot.Position - position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestEntity = entity
                end
            end
        end
    end

    return closestEntity
end

-- Visual: Lightning beam between two points
local function showLightningBeam(startPos: Vector3, endPos: Vector3)
    local beam = Instance.new("Part")
    beam.Size = Vector3.new(0.3, 0.3, (endPos - startPos).Magnitude)
    beam.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -beam.Size.Z / 2)
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = Color3.fromRGB(100, 200, 255)
    beam.Transparency = 0.3
    beam.Parent = workspace

    -- Flicker effect
    task.spawn(function()
        for i = 1, 5 do
            beam.Transparency = 0.3
            task.wait(0.05)
            beam.Transparency = 0.7
            task.wait(0.05)
        end
        beam:Destroy()
    end)
end
```

---

### Example 4: Ring Expansion

**Use Case:** Expanding shockwave that grows outward from player

**Config:**
```lua
Shockwave = {
    type = "aoe",
    name = "Shockwave",
    customDetection = true,
    maxRadius = 25,
    expansionSpeed = 20,  -- Studs per second
    aoeDamage = 30,
    castDuration = 0.5,
    cooldown = 8.0,
}
```

**Detection Logic:**
```lua
Tool.Activated:Connect(function()
    local character = Tool.Parent
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    local origin = humanoidRootPart.Position

    task.wait(weaponConfig.castDuration)

    -- Expand ring outward
    local currentRadius = 0
    local hitEntities: {[Model]: boolean} = {}

    while currentRadius < weaponConfig.maxRadius do
        local deltaTime = task.wait()
        currentRadius = currentRadius + (weaponConfig.expansionSpeed * deltaTime)

        -- Find entities at current radius (ring, not full circle)
        local ringThickness = 3
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {character}

        local parts = workspace:GetPartBoundsInRadius(origin, currentRadius, params)

        for _, part in parts do
            local entity = findEntityFromPart(part)
            if entity and not hitEntities[entity] then
                local entityRoot = entity:FindFirstChild("HumanoidRootPart")
                if entityRoot then
                    local distance = (entityRoot.Position - origin).Magnitude

                    -- Check if entity is at current ring position
                    if distance >= (currentRadius - ringThickness) and distance <= currentRadius then
                        hitEntities[entity] = true

                        CombatSystem.applyDamageToEntity(
                            character,
                            entity,
                            weaponName,
                            {damageOverride = weaponConfig.aoeDamage}
                        )
                    end
                end
            end
        end

        -- Visual: Show expanding ring
        showRing(origin, currentRadius)
    end
end)
```

---

## Best Practices

### 1. Always Use applyDamageToEntity()

**❌ DON'T:**
```lua
-- Bypasses all game rules!
targetHumanoid:TakeDamage(50)
```

**✅ DO:**
```lua
-- Validates PvP, invulnerability, shows feedback
CombatSystem.applyDamageToEntity(
    attacker,
    target,
    weaponName,
    {damageOverride = 50}
)
```

---

### 2. Validate Input Parameters

```lua
-- Validate weapon config exists
local weaponConfig = GameConfig.weapons[weaponName]
if not weaponConfig then
    warn(`Weapon {weaponName} not found`)
    return
end

-- Validate custom properties
if not weaponConfig.coneRange or not weaponConfig.coneAngle then
    warn(`DragonBreath missing required properties`)
    return
end
```

---

### 3. Show Clear Telegraphs

```lua
-- Players should see the attack coming
showConeTelegraph(origin, direction, range, angle, castDuration)

-- Give players time to dodge
task.wait(castDuration)

-- Then apply damage
for _, entity in entitiesHit do
    CombatSystem.applyDamageToEntity(...)
end
```

---

### 4. Use Spatial Filtering (Optimization)

```lua
-- First: Filter by sphere (cheap, built-in)
local parts = workspace:GetPartBoundsInRadius(origin, maxRange, params)

-- Then: Filter by custom shape (cone, rectangle, etc.)
for _, part in parts do
    local entity = findEntityFromPart(part)

    if isInCone(entity, origin, direction, angle) then
        -- Process entity
    end
end
```

---

### 5. Avoid Hitting Same Entity Multiple Times

```lua
local hitEntities: {[Model]: boolean} = {}

for _, part in parts do
    local entity = findEntityFromPart(part)

    if entity and not hitEntities[entity] then
        hitEntities[entity] = true
        -- Apply damage once per entity
        CombatSystem.applyDamageToEntity(...)
    end
end
```

---

### 6. Limit Max Targets

```lua
local hitCount = 0
local maxTargets = weaponConfig.maxTargets or 10

for _, entity in potentialTargets do
    if hitCount >= maxTargets then
        break
    end

    CombatSystem.applyDamageToEntity(...)
    hitCount = hitCount + 1
end
```

---

## Server-Side Validation (Optional)

For server-authoritative custom AOE, use RemoteEvents:

### Client Tool Script

```lua
Tool.Activated:Connect(function()
    -- Show telegraph immediately (client-side prediction)
    showConeTelegraph(...)

    -- Request server to perform attack
    local RemoteEvents = require(ReplicatedStorage.Engine.RemoteEvents)
    RemoteEvents.Events.PerformCustomAOE:FireServer(
        weaponName,
        origin,
        direction
    )
end)
```

### Server Script

```lua
local RemoteEvents = require(ReplicatedStorage.Engine.RemoteEvents)

RemoteEvents.Events.PerformCustomAOE.OnServerEvent:Connect(function(
    player,
    weaponName,
    origin,
    direction
)
    local character = player.Character
    if not character then return end

    -- Validate cooldown, range, etc.
    -- ... validation logic

    -- Find entities (same logic as client)
    local entitiesHit = findEntitiesInCone(
        origin,
        direction,
        weaponConfig.coneRange,
        weaponConfig.coneAngle
    )

    -- Apply damage (server-authoritative)
    for _, entity in entitiesHit do
        CombatSystem.applyDamageToEntity(
            character,
            entity,
            weaponName,
            {damageOverride = weaponConfig.aoeDamage}
        )
    end
end)
```

---

## Helper Functions Library

### Find Closest Enemy

```lua
local function findClosestEnemy(
    origin: Vector3,
    direction: Vector3,
    maxRange: number
): Model?
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Tool.Parent}

    local parts = workspace:GetPartBoundsInRadius(origin, maxRange, params)

    local closestEntity: Model? = nil
    local closestDistance = math.huge
    local seenEntities: {[Model]: boolean} = {}

    for _, part in parts do
        local entity = findEntityFromPart(part)
        if entity and not seenEntities[entity] then
            seenEntities[entity] = true

            local entityRoot = entity:FindFirstChild("HumanoidRootPart")
            if entityRoot then
                -- Check if in forward direction
                local toEntity = (entityRoot.Position - origin).Unit
                local dotProduct = direction:Dot(toEntity)

                if dotProduct > 0.5 then -- Within 60 degree cone
                    local distance = (entityRoot.Position - origin).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestEntity = entity
                    end
                end
            end
        end
    end

    return closestEntity
end
```

### Check Point in Cone

```lua
local function isPointInCone(
    point: Vector3,
    coneOrigin: Vector3,
    coneDirection: Vector3,
    coneRange: number,
    coneAngleDegrees: number
): boolean
    local toPoint = point - coneOrigin
    local distance = toPoint.Magnitude

    if distance > coneRange then
        return false
    end

    local dotProduct = coneDirection:Dot(toPoint.Unit)
    local angleThreshold = math.cos(math.rad(coneAngleDegrees / 2))

    return dotProduct >= angleThreshold
end
```

### Check Point in Rectangle

```lua
local function isPointInRectangle(
    point: Vector3,
    rectPosition: Vector3,
    rectDirection: Vector3,
    length: number,
    width: number
): boolean
    local rightVector = rectDirection:Cross(Vector3.new(0, 1, 0)).Unit
    local toPoint = point - rectPosition

    local forwardDist = toPoint:Dot(rectDirection)
    local rightDist = toPoint:Dot(rightVector)

    local halfLength = length / 2
    local halfWidth = width / 2

    return math.abs(forwardDist) <= halfLength and math.abs(rightDist) <= halfWidth
end
```

---

## Comparison: Standard vs Custom AOE

| Feature | Standard AOE | Custom AOE |
|---------|--------------|------------|
| **Shape** | Circular only | Any shape (cone, rect, line, etc.) |
| **Setup** | Config-driven | Script-driven |
| **Detection** | Automatic | Manual (your code) |
| **Visuals** | Built-in telegraph | Custom (your code) |
| **Damage** | `performAOEAttack()` | `applyDamageToEntity()` per entity |
| **Complexity** | Simple | Advanced |
| **Use Cases** | 90% of weapons | Complex/unique attacks |

---

## When to Use Custom AOE

### Use Standard AOE When:
- ✅ Simple circular/spherical radius
- ✅ Standard falloff behavior
- ✅ No special mechanics
- ✅ Config properties are sufficient

### Use Custom AOE When:
- ✅ Non-circular shapes (cone, rectangle, line, etc.)
- ✅ Chain/bounce mechanics
- ✅ Custom damage calculations
- ✅ Special visual effects
- ✅ Complex targeting logic
- ✅ Expanding/moving AOE zones

---

## Benefits of Custom AOE System

### For Developers
- Full control over hitbox detection
- Custom visual effects
- Unique spell mechanics
- Reuses damage validation/calculation/feedback
- No need to modify core systems

### For Players
- Unique, interesting spells
- Consistent damage rules (PvP, invulnerability work the same)
- Clear visual feedback (telegraphs, effects)
- Fair gameplay (dodge windows, telegraphs)

### For Game Balance
- Central damage system enforces rules
- No bypassing invulnerability or PvP settings
- DamageCalculator applies to all custom spells
- Server can validate custom AOE

---

## Summary

Custom AOE weapons provide maximum flexibility while maintaining game integrity:

- ✅ **Any shape** - Cone, rectangle, line, chain, ring, custom
- ✅ **Full control** - Your detection logic, your visuals
- ✅ **Integrated** - Uses core combat system for damage
- ✅ **Balanced** - PvP rules, invulnerability, feedback all work
- ✅ **Extensible** - Add new shapes without modifying core code

**Key Principle:** You handle detection and visuals, `applyDamageToEntity()` handles everything else.

Start with the cone example and adapt to your specific shape and mechanics!
