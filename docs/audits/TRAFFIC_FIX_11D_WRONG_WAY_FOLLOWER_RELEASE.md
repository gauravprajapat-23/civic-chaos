# TRAFFIC-FIX-11D — Wrong Way Mission Follower Release

**Date:** 2026-11-16  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source and focused regression committed; local Godot and gameplay replay pending.

## Observed failure

User screenshot shows **Wrong Way, Wrong Day** still active after previous tow fixes, municipal truck near central junction, "Waiting" over a normal traffic car and `CIVIC_MISSION_CAR_HOLD` reporting `QueuedVehicle_0` stopped behind `QueuedVehicle_1/CollisionBody layer=4` at `E_AMBER`. This is a *real moving-vehicle queue*, not proof of an incorrectly frozen signal. Changing green alone cannot pass an actual physical collision.

**Source finding:** Previous TRAFFIC-FIX-11C granted a protected entry window to the *authorized tow*, but immediately removed it when tow/offender cleared. The scripted follower cars then had to compete with unrelated newly arriving background traffic for the same one-in-four green turns. This can starve the **actual post-incident recovery objective** when the junction is congested. The mission correctly refuses to award reputation until at least two followers truly pass the former obstruction.

## Implemented code

- `CivicTrafficSpawner` adds a separate, ephemeral `start_central_recovery(followers, duration_ticks)`, `clear_central_recovery()`, `central_recovery_active()` and `central_recovery_allows(car)`.
- On actual authorized tow/offender removal (`CivicWrongWayLiveMission._finish_tow_convoy`), register **only real currently active mission followers** for a bounded central discharge window, maximum **2,800 fixed ticks (140 seconds)**.
- During that window, new **unrelated** center-bound cars wait before the normal stopline. Already-committed cars exit without being frozen. Mission cars remain solid and subject to the **same red/amber lights, pedestrian reservation, lead detection, physical collider sweeps, and central priority**.
- The window shuts off automatically once the registered cars have crossed into the exit lane, when the fixed tick timeout expires, or when the mission truly completes. Normal traffic permission resumes without deleting any NPC.
- All runtime priorities reset on `CivicTrafficSpawner.configure`; a checkpoint restoring a tow-completed but unfinished mission reconstructs a bounded window from the real restored followers; completed missions clear it. No checkpoint schema changes.
- The official mission continues to require at least **two moved and physically passed followers**, `stopped_count == 0` for 12 recovery frames, then the incident transition and idempotent reputation receipt. No automatic mission completion and no fake release statistics.

**Files:** `scripts/traffic/traffic_spawner.gd`, `scripts/civic/wrong_way_live_mission.gd`.

## Test

`tests/traffic_fix_11d_wrong_way_follower_release_test.gd` verifies:
- An invalid/empty recovery group or excessive window is rejected.
- Other background entrants wait behind the central stopline.
- The mission follower does **not** run red.
- A mission follower can proceed during a genuine West green when center is clear.
- A physically occupied pedestrian crossing still prevents entry.
- Normal traffic resumes when followers leave the inbound lane.
- Recovery expires after the bounded tick limit.

Existing integrations must still pass: `aud3_wrong_way_tow_gridlock_recovery_test.gd`, `traffic_fix_11c_tow_priority_lifecycle_test.gd`, `traffic_fix_11b_municipal_junction_priority_test.gd`, `wrong_way_tow_service_priority_test.gd`, `traffic_perf_11a_tow_starvation_test.gd`, `traffic_fix_09_single_approach_rules_test.gd`, `traffic_spawner_test.gd`, `world_junction_checkpoint_test.gd`.

## Local Godot gate

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Merge failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$code = $LASTEXITCODE
$log | Out-Host
if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Import failed"
}
$tests = @(
    "traffic_fix_11d_wrong_way_follower_release_test.gd",
    "traffic_fix_11c_tow_priority_lifecycle_test.gd",
    "traffic_fix_11b_municipal_junction_priority_test.gd",
    "traffic_perf_11a_tow_starvation_test.gd",
    "aud3_wrong_way_tow_gridlock_recovery_test.gd",
    "wrong_way_tow_service_priority_test.gd",
    "traffic_fix_09_single_approach_rules_test.gd",
    "traffic_spawner_test.gd",
    "world_junction_checkpoint_test.gd"
)
foreach ($test in $tests) {
    Write-Host "Running $test" -ForegroundColor Cyan
    $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $code = $LASTEXITCODE
    $log | Out-Host
    if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
        -not ($log | Select-String '_PASS')) { throw "FAILED: $test" }
}
Write-Host "TRAFFIC-FIX-11D focused gate passed!" -ForegroundColor Green
```

## Live acceptance remains open

- [ ] Start a fresh Wrong Way mission, inspect and report the offender, await actual marshal arrival and authorized tow/roadside collection.
- [ ] Tow and offender physically leave only through safe traversal or grounded service. No reward merely for tow cleanup.
- [ ] The mission followers remain real, solid cars, spaced with their normal following rules; no collision bypass or teleport.
- [ ] Once offender is gone, background newcomers wait behind the stopline while real West-approach followers gain their next valid green.
- [ ] At least two real cars physically pass the obstruction and are counted in `released_ids`; ordinary NPCs resume after the bounded window.
- [ ] If a pedestrian enters the crossing or another vehicle is already inside, mission cars still yield.
- [ ] F5/F9 before and after tow completion does not leave stale priority or duplicate civic score.
- [ ] Five-minute replay documents actual stopped queue, number of completed journeys and stage times; Android 8–20 active cars checked.

**No Godot 4.7.2 runtime or APK available in the GitHub connector; not yet verified.** Keep the gameplay finding open until the user confirms the fresh replay.
