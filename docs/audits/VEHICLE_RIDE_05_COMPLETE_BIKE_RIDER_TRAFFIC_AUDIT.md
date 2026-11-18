# VEHICLE-RIDE-05 — Complete Bike / Rider / Traffic Audit and Fix Plan

**Date:** 2026-11-18
**Branch:** `fix/aud-001-game024-gate-hardening`
**Scope:** Audit and implementation plan only. No production ride/collision/animation code changes in this milestone. No GitHub Actions manually triggered.
**Evidence:** User gameplay screenshot from 2026-11-18 showing orange motorcycle visually overlapping a green NPC car, rider sitting high with arms/hands disconnected from handlebar, boxy oversimplified steering/controls, background game city. Direct source review: `scripts/player/player_controller.gd`, `scripts/world/rideable_bike.gd`, `scenes/player/player_root.tscn`, `scripts/rendering/low_poly_character.gd`, `scripts/traffic/vehicle_agent.gd`, `scripts/core/main.gd`, existing VEHICLE-RIDE-01..04 tests.

## Verified source mechanisms (not all runtime root causes proven)

**Critical #1 — player-car-bicycle overlap and mount teleport.**
- `CivicRideableBike.mount_to(player)` reparents bike to the player and sets `position = Vector3.ZERO` without a two-wheeled body-space clearance check at the destination. The player's actual on-foot capsule is only 0.7m wide and its collision mask is layer 1 (world).
- `CivicRideableBike` sets `collision_layer=0` when mounted and uses `layer=16` only as a parked interactable. Thus bike artwork cannot participate as a real physical obstacle. A query-only `BoxShape3D(1.0, 1.1, 1.8)` in `_limit_bike_motion` checks layer 1|4|8 in advance, but no mounted-bike persistent footprint exists; this short, narrow proxy does not cover all forward/rear and side-facing vehicle artwork.
- Player's `_limit_horizontal_actor_motion` is designed around the walking capsule and layer 4 cars, and `_recover_vehicle_descent_overlap` may relocate the CharacterBody when it overlaps a car while descending. The extra bike probe and walking probe do not together guarantee that all bike + rider visual geometry remains clear.
- `CivicVehicleAgent.people_clear_at` and `footprint_blocked_at` sense layer 2 player and other cars, but model-space geometry is not checked against the mounted bike's visible whole-vehicle footprint. That allows *apparent* interpenetration even when the little player capsule and simulated cars behave as designed.
- The screenshot directly establishes visible interpenetration. Whether that overlap began at mount, corner turn, car approach, lane spawn or physics recovery remains to be established using diagnostic traces and in-world replay, not asserted as fact.

**Critical #2 — hand and foot contacts are not rigged.**
- `CivicLowPolyCharacter.build` creates each arm as one `Node3D` with sleeve, forearm and hand sharing one pivot. There are no independently articulated elbows, wrists or hands. Legs similarly have a single leg pivot.
- `CivicPlayerController._set_bike_pose` merely sets `limb.rotation.x` to two constants multiplied by `_bike_pose_blend`; `_advance_bike` does not solve the hand position against the changing world-space handlebar/fork grip points. Hands necessarily detach when steering, banking or changing seated geometry.
- Bike handlebar is one `BoxMesh` at `Vector3(0,1.53,-0.91)`, with no left/right `GripL/GripR` targets, individual steering grips, clutch/front brake lever or rider-to-footpeg rig.

**Critical #3 — driver/seat transform mismatch and apparent pose lag.**
- Bike saddle is at bike local `Vector3(0,1.18,0.4)`. Player visual is moved separately from y=0.9 to y=1.33; the animated character builder was created around Visual's local origin (`y_origin=-0.9`) and bike position becomes player origin on mount, regardless of original bike location. Hips/feet and seat never share a common authoritative seat anchor.
- Bike `VisualRig` has independent steering/lean/suspension bob; the rider `Visual` gets a different percentage of bike lean. Its head/arms/legs are not constrained to moving grips, foot pegs or saddle. This yields visible separation / float / jerk risk, especially during mounting and turning.
- The screenshot shows offset seating and arms; exact frame-time jitter is not proven by a single still. Use video/frame traces to distinguish sprite rig mismatch from a timing issue.
- Main camera springs back 4.0 -> 5.7m by changing SpringArm immediately while pose blends for 0.35s; physics process and render interpolation are not measured, and reparenting is abrupt.

