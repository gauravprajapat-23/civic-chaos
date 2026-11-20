# VEH-RIDE-08 — Parked-bike body integrity and NPC crash reverse

**Baseline:** VEH-ART-08 draft PR #89, which itself depends on WORLD-001F. No direct changes to `main`, `scripts/core/main.gd`, route permissions or save schema. All changes here require native Godot 4.7.2 and physical Windows/Android acceptance.

## Problems traced
1. Walking `CivicPlayerController` has a world-only physics mask. It used a custom horizontal actor sweep restricted to dynamic vehicle layer 4, but the parked motorcycle's interactable physical body is layer **16**. The character could therefore pass through the parked bike even though the player should stop at its shell.
2. When mounted, the bike is carried by the player; the parked collision body is disabled and a sensing-only body advertises the full rider+bike footprint to traffic. Existing contact checks stop forward intrusion into NPC layer 8, but reverse escape from an initial shallow overlap depended entirely on `PhysicsDirectSpaceState3D.collide_shape()` aggregate contact depth. In mixed ground/pedestrian contacts this can be unchanged/unavailable, leaving reverse blocked until the NPC moves.

## Corrections
- `scripts/player/player_controller.gd`: walking-only horizontal and airborne sweeps include layer 16 parked motorcycles as well as layer 4 cars. The actual CharacterBody remains world-only; motorcycles are not climbable floor surfaces. Mounted movement continues using the authoritative full-footprint limiter.
- `scripts/world/rideable_bike.gd`: short reverse recovery still requires an **existing** blocking overlap, no newly encountered collider and no movement toward any remaining blocker. It now accepts carefully bounded outward retreat (0.18 m maximum per attempted step), with contact-depth increase rejected, and never gives permission for moving forward deeper into a front collision or backing into a rear NPC.
- Both existing safety rules remain: zeroing unsafe forward velocity and checking the full physical envelope. This fix does **not** teleport the motorcycle or turn off pedestrian collisions.
- `tests/veh_ride_08_npc_reverse_recovery_test.gd`: walker cannot pass parked bike; genuine mount hides original walker and creates mounted rider; head-on NPC stops forward; bounded reverse is released; second NPC behind denies reverse; removing rear NPC restores reverse; no relocation by collision helper; deterministic fallback refuses forward and large step motions.

## Exact native commands
Use fresh detached review checkout of **this** branch (NOT the WORLD-001F test folder):

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
$review = "C:\Users\gauravp\Projects\civic-chaos-veh-ride-08-review"
if (Test-Path $review) { throw "Review folder already exists; inspect it before reuse" }
git worktree add --detach $review origin/fix/veh-ride-08-npc-reverse-recovery
if ($LASTEXITCODE -ne 0) { throw "Worktree failed" }
Push-Location $review
try {
  $godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
  & $godot --headless --path . --editor --import --quit
  if ($LASTEXITCODE -ne 0) { throw "Import failed" }
  foreach ($test in @(
    "veh_ride_08_npc_reverse_recovery_test.gd",
    "veh_art_08_exterior_design_test.gd",
    "vehicle_ride_07_impact_contact_stress_test.gd",
    "vehicle_ride_07_sustained_grip_stability_test.gd",
    "world_001f_save_contract_test.gd",
    "road_footpath_01_crossing_test.gd"
  )) {
    $output = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $output | Out-Host
    if ($exitCode -ne 0 -or $output -match '(?m)^\s*(SCRIPT ERROR:|ERROR:|FATAL ERROR:)' -or
        $output -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
      throw "Failed $test"
    }
  }
} finally { Pop-Location }
```

## Manual visual/device acceptance
- Walk directly into parked motorbike from all directions: stop before intersecting engine/seat; E/USE still mounts from either side where space is clear.
- On a moving motorcycle touch a standing NPC/front car gently: full bike stops without ghosting; with S/backward stick, reverse escapes without moving the NPC or tunneling.
- Add NPC/car immediately behind during front contact: reverse must **not** enter them.
- Dismount with bike stationary in a clear spot, remount; no duplicated rider, no detached hands/boots, no stuck interaction colliders.
- Repeat on Android touch controls while monitoring FPS and collision log `CIVIC_BIKE_HOLD`.
- Rerun full WORLD-001F regression gate after branch integration (the current WORLD-001F PASS was for baseline commit, not this new branch).

**State:** Source/test written, **no native Godot test executed by this agent**, PR approval/merge pending; GitHub Actions not triggered.
