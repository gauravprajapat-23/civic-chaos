# GAME-014 — Wrong-Way Mission Checkpoint Persistence
Date: 2026-11-06 | Branch `fix/regression-nov05` | **Source implemented; Godot runtime verification pending.**

## Goal and player behavior
The previously disabled F5/F9 keys now save and load the **same** player+civic+wrong-way event. Checkpoints may be taken before inspection, after a valid report, during the marshal response, or while the tow convoy is moving. The game should rebuild the same real car positions and resume from the saved stage without creating a duplicate incident or issuing a second reward.

### What is saved
- Existing versioned `CivicSaveRepository` JSON document (still save version 1 for backwards compatibility), including player position and yaw;
- `civic_session`: existing `CivicGameplaySession.snapshot` with authoritative mission/incident history, city scores and reward claims;
- Optional `wrong_way_checkpoint` **schema_version 1**: physical city approach/exit IDs, current fixed-tick count, inspected/reported/intervention state, marshal progress, offender lane position, tow progress, completion flags, actual queue peak/recovery streak, visible feedback;
- Four physical follower records, keyed by **stable index rather than Godot instance ID**, including lane segment, distance, speed, active flag, initial distance, observed-movement flag and actual release flag. These booleans are re-keyed to new instance IDs when actors are reconstructed after a restart.

### Safe restore rules
1. `CivicGameplaySession.can_restore` checks the existing civic part.
2. `CivicWrongWayLiveMission.checkpoint_valid` checks schema, finite numeric bounds, actual legal lane connectivity, all four follower records, no fabricated queue peak, incident identity, state transitions, matching mission objective counts, and reward state consistency.
3. **No civic manager is modified during preflight.** If a fresh scene has no live wrong-way actor group, `prepare_restore` stages real vehicle nodes without registering a new incident/mission.
4. Existing managers are restored from the saved civic document, then `wrong_way_live_mission.restore` remaps recorded follower indexes to new physical actors, recreates any visible marshal and rebuilds the tow geometry at its saved lane-progress value.
5. World physics and the actual car-following system resume. A previously submitted report is not submitted twice; mission rewards and city outcomes remain idempotent.
6. The first footpath tutorial's session clock now continues after its own completion, because the **same incident manager** is reused for later missions; this prevents future-dated wrong-way events from invalidating legitimate saves.

### Compatibility and conservative failure behavior
- Existing player-only saves can still load if there is **no active wrong-way scene**. They are refused while a wrong-way event is running to avoid replacing mission world state with an incomplete old save.
- A checkpoint with no wrong-way scene but a finished tutorial will launch the next mission normally after loading.
- A malformed, unsupported or inconsistent wrong-way snapshot is rejected before applying its contained actor state.
- If a new scene cannot safely stage the actual vehicles, the load is refused rather than teleporting or inventing traffic.
- **Remaining limitation:** rewinding a *completed and already despawned* tow scene back into its earlier active phase in the **same live scene** is refused; restart the level to rehydrate the earlier checkpoint. This avoids reusing missing car colliders. A future update can implement a clean in-place scene swap.
- **Remaining limitation:** the city's unrelated background traffic and traffic-signal phase are not part of this GAME-014 checkpoint. The live mission's four follower vehicles, offender, tow convoy, and civic state are restored; surrounding city actors are independently simulated. A snapshot may be deferred if their current positions prevent safe re-staging. This is not full-city deterministic replay.
- The engine queues the player controller's collision-validated restore rather than moving its physics body in an input handler. The final position still depends on a valid free floor support and world clearance.

## Code / regression sources
- `scripts/civic/wrong_way_live_mission.gd`: `snapshot`, `checkpoint_valid`, `prepare_restore`, `restore`, stable follower index bookkeeping and resume-progress tow vehicle setup.
- `scripts/core/main.gd`: `_save_gameplay_checkpoint` and `_load_gameplay_checkpoint` now handle F5/F9 rather than blocking them.
- `scripts/civic/gameplay_session.gd`: civic-world clock advances even once the footpath tutorial has completed.
- `tests/wrong_way_checkpoint_test.gd`: verifies schema rejection, wrong lane index rejection, no unearned report, genuine moved cars, JSON checkpoint while reported and while tow is moving, scene destruction/recreation, no duplicate mission, stable tow position, and reward idempotence.
- `tools/run_regression.py`: new test registered in the strict runner. All `ERROR:` and `SCRIPT ERROR:` output still fails a run.

