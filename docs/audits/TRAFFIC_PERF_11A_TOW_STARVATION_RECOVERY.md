# TRAFFIC-PERF-11A — Municipal Tow Starvation & Safe Crossing Recovery

**Date:** 2026-11-16  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source and focused test committed; local Godot/Android verification pending.

## Evidence and defect

User's 433-line Godot log `Pasted text(7).txt` shows the active Wrong Way mission is still blocked despite correct N/E/S/W signal changes. The tow truck repeats `progress=41.38/92.76` with `queue=4 released=0`, holding alternately for `red_signal` and `pedestrian_crossing` through many phases and >7000 mission ticks. QueuedVehicle_3 stays at lane 126 / 31.86 m behind the WrongWayOffender; the three remaining mission followers form a genuine physical queue at 28.84/25.82/22.80 m. Red light holds on other directions are normal, but they do not alone explain zero municipal tow progress.

Root cause in `CivicWrongWayLiveMission._note_tow_hold`: existing grounded service fallback triggers after 180 **consecutive physical-collider** hold frames. Alternating signal/pedestrian holds reset that counter; it never reaches fallback. A tow truck awaiting the four-turn signal (12s green+3s amber+2s all-red per approach; 68s cycle) might have too few truly clear crossing intervals. Do not override a red, ignore the crossing reservation, despawn active background cars, or issue imaginary mission progress.

## Source change

`scripts/civic/wrong_way_live_mission.gd`:

- `_tow_gate_snapshot()`: every six **continuous no-progress seconds** prints `CIVIC_TOW_GATE`, with mission tick, exact tow route distance, held duration, actual incoming signal approach, real signal aspect, time until next green, owner IDs for both crossing zones, whether another vehicle occupies the center, and the current stop reason.
- **Separate progress starvation clock:** `_tow_stationary_seconds` increases only when the authorized tow is stopped, and resets on **actual accepted movement**. Its threshold is at least 136s (two complete 68s signal cycles) or twice four current signal-cycle durations for a custom test controller. A single red, amber or crossing wait never triggers roadside recovery.
- **Authorization gate:** mission must be in `INTERVENTION`, authorized `reported_tick` and `intervention_tick` present, live tow and offender valid, and not already recovered/completed.
- **Real collision and crossing safety:** neither `pedestrian_crossing_ns` nor `pedestrian_crossing_ew` can have an occupied reservation; a real other road vehicle cannot occupy the central conflict zone; a physical sphere query checks the stationary service worksite around the existing tow and offender using layers 2|4|8 (player, car, pedestrian). The probe excludes *only the two convoy's own collision RIDs*. It is deliberately 1m radius because 3m-long queue cars stand ~3.02m apart; a 2.25m-radius probe would permanently register a legitimate follower even if the actual worksite is clear.
- **Safe roadside outcome:** the existing `_advance_ground_recovery` performs a visible 2-second stationary collection; every update now pauses when an actor enters the worksite or any crossing is occupied. Only at completion are the actual tow and offender collision actors retired and the Wrong Way incident lane reopened. **No vehicle proceeds across a red, any road geometry, or a pedestrian.**
- **No fraudulent mission completion:** `_finish_tow_convoy` marks the obstruction cleared, but `_measure_recovery` still requires at least two **physical follower cars released** plus sustained reduced stop count before claiming any reputation/mission payout. Stop reason logs are not gameplay rewards.
- No new checkpoint fields. The transient starvation timers reset when reconstructing a tow convoy; already approved `service_recovery_active` and its existing checkpointed stationary collection time remain unchanged.

## Focused test

`tests/traffic_perf_11a_tow_starvation_test.gd` builds real civic graph, signal, crossing reservation, mission and tow colliders; verifies W approach is red and future green is calculable; refuses recovery before the full two cycles, refuses while a crossing is occupied, refuses a layer-8 pedestrian physically in the worksite; allows grounded recovery only after all safety gates clear; confirms there is **no instant reward** when tow and offender are retired but queued cars have not yet moved.

Run it with existing tests:
- `wrong_way_tow_service_priority_test.gd` — no red/pedestrian bypass
- `aud3_wrong_way_tow_gridlock_recovery_test.gd` — genuine physical obstacle recovery
- `authorized_tow_obstacle_test.gd` — obstacle remains physical until safe clearance
- `aud3_wrong_way_signal_recovery_test.gd` — mission recovery
- `traffic_fix_09_single_approach_rules_test.gd` — central four-turn signal
- `traffic_fix_06_axis_crossing_release_test.gd` — conflicting crossing reservation
- `world_junction_checkpoint_test.gd` — checkpoint safety

## Windows verification

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Update failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$code = $LASTEXITCODE
$log | Out-Host
if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Import failed"
}
$tests = @(
    "traffic_perf_11a_tow_starvation_test.gd",
    "wrong_way_tow_service_priority_test.gd",
    "aud3_wrong_way_tow_gridlock_recovery_test.gd",
    "authorized_tow_obstacle_test.gd",
    "aud3_wrong_way_signal_recovery_test.gd",
    "traffic_fix_09_single_approach_rules_test.gd",
    "traffic_fix_06_axis_crossing_release_test.gd",
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
Write-Host "TRAFFIC-PERF-11A FOCUSED TESTS PASSED" -ForegroundColor Green
```

## Gameplay acceptance

- [ ] Fresh Wrong Way mission: inspect/report; municipal tow only starts after actual marshal intervention.
- [ ] During red/amber and occupied crossing, tow remains stationary; `CIVIC_TOW_GATE` shows correct W signal aspect and reservation owner.
- [ ] After two full cycles without progress, any still-present walker or car inside the actual worksite prevents collection; ensure a clear moment triggers stationary collection, never a red-light crossing.
- [ ] The tow/offender physically disappear only after 2s safe collection. `sustained_recovery` stays 0/1 until real followers actually leave the incident and at least two are counted as released.
- [ ] Resume from F5/F9 before tow, mid-tow and during authorized collection; no collision bypass, duplicate payouts or non-deterministic flash of signals.
- [ ] Five-minute multi-junction replay measures completed route throughput and separates actual incident blockage from ordinary red queueing.
- [ ] Android Compatibility renderer replay, validate input/UI and road collisions.

**Do not declare this resolved from source changes alone. No GitHub Actions manually triggered.**
