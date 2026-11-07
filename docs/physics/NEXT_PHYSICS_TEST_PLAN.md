# Civic Chaos — Next Physics Regression Plan
Date: 2026-11-06 | branch: `fix/regression-nov05` | baseline: `5ecb184`

## Verification precedence
Before any other fixes, rerun the **existing** `tests/pedestrian_spawn_separation_test.gd` on Godot 4.7.2. Previous submitted full run at `927fc8f` had exactly one failure on this test; follow-up source fix `5ecb184` remains unverified. If this test fails, capture the new position diagnostics and keep PHYS-002 open.

## Proposed executable tests (not yet created or run)
| ID | Suggested test | Setup / assertion |
|---|---|---|
| PHYS-010 | `tests/city_signal_stop_line_test.gd` | Generate city graph, choose an inbound lane ID >=100, advance red/green phases, verify release at green and actual vehicle crossing beyond first route leg |
| PHYS-011 | `tests/two_way_lane_separation_test.gd` | Place two oncoming car colliders at opposite ends of one bidirectional road; verify lateral separation >= combined half-width plus margin and both complete |
| PHYS-012 | `tests/vehicle_world_obstacle_test.gd` | Put building, tree/pole and boundary collider directly on a route; assert car stops short; ensure road surface itself does not falsely block |
| PHYS-013 | `tests/vehicle_spawn_occupancy_test.gd` | Spawn lane occupied by player, NPC, oriented car, world prop; assert reject, no one-tick overlap, deterministic demand counts |
| PHYS-014 | `tests/pedestrian_crossing_recovery_test.gd` | Reserve zone, block pedestrian with player, advance beyond reservation window, confirm no occupied zone is forgotten and waiting walkers recover safely |
| PHYS-015 | `tests/pedestrian_recovery_continuity_test.gd` | Force 2 NPC + player overlap, record every movement delta/ground support, verify no pop-through wall or route snap with 30/60/120 Hz |
| PHYS-016 | `tests/player_recovery_exhaustion_test.gd` | Make seven safe-spawn candidates unavailable, drop player to y=-9 and check deterministic recoverable outcome |
| PHYS-017 | `tests/pedestrian_spawn_world_test.gd` | Add static prop under normal pedestrian route and vehicle at spawn; reject or choose supported unoccupied alternative |
| PHYS-018 | `tests/live_traffic_deadlock_test.gd` | Trigger 2–4-car intersection blockage in playable scene, observe wait edges, verify replay-safe recovery |
| PHYS-019 | `tests/city_physics_soak_test.gd` | Seeded city simulation, 20 vehicles / 30 pedestrians / 5 minutes, measure overlaps, stuck durations and time; retain logs |

## Scenario checklist
- [ ] Red, amber and green for inbound expanded-city roads at each junction
- [ ] Left-side driving, opposing cars, left/right turns, merging and parking
- [ ] Car collides correctly with player, pedestrian, another car, sign, tree, wall
- [ ] Vehicle entry cannot spawn inside any actor or world collider
- [ ] NPC already overlapping player/NPC safely separates, without physical pushing or visible teleport
- [ ] Crosswalk occupation releases safely after progress/timeout and queues are fair
- [ ] Player cannot get permanently trapped below world after recovery fails
- [ ] Mobile and PC frame-time and interpolation-on/off results recorded

## Baseline command (Windows PowerShell)
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --import --quit
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/pedestrian_spawn_separation_test.gd
python tools/run_regression.py --godot "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --timeout 60
Write-Host "Exit code: $LASTEXITCODE"
```

When running locally, avoid overwriting an uncommitted `build/regression-report.json` unless the changed file is backed up or explicitly intended to be replaced. The runner's `--report` can target a separate file, e.g. `build/next-physics-audit-report.json`.

**Status:** All test descriptions in this file are proposed acceptance checks, not passing tests. No runtime tests or GitHub Actions were run as part of this source-only audit.
