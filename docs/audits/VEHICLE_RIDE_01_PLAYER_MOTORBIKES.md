# VEHICLE-RIDE-01 — Rideable Player Motorbikes

**Date:** 2026-11-17  
**Repository:** `gauravprajapat-23/civic-chaos`  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source and focused regression committed; Godot 4.7.2 PC and Android verification outstanding. No GitHub Actions manually triggered.

## Player request and implementation

Add bikes the player can ride in the existing 3D Civic Chaos map. Delivered **two reusable low-poly motorcycles** on safe street-side spawn locations rather than adding bikes to automatic NPC traffic.

- `scripts/world/rideable_bike.gd`: Motorbike geometry (front/rear wheels, chassis, fuel tank, seat, fork, handlebars, headlight and rear lamp) with high-visibility BIKE / E / USE TO RIDE hint. Parked interaction uses existing layer-16 non-blocking civic interactable detection; the body is non-colliding while the player rides. The bike attaches to the actual player transform; it is parked at the real current location when dismounting. The game does not delete the bike when parked.
- `scripts/core/main.gd`: Initializes two bikes at `Vector3(6.6, 0.16, -24.0)` and `Vector3(-6.6, 0.16, 33.0)`. They are in the existing low-poly district, outside main traffic centerlines and civic incident stations. No NPC spawner or route graph changes.
- `scripts/player/player_controller.gd`: E/USE interaction mounts within 2.8m; camera widens from 4.0m to 5.7m with a raised perspective. The player's existing `CharacterBody3D` remains the movement and ground-collision authority; a forward-projected bike-sized collision box rejects driving into buildings, cars and pedestrians, while the original player/car collision checks remain active. Acceleration, steering, reverse, coasting, optional boost and explicit brake are separate from walking/jumping movement. Visual arms and legs assume a seated rider pose. Physical accepted distance spins the motorcycle wheels; no synthetic traffic counts.
- `scripts/ui/touch_controls.gd`: Android joystick remains the same. On mounting, JUMP becomes BRAKE, RUN becomes BOOST, USE becomes EXIT. Dismount restores JUMP/RUN/USE with the original touch hitbox rectangles and the same camera look area.
- Checkpoint safety: the preexisting player + world atomic checkpoint does not serialize motorbike ownership. Main now refuses F5/F9 while mounted and explains to park first; no forged vehicle state or save schema changes. `restore_now_safe` rejects a mounted restore rather than mutating rider state in the middle of a failing transaction. A queued legacy restore also safely parks first.

## Controls

| Action | Windows | Android |
| --- | --- | --- |
| Mount / Exit | E near bike, E while riding | USE near bike, EXIT while riding |
| Accelerate | W | Joystick forward |
| Reverse / brake | S or Space to brake | Joystick back or BRAKE |
| Steer | A / D | Joystick left / right |
| Boost | Shift | BOOST |
| Look | Mouse | Drag camera in free right-hand area |
| Pause | F1 | II |

Speed: 12m/s default, 14m/s boosted; 2m/s reverse. Steering is slower at low speed; no jump while riding. Collision checks stop movement before buildings, vehicles and people, rather than turning collisions off.

## Focused regression tests

- `tests/vehicle_ride_01_bike_test.gd`: Player scene + world floor and real bike. Checks interactable body, model pieces, mount ownership and camera, physical acceleration, steer, braking, rejection of unsafe dismount through a layer-4 obstacle, park/reuse, original collision mask and camera.
- `tests/vehicle_ride_01_mobile_actions_test.gd`: Verifies Android BRAKE / BOOST / EXIT text on the original four touch buttons, identical hitboxes while riding and complete restoration of walking buttons.
- Rerun `player_controller_test.gd`, `player_vehicle_contact_test.gd`, `player_safe_restore_test.gd`, `player_checkpoint_atomicity_test.gd`, `touch_controls_test.gd`, `touch_layout_test.gd`, `vehicle_world_obstacle_test.gd`, `world_junction_checkpoint_test.gd`.

