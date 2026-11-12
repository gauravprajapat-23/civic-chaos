# AUD2-MAP-02 — Deterministic Outer Intersection Right-of-Way

**State:** Committed source + headless regression definition, NOT engine-verified. This is the second phase of [#53](https://github.com/gauravprajapat-23/civic-chaos/issues/53), after visual pavement alignment. Do not mark city safety complete without physical Godot/Android playthrough evidence.

## Skills and architecture

Applied the supplied `godot-physics`, `physics-tuning` and `godot-gdscript-headless-testing` guidance:

- Fix traffic decisions on the existing **20 Hz physics-driven** simulation clock; no time-of-day or render-frame timers.
- Separate the pure right-of-way decision from movement: `CivicOuterIntersectionPriority.disposition()` computes intent, `CivicTrafficSpawner.apply_stop_line_observation()` feeds it to existing braking/following and the vehicle's swept collision check.
- Query pedestrian physical bodies on collision layer **8** using `PhysicsShapeQueryParameters3D` in the fixed-tick callback. A sphere of radius 2.75 m near a noncentral intersection is checked only for approaching cars within 12 m of their stop line. It excludes pedestrians waiting on more distant sidewalks.
- Keep the **central** signal controller and pedestrian crossing reservations unchanged.

## Signal and occupancy rules

For all 24 noncentral grid nodes on X/Z `[-120,-46,0,46,120]` (except the center), the right-of-way rule is a deterministic repeating 320-tick cycle:

| Fixed ticks modulo 320 | Aspect |
| --- | --- |
| 0–119 | North/south permitted |
| 120–159 | All-red clearance |
| 160–279 | East/west permitted |
| 280–319 | All-red clearance |

A car may only initiate entrance if its axis is green, the zone is unoccupied, and it wins a **single-car** approach arbitration. A nearer upstream stopline has priority; ties use stable lane ID and then the vehicle slot order already represented by the traffic snapshot. Mission-stopped cars outside the zone don't retain perpetual priority. Cars already past the final 5 m approach stopline or less than 7 m into an outgoing lane continue clearing even if lights change, and block other arrivals while clearing. On a red or occupied zone, the existing longitudinal following limiter stops upstream rather than teleporting the car.

There is **no new mutable reservation table or saved schema**: after F9, the tick and saved lane, slot, route index and traveled distance reproduce the same arbitration decisions. The policy does not replace swept-car footprint collision checks or solve previously corrupt/overlapping legacy save data.

## Source and test changes

- `scripts/traffic/outer_intersection_priority.gd`: new pure fixed-tick signal, grid-node matching, committed-zone detection and stable single-car priority.
- `scripts/traffic/traffic_spawner.gd`: connects noncentral city arrivals to the new policy; small collision-layer-8 pedestrian overlap probe; preserves the central signal and stop-line logic.
- `tests/outer_intersection_priority_test.gd`: verifies no simultaneous perpendicular greens across a complete cycle; both all-red intervals; deterministic opposite-lane/same-lane tie arbitration; closer-car priority; stopped-car fairness; occupied inbound/outbound conflict zones; signal switch while in the zone; tick replay; actual pedestrian collider blocking and clearing.
- `tests/city_signal_stop_line_test.gd`: checks the center continues following `CivicTrafficSignalController` while outer nodes now follow independent fixed ticks.
- Required local release gate: **104 mandatory Godot fixtures, 24 focused tests, 30 Python QA tests, 4 deterministic state replays**, plus clean matching source SHA, import and intentional negative path.

## What is not yet proved

Godot 4.7.2 is unavailable in the authoring environment; **this change has not passed an engine compile or actual fixed-tick movement test**. Before closure of #53:

1. Import the exact branch in Godot 4.7.2; run both new and existing city-signal tests, then the complete local verifier.
2. Drive two real physical cars toward the same *outer* node from perpendicular directions while a pedestrian is crossing; verify no body penetrations or deadlocks, and that right-of-way alternates.
3. Repeat after F5/F9 during green, all-red and an in-progress conflict zone. Validate that no cross-intersection gap or ghost occupant remains.
4. Review signal discoverability: the policy's outer phases do **not yet have visible traffic-light meshes**. Add accurate visual cues after confirming gameplay and signal timing.
5. Measure the added pedestrian shape-query cost on crowded Android and desktop scenes. Only optimize the measured hotspot.
6. Capture Android screenshots and logs, full mission/Free Roam and complete acceptance report. Keep PR #49 draft and do not trigger GitHub Actions.

## AUD2-MAP-02 follow-up — simultaneous observation safety

Commit `6eeccea` changes `CivicTrafficSpawner.advance_fixed()` to gather **both** nearest-lead and outer-junction stop-line decisions for the full fleet before advancing any car. Previously, only nearest-lead detections were snapshotted, so an earlier fleet slot could change its position before a later slot evaluated right-of-way during the same tick. This removes that same-tick evaluation-order inconsistency without changing the phase schedule, mission scoring, save fields, or central signal ownership.

**Verification remains pending:** review and commit are not equivalent to running Godot. The existing `outer_intersection_priority_test.gd` checks deterministic arbitration, occupied lanes, pedestrian colliders and replay; run the exact-SHA Godot gate, plus a physical multi-car scenario to measure any overshoot while braking at the stop line. Keep #53 open and PR #49 draft until runtime evidence is attached.

## AUD2-MAP-03 — real vehicle movement fixture (source staged, engine pending)

Added `tests/outer_intersection_movement_test.gd` as an automatically discovered regression fixture. It instantiates the shipped `vehicle_agent.tscn` scene twice with active physics footprints, positions perpendicular approaches nine metres before the outer junction at (46, 46), places a layer-8 pedestrian collider inside the crossing, and advances the **actual spawner** for 260 logical 20-Hz ticks with an awaited physics frame before each step. It checks blocked pedestrian entry, red-axis compliance, two-car separation, eventual progress, and outbound clearance after the walker leaves. Normal route completion is permitted; completed cars are retired by the spawner.

The fixture is deliberately deterministic and does not alter save format, scoring, traffic timing, or visual assets. It must run with Godot 4.7.2 before any assertion of real-world collision safety. Full inventory rises from **104 to 105** mandatory/discovered Godot fixtures when present; 24 focused checks and 30 Python checks are unchanged. The strict test runner discovers new `*_test.gd` fixtures automatically; the local gate's `-MinimumTestCount` remains a lower bound, not a count to reduce or overwrite.

Run directly:
```powershell
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --import --quit
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/outer_intersection_movement_test.gd
```
Then run the full exact-commit local verification gate. Any Godot error or failing fixture blocks acceptance; do not close #53 or merge PR #49 based on source inspection.

## AUD2-MAP-04 — checkpoint occupancy and visual signals (source committed; engine pending)

**Startup repair:** Godot 4.7.2 reports that `CivicIllegalParkingMission.owner` redeclares the native `Node3D.owner` member. Renamed the actor field to `parking_owner` and updated two referencing regression fixtures. This field was an in-memory node reference, not a serialized checkpoint key, so no save schema migration is required.

**Checkpoint safety:** `tests/outer_intersection_restore_test.gd` captures an occupied outer crossing with two actual collidable car scenes and a waiting perpendicular car, JSON-round-trips the current fleet slot order and tick, reconstructs into an empty scene, checks the exact post-restore priority decision, exercises continued outbound conflict-zone ownership and release, and verifies fixed-phase color replay. In particular, it confirms no mutable reservation state is required beyond vehicle lane progress and current tick.

**Visible indicators:** `scripts/traffic/outer_traffic_lights.gd` constructs 48 non-colliding NS/EW signal heads at the 24 noncentral city nodes. Each visual red/green lamp is selected from `CivicOuterIntersectionPriority.aspect(axis, tick)`; the existing `junction_scene.gd` synchronizes these heads on every simulation tick and immediately after restoring the world clock. The central junction's original signal system remains separate, and indicators do not affect car collision masks or traffic authority. Lighting is intentionally emissive-looking unshaded colored mesh rather than additional real lights, to avoid unmeasured GPU load.

**Local verification:** This adds one automatically discovered Godot fixture after AUD2-MAP-03 (expected total at least 106). Neither authoring-time code changes nor a clean GitHub commit prove runtime acceptance. Run Godot import and `illegal_parking_live_test.gd`, `parking_checkpoint_test.gd`, `outer_intersection_restore_test.gd`, `outer_intersection_movement_test.gd`, `world_junction_checkpoint_test.gd`, then the full strict verification gate on the identical SHA. Keep issue #53 open and PR #49 draft until the actual engine and Android evidence passes. No Actions runs.

## AUD2-MAP-04 Godot failure follow-up — parking actor native-owner collision

Local Godot 4.7.2 evidence: project editor import succeeded but `illegal_parking_live_test.gd` failed at `illegal_parking_mission.gd:109` with a null `owner.name`. The earlier declaration rename had missed two member accesses: actor naming and checkpoint position restoration. Both now explicitly reference `parking_owner`. The actor creation path also checks for a null instance and the live fixture verifies its name and that native `Node3D.owner` remains untouched. The failure occurred before later tests in the provided sequential command, so **no remaining fixture pass is claimed**. Re-run the import and focused suite against the new head SHA; preserve error logs if any new regression occurs.

## Local Godot verification follow-up — parking recovery timeout

Godot 4.7.2 editor import passed and the first focused fixture reached its final relocation/recovery assertion, but `illegal_parking_live_test.gd` failed after 1,300 physics frames. This is **not** an intersection acceptance pass. The failure message previously collapsed several independent stages (owner arrival, incident intervention, physical car movement, collision blocking and witness recovery), so no specific blocker was established by the supplied log.

To avoid an unsafe guess that could let a car pass through a pedestrian, the mission now records the name and collision layer of the last obstacle rejected by the relocation sweep as transient diagnostics (excluded from saves), and the fixture reports owner/intervention state, car progress/position, last blocker, witness X, clearance frames and incident state if it times out. This does **not** claim that the underlying timeout is fixed. Re-run the one failing fixture after the new commit, use the resulting detailed error to isolate the blocked stage, then correct that stage without weakening physical collision checks. Keep PR #49 draft and do not run Actions.