**High — dismount, controls, visuals, save/replay.**
- Dismount requires speed under 0.25m/s and checks only player capsule vs layer 4|8, not *both candidate feet* / target side / bike + surrounding geometry, and reparenting parked bike to world can place the interactable mesh into another vehicle.
- Bike uses a front-axle wheel yaw and cosmetic sine-wave bob, not front/rear contact suspension. Ground clearance, sudden steps/kerbs and road-banking need authoritative probes before visual pitch/roll.
- Visual mesh is mostly BoxMeshes, engine/fork have no meaningful motorcycle silhouette; mirrors are tall; no cohesive frame triangle, wheel alignment, seat ergonomics, swept bars, connected brake/engine assembly, side profile readability or optimized mesh batching.
- Mounted bike cannot be checkpoint-saved; Main explicitly blocks F5/F9 until dismounted (safe current limitation).
- Existing tests predominantly validate transforms/steering/math and a single isolated static car; no head-on/side-swipe angled intersection scenario with moving city traffic, no rider hand-to-grip anchoring, seat height, footpeg continuity, collision prediction at speed or Android actual gameplay visuals. Do not treat passing VEHICLE-RIDE-04 tests as this acceptance.

## Recommended implementation sequence (separate testable PR-sized milestones, all on same branch)

### VEHICLE-RIDE-05A — P0 Collision & Mount Integrity (first)

**Goal:** No bike/car/player visible penetration during mount, forward motion, turning or reverse.

1. Introduce authoritative `BikeFootprint`/bike geometry bounds (wheelbase, width, passenger + front wheel clearance) tied to actual vehicle local position; use shared shape extents for mount validation, sweep and physical overlap diagnostics.
2. Replace snap-to-player mount with checked **player-to-seat placement**, keeping parked bike at original world transform; validate seat, rider capsule and full bike sweep against world, car and pedestrians on physics frame before commit.
3. For every riding physics tick, swept collision must examine full front/rear/side in current AND next heading, and report blocker type and attempted vs accepted travel. Prevent rotation penetrating adjacent stopped cars. Do not simply turn all collision layers on and reintroduce city gridlock.
4. Unify/coordinate bicycle collision response with old player-only car-penetration recovery so recovery cannot move the bike + rider through traffic. The car AI must account for the mounted bike's actual footprint rather than only the layer-2 pedestrian capsule.
5. Establish a safe, legitimate lateral dismount location with foot capsule and parked bike overlap checks; if no clear side, keep rider mounted and display reason.

**Acceptance:** zero overlap across front/rear/side/reverse/high-speed turning/parked car/moving NPC/oblique approach; blocked motion stops before the visible wheel/front fork penetrates; no arbitrary despawn or teleport; 5-minute urban NPC throughput unaffected.
**Tests:** `vehicle_ride_05a_mount_clearance_test.gd`, `vehicle_ride_05a_swept_collision_test.gd`, `vehicle_ride_05a_turning_car_clearance_test.gd`, `vehicle_ride_05a_dismount_side_test.gd`, full traffic/contact regressions.

### VEHICLE-RIDE-05B — P0 Rider Rig, Seat & Handlebar Contacts

**Goal:** Both hands hold the *moving* grips; legs attach to real footpegs; hips meet the saddle at all times.

1. Add bike-owned `SeatAnchor`, `GripLeft/Right` under turning front assembly, `FootpegLeft/Right` and optional knee/tank reference anchors. Define desired values once in bike geometry coordinates, not separate constants guessed in player script.
2. Upgrade low-poly character's arms to shoulder-upper-arm / elbow / forearm / wrist / hand hierarchy (or a deterministic two-bone arm IK); same for thigh/knee/shin/ankle. Preserve legacy walking node names via adapter/walker mode.
3. Mount uses seat anchor plus checked rider root transform. Each animation frame solves wrist targets from `GripLeft/Right.global_transform` and ankles from peg anchors, with joint limits and no spatial lag; rider rotates with bike lean/steering consistently.
4. Define tests for both wrists and soles within an initial target tolerance **<=0.12m**, measured across idle, full right/left steer, bank, brake, speed transitions; no impossible hyperextension. Derive tolerances from scaled mesh dimensions after review.

