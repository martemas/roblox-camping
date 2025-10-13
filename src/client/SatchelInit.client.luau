--!strict

-- Satchel Inventory System Initialization
-- This script runs on the CLIENT via RunContext (see SatchelInit.meta.json)
-- Satchel replaces the default Roblox backpack with a modern UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for Packages to be available
local Packages = ReplicatedStorage:WaitForChild("Packages")

-- Require Satchel to initialize it
-- The module auto-initializes and replaces the default backpack when required
local Satchel = require(Packages:WaitForChild("satchel"))

print("✓ Satchel inventory system initialized")

-- Optional: Access Satchel API for customization
-- Satchel:SetBackpackEnabled(true)
-- Satchel.StateChanged.Event:Connect(function(isOpen)
--     print("Backpack is now:", isOpen and "open" or "closed")
-- end)
