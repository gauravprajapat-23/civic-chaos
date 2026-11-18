# VEHICLE-RIDE-04 — Correct A/D Steering, Leaning, Fork, Visual Suspension and Mount/Exit Polish

**Date:** 2026-11-18
**Branch:** `fix/aud-001-game024-gate-hardening`
**Status:** Source implementation and tests committed; Windows Godot 4.7.2 / Android gameplay verification pending.

## Problem and root cause

User reported the motorcycle turns the opposite direction with both **D** and **A**. The keyboard mappings in `Main._enter_tree` were correct (D -> `move_right`, A -> `move_left`), but `CivicPlayerController._advance_bike` incremented heading in proportion to positive right input. In Godot's coordinate system forward is `-Z`; increasing Y heading rotates that vector toward **negative X (left)**. This reversed A/D in forward gear. Reverse must reverse steering direction again.

## Fixes committed

- `scripts/player/player_controller.gd`: `static func bike_steering_delta(axis, signed_speed, delta)` now uses a **negative steering-axis sign** with genuine speed-dependent turning and reverse inversion. D gives negative yaw/rightward heading and A gives positive yaw/leftward heading when moving forward. Stops steering while stationary. The actual bike's world yaw, visual rider and intended travel direction share this corrected angle.
- `scripts/world/rideable_bike.gd`: New `VisualRig` contains the motorcycle's visual-only mesh children. A `SteeringFork` pivots the real front wheel, handlebars, mirrors, headlight, fork and fender together, so front wheel and visual steering agree. The whole visual rig banks up to ~0.19 radians toward the turn based on steering input and velocity, automatically upright when stationary. Tiny accepted-distance-driven ~2.5cm vertical bob gives a basic suspension feeling, but **this is not physical independent front/rear suspension**.
- `scripts/player/player_controller.gd`: Cosmetic rider lean tracks bike lean by 70%, without rotating the player's CharacterBody or collision capsule. Mount fades the rider into a seated pose over 0.35s. Safe dismount transitions the rider back toward standing over 0.35s, without physically moving player through obstacles. A short exit cooldown prevents same-frame mounting/unmounting from repeated use presses.
- Dismount still requires essentially zero speed and a genuinely clear car/pedestrian standing footprint. Original collision sweep, camera, touch action mapping, save/load restrictions, traffic signals and NPC movement are preserved.

## New and updated regressions

- `tests/vehicle_ride_04_steering_lean_mount_test.gd`: pure deterministic steering assertion (+X/right with D; -X/left with A), opposite reverse turning, no stationary turn; real `CivicRideableBike` fork/lean in both directions, reverse banking, upright rest, stable physical interaction transform.
- `tests/vehicle_ride_01_bike_test.gd`: extends the real physics/input rider fixture to hold D/W and assert right sign, hold A/W and assert left sign; proves safe exit animation and no rapid remount, with eventual remount after cooldown.
- `tests/vehicle_ride_02_wheel_roll_axis_test.gd` and `tests/vehicle_ride_03_design_and_safety_test.gd`: switched pure mesh lookup to recursive search following safe `VisualRig/SteeringFork` reparenting. Preserve wheel-axis and detailed art checks.
- `tests/vehicle_ride_01_mobile_actions_test.gd`: unchanged touch actions BRAKE/BOOST/EXIT and existing joystick.

## Windows PowerShell verification

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Merge failed" }

$importLog = & $godot --headless --path . --editor --import --quit 2>&1
$importCode = $LASTEXITCODE
$importLog | Out-Host
if ($importCode -ne 0 -or ($importLog | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Godot import failed"
}

$tests = @(
    "vehicle_ride_04_steering_lean_mount_test.gd",
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
    $testLog = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $testCode = $LASTEXITCODE
    $testLog | Out-Host
    if ($testCode -ne 0 -or ($testLog | Select-String 'SCRIPT ERROR:|ERROR:') -or
        -not ($testLog | Select-String '_PASS')) {
        throw "FAILED: $test"
    }
}
Write-Host "VEHICLE-RIDE-04 focused gate passed" -ForegroundColor Green

New-Item -ItemType Directory -Force build | Out-Null
$apk = "build\CivicChaos-ride-04-debug.apk"
& $godot --headless --path . --export-debug "Android Debug" $apk
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $apk)) { throw "Android build failed" }
Get-Item $apk | Select-Object FullName, Length
```

## Gameplay acceptance

- [ ] On forward riding, holding **D** rotates/steers motorcycle **right**, A **left**; releasing steering keeps natural forward trajectory. Verify under physically clear street conditions.
- [ ] Reverse gear inverts steering relative to forward, without unnatural instantaneous 180-degree facing.
- [ ] Front fork/wheel/bar/mirrors turn with steering; wheel rolling around horizontal axle stays correct.
- [ ] Motorcycle and rider lean toward a real turn and straighten when steering ends; no tipping of the physical player collider, no car clipping.
- [ ] Very subtle visual suspension motion on accepted travel and no perpetual bob at idle; the interaction target remains stationary while parked.
- [ ] Mounted rider smoothly settles into a seated pose, and safe dismount returns to standing; rapid E/EXIT taps do not accidentally remount.
- [ ] Android joystick left/right matches A/D, including while BOOST is held; BRAKE/EXIT labels do not overlap; safe pause/focus and checkpoint restrictions remain intact.
- [ ] Motorcycles spawn safely and existing civic/traffic missions remain functional after five minutes.

## Open limitations

Arcade steering and visual-only suspension, not true two-wheel multi-body suspension, tire traction, grounded ray-wheel physics or crash/ragdoll. Mount still reattaches the bike model to the existing rider transform for compatibility; this milestone improves the character animation without a physically interpolated vehicle-seat transfer. The rider's collision footprint and NPC-traffic priority rules are not replaced.

**No user-local Godot/Android verification has yet been run on these changes; treat source-complete as pending QA. No GitHub Actions manually triggered.**