**Acceptance:** head, torso, hips, thighs and feet visibly seated; no hovering or disjoint arms at any steering angle; walking pose unchanged on dismount.

### VEHICLE-RIDE-05C — P1 Complete Bike Geometry Redesign

**Goal:** Recognizably plausible modern commuter/street motorcycle without borrowing a branded/copyrighted design.

- Rebuild hierarchy with modular frame spine/triangle, actual steering head, front fork two stanchions connected to axle, two grip assemblies with brake/clutch levers, fuel tank, saddle, engine casing/fins, exhaust, front/rear swingarms, chain/sprocket, realistic suspension legs, brake rotors/calipers, tires/tread/rim, lights/indicators, fairings and coherent color palette.
- Establish a parametric dimensions table so wheelbase, handlebar/grip width, seat height and collision footprint match exactly. Remove/replace duplicative primitive shapes rather than stacking decorative boxes.
- Optimize mesh/material counts (prefer shared materials and instanced details) for Android Compatibility. Visual-only detailing remains nonblocking.

**Acceptance:** readable silhouette in front/side/rear, no floating parts, handles within arm reach, front wheel/fork alignment and leg clearance, tested on low-end Android.

### VEHICLE-RIDE-05D — P1 Real Riding Animation & Camera

- Finite states: `PARKED -> MOUNT_REQUEST -> MOUNTING -> RIDING -> STOPPING -> DISMOUNT_REQUEST -> DISMOUNTING -> PARKED`, with collision/controls gating and cancellation.
- Animate controlled transfer (footstep onto peg, hip onto saddle, hands reach grip) in a valid placement corridor. Do not teleport bike through static cars.
- Smooth camera framing/zoom and speed-weighted look-ahead; synchronize character and bike transform updates, disable physics interpolation during reparent where required, profile frame hitch. Detect time-lag using motion frame captures rather than relying on still screenshots.
- Realistic-looking, tunable handlebar response and suspension fork compression from ground contacts, modest lean/pitch, shock absorption and tire rotation based on signed accepted travel (not an ungrounded sine-only bob). Remain arcade-kinematic unless a dedicated true two-wheel physics milestone is justified.

### VEHICLE-RIDE-05E — P1 Mobile, Checkpoint and Live-City Release Gate

- Validate W/A/S/D and analog joystick, BRAKE/BOOST/EXIT, touch release/focus, pause/resume while riding, low-speed steering, reverse, traffic-signal intersections, roadworks, missions and five-minute NPC traffic.
- Version and atomically serialize bike identity/position/heading/occupancy **after** mounted gameplay is stable. F5/F9 should not silently create duplicate vehicles or place rider in blocked cells.
- Android debug/release export after clean parser + P0 tests + existing full regressions; visual captures on PC and Android at close-up, side angle, rear chase and near-car clearance.
- Performance target: maintain previous project baseline at 8–12 moving city cars; quantify frame time/physics cost rather than assuming new IK/sweeps are free.

## Required evidence, release gate and ownership

- Keep changes on `fix/aud-001-game024-gate-hardening`, commits with `[skip ci]`, do not manually run GitHub Actions.
- Before each implementation milestone: run headless Godot 4.7.2 import, new focused regression and pre-existing `vehicle_ride_01..04`, `player_vehicle_contact`, `vehicle_world_obstacle`, `traffic_spawner`, `world_junction_checkpoint` tests.
- Fail on Godot nonzero exit OR any `SCRIPT ERROR:|ERROR:`, not a printed PASS alone.
- Highest priority manual scenario: recreate the user's green-car side contact screenshot at zero, low and boosted speed, then compare top-down footprint debug and the visible wheel/body mesh to find the exact first penetration.
- **No source gameplay changes and no new passing tests are claimed in this audit.** Actual source-level hypotheses are grounded above; exact runtime timing must be confirmed by local recordings/diagnostics.

## Definition of done

Never call bike redesign release-ready until mounting is checked, cars do not overlap bike/rider, both hands stay on bar grips, both feet stay planted on footpegs, saddle contact is aligned, mount/exit transitions are natural, city traffic remains physical, and live PC + Android runs meet the same acceptance. Cosmetic work cannot close a P0 collision bug.
