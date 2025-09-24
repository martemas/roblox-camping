MVP Phase 1 Implementation Plan

  System Architecture

  1. Day/Night Cycle System (src/server/DayNightCycle.server.luau)

  Purpose: Control game timing and phase transitions

  Core Components:
  - GameState Manager: Track current phase (Day/Night), day number, time
  remaining
  - Lighting Controller: Smoothly transition between day/night lighting
  - Phase Events: Fire events when phases change to notify other systems

  Implementation Details:
  - Day duration: 300 seconds (5 minutes)
  - Night duration: 180 seconds (3 minutes)
  - Use game.Lighting.TimeOfDay for visual day/night
  - RunService.Heartbeat for countdown timer
  - RemoteEvents to sync UI countdown with clients

  2. Resource Management (src/server/ResourceManager.server.luau)

  Purpose: Handle resource spawning, collection, and inventory

  Resource Types:
  - Wood: Scattered around trees (8-12 wood nodes)
  - Stone: Near rocky areas (4-6 stone nodes)

  Implementation Details:
  - Fixed spawn locations stored in shared/GameConfig.luau
  - Resource nodes as Parts with ClickDetector
  - Player inventory stored server-side (prevent exploiting)
  - Yield 1-3 resources per collection with 30-second respawn
  - Visual feedback: shrink/hide part when depleted

  3. Enemy Spawning System (src/server/EnemySpawner.server.luau)

  Purpose: Spawn and manage zombie enemies during night phase

  Zombie Specifications:
  - Health: 50 HP
  - Speed: 8 walkspeed
  - Damage: 15 per attack
  - Spawn rate: 1 zombie every 15 seconds during night

  Implementation Details:
  - Spawn locations: 4 fixed points around map perimeter
  - Basic pathfinding using PathfindingService to campsite
  - Attack detection via Touched event with debounce
  - Clean up all enemies at dawn

  4. Building System (src/server/BuildingManager.server.luau)

  Purpose: Handle structure placement and validation

  Wooden Wall Specifications:
  - Cost: 5 wood
  - Health: 100 HP
  - Size: 4x8x1 studs
  - Placement rules: Must be on ground, not overlapping

  Implementation Details:
  - Ghost preview on client, validation on server
  - Grid-based placement system (4-stud increments)
  - Store placed structures in server dictionary
  - Structure damage system with visual feedback

  5. Combat System (src/server/CombatManager.server.luau)

  Purpose: Handle weapon creation and damage dealing

  Basic Sword:
  - Cost: 3 wood
  - Damage: 25
  - Range: 6 studs
  - Attack cooldown: 1 second

  Implementation Details:
  - Tool creation and equipping via RemoteFunction
  - Raycast-based melee detection
  - Damage validation server-side
  - Simple swing animation

  Client-Side Components

  6. UI System (src/client/UI/)

  Main HUD Elements:
  - Resource Counter: Wood/Stone quantities
  - Health Bar: Player health (100 max)
  - Phase Timer: Countdown to next phase
  - Crafting Panel: Available recipes

  Files Structure:
  src/client/UI/
  ├── MainHUD.client.luau
  ├── CraftingUI.client.luau
  └── GameUI.client.luau

  7. Input Handler (src/client/InputHandler.client.luau)

  Purpose: Handle building placement and crafting inputs

  Key Bindings:
  - B: Toggle building mode
  - C: Open crafting menu
  - Mouse Click: Place structure/collect resource

  Shared Components

  8. Game Configuration (src/shared/GameConfig.luau)

  Contains:
  - Resource spawn locations (Vector3 positions)
  - Enemy spawn points
  - Campsite center location
  - Recipe definitions
  - Game balance values

  9. Remote Events (src/shared/RemoteEvents.luau)

  Event Definitions:
  - CollectResource: Player → Server
  - CraftItem: Player → Server
  - PlaceStructure: Player → Server
  - PhaseChanged: Server → All Players
  - UpdateInventory: Server → Player

  Map Layout

  10. Basic Map Structure

  Campsite (Center):
  - 20x20 stud cleared area
  - SpawnLocation for players
  - Campfire model (visual landmark)

  Resource Distribution:
  - Wood nodes: Scattered within 50-100 studs of campsite
  - Stone nodes: Concentrated in 2-3 rocky areas
  - Enemy spawns: 80-120 studs from campsite

  Terrain:
  - Flat baseplate with basic terrain
  - Some trees and rocks for atmosphere
  - Clear sight lines for defense planning

  Win/Lose Conditions

  11. Game State Manager (src/server/GameStateManager.server.luau)

  Victory: All players survive 3 complete day/night cycles
  Defeat: All players die during any night phase

  Implementation:
  - Track living players count
  - Monitor day progression
  - Handle player respawning (unlimited during day, none during night)
  - End game and return to lobby on win/lose

  Technical Specifications

  Performance Targets

  - Support 5 concurrent players smoothly
  - Maximum 50 active enemy instances
  - Resource nodes: 15 maximum simultaneously
  - Structures: 100 maximum per game

  Security Considerations

  - All game state on server
  - Client sends requests, server validates
  - Sanity checks on all RemoteEvent parameters
  - Rate limiting on resource collection

  This implementation focuses on core survival mechanics while keeping
  complexity manageable for MVP testing and iteration.