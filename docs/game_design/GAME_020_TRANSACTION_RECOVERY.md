# GAME-020 — Dense-Traffic Transaction Recovery

**Date:** 2026-11-07
**Branch:** `fix/regression-nov05`
**Status:** Source implemented and committed; **Godot 4.7.2 execution pending**.

## Purpose and finding

GAME-019 recorded background vehicles, pedestrians, intersection reservations, signal phases and the simulation clock. Its restore originally committed the new traffic generation **before** checking saved pedestrian landing positions. When a pedestrian destination was occupied, the code had to rebuild the previous traffic generation, which could fail a second collision check. That is not safe rollback.

GAME-020 replaces that path with a staged traffic-generation transaction. This is a targeted fix, **not a claim of full-city ACID transactions**.

## Two-phase world restore

1. Validate the whole versioned world checkpoint, including matching simulation ticks and coherent mission history in the calling F9 path.
2. Freeze the relevant simulation director, civic mission actors and background pedestrians using the existing GAME-018 transaction guard.
3. `traffic_spawner.prepare_restore` creates **incoming** vehicle nodes and collision-checks them while temporarily disabling the original generation's collision layers. Original vehicle nodes, route data, RNG state, counters and per-car delay history are retained.
4. `pedestrians.restore_checkpoint` checks every destination against the newly staged car colliders and world geometry, and only moves walkers when all are safe.
5. **Failure:** `traffic_spawner.abort_restore` deletes only the staged cars and re-enables the original vehicles' collision layers. The old traffic objects and counters remain unchanged, so no reconstructive rollback is needed.
6. **Success:** `traffic_spawner.commit_restore` replaces exactly one generation, remaps per-car delays by new runtime IDs, and applies prevalidated route/tick/RNG/counter data. The junction then restores crossing permissions, signals and the simulation clock from the same source.
7. A pending traffic generation rejects another `prepare_restore`, refuses `advance_fixed` ticks and is automatically aborted if the spawner is reconfigured or torn down.

F9 also checks whether the player is an active, mounted `CivicPlayerController` with a finite saved player location **before modifying civic/traffic managers**. The existing deferred ground/collision placement remains in force; the player is not teleported in the input handler.

The established `CivicSaveRepository` checksum-verified primary/backup file format is unchanged. Older checkpoint versions remain subject to GAME-018/019 compatibility rules.

## Regression coverage

- `tests/world_transaction_rollback_test.gd`: a real busy junction is saved. A physical barricade is placed at a saved pedestrian position. Loading must fail **after traffic staging** but preserve the same old car instance identities, positions, collision layers, RNG state and simulation tick. Removing the obstruction permits a normal restore.
- `tests/traffic_transaction_stress_test.gd`: 12 consecutive prepare/abort cycles preserve original actors and collision layers, second concurrent prepares are rejected, fixed traffic ticks are blocked during preparation, and one successful commit replaces the generation exactly once.
- `tests/save_generation_consistency_test.gd`: additionally rejects non-finite and unmounted player snapshots at the new preflight gate.
- Existing `world_traffic_checkpoint_test.gd`, `world_junction_checkpoint_test.gd`, `world_pedestrian_checkpoint_test.gd` and GAME-014–018 tests remain relevant.
- Both new test scripts are registered in `tools/run_regression.py`; engine errors remain strict failures.

## Windows PowerShell acceptance

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
$tests = @(
    "world_transaction_rollback_test.gd",
    "traffic_transaction_stress_test.gd",
    "world_traffic_checkpoint_test.gd",
    "world_junction_checkpoint_test.gd",
    "world_pedestrian_checkpoint_test.gd",
    "save_generation_consistency_test.gd",
    "wrong_way_checkpoint_test.gd",
    "parking_checkpoint_test.gd",
    "multi_incident_checkpoint_test.gd"
)
foreach ($test in $tests) {
    & $godot --headless --path . --script "res://tests/$test"
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
}
python tools/run_regression.py --godot $godot --timeout 120 --report build/game-020-transaction-recovery.json
Write-Host "Exit code: $LASTEXITCODE"
```

**New expected markers (NOT yet observed):**
- `CIVIC_CHAOS_WORLD_TRANSACTION_ROLLBACK_PASS`
- `CIVIC_CHAOS_TRAFFIC_TRANSACTION_STRESS_PASS`

## Limitations and release gates

- [x] Two-phase car staging/commit/abort implemented in GitHub source
- [x] Actual dense-traffic rollback and repeated-retry tests added
- [x] Player snapshot eligibility preflight added
- [ ] Godot 4.7.2 headless import and focused regression passes
- [ ] Full strict regression passes, including earlier GAME-014 checkpoint failure
- [ ] Manual PC F5/F9 playthrough with congested signals and pedestrian crossings
- [ ] Android controls and performance checks

**Scope boundary:** The outer F9 transaction still performs civic-manager/mission restores before the world-state commit. A later player-scene failure or external scene transition is handled with best-effort rollback; this is not a crash-atomic transaction across every physical object and side effect. Game-state reconciliation, interruption-safe save journals, and world-object-independent rollback are still future milestones.

No GitHub Actions were manually triggered. The regression report filename is distinct from the user's locally modified `build/regression-report.json`.
