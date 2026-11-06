# Civic Chaos — Physics Implementation Plan
Date: 2026-11-06 | Branch: `fix/regression-nov05` | No GitHub Actions.

## Phase 1: Baseline and audit (source review complete; runtime baseline pending)
- [x] Inspect scene and script physics bodies, masks and motion paths.
- [x] Reconcile legacy 36-test report with the later 38/41 failure report.
- [x] Publish audit, layer matrix, issue register, test plan.
- [ ] Run headless import and all tests against this exact branch tip.
- [ ] Capture failed test logs and reproducible gameplay evidence.

## Phase 2: Player and surfaces
1. Add **horizontal-only** shape sweep against pedestrian bit 8 before player `move_and_slide()` while keeping normal player mask world+cars (5).
2. Add actual physics-frame player approaching stationary pedestrian test, release test, and falling past a pedestrian without standing on it.
3. Test curb and surface transitions; avoid creating second overlapping ground collider.
4. Validate fall recovery, invalid load transforms and spawn occupancy.
5. Run focused test, full regression and Windows gameplay. Record exact commit/log.

## Phase 3: Pedestrians
- Replace stop-forever avoidance with bounded sidestep/yield/reroute and deterministic priority.
- Validate spawn clearance, opposing paths, crossing queues, corners and 120+ physics frames.
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
