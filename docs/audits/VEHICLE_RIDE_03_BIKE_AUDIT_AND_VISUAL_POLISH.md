# VEHICLE-RIDE-03 — Motorcycle Audit, Safety & Visual Polish

**Date:** 2026-11-18
**Branch:** `fix/aud-001-game024-gate-hardening`
**Status:** Source + focused regressions committed. Real Windows/Android engine gates, visual review, handling and crowded-street acceptance OPEN.

## Scope reviewed

Existing rider scene/controller `scripts/player/player_controller.gd`, motorcycle `scripts/world/rideable_bike.gd`, mobile controls `scripts/ui/touch_controls.gd`, city initialization `scripts/core/main.gd`, focused tests and previous VEHICLE-RIDE-01/02 changes. The source is an **arcade-style drivable motorbike sharing the player CharacterBody3D**, not a simulated two-wheel RigidBody3D. Do not assume traction, suspension or leaning physics.

## Confirmed code findings and actions

| Severity | Finding | Status |
| --- | --- | --- |
| P1 | `animate_wheels(abs(distance))` always advanced both wheels forward; reverse riding visually rolled forward | FIXED: wheel travel is now the signed dot product of measured planar displacement and bike forward direction |
| P1 | Pressing E/EXIT at high speed instantly parked the motorcycle (a world/static interaction target), even in moving traffic | FIXED: dismount refused until bike speed <=0.25m/s and actual horizontal player velocity <=0.35m/s; parking still vetoes real car/pedestrian occupancy |
| P1 | Mounting replaced the bike's direction with the player's previous walking-facing yaw; after a player-root rotation its local yaw could also misalign in world | FIXED: preserve the parked bike's actual world yaw; control and visuals set `global_rotation.y` |
| P2 | Rider's pose changed to sitting at mount but `_animate_walk(0)` was still called while riding; it could preserve stale swing angles | FIXED: riding consistently applies stationary seated pose without running the walking animator |
| P2 | Wheels were plain cylinders with little visual motion, and initial bike was mostly seven box meshes | FIXED: wheel hubs/discs, additional engine cover/fins, shocks, exhaust, foot pegs, fenders, tank accents, side panels, headlight/number plate, rear rack, two mirrors, and brighter brake lamp feedback |
| P2 | No explicit verification of reverse wheel spin, alternate initial heading, brake visual or large-bike accessory collision policy | FIXED IN REGRESSIONS: expanded existing riding test, added detailed design/safety test |
| P2 | Original wheel horizontal yaw issue in VEHICLE-RIDE-02 | Already fixed by local-axle rotation; retain its regression |

## Remaining issues not represented as completed

1. **Realistic suspension / lean / motorcycle steering:** Still arcade kinematic motion through the player CharacterBody. Real suspension, banking into corners and steering-fork articulation need a dedicated vehicle visual/physics layer and Android tuning.
2. **Riding in active city traffic:** A static rider is represented on the same player collision layer; bike-sized predictive casts check against world/cars/pedestrians but real dynamic NPC behavior and safe cross-intersection driving require gameplay replay. A driven player is not automatically an authorized traffic-signal actor.
3. **Mount transition geometry:** The current bike reparenting snaps its seat from within 2.8m to the rider's standing position; future animation should place player at a checked bike-side seat, without a physics-query outside of a physics frame or moving the bike through a wall.
4. **Checkpoint persistence:** F5/F9 intentionally blocked while mounted. A future versioned checkpoint transaction could preserve chosen bike, bike positions, occupancy and safe restore atomically. Do not hack bike fields into player-only save.
5. **Parked motorcycles and city traffic:** Parked bike remains a layer-16 interaction-only body. If public traffic must avoid user-parked bikes as real obstructions, introduce owner-specific physical occupancy and safe towing/recovery rather than an invisible road-blocking collider.
6. **Visual inspection:** No Android frame captures or side-on live gameplay screenshots are available from code editing. Verify actual wheel/rider alignment, handlebar height, 3D depth sorting, motorbike footprint, and street-side spawning on the device.

## Changed / tested code

- `scripts/world/rideable_bike.gd` — detailed low-poly model; reversible signed wheel travel; brake lamp visual method
- `scripts/player/player_controller.gd` — preserve world orientation, safe speed-gated dismount, signed movement, seated pose and brake lamp updates
- `tests/vehicle_ride_01_bike_test.gd` — rotating player root, initial bike heading, no dismount during forward/reverse travel, brake to stop
- `tests/vehicle_ride_03_design_and_safety_test.gd` — cosmetic scene contracts, wheel sign/return, light response, and collision safety
- `tests/vehicle_ride_02_wheel_roll_axis_test.gd` — existing wheel-axis guard
- No unrelated map, NPC mission, signal, civic reward, save schema or traffic spawner changed.

## Godot 4.7.2 PowerShell gate

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
if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) { throw "Import failed" }

$tests = @(
    "vehicle_ride_03_design_and_safety_test.gd",
    "vehicle_ride_02_wheel_roll_axis_test.gd",
    "vehicle_ride_01_bike_test.gd",
    "vehicle_ride_01_mobile_actions_test.gd",
    "player_controller_test.gd",
    "player_vehicle_contact_test.gd",
    "player_safe_restore_test.gd",
    "player_checkpoint_atomicity_test.gd",
    "touch_controls_test.gd",
    "vehicle_world_obstacle_test.gd",
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
Write-Host "VEHICLE-RIDE-03 FOCUSED GATE PASSED" -ForegroundColor Green

New-Item -ItemType Directory -Force build | Out-Null
$apk = "build\CivicChaos-bike-03-debug.apk"
& $godot --headless --path . --export-debug "Android Debug" $apk
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $apk)) { throw "APK export failed" }
Get-Item $apk | Select-Object FullName, Length
```

## Manual acceptance

- [ ] Approach bike sideways, mount with E / mobile USE, bike preserves its parked direction even if the player approached facing backward.
- [ ] Accelerate and observe both wheels roll forward; S reverse rolls backwards. Brake to standstill; wheel rotation ceases.
- [ ] E/EXIT refuses while bike is moving; after braking fully, parks the bike at its real location.
- [ ] Seated player legs no longer animate like walking; mirrors, exhaust, wheel hubs, fenders, side panels and engine are visible without floating above chassis.
- [ ] Tail lamp brightens while BRAKE or S is held, dims afterward.
- [ ] Crowded street and turn test at 12–14m/s: collisions remain enforced with pedestrians and NPC traffic. No vehicle can clip into solid buildings.
- [ ] Android action buttons, camera, modal pause/touch release and low-end compatibility performance are acceptable.
- [ ] Normal F5/F9 save/load remains correct when dismounted and rejected explicitly when mounted.

**Source/test commits do not imply that engine execution succeeded. Keep open until user-local gate + device ride passes.**
