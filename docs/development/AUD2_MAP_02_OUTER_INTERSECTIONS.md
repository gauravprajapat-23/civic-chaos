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
