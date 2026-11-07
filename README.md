# Civic Chaos

A Godot 4.x offline-first 3D civic-sense game about believable NPC behavior, traffic, and real-world consequences.

## Status
**Playable district prototype under development; not release verified.** The repository has a third-person player, procedural neighborhood, traffic, pedestrians, HUD, offline save/load and a connected civic story flow: footpath tutorial → wrong-way driving → illegal parking → Market Clean-Up. Latest physical gameplay, checkpoint recovery and Android builds still require local Godot 4.7.2 verification; no release acceptance is claimed.

**Current game direction:** [Game Design Document](docs/game_design/CIVIC_CHAOS_GAME_DESIGN.md) · [Phased Build Plan](docs/game_design/PHASED_BUILD_PLAN.md) · [First-Playable Backlog](docs/game_design/IMPLEMENTATION_BACKLOG.md)

First release target: one fictional Indian-inspired district, three linked civic missions (wrong-way driving, blocked footpath, market litter), visible cause-and-effect and safe citizen-led interventions. Keep the game offline-first for PC and Android.

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
- `scenes/player` — player character and camera
- `scenes/world` — procedural district and environment
- `scenes/traffic` — lanes, vehicles, intersections
- `scenes/npcs` / `scripts/npc` — NPCs and scripted behaviors
- `scenes/missions` / `scripts/civic` — mission and incident logic (player-facing integration planned)
- `scenes/ui` / `scripts/ui` — HUD, menus and touch controls
- `scripts/core` — shared contracts and registry
- `tests` — executable smoke tests

See [ROADMAP.md](ROADMAP.md) for development dependencies and acceptance gates.
