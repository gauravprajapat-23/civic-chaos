# GAME-019 — Background World Checkpoints

Status: **Source implemented, Godot 4.7.2 runtime tests pending**. Date: 2026-11-07. Branch: `fix/regression-nov05`.

## Scope
The verified v2 F5/F9 checkpoint now includes `world_checkpoint` with one coherent version-1 background simulation snapshot:

- Fixed-step simulation clock: tick, delta, accumulator, pause state
- Traffic lights: six legal phases (including amber/all-red), elapsed time and timings
- Background vehicles: ordered road routes, positions, speeds, profiles, delays, traffic counters and RNG state as decimal string
- Intersection reservations: pending intervals, zones and occupied crossing owners
- District pedestrians: actual physical positions, progress, sidesteps, blocked frames, crossing state and reservation start times

The world preflight rejects invalid schema, impossible phases, illegal routes, mismatched clock/spawner/reservation ticks, forged crossing owners and unsafe actor data. Vehicle restore temporarily disables the old generation's colliders, validates **new physical** cars against other actors/props, and restores old colliders on a failed stage. Walkers receive individual collision probes, and the existing transaction guard now freezes both the background simulation director and pedestrians during scene restore.

`scripts/world/junction_scene.gd` orchestrates save and restore, while `scripts/core/main.gd` writes and validates the background state in the same checksum-protected file as civic missions. Older checkpoints without `world_checkpoint` remain supported but do not overwrite the existing background simulation.

## Code and tests
- `scripts/core/simulation_clock.gd` and `simulation_director.gd`
- `scripts/traffic/traffic_signal_controller.gd`, `traffic_spawner.gd`, `intersection_reservations.gd`
- `scripts/npc/district_pedestrians.gd` and `scripts/world/junction_scene.gd`
- `scripts/core/main.gd`
- `tests/world_traffic_checkpoint_test.gd`
- `tests/world_junction_checkpoint_test.gd`
- `tests/world_pedestrian_checkpoint_test.gd`

All three tests are registered in `tools/run_regression.py` with strict Godot `ERROR:` scanning.

## Acceptance on Windows

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
$tests = @(
  "world_traffic_checkpoint_test.gd",
  "world_junction_checkpoint_test.gd",
  "world_pedestrian_checkpoint_test.gd",
  "wrong_way_checkpoint_test.gd",
  "parking_checkpoint_test.gd",
  "multi_incident_checkpoint_test.gd",
  "save_resilience_test.gd"
)
foreach ($test in $tests) {
  & $godot --headless --path . --script "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
}
python tools/run_regression.py --godot $godot --timeout 120 --report build/game-019-world-checkpoints.json
Write-Host "Exit code: $LASTEXITCODE"
```

New expected markers (not yet actually observed): `CIVIC_CHAOS_WORLD_TRAFFIC_CHECKPOINT_PASS`, `CIVIC_CHAOS_WORLD_JUNCTION_CHECKPOINT_PASS`, `CIVIC_CHAOS_WORLD_PEDESTRIAN_CHECKPOINT_PASS`.

## Unverified and out of scope

- [x] Source and test registration committed
- [x] Static GitHub consistency reviewed
- [ ] Godot 4.7.2 import, focused tests, all strict regressions, real-PC playthrough
- [ ] Android controls/performance and busy crossing recovery
- [ ] Stronger full-world atomic rollback for unreconstructable actor positions

The physics snapshot includes mission/world vehicles, background pedestrians, signals and reservations, but not every optional world prop, VFX or transient behavior. When the fresh city's actual collider occupancy makes restoration unsafe, F9 refuses rather than teleporting a car through an actor. Rollback is currently best-effort. The earlier GAME-014/017/018 engine gates remain open; do not claim a validated release.

No GitHub Actions were manually dispatched. The test report uses a separate filename, leaving the user's modified `build/regression-report.json` untouched.
