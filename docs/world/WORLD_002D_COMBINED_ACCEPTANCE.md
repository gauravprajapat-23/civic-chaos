# WORLD-002D — Combined City Playtest, Traffic Safety, Android Acceptance

Status: Implementation and test harness committed. NATIVE WINDOWS GODOT AND ANDROID VERIFICATION HAVE NOT BEEN RUN. PR #92 and MAP PR #91 remain draft and unmerged.

## Audit findings and fixes

1. Previously, the outer-intersection policy controlled only grid-aligned junctions. The interior neighborhood junction at (83, -106) was therefore uncontrolled. The policy now recognizes canonical world002 nodes and uses the existing deterministic approach/clearance/occupancy protections.
2. The new six-metre connector carries two 2.5-metre lanes rather than inheriting the 3.2m lane widths designed for wider streets.
3. The MAP-002A/B/D tests on draft PR #91 now accept either 40 legacy roads (standalone map branch) or 40 unchanged legacy roads plus exactly the two new reserved connectors (combined review).
4. Existing city spawner logic excludes appended lane IDs 1000+ as initial vehicle entries, retaining them for legal through routes. Traffic-worker review is required.

## New regression tests

- tests/world_002d_junction_integration_test.gd: verifies both opposing incoming lanes are actually controlled at the off-grid junction, single-approach admission across every tick of the policy cycle, occupancy conflict rejection, deterministic clock replay, old saved lane identity and city GPS connectivity.
- tests/world_002d_road_surface_test.gd: instantiates the live neighborhood and raycasts the sampled centerlines of the two east curves and two new connectors. It verifies that a proper drivable, upward-facing road collision surface was hit rather than the terrain or decorative geometry.
- Existing WORLD-002A/B/C/C2, WORLD-001E/F, MAP-002A/B/C/D, outer-junction priority, road-footpath and AUD3 tests remain part of the release gate.

## Safe local combined verification

Work from the normal repo at C:/Users/gauravp/Projects/civic-chaos, but create a fresh, detached review worktree at C:/Users/gauravp/Projects/civic-chaos-world-002d-combined-review from origin/feature/world-002-organic-neighborhoods. Within that disposable worktree only, run git merge --no-ff --no-edit origin/feature/map-002-gta-style-overhaul. This creates only a LOCAL review merge commit; do not push or merge either GitHub PR. If the merge reports conflicts, stop and inspect the worktree rather than forcing it.

With Godot_v4.7.2-stable_win64_console.exe, run headless editor import and all 15 focused tests below. Require exit code zero, absence of Godot ERROR/SCRIPT ERROR/FATAL ERROR and the expected CIVIC_CHAOS_*_PASS marker for each.

1. world_002d_junction_integration_test.gd
2. world_002d_road_surface_test.gd
3. world_002c2_connected_streets_test.gd
4. world_002c_organic_roads_test.gd
5. world_002b_public_spaces_test.gd
6. world_002a_block_layout_test.gd
7. world_001f_save_contract_test.gd
8. world_001e_map_parity_test.gd
9. map_002a_visual_foundation_test.gd
10. map_002b_districts_landmarks_test.gd
11. map_002c_gps_navigation_test.gd
12. map_002d_driving_performance_test.gd
13. outer_intersection_priority_test.gd
14. road_footpath_01_crossing_test.gd
15. aud3_city_map_test.gd

## Android debug APK

From the combined review worktree, export with the existing Godot preset Android Debug to build/android/civic-chaos-world-002d-review.apk, then install with adb install -r. Requires Godot export templates and local Android SDK/keystore. Export success is NOT evidence of rendered or physics acceptance.

## Manual release gate

- Drive the NE connector and east curves with car and motorcycle in both directions. Confirm actual collisions match visible asphalt, no wheel falling, stuck reverse or vehicle teleport.
- At both junctions and the interior off-grid node, observe opposing NPC traffic during dense load. Record any overlapping grants, side-swipe, deadlock, wrong-way, or priority violations. Independent Traffic-worker signoff required.
- Walk into and out of neighborhoods and plazas, inspect curbs and incident markers, and confirm original bus stop, parking court and Community Park still work.
- Test F5/F9 traffic checkpoints with legacy 100..179 routes and new 1000..1003 routes, including invalid-save rejection.
- Open full map and minimap: verify all 42 roads, GPS, player marker, district overlays, safe-area touch controls and Android portrait/landscape behavior.
- Record Android FPS, draw calls, frame time, memory, freezes, and touch latency with traffic present. Do not claim gains without measurements.

Release decision: BLOCKED until all native tests and rendered traffic, rider, navigation and Android acceptance are recorded. No GitHub Actions manually triggered; scripts/core/main.gd untouched.