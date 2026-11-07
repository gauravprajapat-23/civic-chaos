# GAME-017 — Multi-Incident Save/Load

**Date:** 2026-11-07  
**Branch:** `fix/regression-nov05`  
**Status:** Code committed, Godot 4.7.2 runtime verification pending.

## Gameplay and checkpoint behavior

F5/F9 now support one JSON checkpoint containing the player, completed footpath tutorial, wrong-way traffic mission and active/completed illegal-parking mission. The existing `CivicSaveRepository` v1 atomic JSON writer remains in use.

- `civic_session`: authoritative incidents, mission objectives, score audit history and claimed rewards.
- `wrong_way_checkpoint`: existing GAME-014 real follower/tow state, with historical tick allowance only when the wrong-way mission is already finished.
- `parking_checkpoint` (schema v1): real pedestrian witness progress/stoppage frames, owner progress and consent, incident/intervention stage, car distance along a fixed marked route, completion and feedback.

Actor IDs are not written to disk. Car positions and orientation are reconstructed from bounded route progress, and owner/witness positions are reconstructed from validated progress. The original civic incident is not registered twice.

Before restoring any civic manager, the new F9 path checks all present snapshots against the same civic document and refuses missing or incompatible campaign stages. Fresh physical scenes are staged without creating new incidents, then populated from validated progress. The player is requested to move only after mission reconstruction, via the existing safe-position controller. A failed physical reconstruction is rejected, with best-effort state rollback.

Saves are rejected for invalid schema, forged reports/consent, out-of-bounds progress, illegal stages, missing incident identities, inconsistent objective counts, unsupported reward state or impossible pedestrian recovery. Saving an active parking mission is no longer blocked.

## Code and tests

- `scripts/civic/illegal_parking_mission.gd`: versioned `snapshot`, pure `checkpoint_valid`, `prepare_restore`, `restore`, stable route geometry; exact owner arrival.
- `scripts/civic/wrong_way_live_mission.gd`: finished wrong-way state is compatible with a later civic incident's global tick.
- `scripts/core/main.gd`: campaign F5/F9 preflight, physical actor staging, rollback attempts and UI connections.
- `tests/parking_checkpoint_test.gd`: reported/moving-car JSON checkpoints, destroyed/rebuilt scene, continuing physical pedestrian recovery, reward idempotency and forged-save rejection.
- `tests/multi_incident_checkpoint_test.gd`: actual wrong-way incident completed, parking incident underway, both saved in one JSON document, rebuilt together, then the parking mission completes without a second reward.
- `tools/run_regression.py`: both tests registered; strict `ERROR:` and `SCRIPT ERROR:` detection retained.

## Windows PowerShell acceptance

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
$tests = @(
  "parking_checkpoint_test.gd",
  "multi_incident_checkpoint_test.gd",
  "wrong_way_checkpoint_test.gd",
  "illegal_parking_live_test.gd",
  "illegal_parking_obstacle_test.gd"
)
foreach ($test in $tests) {
  & $godot --headless --path . --script "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { throw "Focused test failed: $test" }
}
python tools/run_regression.py --godot $godot --timeout 120 --report build/game-017-campaign-report.json
Write-Host "Exit code: $LASTEXITCODE"
```

Expected new markers, **not yet observed**: `CIVIC_CHAOS_PARKING_CHECKPOINT_PASS` and `CIVIC_CHAOS_MULTI_INCIDENT_CHECKPOINT_PASS`.

## Limitations

- Godot executable is unavailable in the editing environment; the implementation and tests have not been run locally.
- The previously reported GAME-014 terminal completion test still needs a rerun on the corrected branch. GAME-017 acceptance depends on that gate too.
- The wider background traffic, city signal phase, and unrelated pedestrians are not part of these snapshots. If a restored vehicle's physical position is occupied, loading may be deferred.
- Scene rollback and the player controller's deferred collision acceptance are **not** yet fully atomic for every possible world-state transition. GAME-018 should add stronger transaction orchestration, save migration, and interruption recovery.
- Manual PC playthrough and Android touch/performance checks remain pending.

No GitHub Actions manually dispatched. A separate report file avoids changing the locally modified `build/regression-report.json`.
