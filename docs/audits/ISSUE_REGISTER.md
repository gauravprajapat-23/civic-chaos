> **Current branch update — 2026-11-10:** For current findings and exact revision evidence, use [AUD-002 Complete Game Source Audit](AUD_002_COMPLETE_GAME_SOURCE_AUDIT.md), not the historical November 6 statuses below. New tracked work: [#53 perimeter road + outer intersection safety](https://github.com/gauravprajapat-23/civic-chaos/issues/53) (P1), [#54 18 bare-assert headless fixtures](https://github.com/gauravprajapat-23/civic-chaos/issues/54) (P2), existing [#51 responsive UI](https://github.com/gauravprajapat-23/civic-chaos/issues/51), [#50 opt-in NPC AI](https://github.com/gauravprajapat-23/civic-chaos/issues/50), and [#52 performance baseline](https://github.com/gauravprajapat-23/civic-chaos/issues/52). Current release gate: **102 mandatory Godot, 22 focused, 30 Python QA, 4 matching state replays**; no current engine pass evidence. BUG-001 street-prop roots, BUG-007 missing far LOD fallback, BUG-008 secondary-road material and BUG-005 duplicate ground are source-addressed in the current branch, but still need runtime evidence for closure.

# Civic Chaos — Prioritized Issue Register
Date: 2026-11-06 · Branch: `fix/regression-nov05`

**Evidence status:** "Confirmed" means source-level mismatch observed; it does not mean reproduced in Godot. "Risk" requires a runtime test. All Godot runtime verification is **NOT RUN**.

| ID | Priority | Status | System | Evidence (file:lines) | Root cause / impact | Acceptance |
|---|---|---|---|---|---|---|
| BUG-001 | P0 | Fix committed; runtime verification pending | Street props | `scripts/world/street_furniture.gd:58–64,94–133` | All street prop roots converted to StaticBody3D; regression expanded; local Godot run still required | Godot imports; every prop has a valid physics collider |
| BUG-002 | P1 | Partial fix committed; runtime verification pending | NPC/player | `scripts/npc/district_pedestrians.gd:77–125,146–162` | direct movement and incomplete avoidance, NPCs can overlap/stack | live player/NPC contact tests pass |
| BUG-003 | P1 | Partial fix committed; runtime verification pending | Vehicle physics | `scripts/traffic/vehicle_agent.gd:125–135`, `scenes/traffic/vehicle_agent.tscn:65–76` | teleport-style lane positioning, no swept physical obstacle response | vehicle/player/NPC contact tests pass |
| BUG-004 | P2 | Initial graph integration committed; runtime verification pending | Map/traffic | `scripts/world/junction_builder.gd:8–33`, `scripts/world/neighborhood.gd:75–99` | visual streets not represented in traffic graph | every driveable road connected and routed |
| BUG-005 | P2 | Confirmed overlap; severity runtime-dependent | Ground | `scenes/core/main.tscn:7–12,42–51`, `scripts/world/neighborhood.gd:20–23` | redundant overlapping ground colliders | one coherent ground, no falling/z-fighting |
| BUG-006 | P2 | Confirmed validation gap | Save/load | `scripts/core/game_lifecycle.gd:37–47` | loaded player position not collision-/bounds-validated | invalid save safely recovers |
| BUG-007 | P2 | Confirmed source behavior | LOD | `scripts/rendering/graphics_lod.gd:42–55`, `scripts/core/main.gd:68–71` | distant building mesh hidden with no substitute | far skyline remains readable |
| BUG-008 | P3 | Confirmed | Road visuals | `scripts/world/neighborhood.gd:145–146` | secondary road name fails ends_with("Road") | secondary road material matches main roads |
| BUG-009 | P3 | Confirmed | UI | `scenes/core/main.tscn:92–94` | obsolete district preview title | correct game title |
| BUG-010 | P2 | Confirmed | Code hygiene | `scripts/world/street_furniture.gd:2,58–64` | visual-only comment contradicts collider code | accurate docs and enforced scene tests |
| PERF-RISK-001 | P2 | Risk; not measured | Rendering | `scripts/world/neighborhood.gd:125–161` | many unique Mesh/Material nodes | device frame-time budgets measured |
| PERF-RISK-002 | P2 | Risk; not measured | AI | `scripts/npc/district_pedestrians.gd:146–162` | O(N²) crowd checks | scalable crowd benchmark |

## Priority rules
P0 = startup/runtime blocker; P1 = serious collision/gameplay failure; P2 = high-impact integration/optimization; P3 = polish; P4 = optional. Reassess P0 if Godot compilation proves the mismatch is not triggered.

## Reproduction protocol
For every issue: record branch/commit, Godot version, platform, exact steps, actual vs expected behavior, engine log, regression test, and commit fixing it. Do not close based on code review alone.

## Testing
Latest local regression results were reported by the user **before** these audit changes and recent code commits. Current-branch full regression: **NOT RUN**. Godot executable not available in audit environment; no GitHub Actions executed.

## BUG-001 implementation update (2026-11-06)
- Fix: `8a99b58` changes streetlights, trees, bins, benches to StaticBody3D and uses layer 1/mask 0.
- Regression: `80d4200` adds collider/layer/shape/count assertions; `811f95a` accounts for Godot's automatic duplicate-node renaming.
- **Not closed:** Headless Godot import and regression execution are still pending on a machine with Godot 4.7.2.

## BUG-002 implementation update (2026-11-06)
- Initialized NPC bodies at their intended sidewalk coordinates on spawn.
- Added player, other pedestrian, and vehicle clearance checks plus a physics shape check at each proposed destination; adjusted capsule floor clearance.
- Added `tests/pedestrian_collision_test.gd` to the local regression runner.
- **Open:** This is a stop-on-obstacle policy, not full navigation or swept-body motion. No engine run was available; head-on contact, crowd deadlocks, vehicle interactions and standing atop NPCs still need in-game verification. Do not close BUG-002 until all acceptance criteria pass.

## Regression follow-up (2026-11-06)
User's Godot 4.7.2 run: 35 PASS, 2 FAIL (`neighborhood_test.gd`, `world_collision_test.gd`), including `pedestrian_collision_test.gd` PASS. Boundary collider was not named as the test expected; repeated street furniture roots were auto-renamed and the test read `prop.name` after freeing the parent. Fixes committed to name boundary collision nodes, give furniture unique stable names, and avoid accessing freed props in test error reporting. **Rerun pending**; do not mark BUG-001 or BUG-002 closed yet.

## BUG-003 implementation update (2026-11-06)
- Vehicle lane movement now probes physical player and pedestrian obstacles along the proposed path in sub-metre increments, stopping before entering occupied space; original simulation-only agent behavior remains unchanged.
- Added `tests/vehicle_obstacle_test.gd` to local regression runner; covers stopping for a player and resuming after clearance.
- **Open:** Godot import and regression are NOT RUN in the agent environment. Other vehicle contacts, emergency braking feel, spawn overlaps, high-speed tunneling and vehicle-to-vehicle physics require additional coverage. Do not close BUG-003 until verified on PC and Android.

## BUG-004 implementation update (2026-11-06)
- Added `CivicJunctionBuilder.make_city_graph()`: 5x5 intersections along x/z = [-120,-46,0,46,120], 80 directed road segments, no immediate U-turns, deterministic lane IDs.
- Playable `FourWayJunction` now uses the city graph when `Neighborhood` is a sibling; isolated junction tests retain original 8-lane graph.
- City traffic spawner now chooses inbound perimeter roads and follows multi-segment routes. Added `tests/city_traffic_test.gd` to local regression runner.
- **Open:** Godot runtime verification pending. Lane centerlines currently share road center rather than separated left/right lanes; intersection turn curves, right-of-way and traffic signals for new nodes, vehicle-vs-vehicle collisions, pedestrian crossings and map-aligned road visual verification remain necessary. Do not close BUG-004 as fully complete.

## Pedestrian intersection overlap follow-up (2026-11-06)
- Report: two NPCs overlap in the middle of the road.
- Change: pedestrian-to-pedestrian movement-path clearance, conservative spacing, occupied route-reset checks, and no position changes when blocked; pedestrian mask now includes other pedestrian bodies.
- Regression expanded to assert short-term pedestrian separation and occupied-path detection.
- **Verification pending:** User must run Godot regression and inspect busy crossings; no engine run in agent environment. Pedestrian rerouting and full deadlock recovery remain future work.

## Regression failures reported 2026-11-06 (38/41 passed)
- `traffic_spawner_test.gd`: isolated 8-lane throughput failed after vehicle-vs-vehicle physical obstruction was introduced. Keep physics collision checks enabled for expanded city gameplay; bypass only in isolated graph simulation mode. Pending user rerun.
- `pedestrian_collision_test.gd`: test moved an `AnimatableBody3D` manually despite physics synchronization, making the test setup unreliable. Extracted deterministic segment geometry and asserted near/far cases directly; retained 120-frame pedestrian separation test. Pending rerun.
- `surface_player_test.gd`: generated road mesh lacked explicit name; now assigned `MeshInstance3D`. Pending rerun.
- **All three are unverified after changes.** Do not close collision issues without passing suite and visual inspection.
