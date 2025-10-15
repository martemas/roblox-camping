# Roblox Camping Game - Project Instructions

## Project Overview
This is a Roblox project using Rojo for development workflow. The project follows standard Roblox/Luau conventions and uses Rojo for syncing code between the filesystem and Roblox Studio.

## Game Concept
This game will be used as the base for many games in the future. This will be the framework and platform to build other Roblox games. The platform will provide:
- Combat mechanics - action (first person like, skill based) vs tactical (stats based damage calculations)
- Weapons mechanics - melee, aoe, hitscan, projectile, etc
- PVP/NPC support - fair system that allows fair damage calculation against/from NPCs and other players.
- Build and Create mechanics - allowing player to buy items and place those items in the game
- Data storing/state management - store players data
- Secure implementation - prevent clients from manipulating data
- Highly configurable (GameConfig for server side settings and PlayerSettings for UI related settings)
- And more ...

A cooperative survival game where 5+ players must defend their campsite against increasingly dangerous enemies that emerge from another dimension each night. Success requires teamwork, strategic planning, and resource management across multiple in-game days.

## Technology Stack
- **Language**: Luau (Roblox's typed Lua variant)
- **Build Tool**: Rojo 7.5.1 (managed via Aftman)
- **Project Structure**: Standard Roblox architecture with client/server/shared separation

## Project Structure
```
src/
├── client/          # Client-side scripts (StarterPlayerScripts)
├── server/          # Server-side scripts (ServerScriptService)
└── shared/          # Shared modules (ReplicatedStorage)
```

## Development Workflow Commands
- **Build project**: `rojo build -o "roblox-camping.rbxlx"`
- **Start Rojo server**: `rojo serve`
- **Tool management**: Use `aftman` to manage tools

## Code Conventions

### File Naming
- Use `.luau` extension for all Lua/Luau files
- Server scripts: `*.server.luau`
- Client scripts: `*.client.luau`
- Modules: `*.luau`

### Code Style
- Use tabs for indentation (based on existing codebase)
- Follow PascalCase for Roblox services and APIs
- Use camelCase for local variables and functions
- Prefer explicit typing when possible (Luau feature)

### Architecture Patterns
- **Client**: Entry point at `src/client/init.client.luau`
- **Server**: Entry point at `src/server/init.server.luau`
- **Shared**: Modules in `src/shared/` for code used by both client and server

## Roblox-Specific Guidelines

### Services
- Always use `game:GetService()` to access Roblox services
- Cache frequently used services at the top of scripts

### Remote Events/Functions
- Place RemoteEvents and RemoteFunctions in ReplicatedStorage
- Use proper naming conventions: `PascalCase` for remote objects

### Security
- Always validate inputs from clients on the server
- Never trust client data for game-critical operations
- Use FilteringEnabled (already configured in project)

### Performance
- Prefer `:Connect()` over `.Changed` when possible
- Clean up connections when objects are destroyed
- Use `:Disconnect()` to prevent memory leaks

## Testing and Building
- Test changes in Roblox Studio using `rojo serve`
- Build final place file with `rojo build` before publishing
- Always test both client and server functionality

## Important Notes
- This project uses Rojo's project format in `default.project.json`
- Workspace contains a basic baseplate configuration
- Lighting and SoundService are pre-configured
- FilteringEnabled is enabled for security

## Development Best Practices
1. Always sync changes through Rojo rather than editing directly in Studio
2. Keep client and server code separate and well-organized
3. Use shared modules for common functionality
4. Follow Roblox's security best practices
5. Test thoroughly in both Studio and published games

## Roblox Lua language

- use `vector.create` instead of `Vector3.new`
- use `vector` instead of `Vector3`


- Don't use ipairs - While ipairs is still functional in Luau (Roblox's version of Lua), newer, more generalized iteration syntax is often preferred for its flexibility and potential performance benefits, especially when dealing with tables that might not be strictly arrays (i.e., tables with non-sequential or non-numeric keys, or with nil values in the sequence). Instead use generalized iteration:

A more modern and flexible approach in Luau is to use the generalized for loop directly on the table, which essentially uses next internally. This handles both array-like and dictionary-like tables more robustly. Example of generalized iteration:
```
local mixedTable = {
    "apples",
    "oranges",
    key = "value",
    [4] = "grape", -- Explicitly setting an index
    [6] = "banana" -- Another explicit index, creating a gap
}

for index, value in mixedTable do
    print(index, value)
end
```
This generalized iteration provides a more consistent way to loop through tables regardless of their structure, making it a common and recommended practice in modern Roblox development.

- Use Roblox best practices
- Make sure the method definitions are defined before they are called.
- Run rojo build after changes to ensure there are no compilation error.

MAKE SURE
- Put client only code in either /src/client or /src/shared (ReplicatedStorage)
- Any server code or code that the client does not use or need should be stored or split into /src/server (ServerScriptStorage)