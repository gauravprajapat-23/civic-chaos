# Civic Chaos — Physics Implementation Plan
Date: 2026-11-06 | Branch: `fix/regression-nov05` | No GitHub Actions.

## Phase 1: Baseline and audit (source review complete; runtime baseline pending)
- [x] Inspect scene and script physics bodies, masks and motion paths.
- [x] Reconcile legacy 36-test report with the later 38/41 failure report.
- [x] Publish audit, layer matrix, issue register, test plan.
- [ ] Run headless import and all tests against this exact branch tip.
- [ ] Capture failed test logs and reproducible gameplay evidence.

## Phase 2: Player and surfaces
1. [CODE ADDED, UNVERIFIED] Horizontal-only player sweep now targets pedestrian+vehicle bits (12) and keeps normal player mask world-only (1); commits `af04f32` and `b442124`.
2. [TEST ADDED, NOT RUN] Actual-frame pedestrian and parked-vehicle approach, release and roof-fall tests; `tests/player_pedestrian_contact_test.gd` and `tests/player_vehicle_contact_test.gd`.
3. Test curb and surface transitions; avoid creating second overlapping ground collider.
4. [CODE+TEST ADDED, NOT RUN] Validate fall recovery, invalid load transforms and spawn occupancy via physics-tick placement; commit `9aa948d`, `tests/player_safe_restore_test.gd`.
5. Run focused test, full regression and Windows gameplay. Record exact commit/log.

## Phase 3: Pedestrians
- [CODE ADDED, NOT RUN] Bounded sidestep/yield and alternate passing side; later screenshot fix explicitly disables NPC rigid blocking and adds player yielding, local separation and floor-filtered obstacle probes (`404755a`–`28b9969`). Full route reroute remains future work.
- [TEST ADDED, NOT RUN] Safe spawn clearance, perpendicular approach, head-on movement, 360/420 physics-frame separation and progress assertions (`f4922dd`). Busy junction/30-NPC playtest remains outstanding.
- Separate navigation goal choice from movement/collision resolution.

## Phase 4: Vehicles
- Define one authoritative collision-safe movement policy; evaluate CharacterBody3D/AnimatableBody3D vs the current scripted Node3D.
- Add full oriented-volume spawn checks, vehicle/vehicle, player, NPC, buildings and turning.
- Tune safe braking against actual speed/size; no disabling obstacle checks in gameplay.

## Phase 5: Lane graph and junctions
- Model left-hand directional lane offsets with right-of-way and curved turn connectors.
- Preserve graph continuity, signal and pedestrian crosswalk correspondence.
- Validate no sidewalk/building clipping on every junction.

## Phase 6: Performance
- Measure first, then cache query objects or use spatial neighbor filtering where justified.
- Target PC 60 FPS and Android 30 FPS at 20 active cars and 30 pedestrians; record device and scenario.

## Phase 7: Final QA
- Run all regression and negative-path tests with seeded replay.
- Physically inspect grounding, no stacking, contacts, intersection deadlocks and save/load recovery.
- Update docs with real commands, logs, commits and remaining risks.

## Local validation (Windows PowerShell)
```powershell
git fetch origin fix/regression-nov05
git switch fix/regression-nov05
git merge --ff-only origin/fix/regression-nov05
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --import --quit
python tools/run_regression.py --godot "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --timeout 60
Write-Host "Regression exit: $LASTEXITCODE"
```

No GitHub Actions. Prefer small commits, never weaken assertions to make tests green.

## Screenshot-specific immediate verification
- [x] Code: player start moved from central junction to nearby sidewalk.
- [x] Code: NPC layer 8/mask 0 retained for car detection without rigid character collision.
- [x] Code: NPC spawn search must find a clear position or skip; active overlaps trigger small local corrections.
- [x] Tests authored: forced NPC/NPC and player/NPC overlap, 240 frames normal crowd movement.
- [ ] Run Godot import against exact branch head.
- [ ] Execute `tests/pedestrian_spawn_separation_test.gd`, `tests/player_pedestrian_contact_test.gd`, `tests/pedestrian_collision_test.gd` and `tests/pedestrian_crowd_avoidance_test.gd`.
- [ ] Run full local `tools/run_regression.py` suite.
- [ ] Visually verify player approaching NPC, red-light crossing yielding, 30-NPC crowd and traffic stops.
