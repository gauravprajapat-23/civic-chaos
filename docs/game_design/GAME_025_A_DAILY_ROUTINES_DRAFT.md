# GAME-025-A — Daily Routines Foundation (gated draft)

**Branch:** `feat/game-025-daily-routines-draft` (based on `feat/game-024-dynamic-free-roam`)  
**Status:** Source and regression authored. Not connected to live pedestrian simulation. Not engine-tested.  
**Gate:** GAME-024 import and full regression must pass in Godot 4.7.2 before the routine system is enabled or this branch is merged.

## Implemented in draft

`scripts/npc/npc_daily_routines.gd` implements `CivicNPCRoutines`, a pure-data deterministic daily agenda model for stable zero-based NPC IDs.

- Four roles: commuter, shopkeeper, sanitation worker, resident.
- Four simulated day phases: morning, workday, evening and night.
- Role-specific activity + semantic destination (e.g., shop, transit stop, neighborhood lane, home).
- Simulated 24,000-tick days (about 20 minutes at the existing 20 Hz fixed simulation rate), with 6,000 ticks per phase; no wall-clock or unseeded randomness.
- Stable role allocation using configured seed and actor ID, not spawn order or dictionary iteration.
- Idempotent monotonic `advance_to(tick)`; no time travel.
- Canonical v1 checkpoint with seed, agent count, tick and derived role/agenda records.
- JSON-safe validator rejects altered IDs, fabricated roles/destinations, wrong seeds, stale/negative ticks and population changes. Rejected state does not mutate the live scheduler.

The module is not instantiated by `district_pedestrians.gd` or `main.gd` yet. It does not move, stop, collide or teleport any NPC; crossing reservations, player interactions and the civic metrics ledger are untouched.

`tests/npc_daily_routines_test.gd` covers four-role coverage, boundaries, seeded replay, forged saves, JSON round-trip, monotonic ticks and non-mutating rejection. It is listed in the draft branch's local `tools/run_regression.py` suite.

## 025-A2 — Routine-to-navigation safety contract (draft)

`scripts/npc/npc_routine_intent.gd` implements `CivicNPCRoutineIntent`, a **stateless intent arbiter** consuming canonical role/time schedules and observed pedestrian safety flags. It proposes an existing-route travel, safe-place activity, obstacle yield, or crossing-authority handoff. **It never sets a position, changes crossing reservations, forces traffic-light progression, or awards civic points.**

- The current controller remains authoritative over scene geometry and physical movement.
- A walker inside a crosswalk or holding a crossing reservation must remain under existing crossing authority, even when their next planned activity is stationary.
- Physical path obstructions take precedence over routine travel, but never allow routines to override a crossing already in progress.
- A stationary activity is requested **only** after the existing controller has established a clear, safe destination.
- All seven semantic destination types have data-only area tags. Coordinates, interaction priorities, and actual waypoint navigation remain deferred until the GAME-024 gate passes.

`tests/npc_routine_intent_test.gd` verifies all four day phases across 16 agents, occupied crossing and held-reservation safety, obstacle yield, stationary idle at safe destinations, determinism, and rejection of invalid IDs/times/seeds. Registered with `tools/run_regression.py` on this draft branch.

This new layer remains disconnected from live `district_pedestrians.gd` until GAME-024's acceptance report is green.

## 025-A3 — Safe sidewalk stops + real-physics adapter (staged, OFF in live game)

- `scripts/npc/npc_routine_waypoints.gd` maps all seven schedule destination types onto deterministic stop coordinates **along the existing sidewalk routes**. Each target stays over eight metres away from the central crossing region and short of the route wrap.
- `scripts/npc/npc_routine_world_adapter.gd` reads real `district_pedestrians.gd` walker bodies, progress, crossing flags and `_recovery_position_is_clear()` physics checks. It returns a suggestion for when a routine may pause and does not move, teleport, snap, spawn, or score any actor.
- Crossing-zone occupancy and held reservations always veto a scheduled break. Only a clear real sidewalk stop within the arrival tolerance can permit `perform_activity`.
- The adapter accepts **simulation tick values supplied by the existing JunctionScene clock**. It must never advance itself using render delta or system wall time.
- `tests/npc_routine_world_adapter_test.gd` stages a real `AnimatableBody3D` pedestrian in an isolated scene, tests a clear market stop, overlap with the player, simulated occupied crossing, sidestep deviation, deterministic save round-trip and tamper refusal. The test is registered in the local Python regression runner.

**Not yet completed:** No call site is wired into `district_pedestrians.gd`, `main.gd` or the world checkpoint transaction. There is no live movement variation until GAME-024 has a recorded passing report for the accepted source revision and this draft passes Godot 4.7.2 import + full local regression. Do not interpret draft commits as GAME-025-A3 accepted or shipped.

## Verify GAME-024 first (on Windows)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git switch feat/game-024-dynamic-free-roam
git pull --ff-only origin feat/game-024-dynamic-free-roam
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_game024.ps1
```

**Do not claim the gate passed until** `build/game-024-verification.json` reports `status: passed`, its report is tied to the tested commit and the full strict suite is green.

## Preview the draft routine test separately

```powershell
git switch feat/game-025-daily-routines-draft
git pull --ff-only origin feat/game-025-daily-routines-draft
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
& $godot --headless --path . --script res://tests/npc_daily_routines_test.gd
if ($LASTEXITCODE -ne 0) { throw "NPC routine test failed" }
& $godot --headless --path . --script res://tests/npc_routine_intent_test.gd
if ($LASTEXITCODE -ne 0) { throw "NPC routine intent test failed" }
& $godot --headless --path . --script res://tests/npc_routine_world_adapter_test.gd
if ($LASTEXITCODE -ne 0) { throw "NPC physical routine adapter test failed" }
```

This test can prove the *model* works, but does **not** authorize enabling routines in the existing city before the GAME-024 acceptance gate.

## Follow-on implementation after acceptance

1. Assign one routine model to the current `_walkers` population and drive it from the same deterministic simulation tick.
2. Map semantic destinations to the existing collision-safe pedestrian routes. Avoid route changes in pedestrian crossing conflict zones or while reservations are held.
3. Represent stationary routines at validated resting points only; waiting must not occur on crossings and must not trap or overlap other walkers.
4. Upgrade the pedestrian checkpoint schema *transactionally*, preserving old v1 walker snapshots and authoritative world rollbacks.
5. Add two physical-scene tests: safe routine transitions under loaded crossings, and deterministic saved/restored movement including role/phase.
6. Then proceed to GAME-025-B contextual conversations and 025-C crowds.

## Verification log

- GitHub source commit(s): recorded in branch history.
- Godot 4.7.2 import: **not executed here**.
- Local focused tests: **not executed here**.
- Full regression: **not executed here**.
- GitHub Actions: **not triggered**.

No new backend, release workflow, networking or analytics was introduced.
