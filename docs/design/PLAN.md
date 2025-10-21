# Roblox Camping Game Development Plan

## Phase 0: Core Mechanics Testing (CURRENT PHASE)

**Focus**: Test fundamental mechanics with minimal complexity
**Goal**: Establish basic resource gathering → storage → defense loop

### Core Systems
- **Resource Mining**: Wood/stone/metal nodes with tool requirements
- **Inventory Management**: 5-item limit, warehouse storage system
- **Day/Night Cycle**: 5min day / 3min night with visual transitions
- **Wildlife**: Random bears/wolves with proximity aggro
- **Basic Enemies**: Zombie spawning during night phase
- **Tool System**: Axe (wood) and pickaxe (stone/metal) with combat

### Key Features
- RTS-style resource collection and central storage
- Limited inventory forces strategic warehouse trips
- Wildlife provides environmental challenge during gathering
- Basic pathfinding enemies during night defense
- Foundation for all future building and progression systems

**See PHASE0.md for detailed implementation plan**

---

## Phase 1: Building & Defense System

### Expanded Systems
- **Building Placement**: Walls, traps within camp radius
- **Structure System**: HP, repair mechanics, destruction
- **Camp Upgrades**: Tier progression (wood → stone → metal requirements)
- **Enhanced Combat**: Weapon crafting, ranged combat
- **Resource Economy**: Balanced costs for progression

### New Features
- Wooden walls, stone fortifications, spike traps
- Building placement validation and ghost previews
- Structure damage and repair during day phases
- Crafted weapons with different damage/range stats
- Camp tier unlocks (1000 wood + 1000 stone for Tier 2)

---

## Phase 2: Progressive Difficulty & Enemies

### Enhanced Enemies
- Multiple enemy types (zombies, ogres, orcs)
- Configurable spawn waves and difficulty scaling
- Different AI behaviors (player-first vs structure-first)
- Enemy attributes system (proximity, health, damage)

### Advanced Systems
- Global leaderboard for longest survival
- Dynamic difficulty based on team performance
- Enemy drops for crafting materials
- Improved pathfinding and group behaviors

---

## Phase 3: Portal System & Victory Conditions

### Dimensional Rifts
- 5 hidden rift locations scattered across map
- Portal key collection system for ultimate victory
- Travel between dimensions to find keys and locks
- Evil camp location and portal sealing mechanics

### Advanced Magic System
- Temple discovery and spell crafting
- Elemental magic types (fire, ice, lightning, healing)
- Magic resource requirements and recipes

---

## Phase 4: Procedural Elements & Polish

### Map Generation
- Random resource node placement per session
- Variable terrain features and biomes
- Multiple campsite spawn locations

### Advanced Features
- Arrow towers with auto-targeting
- Slow fields and area effects
- Defensive structure upgrades
- Boss enemy variants

---

## Phase 5: Progression & Monetization

### Player Persistence
- Cross-session character progression
- Unlockable abilities and cosmetic customization
- Carry capacity upgrades and skill trees

### Monetization Framework
- Robux shop with cosmetic items
- Time-saver purchase options (non-pay-to-win)
- Pet system with buffs and visual effects

---

## Phase 6: Server Optimization & Social

### Scalability
- Increase player capacity beyond 5
- Server performance optimization
- Anti-cheat and exploit prevention

### Social Features
- Global leaderboards and statistics
- Matchmaking system for balanced teams
- Friends system and team formations

---

**Development Approach**: Each phase should be fully functional and playable before moving to the next. Phase 0 establishes the core mechanics foundation that all future phases will build upon.