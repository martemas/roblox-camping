--!strict
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

-- Register all collision groups for the game
local function setupCollisionGroups()

    PhysicsService:RegisterCollisionGroup("Entities")

    -- Projectiles group (don't collide with themselves)
    PhysicsService:RegisterCollisionGroup("Projectiles")
    PhysicsService:CollisionGroupSetCollidable("Projectiles", "Projectiles", false)

    PhysicsService:RegisterCollisionGroup("Characters")
    PhysicsService:CollisionGroupSetCollidable("Characters", "Characters", false)

    PhysicsService:RegisterCollisionGroup("Items")
    PhysicsService:CollisionGroupSetCollidable("Items", "Entities", false)

    -- Future: Add more groups as needed
    -- PhysicsService:RegisterCollisionGroup("NPCs")
    -- PhysicsService:RegisterCollisionGroup("Buildings")
    print("✓ Collision groups registered")
end

setupCollisionGroups()


local function onDescendantAdded(descendant)
	-- Set collision group for any part descendant
	if descendant:IsA("BasePart") then
		descendant.CollisionGroup = "Characters"
	end
end

local function onCharacterAdded(character)
	-- Process existing and new descendants for physics setup
	for _, descendant in character:GetDescendants() do
		onDescendantAdded(descendant)
	end
	character.DescendantAdded:Connect(onDescendantAdded)
end

Players.PlayerAdded:Connect(function(player)
	-- Detect when the player's character is added
	player.CharacterAdded:Connect(onCharacterAdded)
end)