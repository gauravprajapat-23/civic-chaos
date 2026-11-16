# TRAFFIC-FIX-08 — Junction Gridlock & Incident Isolation

**Date:** 2026-11-16  
**Existing branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source fixes and focused tests committed; local Godot/Android verification pending. Do not close PHYS-003, PHYS-005, PHYS-009.

## Evidence from latest PC gameplay log

The user's `traffic-fix-07.log` (Godot 4.7.2, Compatibility renderer) shows:

- Wrong Way mission followers first accumulate behind `WrongWayOffender/CollisionBody`, then behind each other: `QueuedVehicle_3` at lane 126, 24.98m; `QueuedVehicle_2` at 21.96m; `QueuedVehicle_1` at 18.94m; `QueuedVehicle_0` at 15.92m. This is a *real scripted incident*, not a stray signal flag. The lawful mission outcome still requires evidence, report, authorized tow, and observed traffic recovery.
- Background cars on lanes 142 and 147 repeatedly stop at 41.38m for a signal/zone, while several more cars remain at 38.36m and 35.33m with `lead_vehicle` blockers under `FourWayJunction` for thousands of ticks.
- At tick 3165 one car rightly stops for `player` layer 2. Do **not** weaken human sensing or blame every red hold on a signal bug.
- `red_signal` changes with NS_GREEN, NS_AMBER, ALL_RED_NS, EW_GREEN etc. The controller *is* advancing; the recurring blocker is a queue and physical central-zone occupancy, not evidence of a permanently frozen phase clock.
- Source of the persistent center deadlock may include vehicles admitted despite no safe space in the lane immediately after the intersection. The outer-junction priority logic already checks outbound capacity; the central one previously did not.

## Fix 08A — Central exit-capacity arbitration

**Code:** `scripts/traffic/central_intersection_priority.gd`

- Added a nine-metre outbound queue clearance requirement (`EXIT_CLEARANCE_M` 7 + 2 extra); an inbound vehicle must have space in *its intended next lane* before it may enter the central conflict zone.
- This check only inspects actual registered physical road users and their existing lane progress, so both background and mission-owned cars count; no new save state or RNG.
- A waiting contender whose exit is occupied cannot win all available green time and starve another approach whose exit is open.
- Existing **already-committed vehicles remain protected**, even when phase transitions. Red/amber/all-red and pedestrian reservations still override entry.
- A route legitimately terminating at the junction is not forced into a nonexistent next lane.

**Test:** `tests/traffic_fix_08_central_spillback_test.gd`: blocked exit prevents entry, free alternative can proceed, committed crossing stays protected, release occurs only after real outbound progress.

## Fix 08B — Isolate new routes from unresolved Wrong Way obstruction

**Code:** `scripts/traffic/traffic_spawner.gd`, `scripts/civic/wrong_way_live_mission.gd`

- Runtime route closure identified by civic mission owner. When Wrong Way starts, it closes only its actual approach lane to **new** background traffic route planning. Other entry lanes and destination choices remain available.
- This is NOT a collider, not a new signal phase, not a teleport and not a traffic completion. Cars already on the closed lane and the four mission follower actors remain physically present, obeying actual stop lines and obstacles.
- The mission closes the lane after physical staging; an authorized tow completion reopens it. The closure is also cleared on mission removal.
- Checkpoint preparation reinstates the incident closure and registers mission followers for shared sensing. Validated checkpoint restoration reopens it if the tow was already completed. It is a transient routing constraint, not a new checkpoint schema field.
- No changes to the civic mission's reward, reporting, tow completion or evidence requirements. Traffic Marshal metering remains an optional player action; it cannot remove an offender.

**Test:** `tests/traffic_fix_08_incident_detour_test.gd`: invalid closures refused, new city paths avoid the closed lane, multiple other routes still spawn, existing cars keep their routes, authorized reopen works, full generation reconfiguration drops transient closures.

**Scope caveat:** Illegal Parking uses a world-positioned stationary car, not the Wrong Way graph-lane offender. Its exact lane footprint must be established from physical collision captures before imposing any incident closure; a global closure could prevent legitimate traffic from reaching the district. Further **TRAFFIC-FIX-08C** will identify that exact lane and scope its spawn detour only if justified by runtime evidence.

## Focused Windows verification

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Git fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Git merge failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$exitCode = $LASTEXITCODE
$log | Out-Host
if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Godot import failed"
}

$tests = @(
    "traffic_fix_08_central_spillback_test.gd",
    "traffic_fix_08_incident_detour_test.gd",
    "traffic_fix_07_cross_fleet_junction_test.gd",
    "junction_fix_03b_central_release_test.gd",
    "traffic_fix_06_axis_crossing_release_test.gd",
    "wrong_way_tow_service_priority_test.gd",
    "aud3_wrong_way_tow_gridlock_recovery_test.gd",
    "road_game_01_traffic_marshal_test.gd",
    "traffic_game_02_manual_signal_test.gd",
    "traffic_spawner_test.gd",
    "world_junction_checkpoint_test.gd"
)
foreach ($test in $tests) {
    Write-Host "Running $test" -ForegroundColor Cyan
    $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $exitCode = $LASTEXITCODE
    $log | Out-Host
    if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
        -not ($log | Select-String '_PASS')) { throw "FAILED: $test" }
}
Write-Host "TRAFFIC-FIX-08 focused tests passed" -ForegroundColor Green
```

## Gameplay acceptance

- [ ] Replay a fresh five-minute traffic scene with central green for both axes across several complete phase rotations; confirm completed route counter increases and no gridlocked vehicle remains physically occupying the center across multiple greens without a real obstruction.
- [ ] The Wrong Way offender remains solid until reported and removed by authorized tow; background traffic chooses other legal paths for new cars while the incident is unresolved.
- [ ] The queued mission followers recover lawfully and the mission's **real** `released_ids` condition eventually completes; never fake a release.
- [ ] Pedestrians and player remain protected. A car already inside the central zone completes its path before another enters.
- [ ] If the player obstructs the road, stop reason remains `player`, and the car recovers once the player leaves.
- [ ] Test a checkpoint saved before and after the authorized tow; new background routes must obey the correct restored closure state.
- [ ] Android Compatibility renderer shows reasonable throughput with 8, 12 and 20 cars; collect frame-times and compare without disabling physics checks.
- [ ] Verify user-facing Traffic Marshal UI requires actual clearance for score rewards.

**Important:** these are source changes, not a verified resolution of the live screenshot. Never manually trigger GitHub Actions; use `[skip ci]` commits.