## Windows PowerShell acceptance
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
& $godot --headless --path . --script res://tests/wrong_way_checkpoint_test.gd
if ($LASTEXITCODE -ne 0) { throw "Wrong-way checkpoint test failed" }
& $godot --headless --path . --script res://tests/authorized_tow_route_test.gd
if ($LASTEXITCODE -ne 0) { throw "Tow route regression failed" }
& $godot --headless --path . --script res://tests/authorized_tow_obstacle_test.gd
if ($LASTEXITCODE -ne 0) { throw "Tow obstruction regression failed" }
python tools/run_regression.py --godot $godot --timeout 60 --report build/game-014-checkpoint-report.json
Write-Host "Exit code: $LASTEXITCODE"
```
Expected new success marker: `CIVIC_CHAOS_WRONG_WAY_CHECKPOINT_PASS`.

Manual gameplay: finish orange footpath tutorial, observe the wrong-way queue, inspect/report at the yellow post, press F5 during marshal arrival or towing, restart/re-enter the game, press F9 and verify the same incident, convoy progress, and city score. Confirm no extra wrong-way cars or repeated reward. Also try a corrupted checkpoint on a disposable test save, not the main playthrough.

## Status
- [x] Source additions and GitHub commit
- [x] New checkpoint regression authored and registered
- [ ] Godot 4.7.2 import and focused checkpoint regression PASS
- [ ] Full strict regression PASS (including prior GAME-013 checks)
- [ ] Manual PC gameplay check during marshal/tow restore
- [ ] Mobile save/load check
- [ ] Extended end-to-end recovery and UI checks on restart

**No Godot engine executable was available in the editing environment. All code changes are unverified until the user runs the above tests.** No GitHub Actions were manually dispatched, though repository pushes may trigger the configured workflow.

## 2026-11-06 — Actual restored-mission completion failure

User ran Godot 4.7.2 on commit `27f5c13`. Headless import succeeded. The focused `wrong_way_checkpoint_test.gd` created a real wrong-way queue, saved during towing, reconstructed actors and completed the mission after reload. The test nevertheless failed at the final `checkpoint_valid` call (line 171 of that earlier test) with `final restored mission checkpoint is inconsistent`.

**What was changed:** `_finish_tow_convoy` now stores the exact route-end progress when an authorized tow completes, rather than a near-end incremental position. The preflight validator allows at most 2 cm numeric variation at legal lane and tow endpoints while preserving strict checks for reported/inspected stage, authorized intervention, incident resolution, mission completion, follower history and once-only reward claims. The regression now checks that tiny endpoint drift is accepted and a 0.5 m overshoot is rejected. All 48 validator rejection branches optionally append a specific code and condition to an `Array` provided by the caller; routine invalid saves remain quiet.

The completed checkpoint regression prints a structured summary with the exact failing `CKP-XX` condition and terminal follower states if another invariant still rejects the snapshot.

**This is a targeted endpoint correction plus diagnostics, not a claim that the updated Godot test passed.** No Godot runtime is available in this editing environment.

Rerun on your Windows PC:
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Import failed" }
& $godot --headless --path . --script res://tests/wrong_way_checkpoint_test.gd
if ($LASTEXITCODE -ne 0) { throw "GAME-014 checkpoint test failed; share the CKP code from its output" }
python tools/run_regression.py --godot $godot --timeout 90 --report build/game-014-completion-retest.json
Write-Host "Exit code: $LASTEXITCODE"
```
The dedicated report file avoids touching locally modified `build/regression-report.json`. No GitHub Actions were manually dispatched.
