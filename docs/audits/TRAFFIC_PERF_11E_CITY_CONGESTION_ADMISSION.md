# TRAFFIC-PERF-11E — City Arrival Metering & Congestion Drain

**Date:** 2026-11-16
**Branch:** `fix/aud-001-game024-gate-hardening`
**Status:** Source and focused regression committed; local Godot tests and five-minute live replay **pending**.

## User report

User waited five minutes; new traffic continued appearing while existing NPC vehicles remained stopped at intersections. Changing the signals manually did not relieve the physical queues. Earlier screenshots and traffic diagnostics showed genuine `lead_vehicle`, `central_zone_occupied`, `red_signal`, and scripted `WrongWayLiveMission` blockage. These are **different** causes: a vehicle cannot move into an occupied lane simply because it gets green.

## Root cause in current source

`CivicTrafficSpawner` used `spawn_interval_ticks = 30` at 20 Hz (**one new car attempt every 1.5 s**) with up to **20 active city cars**. The existing backpressure engaged only when at least **75%** of three or more cars were stopped. That permits a four-exclusive-direction signal junction to accumulate demand long before backpressure triggers. Active municipal towing and the post-tow follower discharge window held new central entries but did **not** prevent the background spawner from creating additional traffic outside the center. This is counterproductive: blocking entry while still creating new cars can fill more roads.

## Implemented

`scripts/traffic/traffic_spawner.gd`:

1. **Four-way city inflow:** in expanded-city mode, automatic spawning now requires at least **100 fixed ticks between attempts** (five seconds), even if its general `spawn_interval_ticks` export remains 30. Does not affect legacy `make_test_graph()` fixtures.
2. **Bounded live fleet:** only **12 ordinary active background cars** may be admitted in expanded-city mode (also respects lower `maximum_active` values and `work_budget.maximum_agents`). This is an *admission cap*, not a despawn; existing checkpoints with up to 20 physical cars are still preserved.
3. **Early physical queue detection:** pause new arrivals when **at least five live background cars** exist and **50% or more are physically stopped**, rather than waiting until 75% stopped. All counts come from actual `CivicVehicleAgent.speed_mps` and `active`, not fabricated mission counters.
4. **Drain hysteresis:** after an actual soft-congested state, hold new spawns until the queue has improved *and* at least 80 simulation ticks (four seconds) of recovery pass. No extra RNG draws, rejected totals or fake throughput when an arrival is deferred.
5. **Municipal / mission priority linkage:** while the reported and authorized municipal tow has central admission priority or a legitimate post-tow mission follower discharge window is active, **new normal background spawning is fully deferred city-wide**. Existing NPCs continue to travel legally; other junctions and missions remain active. When service ends and traffic drains, the usual capped city admission resumes.
6. **Safety preserved:** No signal bypass, pedestrian collision layer change, forced teleport, early civic reputation, car deletion, checkpoint format change or physical mission follower removal. Waiting at red is still legitimate. The player may still need to complete an incident to eliminate an actual physical obstruction.

`tests/traffic_perf_11e_city_admission_test.gd` verifies expanded-city pace, service/recovery admission, RNG/reject counter preservation, earlier stopped-pressure threshold, recovery hysteresis, 12-car live cap and unchanged legacy small-test-graph demand.

## Local verification

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Merge failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$exitCode = $LASTEXITCODE
$log | Out-Host
if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Import failed"
}
$tests = @(
    "traffic_perf_11e_city_admission_test.gd",
    "traffic_fix_11d_wrong_way_follower_release_test.gd",
    "traffic_fix_11c_tow_priority_lifecycle_test.gd",
    "traffic_fix_11b_municipal_junction_priority_test.gd",
    "traffic_perf_11a_tow_starvation_test.gd",
    "traffic_fix_08_incident_detour_test.gd",
    "traffic_fix_09_single_approach_rules_test.gd",
    "outer_signal_10_four_approach_test.gd",
    "traffic_spawner_test.gd",
    "world_junction_checkpoint_test.gd"
)
foreach ($test in $tests) {
    Write-Host "Running $test" -ForegroundColor Cyan
    $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $exitCode = $LASTEXITCODE
    $log | Out-Host
    if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
        -not ($log | Select-String '_PASS')) {
        throw "FAILED: $test"
    }
}
Write-Host "TRAFFIC-PERF-11E focused gate passed" -ForegroundColor Green
```

## Live gameplay acceptance (issue remains OPEN)

- [ ] Fresh run, five-minute timer: `TRAFFIC Active` stays at or below **12** normal cars (mission vehicles are separately authored and counted) while backlog changes; **Completed** increases during normal green windows.
- [ ] During authorized Wrong Way tow and follower recovery, **spawned_total stops increasing**; already-entered ordinary cars physically finish, then real followers move through next safe W green.
- [ ] When 50% of five or more normal cars are stopped, new spawning pauses instead of contributing new gridlocked cars; after four-second hysteresis and real movement, capped arrivals resume.
- [ ] Test traffic marshal UI manually: signal change has no unsafe effect if exit lane is physically blocked; no two directions green or pedestrian overlap.
- [ ] F5/F9 with 12–20 saved cars preserves genuine car nodes and their physics without synthetic completion or reputation.
- [ ] Capture `CIVIC_TRAFFIC_HOLD`, `CIVIC_TOW_GATE`, and `CIVIC_MISSION_CAR_HOLD` for any remaining fixed-position blockers; identify the *front-most* blocking vehicle instead of weakening collision checks.
- [ ] Android performance replay (Compatibility): compare 8/12/20-car CPU/graphics load, draw calls, and throughput.

**Note:** Admission control prevents making the queue worse but cannot magically clear an occupied junction. If five-minute *physical* gridlock persists with the new demand limits, next task is `TRAFFIC-FIX-12 — Head-of-Line Blocker Identification & Physically Safe Turn Recovery`, not increasing green times.

No GitHub Actions manually triggered.
