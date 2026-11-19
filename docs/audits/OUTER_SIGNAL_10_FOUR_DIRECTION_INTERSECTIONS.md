# OUTER-SIGNAL-10 — Four Exclusive Approaches at Outer Junctions

**Date:** 2026-11-16
**Branch:** `fix/aud-001-game024-gate-hardening`
**Status:** Source and regression committed; Windows Godot and Android verification pending.

## Objective and scope

The central intersection already uses one-green-at-a-time N -> E -> S -> W. The other **24** nodes of the 5×5 city graph previously used an independently ticking two-axis NS / EW priority policy and only two visible heads per intersection. This milestone aligns outer junctions with the requested single-approach road rule while preserving their deterministic fixed tick clock.

## Source implementation

- `scripts/traffic/outer_intersection_priority.gd`: `approach_for_lane(lane)` derives incoming direction from start/end vectors, matching the central convention (positive Z = North approach, negative Z = South, positive X = West, negative X = East). The `aspect("N"|"E"|"S"|"W", tick)` 640-tick cycle (20 ticks per second) grants each approach **120 ticks / six seconds** of green, followed by **40 ticks / two seconds** all-red. Order N -> E -> S -> W, then repeat.
- `disposition` now checks **that exact vehicle's incoming direction**, not the shared NS/EW axis. Other approaches are red even when opposite. Existing single-occupant center protection, committed crossing, real pedestrian collision probe, downstream clearance, and deterministic nearest/slot tie-breakers remain unchanged.
- `scripts/traffic/outer_traffic_lights.gd`: adds one distinct physical-looking head for **each direction** at every outer node, total **96** heads vs previous 48. No new collision bodies or per-node clocks; all lights read `Policy.aspect(approach, displayed_tick)`, updated from the actual traffic tick and restored from the saved tick.
- No changes to civic incident reporting, reputation, route graphs, physics collisions, or checkpoint serialization. Old snapshots saved with `current_tick` remain structurally valid; after loading, the new four-turn policy is deterministically recomputed from that tick. Its *meaning* changes from paired phases to four-turn phases, so replay the actual restored junction for correctness instead of assuming an old visual phase remains unchanged.

## Tests

- `tests/outer_signal_10_four_approach_test.gd` checks N,E,S,W incoming lanes, 96 visible heads, exact single green permissions at every green phase, all-red clearances and deterministic tick-based presentation replay.
- Updated `tests/outer_intersection_priority_test.gd` checks full 640-tick cycle and physical occupancy/same-lane prioritization under North/East green.
- Updated `tests/outer_intersection_movement_test.gd` selects the actual N/E approaches and verifies physical pedestrian yield and vehicle separation.
- Updated `tests/outer_intersection_restore_test.gd` checks JSON restored lane/clock and all four visible direction heads across the 640-tick cycle.

## Local Godot verification

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Git fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Git update failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$exitCode = $LASTEXITCODE
$log | Out-Host
if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
  throw "Godot import failed"
}

$tests = @(
  "outer_signal_10_four_approach_test.gd",
  "outer_intersection_priority_test.gd",
  "outer_intersection_movement_test.gd",
  "outer_intersection_restore_test.gd",
  "traffic_fix_09_single_approach_rules_test.gd",
  "traffic_fix_09_visual_marshal_test.gd",
  "traffic_fix_08_central_spillback_test.gd",
  "traffic_fix_07_cross_fleet_junction_test.gd",
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
Write-Host "OUTER-SIGNAL-10 focused tests passed" -ForegroundColor Green
```

## In-game acceptance

- [ ] At the four external approaches to each of several outer junctions, at most one green head is illuminated; all heads red for two seconds between greens.
- [ ] A vehicle on the opposite side is NOT authorized merely because it is on the same axis as green.
- [ ] A committed vehicle already inside a junction finishes its crossing without being frozen by a phase change.
- [ ] A real walker/solid object inside the crossing blocks movement even on green.
- [ ] Save F5/load F9 during an occupied outer crossing; active cars, actual visible heads and new four-direction tick policy agree, without duplicate cars or crashes.
- [ ] Five-minute traffic replay with ~8, 12, 20 cars; actual completed route counter advances and no unresolvable physical queues arise. Four-turn mode decreases green frequency per direction compared to paired mode, so do not assume it improves raw throughput.
- [ ] Android Compatibility/low-end GPU: 96 simple signal heads do not cause an unacceptable FPS or draw-call regression.
- [ ] Export Android Debug APK only after all focused tests pass.

**Not yet run in a local Godot engine.** Existing traffic-gridlock bug, Wrong Way incident completion, and HUD polish remain separate open acceptance issues.
