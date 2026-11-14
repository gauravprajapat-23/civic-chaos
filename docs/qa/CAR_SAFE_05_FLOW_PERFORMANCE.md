# CAR-SAFE-05 — Flow Recovery and Android Performance

## Scope and current status
Source committed; local Godot acceptance and physical Android measurements **pending**. This milestone prevents **new traffic arrivals** from compounding near-total standstill. It does **not** forcibly teleport, remove, or accelerate existing cars and never overrides character clearance, red lights, reservations, or braking.

## Control rule
When at least 3 physical cars are active and at least 75% are below 0.2 m/s, delay additional spawns for that tick. The rule is deterministic and evaluated after vehicle movement, so cars automatically admit new traffic on a subsequent scheduled tick when flow recovers. Manual `try_spawn()` callers follow the same rule. No RNG draws or rejection-count updates occur for deferred arrivals.

The live `CivicTrafficSpawner.metrics()` now includes:
- `congested`: whether the current fleet meets the queue-pressure rule
- `spawn_backpressure_ticks`: cumulative ticks that deferred new traffic in this runtime generation
- `timing`: existing measured average/peak traffic tick microseconds and exact sensor count diagnostics

These metrics are local session diagnostics, **not** saved or cross-device performance claims. `configure()` and checkpoint commit reset the runtime backpressure counter. The checkpoint schema remains unchanged.

## Windows local regression gate
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git merge --ff-only origin/fix/aud-001-game024-gate-hardening
if ($LASTEXITCODE -ne 0) { throw "Git update failed" }

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
$import = & $godot --headless --path . --editor --import --quit 2>&1 | Out-String
$importCode = $LASTEXITCODE
$import
if ($importCode -ne 0 -or $import -match 'SCRIPT ERROR:|ERROR:') { throw "Import failed" }

foreach ($test in @(
 "car_safe_05_backpressure_test.gd",
 "traffic_budget_test.gd",
 "traffic_checkpoint_invariants_test.gd",
 "car_safe_04_checkpoint_test.gd",
 "car_character_clearance_test.gd",
 "vehicle_actor_safety_test.gd",
 "vehicle_pedestrian_recovery_test.gd",
 "outer_intersection_movement_test.gd",
 "outer_intersection_priority_test.gd"
)) {
  $result = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
  $code = $LASTEXITCODE
  $result
  if ($code -ne 0 -or $result -match 'SCRIPT ERROR:|ERROR:') { throw "FAILED $test" }
}
```

After focused tests pass, run `tools/verify_game024.ps1` for the exact current commit before release. Keep the `build/` reports and logs as evidence. Do not manually trigger GitHub Actions.

## Physical Android measurement
Install the new debug APK and document: device model, Android version, orientation, scene, run length, active car count, on-screen FPS, worst observed hitch, and temperature/throttling symptoms. Test a busy intersection while a player approaches and a pedestrian crosses. Repeat after a checkpoint load and after background/resume. Compare before/after screenshots or video of queues, visible car overlap and stop/resume behavior.

**Fail** if traffic enters a character, the crossing is blocked permanently after pedestrians leave, a light is bypassed, a checkpoint restores into an occupied body, or a newly spawned car enters a jam. Never assert the game holds 30/60 FPS without hardware profiling.

## Remaining improvements
This batch implements congestion backpressure and metrics; persistent-stall root-cause classification and alternate routing are **not implemented**. They need a safe deterministic junction test proving liveness without violating existing signal or pedestrian priority.