## Local PowerShell verification and Android APK

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
    "vehicle_ride_01_bike_test.gd",
    "vehicle_ride_01_mobile_actions_test.gd",
    "player_controller_test.gd",
    "player_vehicle_contact_test.gd",
    "player_safe_restore_test.gd",
    "player_checkpoint_atomicity_test.gd",
    "touch_controls_test.gd",
    "touch_layout_test.gd",
    "vehicle_world_obstacle_test.gd",
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
Write-Host "VEHICLE-RIDE-01 REGRESSION PASSED!" -ForegroundColor Green

New-Item -ItemType Directory -Force build | Out-Null
$apk = "build/civic-chaos-rideable-bikes-debug.apk"
& $godot --headless --path . --export-debug "Android Debug" $apk
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $apk)) {
    throw "Android debug APK export failed"
}
Get-Item $apk | Select-Object FullName, Length
```

## Gameplay acceptance still open

- [ ] On starting the city the two bikes exist by the roadside with readable BIKE / E / USE hints.
- [ ] E / USE from 2.8m or less mounts one; input W/joystick accelerates, A/D/left-right steers, S/Space/BRAKE slows, Shift/BOOST increases acceleration, and steering/camera are smooth.
- [ ] Character appears seated and wheels animate as the character physically travels.
- [ ] Cannot drive through buildings, live traffic or pedestrians; no bypass of central intersection pedestrian safety, no new NPC jams, and no city car despawn.
- [ ] E / EXIT safely parks, returning to walking, default camera and original touch labels; can remount the same bike or use the second.
- [ ] Dismount is refused when another car or pedestrian occupies the rider's standing space.
- [ ] F5/F9 while mounted clearly prompts parking, and normal checkpoint save/restore still passes when on foot.
- [ ] Android Compatibility mode has usable bike hit targets and no stuck touch actions after pausing, rotating or closing a modal.
- [ ] Long play with 12 background cars and campaign mission cars has no significant FPS regression.

**No Godot or Android runtime was available through the GitHub editing tools. Do not treat committed source as verified gameplay.**


## 2026-11-17 focused QA follow-up — standalone input fixture

User's first `vehicle_ride_01_bike_test.gd` run printed `CIVIC_CHAOS_VEHICLE_RIDE_01_BIKE_PASS` but emitted hundreds of real engine errors for missing InputMap actions `look_left/right/up/down`, `jump`, and `sprint`. The test only registered the four walking directions. These other actions normally come from `Main._enter_tree()`, which a standalone `SceneTree --script` test does **not** load. Consequently the user's deliberately strict ERROR-check gate correctly failed. The test also accessed `obstacle.global_position` while that StaticBody3D was not in SceneTree, triggering `!is_inside_tree()` and a default transform.

**Fixed in `tests/vehicle_ride_01_bike_test.gd`:** the headless test now registers every action the player's walking, look and bike physics polls **before** adding PlayerRoot; sets the obstruction's local position prior to parenting; and suspends the player's physics before fixture teardown. `Main._enter_tree()` bindings and gameplay input behavior stay unchanged. This is a correction of the test harness, **not** a claim of new bike gameplay physics behavior. Earlier PASS marker was not clean because errors accompanied it. The full clean gate still requires user-local rerun.


## VEHICLE-RIDE-02 — Correct motorcycle wheel rolling axis (2026-11-18)

The player reported both wheels turning horizontally instead of rolling vertically while driving. Root cause: motorcycle wheels use `CylinderMesh` (axle along its **local Y axis**) and each wheel is tilted `PI / 2` about its Z axis so the physical axle lies **horizontally across the bike**. The prior animation used `wheel.rotate_y(angle)`, which yaws around the parent-space upright axis. Updated `CivicRideableBike.animate_wheels` to use `rotate_object_local(Vector3.UP, angle)`, preserving the horizontal axle while rotating each tire around its **own local Y**. Added a contrasting lightweight `RollingSpoke` as a child of each wheel so physical rotation is visible against otherwise featureless round tires. Rotation derives exclusively from the player's accepted world displacement; the parked bike still does not spin.

New regression: `tests/vehicle_ride_02_wheel_roll_axis_test.gd`. Verifies axle begins and stays across bike, a quarter-circumference roll changes the radial direction by 90 degrees into the vertical plane, wheel centers stay fixed, and zero distance produces no rotation.

**Status:** GitHub source and regression test committed; local Godot import, bike-drive visual review and Android verification pending. No GitHub Actions manually triggered.
