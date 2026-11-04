# Civic Chaos

A Godot 4.x offline-first 3D civic-sense game about believable NPC behavior, traffic, and real-world consequences.

## Status
Foundation scaffold for [CC-001](https://github.com/gauravprajapat-23/civic-chaos/issues/1). The current scene is a minimal placeholder, **not** the finished game. Player controls, traffic, NPC AI and missions are separate backlog issues.

## Open in Godot
1. Install Godot 4.x (standard, not .NET).
2. Import `project.godot` in the Project Manager.
3. Press F6 to run the current scene or F5 for the project.

## Validation
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/smoke_test.gd
```

## Architecture
- `scenes/core` — entry scene and orchestration
- `scenes/player` — player character and camera (future)
- `scenes/world` — district and environment (future)
- `scenes/traffic` — lanes, vehicles, intersections (future)
- `scenes/npcs` — NPC actors and brains (future)
- `scenes/missions` — civic mission framework (future)
- `scenes/ui` — HUD and menus (future)
- `scripts/core` — shared contracts and registry
- `tests` — executable smoke tests

See [ROADMAP.md](ROADMAP.md) for development dependencies and acceptance gates.
