# ROAD-GAME-01 — Player Traffic Marshal & Verified Reputation

**Date:** 2026-11-16  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source and focused regression committed; Godot import, PC gameplay and Android verification pending.

## Why this task exists

The user's November 16 screenshot shows traffic jammed on a busy central crossing while *Footpath First | Illegal Parking* is active. The supplied console log records repeated `lead_vehicle` holds against `WrongWayLiveMission/QueuedVehicle_1/CollisionBody`, even long after the original Wrong Way mission. Some observed traffic signal heads appear simultaneously green; the **central** controller intentionally grants opposite parallel approaches green together (N + S or E + W), never perpendicular N/E concurrently. Outer intersections run their own independent right-of-way clock. Visual signal appearance and logical car entry still require in-game verification.

This makes a good civic-sense gameplay activity, but **not** an excuse to override pedestrian crossing ownership or ghost vehicles off the street and hand out fake reputation. The player should coordinate lawful queue relief and earn a reward only for *measured actual recovery*.

## Root cause and collision lifecycle fix

- `CivicWrongWayLiveMission._advance_cars` previously kept all four mission-specific follower scenes indefinitely. When a follower's graph route finished, `CivicVehicleAgent.active` became false, but unlike normal `CivicTrafficSpawner` actors, the follower's `CollisionBody` remained on physical layer 4. Background traffic could then report a persistent blocking collider from an **inactive** car.
- `_sync_follower_presence(car)` now leaves a **route-complete** follower's logical record in place for checkpoint/history, while hiding the vehicle and switching its collision body to layer 0. An active mission follower remains fully visible and solid. The state is synchronized after physical advancement and again when restoring a checkpoint.
- A still-active offender, actual stalled mission car, parked car, pedestrian or obstacle is **not** removed by this cleanup. A player must complete its normal incident/reporting/municipal service action.

## Player interaction: Traffic Marshal station

**Location:** North-west side of center, on the west sidewalk at approximately `(-5.5, 0.21, -10)`.  
**Control:** Aim at the small yellow roadside TRAFFIC MARSHAL sign, press **E** on PC or **USE** on mobile. It is an interactable sensor on layer 16, **not** a collision blocker.

**Evidence gate:**

1. At least three live background traffic cars, at least two stopped.
2. At least one real central-intersection car within 18 metres has been held for 40 fixed ticks (two seconds) because of `lead_vehicle`, `world_collider`, `central_zone_occupied`, `outer_zone_occupied` or `outbound_blocked`. Ordinary red-light holds alone don't count.
3. The one-time, checkpoint-persistent `traffic_marshal:center:verified_clearance` reputation receipt hasn't already been awarded.

**Action:** `CivicTrafficSpawner.request_marshal_metering(400)` defers new background car spawns for 20 seconds (20 Hz fixed clock) and otherwise leaves the world alone. Current cars continue their usual route, legal lights, pedestrian reservations, obstacle sweeps and crossing rules. No player-authorized signal override, teleport, collider removal or phase mutation occurs.

**Win gate** (during 40 seconds after action): At least two **actual `completed_total`** background routes finish, global stopped count decreases, **and** the number of physically stalled center-junction vehicles decreases. This evidence is compared with the snapshot at the moment the player interacts, not a synthetic timer.

**Reward:** Once only, civic metrics change by Safety +10, Efficiency +15 and Cooperation +10; the player's aggregate reputation updates through the existing score manager. This is an **outcome**, not an additional claimable mission reward, and uses the existing idempotent `processed_events` ledger so F5/F9 cannot double-pay.

**Failure:** If the physical queue does not recover, the player receives a message explaining that no reward was granted. The sign changes to TRY AGAIN. A still-blocked vehicle remains solid and must be dealt with through the relevant incident (e.g. talk to the illegally parked vehicle's owner). New arrivals resume after the temporary 20-second meter expires.

**Checkpoint:** The reputation receipt is already part of saved `CivicCityMetrics`. Meter duration and in-progress button state are *ephemeral*; they are cleared after a successful checkpoint load, because they are not a physical traffic or civic outcome and should not be duplicated across restore. No checkpoint schema changes.

## Code and tests

- `scripts/civic/traffic_marshal_assist.gd` — pure eligibility and measured-clearance gates.
- `scripts/core/main.gd` — player-interactable world station, role guidance, evidence gate, completion and once-only reputation.
- `scripts/traffic/traffic_spawner.gd` — bounded spawn metering; no signal/vehicle safety change.
- `scripts/civic/wrong_way_live_mission.gd` — retire physically completed follower colliders but retain checkpoint records.
- `tests/road_game_01_traffic_marshal_test.gd` — red-light fraud prevention, real sustained central blocker, two-route/queue clearance, idempotent ledger across restores, meter expiration, active/inactive follower body preservation.

## Local gate

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
$branch = "fix/aud-001-game024-gate-hardening"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Git fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Git update failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$exitCode = $LASTEXITCODE
$log | Out-Host
if ($exitCode -ne 0 -or ($log | Select-String 'ERROR:|SCRIPT ERROR:')) { throw "Import failure" }

foreach ($test in @(
    "road_game_01_traffic_marshal_test.gd",
    "aud3_wrong_way_tow_gridlock_recovery_test.gd",
    "wrong_way_tow_service_priority_test.gd",
    "vehicle_world_obstacle_test.gd",
    "city_signal_stop_line_test.gd",
    "traffic_fix_06_axis_crossing_release_test.gd",
    "traffic_spawner_test.gd",
    "world_junction_checkpoint_test.gd"
)) {
    $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $exitCode = $LASTEXITCODE
    $log | Out-Host
    if ($exitCode -ne 0 -or ($log | Select-String 'ERROR:|SCRIPT ERROR:') -or
        -not ($log | Select-String '_PASS')) { throw "Failed $test" }
}
```

## Required live acceptance

- [ ] Spawn and aim at traffic marshal post from sidewalk, activate via E and mobile USE. The sign must not obstruct walking or cars.
- [ ] A normal red-light-only queue must **not** allow the reward.
- [ ] A two-second physical central queue allows temporary metering; no new car spawns during 20 seconds, with no extra RNG draws or rejected counters.
- [ ] Real cars remain bound by traffic lights and actual pedestrians, not forced across a crossing.
- [ ] Complete the wrong-way/parking incident legitimately; actual path recovery should drain the queue. Only then can central traffic-marshalling reward be issued.
- [ ] Two real background route completions, reduced global queue and lower central blockage produce exactly one score event. No proof = no reward.
- [ ] After F5/F9, prior reward remains claimed and no pending metering persists.
- [ ] PC visual signal audit: both opposite parallel directions green is **expected**, but perpendicular conflicts must never both green. Verify both outer and center heads correspond to their respective logical controllers.
- [ ] Android test with on-screen USE, 20 moving cars, no input/physics regressions.

**Not verified in Godot locally yet.** Do not close ROAD-GAME-01 or existing PHYS-003/005/009 just because a code commit exists.
