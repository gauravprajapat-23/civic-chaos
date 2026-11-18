# VEHICLE-RIDE-05A — Full-Footprint Bike Collision, Safe Mount, Swept Turns & Side Exit

**Date:** 2026-11-18
**Existing branch:** `fix/aud-001-game024-gate-hardening`
**Status:** Source and focused tests committed; Godot 4.7.2 local import/tests, five-minute city replay, Android QA OPEN.
**Prior audit:** `docs/audits/VEHICLE_RIDE_05_COMPLETE_BIKE_RIDER_TRAFFIC_AUDIT.md`.
**User evidence:** PC screenshot: motorcycle visibly intersecting a green NPC car while rider is not properly seated.

## Findings and implementation

### 1. Shared real vehicle footprint

`scripts/world/rideable_bike.gd` introduces a **single** 1.15m wide × 1.55m tall × 3.05m long `BoxShape3D`, centered at local (0, 1.12, -0.05) relative to bike root, with modest 0.035m margin. The actual low-poly motorcycle's front wheel and rear assembly require a significantly longer clearance than the old 1.0×1.1×1.8m player-side probe.

`footprint_clear_at(world_origin,yaw,excluded)` queries world, player, vehicles and pedestrians (mask 1|2|4|8|16) and ignores only known flat under-wheel road support on world layer 1. Walls, poles, buildings, other vehicles, parked bikes (but not the bike's own interaction RID), and people remain blockers. A shared `_make_footprint_query` feeds both stationary and moving probes, so future modifications cannot accidentally use different dimensions.

### 2. Safe mount at the parked vehicle

`CivicPlayerController.mount_bike` now:
- captures the existing bike origin and orientation;
- refuses an occupied full bike envelope (excluding the rider's own RID);
- checks the actual rider capsule at the planned seat/root position and throughout the short transfer path (samples each ~0.3m);
- **moves the rider to the validated bike** and only then attaches the bike model, rather than snapping the parked motorcycle through a car to the walking player;
- restores rider position if attachment is refused, with clear failure messages.

This is a collision-checked short mount transfer, **not yet** a realistic stepping/leg-over animation. Rider's hands/grips and saddle alignment belong to 05B.

### 3. Full forward and turn-side collision

`CivicPlayerController._limit_bike_motion` now uses the bike-owned, 3.05m vehicle shape in a `cast_motion` and stationary overlap check before applying actual horizontal movement. Physics masks are unchanged; world-layer road support does not count as a solid wall for the overlap check. A blocked sweep clamps intended movement and speed, with `CIVIC_BIKE_HOLD reason=...` diagnostics.

Steering no longer checks only the tiny player capsule or only final yaw: three interpolated angular samples guard against the *front wheel swinging sideways* into a nearby car while the bike rotates. Actual accepted movement still runs through `CharacterBody3D.move_and_slide()`, and its original world-only collision mask stays unchanged. The walking-only `_recover_vehicle_descent_overlap()` relocation was removed from **riding only**, preventing an NPC overlap from magically shifting the entire mounted bike/rider sideways.

### 4. Mounted bike recognized by moving NPC traffic

When mounted, a nonblocking, layer-2 `MountedBikeTrafficSensor` StaticBody3D advertises the **complete bike footprint** to existing `CivicVehicleAgent.people_clear_at()` / `footprint_blocked_at()` checks. It has collision mask zero, so it does not physically shove traffic. The motorcycle itself stays on nonphysical interaction layer while attached to the player's physically authoritative CharacterBody. The sensor is deliberately excluded from the rider's own collision probes and removed from the sensing layer on park. No traffic light permissions, lane graphs or spawn logic changed.

### 5. Safe side-specific dismount

Once stopped and off the mount cooldown:
- preserve prior central player-capsule check (can't exit from inside a car or pedestrian);
- test a genuine walking-capsule transfer to first the right then left side, ~1.15m from the bike center;
- park motorcycle at its **current world position**, then move player only to the collision-checked side;
- refuse EXIT and leave the bike occupied if neither side is clear.

This fixes the old issue where the walker remained placed *inside* the freshly parked motorcycle.

## Committed regression files

- `tests/vehicle_ride_05a_mount_and_car_clearance_test.gd` — parked car covering bike denies mount without moving either actor, then clear mount puts rider at original parked location and enables front-wheel layer-2 recognition for ordinary NPC traffic.
- `tests/vehicle_ride_05a_swept_turn_clearance_test.gd` — a right-hand steering yaw would sweep the front wheel into a car even though the straight pose is clear, and a swept forward move stops before reaching another car.
- `tests/vehicle_ride_05a_safe_dismount_test.gd` — both sides obstructed rejects EXIT; one side cleared allows lateral escape while parked bike remains at original world location.
- Existing `vehicle_ride_01_bike_test.gd`, `vehicle_ride_02_wheel_roll_axis_test.gd`, `vehicle_ride_03_design_and_safety_test.gd`, `vehicle_ride_04_steering_lean_mount_test.gd`, `player_vehicle_contact_test.gd`, `traffic_spawner_test.gd`, `world_junction_checkpoint_test.gd` need rerun.

## Windows Godot 4.7.2 verification

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
    throw "Godot import failed"
}

$tests = @(
  "vehicle_ride_05a_mount_and_car_clearance_test.gd",
  "vehicle_ride_05a_swept_turn_clearance_test.gd",
  "vehicle_ride_05a_safe_dismount_test.gd",
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
  "traffic_spawner_test.gd",
  "world_junction_checkpoint_test.gd"
)
foreach ($test in $tests) {
  Write-Host "Running $test" -ForegroundColor Cyan
  $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
  $code = $LASTEXITCODE
  $log | Out-Host
  if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
      -not ($log | Select-String '_PASS')) {
    throw "FAILED: $test"
  }
}
Write-Host "VEHICLE-RIDE-05A local focused gate passed!" -ForegroundColor Green
```

## Manual acceptance and release blockers

- [ ] Reproduce user screenshot with green NPC car and bike side by side. Bike stops/steers clear before red body or wheels visually enter the car, even at 14m/s BOOST.
- [ ] E/USE cannot mount through an occupied bike seat/transfer path or move a parked bike from its initial location.
- [ ] Ride toward parked car head-on and obliquely; front tire stops before car, then reverse away without jumping sideways.
- [ ] Turn A/D with vehicle close on the inside and outside; no clipped front wheel, jump in yaw or unrecoverable stuck overlap.
- [ ] Ordinary NPC car senses front wheel beyond player's capsule and yields rather than striking rider from behind.
- [ ] Left and right dismount work only if that side's pedestrian capsule corridor is clear; if both obstructed, remain seated.
- [ ] 5-minute urban mission/traffic loop without new phantom blockers, vehicles spontaneously removed, or red-light bypass.
- [ ] Front/rear motorcycle mesh and visual lean still agree with whole-vehicle guard.
- [ ] Android input/physics and pause/resume remain reliable and frame time acceptable.

**Known limitations:** This is an early full-footprint guard built over arcade CharacterBody3D physics. It is not yet two-wheel rigid-body suspension, motorcycle crash/ragdoll handling or a versioned mounted-bike save system. Nonphysical visual lean can protrude slightly outside the upright bounding approximation; review actual screenshots and adjust shared constants. The runner cannot currently execute the user's local Windows Godot 4.7.2. Do not claim zero overlaps or a passing APK until the above verification is completed.
