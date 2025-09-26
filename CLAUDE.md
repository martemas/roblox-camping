# Roblox Camping Game - Project Instructions

## Project Overview
This is a Roblox camping game project using Rojo for development workflow. The project follows standard Roblox/Luau conventions and uses Rojo for syncing code between the filesystem and Roblox Studio.

## Game Concept
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

use `vector.create` instead of `Vector3.new`
use `vector` instead of `Vector3`