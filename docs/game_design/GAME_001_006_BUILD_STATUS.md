# Civic Chaos — GAME-001 / Traffic / GAME-006 Implementation Status
Date: 2026-11-06 | Branch `fix/regression-nov05` | Base `13d4c09` | **Source changes committed, engine results pending**

## Work completed in code (not accepted yet)
| Work item | Commits | Changes | Godot 4.7.2 status |
|---|---|---|---|
| GAME-001 | Existing `5ecb184`, `79b2148` | Reviewed existing soft NPC recovery + LOD source and tests; verification checklist `GAME_001_VERIFICATION.md` | **NOT RUN on latest head** |
| PHYS-010 / GAME-002 | `71f66d3` | Geometry-derived center traffic signals for expanded lanes; old 1/3/5/7 ID dependency removed | **NOT RUN** |
| PHYS-012/013 / GAME-004 | `91f6cf3` | Vehicle footprint queries now include world solids, player, cars and NPCs; ignore ground support; reject occupied spawns | **NOT RUN** |
| GAME-006 start | `5d0c5b9`, `9e8792c`, `749ffc6` | Live footpath obstruction, inspect, report, municipal service delay, collider removal, mission/HUD/city metric updates, pause-safe coordinator | **NOT RUN** |

## New executable tests
- `city_signal_stop_line_test.gd`: red/green, center city lanes >=100, outer intersection unaffected.
- `vehicle_world_obstacle_test.gd`: road floor permitted; building blocks and car resumes after it clears.
- `vehicle_spawn_occupancy_test.gd`: full car volume spawn blocked by actors and recovers when clear.
- `gameplay_session_test.gd`: report only in range, no duplicate reports, real world collider removed, single completion and idempotent rewards.

The local regression runner registers these new files. Legacy `graphics_lod_test.gd` is discovered from the workflow manifest and `building_distance_lod_test.gd` is explicitly registered; **no workflow has been manually dispatched**. Note: the repository itself has a push-triggered GitHub workflow, so ordinary commits may cause automatic CI. Do not equate the absence of a manual dispatch with a guarantee of zero Actions executions.

## Current playable tutorial (candidate)
In the real scene the session places an **orange FOOTPATH BLOCKED obstruction at (5, 0.21, -14)**. Start near (5.7, 0.25, -8); face and approach the crate, press E to inspect, press E again to report; wait for municipal response and observe the obstruction disappear. It is a modest first vertical slice, **not** the full wrong-way scenario or 3-mission campaign. Mission and city score react once to removal of an actual world collider.

## Pending work
- [ ] GAME-001 verified at latest head using Godot on PC; previous user run `927fc8f` failed forced NPC overlap (45/46).
- [ ] GAME-002/004 tests verified and any failures fixed; no ready/accepted claims yet.
- [ ] PHYS-011 opposing lane geometry and turn connectors.
- [ ] PHYS-014 crossing ownership timeout and safety.
- [ ] PHYS-015 route continuity after NPC recovery.
- [ ] GAME-006 interactive card, physical authorized helper visualization, civic-state save/restore.
- [ ] GAME-012 live wrong-way traffic mission.

## Local verification commands (Windows PowerShell)
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/pedestrian_spawn_separation_test.gd
& $godot --headless --path . --script res://tests/graphics_lod_test.gd
& $godot --headless --path . --script res://tests/building_distance_lod_test.gd
& $godot --headless --path . --script res://tests/city_signal_stop_line_test.gd
& $godot --headless --path . --script res://tests/vehicle_world_obstacle_test.gd
& $godot --headless --path . --script res://tests/vehicle_spawn_occupancy_test.gd
& $godot --headless --path . --script res://tests/gameplay_session_test.gd
python tools/run_regression.py --godot $godot --timeout 60 --report build/game-001-006-regression.json
Write-Host "Exit code: $LASTEXITCODE"
```
The separate report avoids overwriting user's locally modified `build/regression-report.json`. Any failures should be preserved verbatim for a targeted fix. Also launch the game and test actual sightline, E interaction and visible cleanup.
