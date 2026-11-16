# TRAFFIC-FIX-13 — Wrong-Way Mission Completion Must Not Freeze Traffic

**Date:** 2026-11-16
**Branch:** `fix/aud-001-game024-gate-hardening`
**Status:** Root cause isolated, source + regressions committed; Godot and Android acceptance pending.

## User screenshot and root cause

The user screenshot shows `Wrong-way mission complete! 2 cars resumed; civic reward +100` while a visible line of red mission vehicles still occupies the road, some with `Moving` labels. This is not primarily a signal-timing problem.

Source audit identified **a deterministic mission lifecycle bug**:

`CivicWrongWayLiveMission._physics_process` returned as soon as `finished == true`. That instantly stopped `_advance_cars` for all remaining live `QueuedVehicle_*` actors. These actors kept their `CollisionBody` layer 4, so they became **permanent, real static obstacles** while their last agent feedback label kept saying Moving. Ordinary traffic and new NPCs then stopped behind them, regardless of signal changes. The mission could legitimately reward the first two released followers while the other two still had not reached their route endpoint; completion alone must not freeze them.

A second presentation issue amplified the problem: `CivicAgentFeedback.observe_vehicle` displayed `Moving` based on last requested/calculated speed, not directly on actual accepted displacement.

## Source fix

- `scripts/civic/wrong_way_live_mission.gd`: if the civic mission is finished, continue calling **only** `_advance_cars(delta)` every physics step, while stopping any further incident/mission/tow transitions. Remaining follower actors retain normal red/green stopline gates, lead sensors, world collision and pedestrian checks until `CivicVehicleAgent.advance_fixed` actually reaches the end of the legal route. `_sync_follower_presence` then hides the finished car and clears its collision layer. No new civic score/reputation is applied after completion.
- `scripts/npc/agent_feedback.gd`: `observe_displacement(distance_m, delta, active, alert)` converts *accepted travel* to displayed movement status. Real zero travel renders Stopped, actual travel renders Moving, inactive completed cars have no floating label.
- `scripts/traffic/vehicle_agent.gd`: pass the **accepted** travel from each legal physics step into the movement feedback; retain the old `observe_vehicle` optional fallback for compatibility. It does not alter the physics speed, steering, routes, lights, collisions or save fields.

## Regression files

- `tests/traffic_fix_13_post_completion_traffic_test.gd`: stage real graph and civic mission, simulate a completed offence with its offender removed, prove two or more remaining physical followers **continue advancing**, then confirm completed-route cars are hidden and no longer have collision layer 4.
- `tests/traffic_fix_13_actual_movement_label_test.gd`: state cues use actual 0m/positive movement, then a real car accelerates and brakes to zero, demonstrating that the label changes to Stopped instead of remaining Moving.
- Rerun `traffic_fix_12_marshal_removal_test.gd`, `traffic_fix_12_head_of_line_test.gd`, `traffic_fix_11d_wrong_way_follower_release_test.gd`, `aud3_wrong_way_signal_recovery_test.gd`, `vehicle_world_obstacle_test.gd`, `traffic_spawner_test.gd`, `world_junction_checkpoint_test.gd`.

## Windows local verification

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Update failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$code = $LASTEXITCODE
$log | Out-Host
if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) { throw "Import failed" }

$tests = @(
  "traffic_fix_13_post_completion_traffic_test.gd",
  "traffic_fix_13_actual_movement_label_test.gd",
  "traffic_fix_12_marshal_removal_test.gd",
  "traffic_fix_12_head_of_line_test.gd",
  "traffic_fix_11d_wrong_way_follower_release_test.gd",
  "aud3_wrong_way_signal_recovery_test.gd",
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
      -not ($log | Select-String '_PASS')) { throw "FAILED: $test" }
}
Write-Host "TRAFFIC-FIX-13 local gate passed!" -ForegroundColor Green
```

## Gameplay acceptance

- [ ] Fresh Wrong Way mission: inspect and report offender, wait for marshal, use the roadside Clear Wrong-Way Vehicle action. Removal follows its existing 2s safe-worksite path.
- [ ] At least two genuine followers move past the former obstruction; the mission reports completion once, +100 only once.
- [ ] **After the mission-complete message, watch the remaining queued cars:** they must continue obeying traffic lights and physically moving toward the end of their legal route. No permanent stationary mission cars left with active collision bodies.
- [ ] Visual statuses match the movement: stopped at red -> Stopped, accepted travel -> Moving, completed car -> no label/visible vehicle.
- [ ] Ordinary background traffic resumes after the mission cars retire. `CIVIC_HEAD_OF_LINE` identifies any other physical blocker, with real geometry checks still in effect.
- [ ] F5/F9 across the completed-mission state restores the real remaining cars and does not re-award reputation.
- [ ] Five-minute PC/Android replay confirms that background route `Completed` continues increasing and active ordinary car queue does not permanently accumulate at the same position.

**No Godot runtime tests or Android APK executed in this environment.** The source fix is complete but the gameplay result remains OPEN until user-local tests and replay pass.
