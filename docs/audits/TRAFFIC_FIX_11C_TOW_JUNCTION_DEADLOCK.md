# TRAFFIC-FIX-11C — Municipal Tow Right-of-Way and Mission Queue Deadlock

**Date:** 2026-11-16  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source and tests committed; local Godot verification and live traffic replay pending.

## Reported behavior

The user uploaded a 2026-11-16 screenshot showing the Wrong Way mission active, tow and queued vehicles near the central crossing, several "Stopped" NPC labels, and the mission guide reading "No service/traffic progress for about 30 seconds." In the visible terminal portion `CIVIC_MISSION_CAR_HOLD` reports `QueuedVehicle_0` stopped behind `QueuedVehicle_1/CollisionBody`. That is a real physical queue; the visible screenshot alone does not prove that the current traffic controller is frozen. Changing lights manually cannot make cars pass through a physically occupied road.

Source inspection found:
1. `CivicTrafficSpawner` coordinated ordinary traffic and mission cars for lead sensing and central occupancy but had **no municipal service admission window**. New cars could continue entering the central conflict zone on their greens while the authorized municipal tow awaited its own W-direction green. The central four-turn phase spans 68 seconds; an already occupied junction can consume repeated eligible greens.
2. TRAFFIC-PERF-11A's `_tow_stationary_seconds` increased for zero permitted travel (red or pedestrian holds), **but not for physical footprint-sweep rejection**. Alternating these causes could keep the tow stuck forever without reaching the two-cycle no-progress fallback. The original fallback counted only consecutive same-category holds.
3. The previous physical-collider fallback's authorization/safety checks needed to match the new starvation fallback, so no earlier path could trigger collection through an active pedestrian/civic incident without authorization.

## Implemented source changes

### A. Temporary municipal admission control

`CivicTrafficSpawner.set_central_service_priority(service)` registers a single **active, valid** external municipal service car. When it exists, `apply_stop_line_observation` holds **all other new inbound cars** at the central stop line with reason `municipal_service_priority`. This includes mission followers and ordinary background traffic; they are not removed or made non-solid.

- Cars already **past the stopline** are explicitly unaffected and allowed to finish their crossing.
- This is **not** a signal override: a service car still obeys its own red/amber, pedestrian crossing reservation and occupied central conflict zone.
- The original per-car physical collision probes remain fully enabled.
- The admission gate is activated only after an authorized municipal tow successfully stages. It is released when the tow legally finishes or completes guarded on-site collection, when its mission exits, and when a restored/new spawner generation is configured. During checkpoint restoration, recreating a live authorized convoy recreates the correct transient service window. No checkpoint schema change.
- Once the obstruction is gone, default normal vehicle admission resumes automatically.

### B. Shared starvation clock for all real no-motion causes

`CivicWrongWayLiveMission._record_tow_stalled_frame(delta, reason)` counts real zero-displacement time regardless of whether the cause is a red light, a pedestrian reservation or a collider rejected by the tow/offender footprint sweep. **Only successful convoy movement resets the timer.**

Existing TRAFFIC-PERF-11A safeguards still require a reported incident and real marshal intervention, at least two complete signal cycles with no progress (minimum 136s in four-turn mode), an unoccupied crossing, no other physical car in the central zone, and a layer 2/4/8 clear stationary collection worksite. The two-second collection step pauses if a person or car enters the worksite.

The earlier 180-frame physical-obstruction recovery now calls the same authorization and physical safety guard instead of bypassing them.

### C. Honest civic completion

Tow and offender clearance are distinct from mission completion. The `sustained_recovery` objective still requires at least **two real queued follower cars to move past the old obstruction**, zero actually stopped mission followers, and sustained recovery before claimable reputation. The temporary admission hold creates physical crossing time; it does not fake any follower motion.

## Regression tests

- `tests/traffic_fix_11b_municipal_junction_priority_test.gd` — ordinary car gets green before tow is authorized, is held on its stop line during service, can finish if already committed, service still waits for its own red/pedestrian, clears on W green, no priority survives release or new traffic generation.
- `tests/traffic_fix_11c_tow_priority_lifecycle_test.gd` — actual civic incident cannot start unauthorized tow; approved tow activates admission control; mixed stop reasons contribute to one no-progress clock; completed service releases priority without creating civic progress or reward.
- Rerun `traffic_perf_11a_tow_starvation_test.gd`, `aud3_wrong_way_tow_gridlock_recovery_test.gd`, `wrong_way_tow_service_priority_test.gd`, `authorized_tow_obstacle_test.gd`, `traffic_fix_09_single_approach_rules_test.gd`, `traffic_fix_08_central_spillback_test.gd`, `traffic_spawner_test.gd`, `world_junction_checkpoint_test.gd`.

## Local Windows gate

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Git fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Git merge failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$code = $LASTEXITCODE
$log | Out-Host
if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) { throw "Import failed" }

$tests = @(
  "traffic_fix_11b_municipal_junction_priority_test.gd",
  "traffic_fix_11c_tow_priority_lifecycle_test.gd",
  "traffic_perf_11a_tow_starvation_test.gd",
  "wrong_way_tow_service_priority_test.gd",
  "aud3_wrong_way_tow_gridlock_recovery_test.gd",
  "authorized_tow_obstacle_test.gd",
  "traffic_fix_09_single_approach_rules_test.gd",
  "traffic_fix_08_central_spillback_test.gd",
  "traffic_fix_07_cross_fleet_junction_test.gd",
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
Write-Host "Municipal junction deadlock tests passed" -ForegroundColor Green
```

## Live PC/Android acceptance

- [ ] Report Wrong Way incident and wait for the **authorized** marshal/tow. Before the tow exists, normal NPC traffic is unchanged.
- [ ] As soon as the tow is staged, vehicles not yet entered at the central junction wait behind their actual stop lines; **already-committed vehicles exit** physically.
- [ ] During a W red/amber or occupied crosswalk, tow is stationary; on W green with empty conflict zone, tow advances physically. No car drives through pedestrians.
- [ ] If convoy remains blocked for two full cycles, `CIVIC_TOW_GATE` explains the exact signal/crossing/worksite cause. Any grounded fallback runs only when worksite is empty and authorized.
- [ ] After authorized physical tow/offender removal, service priority stops immediately; two or more real followers must resume and the civic objective only then pays once.
- [ ] Five-minute live replay of active signal cycles with background fleet and mission convoy; measure completed routes, queue count and location-specific blockers. Keeping ordinary traffic stopped for the entire duration is NOT acceptable.
- [ ] Save F5 / restore F9 during active tow and after service completion; verify no stale priority, duplicate reward, missing physical actor or snapshot mismatch.
- [ ] Android debug APK tested on a low-end Compatibility renderer, including the compact HUD and traffic marshal panel.

**No Godot engine is available within the GitHub coding environment; tests and gameplay are not yet verified. Keep this issue OPEN until user-local QA passes.**
