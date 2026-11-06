# GAME-013 — Authorized Municipal Tow & Safe Vehicle Removal
Status: **Implemented in source; Godot 4.7.2 verification pending.** Branch: `fix/regression-nov05`. Date: 2026-11-06.

## Player-visible change
The GAME-012 wrong-way incident no longer deletes the offending car when the marshal arrives.

After the player has inspected the **real** queued vehicles and filed a valid report at the yellow report post, the visible marshal approaches and records an authorized intervention. Following the service delay:

1. A yellow **CITY TOW SERVICE** vehicle enters the staged traffic scene.
2. The real red offending vehicle is connected behind it with a visible tow link.
3. The convoy moves in small swept increments following the existing road graph's **legal west-approach → east-exit route**.
4. The offender stays facing against its initial driving direction while being **towed backwards**, rather than performing an unsafe instant 180° turn.
5. Both vehicles retain physical collision shapes while moving. The convoy **stops** for pedestrians, players, other vehicles, buildings/props, and live central traffic-signal/crossing restrictions.
6. Only after reaching the actual outbound legal exit do both vehicles leave the simulated world and the incident set `blocker_removed = true`.
7. Actual follower vehicles that moved and passed the original obstruction are counted from observed speed/route positions, including while the tow convoy is on the move.
8. Mission completion still requires the tow to finish, at least two **real** vehicles to resume past the old blockage, and a sustained zero stopped-vehicle queue. Rewards and civic scores are applied once via existing idempotent managers.

No fabricated queue sizes; no instant teleport/delete at marshal arrival; no player-controlled towing or unsafe vehicle removal.

## Relevant source and tests
- `scripts/civic/wrong_way_live_mission.gd`: `_start_tow_convoy`, `_tow_pose`, `_tow_route_length`, `_advance_tow_convoy`, `_update_tow_link`, `_finish_tow_convoy`.
- `tests/authorized_tow_route_test.gd`: rejects unapproved start, validates graph-legal route, opposite vehicle facing and continuous junction positions.
- `tests/authorized_tow_obstacle_test.gd`: real world collider ahead stops the convoy; removing it allows safe forward progress; no premature scene clearance.
- `tests/wrong_way_live_mission_test.gd`: extended to require a visible tow convoy, non-teleporting movement, legal route and proper removal before mission completion.
- `tools/run_regression.py`: registers both new focused tests; strict ERROR scanning remains active.

## Engineering behavior
- **TOW_GAP_M = 6.5**, **TOW_SPEED_MPS = 7.0** and **TOW_SWEEP_STEP_M = 0.3** are fixed simulation parameters for first playtesting, not real towing operating specifications.
- The physical convoy uses existing `CivicVehicleAgent` scene geometry and `footprint_blocked_at` for both collision-bearing vehicles.
- The convoy moves only from inside `_physics_process` with full swept candidate collision checks, not from UI interactions.
- Route is validated via `outgoing_legal_lanes`, and the live controller checks `apply_stop_line_observation` before allowing it across the central signal.
- If the tow staging location is occupied, service retries without deleting the original offender.
- **Current limitation:** towing consists of the existing stylized car geometry colored as municipal service equipment, plus a beacon and tow link. A high-quality flatbed/winch, physical coupling animation, realistic attach alignment and custom meshes remain art/polish tasks.
- **Current limitation:** the route uses the eastbound corridor. Because all normal traffic and NPC path systems share a procedural city, integrated motion and clearance on the complete playable neighborhood must be visually verified. No fallback teleport is permitted if the service cannot find a clear lane.

## Test gate (Windows PowerShell)
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Import failed" }
& $godot --headless --path . --script res://tests/authorized_tow_route_test.gd
if ($LASTEXITCODE -ne 0) { throw "Tow route test failed" }
& $godot --headless --path . --script res://tests/authorized_tow_obstacle_test.gd
if ($LASTEXITCODE -ne 0) { throw "Tow obstacle test failed" }
& $godot --headless --path . --script res://tests/wrong_way_live_mission_test.gd
if ($LASTEXITCODE -ne 0) { throw "Live wrong-way mission test failed" }
python tools/run_regression.py --godot $godot --timeout 60 --report build/game-013-authorized-tow-report.json
Write-Host "Exit code: $LASTEXITCODE"
```

Expected success markers:
- `CIVIC_CHAOS_AUTHORIZED_TOW_ROUTE_PASS`
- `CIVIC_CHAOS_AUTHORIZED_TOW_OBSTACLE_PASS`
- `CIVIC_CHAOS_WRONG_WAY_LIVE_MISSION_PASS`

### Manual PC/Android scene gate
Complete the orange footpath incident, open the west-road wrong-way report post, inspect the **actual stopped queue**, then report. Watch the marshal enter the scene, a yellow tow truck and red offender move together with a tow link, and the real queue release. Pause midway, look for physical clipping, confirm red-light restrictions, and ensure the mission doesn't complete before safe exit. Mobile and high-density traffic need separate real-device review.

## Test state
- [x] Code changed in branch
- [x] Route, obstacle and integration regressions authored and runner-registered
- [ ] Godot 4.7.2 import and all focused tests pass on the new commit
- [ ] Full strict regression passes on new commit
- [ ] Manual PC playthrough with no teleports, intersections, or stuck convoy
- [ ] Android touch/performance check

Last user-provided full suite (prior to these changes) identified three strict regression failures in the lifecycle, incident JSON and spawn-occupancy tests. Fixes for those were committed previously, but the user has **not yet provided a subsequent full Godot run**. Therefore neither GAME-013 nor prior strict-regression fixes should be called accepted yet.

## Follow-on tasks
- GAME-014: mission checkpoint state/versioned restore for the wrong-way scenario and tow states, plus idempotent reward audit.
- GAME-015: mission directions, retry/failure UI, audible feedback, and service animations.
- GAME-024: more realistic tow truck, winch, coupling, signals and NPC service reactions.

No GitHub Actions manually dispatched. Push-triggered workflows may still execute automatically.
