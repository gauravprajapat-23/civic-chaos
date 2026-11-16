# Civic Chaos — AUD3 Physics, Road & Traffic Stability Tracker

**Audit date:** 2026-11-16  
**Repo / branch:** `gauravprajapat-23/civic-chaos` · `fix/aud-001-game024-gate-hardening`  
**Scope:** Full city road geometry, moving vehicle physics, central/outer signals, pedestrians, collision queries, player interaction, mission-specific vehicles, world checkpoint restore and Android performance.  
**Evidence:** Source inspection of the live GitHub branch and prior collision audits; player-reported cars stuck at signals. **No new Godot 4.7.2 runtime tests, full regression, device profiling or Android APK validation were executed as part of this audit.**  
**Goal:** Remove accidental vehicle blockers and permanent gridlock **without** ignoring real people, traffic lights, cars, collision bodies or valid civic mission actors.

## Reading the tracker

- **Confirmed (source):** the code demonstrates the specified behavior/limitation; observed in-game impact may still need reproduction.
- **Reported:** player observed the failure; exact underlying cause is not proven.
- **Risk:** plausible from source but requires targeted Godot/Android reproduction.
- **Fixed in source, verify:** code change exists; not closed until acceptance passes.
- **P0:** release-blocking safety/corruption/crash; **P1:** frequent blocked gameplay/physics; **P2:** intermittent or integration risk; **P3:** visual/diagnostic/polish.
- **Status:** `OPEN`, `SOURCE-FIX-PENDING-VERIFY`, `TESTING`, `VERIFIED`, `CLOSED`. Only mark **CLOSED** with tested commit, date/platform, reproduction evidence, and regression.

## Executive findings

**Priority order:** **PHYS-001 → PHYS-002 → PHYS-003 → PHYS-004 → PHYS-005 → PHYS-006** before gameplay expansion. The user's green-light gridlock may have multiple simultaneous causes; the recently changed continuous sidewalk slabs were one demonstrable geometry hazard but **not yet proven to be the only cause**.

- Road render/collision: `scripts/world/neighborhood.gd:32-35,135-153` creates continuous 240 m sidewalk ribbons across several streets. Commit `2d28c95` kept meshes but disabled their collision layers. The **visual ribbon still crosses live roads**, and physically-correct curbs/sidewalk walking support needs a segmented replacement. New focused test: `aud3_secondary_road_clearance_test.gd` (not yet run).
- Signals: `scripts/traffic/traffic_spawner.gd:150-208` merges stopped lead-car, red signal and pedestrian conflict into the same zero-speed observation. A vehicle may appear permanently stopped at green, but current diagnostics cannot identify whether it is blocked by terrain, a car, a pedestrian or intersection priority. Central crossing reservation occupancy blocks both approach axes.
- Vehicle movement: `scripts/traffic/vehicle_agent.gd:94-125,139-177,215-250` probes people and world shapes along a forward swept path. Unknown layer-1 shapes are treated as solid obstacles; standing on a road must not be misclassified as a blocked lane. The travel loop is non-rigid deterministic placement (intentional), so it needs real-world collision coverage.
- Outer intersections: `scripts/traffic/outer_intersection_priority.gd:64-127` uses per-tick alternating right-of-way, geometry-derived occupancy and stable winner selection. An occupied conflict zone keeps entry closed; there is no driver-facing breakdown of why it remains occupied.
- Pedestrians: `scripts/npc/district_pedestrians.gd:230-270,689-724` prevents illegal crossings, checks physical clearances, and has voluntary routine pauses. Check that waiting/recovering pedestrians and floor contacts do not create persistent conflict occupancy in the expanded city.
- Tow/missions: `scripts/civic/wrong_way_live_mission.gd:503-565` has a ground-level roadside recovery after prolonged **physical** tow blockage. Verify it does not mask systemic world geometry failures or fail to restore physical traffic after cleanup.
- Checkpoints: `scripts/world/junction_scene.gd:55-111` saves signal, traffic, reservation and pedestrian state as one world transaction. Restore must be tested *while vehicles occupy stop lines/intersections*, not just in idle scenes.
- Historical source audit: `docs/audits/COLLISION_PHYSICS_AUDIT.md` and `docs/audits/ISSUE_REGISTER.md` include November 6 behavior, some of which has already been changed. Do **not** carry old BUG-001/003 statuses forward without checking current source.

## Prioritized issue register

| ID | Priority | Status / confidence | Problem & current evidence | Fix task | Proof to close |
|---|---|---|---|---|---|
| **PHYS-001** | **P1** | **SOURCE-FIX-PENDING-VERIFY** / confirmed layout hazard | Continuous `SidewalkX/Z` meshes and former solid slabs cross secondary/perimeter road axes (`neighborhood.gd:32-35,139-146`). Source fix disabled slab collision, not the visibly crossing ribbons. | Segment sidewalk strips between legal intersections; replace surface geometry without creating car barriers. Validate cars, player and NPC floor transitions. | `aud3_secondary_road_clearance_test`, `neighborhood_test`, `city_road_alignment_test`; drive *all* inner/perimeter axes; no blocker above wheel clearance; pedestrian stays grounded. |
| **PHYS-002** | **P1** | **OPEN** / source-confirmed diagnostic gap; gameplay trigger reported | A green light doesn't imply motion: `apply_stop_line_observation` and physics sweep can stop cars for several distinct reasons, while `queue_pressure` only reports overall stopped counts (`traffic_spawner.gd:41-53,114-148,150-208`). | Add fixed-step read-only car stop reason: `red_signal`, `crossing_occupied`, `outer_priority`, `lead_vehicle`, `world_collider`, `pedestrian`, `mission_hold`. Include junction/lane/pose/tick in throttled debug report; do not change simulation decisions for instrumentation. | Capture actual 60-second live gridlock, one unambiguous source collider/reason per affected car, prove no false reason on an ordinary red; throughput resumes on green after blocker clears. |
| **PHYS-003** | **P1** | **OPEN** / risk | Outer node occupancy `occupies()` and `disposition()` block all entrants while a car is committed (`outer_intersection_priority.gd:64-127`). A car stopped beyond stopline could hold this authority indefinitely. | Add deterministic starvation detector and safe recovery policy; no forced vehicle teleport, collision override or red-light bypass. Verify commitments are released upon actual exit. | `outer_intersection_movement_test`, `outer_intersection_priority_test`, `outer_intersection_restore_test`; 10-minute fixed seed, both axes make measurable progress and no car/crosswalk overlaps. |
| **PHYS-004** | **P1** | **OPEN** / risk | Vehicle shape probe treats any non-world collider as blocking and any non-Box world hit as blocking; surfaces are classified using a global Y top calculation (`vehicle_agent.gd:215-250`). Complex/rotated parent shapes may be misclassified; collider names are not logged. | Make an explicit support-vs-obstacle classifier using each shape's world transform and actual height; report offending collider path/layer. Preserve real prop and building stops. | `vehicle_world_obstacle_test`, `vehicle_obstacle_test`, `vehicle_spawn_occupancy_test` plus sloped/offset/rotated fixtures; floor clear, actual solid obstruction blocks. |
| **PHYS-005** | **P1** | **OPEN** / risk | Center junction blocks on either `pedestrian_crossing_ns` **or** `pedestrian_crossing_ew` occupancy (`traffic_spawner.gd:182-186`); crossing ownership lives in `intersection_reservations.gd`. Failed release or stale saved occupant can stop every central approach. | Audit reservation lifecycle, pedestrian crossing exit and timeouts; distinguish legitimate occupied crossings from stale occupant; repair only safely unoccupied zones. | `intersection_reservations_test`, `pedestrian_crossing_recovery_test`, `city_signal_stop_line_test`, `world_junction_checkpoint_test`; no competing car/pedestrian on shared conflict zone, timely green release after crossing fully clears. |
| **PHYS-006** | **P1** | **OPEN** / integration risk | Stop/lead observation is frozen once per tick then each car advances sequentially (`traffic_spawner.gd:114-132`); nearest lead only checks the same directed lane (`traffic_sensor.gd`). Near an intersection or lane change, lead position/occupancy may become inconsistent. | Verify same-tick lane handoffs, following gaps, and merge conflicts under dense traffic; reserve a deterministic junction entry before movement if required. | `traffic_braking_test`, `traffic_stop_line_test`, `vehicle_actor_safety_test`, `traffic_transaction_stress_test`; no overlap, bounded gap, deterministic replay after F9. |
| **PHYS-007** | **P2** | **OPEN** / risk | `_outer_pedestrian_occupied` spheres around each junction and `_routine_rest_at_safe_sidewalk` can interact with waiting pedestrians (`traffic_spawner.gd:195-208`, `district_pedestrians.gd:299-341`). A sidewalk rest must never be interpreted as occupancy of the carriageway. | Test each outer junction with waiting/crossing NPCs; tighten conflict geometry only when supported by actual collider positions. | `outer_intersection_movement_test`, `pedestrian_crowd_avoidance_test`, `pedestrian_crossing_recovery_test`, `game025_living_city_routines_test`; stationary sidewalk NPC doesn't indefinitely block its nearby green. |
| **PHYS-008** | **P2** | **OPEN** / risk | Street furniture colliders (`street_furniture.gd:66-146`) and civic mission props can be solid. Even sidewalk-local objects can clip turning clearance at narrow junctions. | Generate collision-volume clearance report for road graph paths, curb, lamps, signs, trees, bins, benches and mission objects. Move only offending objects to safe sidewalk locations. | `world_collision_test`, `aud3_road_marker_clearance_test`, `aud3_secondary_road_clearance_test`, `vehicle_world_obstacle_test`; no object intersects driven vehicle swept footprint, real urban props remain interactable. |
| **PHYS-009** | **P2** | **OPEN** / risk | Mission tow is fixed by safe grounded removal after physical congestion (`wrong_way_live_mission.gd:503-565`), but the root obstruction may remain and stop subsequent background cars. | Capture tow hold reason plus world blocker ID; after service confirm background car throughput without despawning healthy traffic. | `aud3_wrong_way_tow_gridlock_recovery_test`, `authorized_tow_obstacle_test`, `aud3_wrong_way_signal_recovery_test`; no flying car, no residual obstruction, correct civic reward count. |
| **PHYS-010** | **P2** | **OPEN** / risk | World restore applies saved vehicle, signal, reservations and walker states together (`junction_scene.gd:55-111`), but restart while a green junction is occupied can change physics contacts when all bodies re-enter the tree. | Save/load under stopline occupancy, pedestrian crossing, high density and active mission; validate collision-free post-load positions and unchanged clock/ownership. | `world_traffic_checkpoint_test`, `world_pedestrian_checkpoint_test`, `outer_intersection_restore_test`, `traffic_checkpoint_invariants_test`, `checkpoint_transaction_test`; no new stuck cars and no duplicate actor or score. |
| **PHYS-011** | **P2** | **OPEN** / diagnostic risk | Congestion backpressure counts all near-zero-speed cars including ordinary red-light waiters (`traffic_spawner.gd:34-53,143-148`), so blocked arrivals might appear when no physical gridlock exists. | Track justified red/amber/clearance waiting separately from *abnormally long* physical blockage; throttle only genuinely unsafe queues. | `traffic_spawner_test`, `traffic_budget_test`, `city_traffic_test`; fixed-seed arrival counts and no runaway queue or idle city on ordinary red. |
| **PHYS-012** | **P2** | **OPEN** / integration/performance risk | Per-car sweep uses shape queries at <= 0.4 m steps and NPCs at <= 0.2 m; both may scale badly with crowds, especially on Android (`vehicle_agent.gd:139-177`, `district_pedestrians.gd:689-724`). | Measure p50/p95/p99 physics step cost, query counts and FPS on a real phone; optimize only with replay-safe batching and no weaker human collision checks. | Android 10-minute traffic/Free Roam soak, report FPS and collisions; regression parity and no crashes/stuck touch after pause. |
| **PHYS-013** | **P2** | **OPEN** / visual and gameplay risk | The prior sidewalk fix leaves fully visible ribbons across perpendicular roads, although not collidable. This can look like road barriers and can mislead players about legal crossing space. | Replace with actual non-overlapping sidewalk sections and zebra crossings; do not remove visual road markings or valid collision guidance. | Android screenshots from center, ±46, perimeter junctions: no pavement across carriageway; pedestrian wayfinding readable; no floating slab. |
| **PHYS-014** | **P2** | **OPEN** / test reliability risk | New road-clearance test from `190dfbd` has not been run in Godot, and the full suite must be verified against latest GAME-025 changes before release. | Fix tests if they expose real script/geometry mismatches; keep *at least* one physics-frame integration case, not bare assertions or source-string checks. | All test commands below clean (0 nonzero exits, 0 `ERROR:`, expected PASS marker); attach console output and tested commit SHA. |

## Work packages (tick each only after test evidence)

- [ ] **ROAD-FIX-01 (PHYS-001/013):** Replace collider-disabled crossing sidewalk ribbons with segmented, sidewalk-only mesh/physics geometry. Recheck full 5×5 grid and car clearance.
- [ ] **ROAD-DIAG-02 (PHYS-002/011):** Add deterministic, read-only per-car stop classification and live debugging overlay or CSV. Reproduce *the user's* signal jam.
- [ ] **JUNCTION-FIX-03 (PHYS-003/005/006/007):** Solve only proven phase, reservation, priority, and starvation defects, retaining red-light/crosswalk protection.
- [ ] **PHYS-FIX-04 (PHYS-004/008):** Audit and classify every world collider on all route sweeps, improve shape filtering, eliminate unintended fixed-blocker overlap.
- [ ] **MISSION-FIX-05 (PHYS-009):** End-to-end wrong-way tow, parking, cleanup and background traffic recovery.
- [ ] **SAVE-FIX-06 (PHYS-010):** Mid-junction and crossing save/load atomicity and physical restoration.
- [ ] **PERF-VERIFY-07 (PHYS-012/014):** Full regression, seed replay, 10-minute PC soak, 10-minute Android soak and test APK sign-off.

## Mandatory safety invariants

1. No car enters during a red/amber/all-red authorization or occupied pedestrian conflict zone.
2. No car moves through a real vehicle, person, building or legitimately obstructing prop.
3. A green phase **with a genuinely clear path** results in measurable movement before the next phase; do not “fix” traffic by disabling vehicle collider scans.
4. Waiting pedestrians do not freeze irrelevant lanes; NPCs never use scene visuals as physical right-of-way.
5. Checkpoint restore retains the same traffic signal phase, physical ownership, route index, world clock and civic score receipts.
6. Visual-only landmarks, HUD markers, zebra stripes and road dashes must never become collision blockers.
7. No flying/tunnel-through cars or untracked emergency movement. Deadlock recovery must remain physically safe and auditable.
8. Do not declare any issue resolved using a PASS marker alone when Godot also logs `ERROR:` / `SCRIPT ERROR:`.

## Local reproduction / focused acceptance (PowerShell)

Use the **latest branch** and Godot 4.7.2 on Windows. The audit itself did not execute these commands.

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

git -c remote.origin.fetch= fetch --no-tags origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Update failed" }
git rev-parse --short HEAD

& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

$tests = @(
    "aud3_secondary_road_clearance_test.gd",
    "neighborhood_test.gd",
    "city_road_alignment_test.gd",
    "vehicle_world_obstacle_test.gd",
    "vehicle_obstacle_test.gd",
    "vehicle_actor_safety_test.gd",
    "city_signal_stop_line_test.gd",
    "outer_intersection_movement_test.gd",
    "outer_intersection_priority_test.gd",
    "outer_intersection_restore_test.gd",
    "pedestrian_crossing_recovery_test.gd",
    "pedestrian_crowd_avoidance_test.gd",
    "world_junction_checkpoint_test.gd",
    "aud3_wrong_way_tow_gridlock_recovery_test.gd",
    "traffic_checkpoint_invariants_test.gd"
)

foreach ($test in $tests) {
    Write-Host "RUN $test" -ForegroundColor Cyan
    $output = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $exitCode = $LASTEXITCODE
    $output | Out-Host
    if ($exitCode -ne 0 -or
        ($output | Select-String -Pattern "ERROR:|SCRIPT ERROR:") -or
        -not ($output | Select-String -Pattern "_PASS")) {
        throw "FAILED: $test"
    }
}
Write-Host "Focused physics audit gate passed" -ForegroundColor Green
```

### Physical/manual replay matrix

| Scenario | Set-up | Record |
|---|---|---|
| Center NS & EW | Wait through 2 whole signal cycles; restart with F9 while each direction queues | Time to move once green, closest static collider path, reservations, queue depth |
| Outer ±46 intersections | At least 3 seeded cars + one nearby pedestrian, then pedestrian clears | Which axis moved, first-move tick, remaining occupation |
| Perimeter ±120 | Cars travel and turn past road caps/walls | Any car snap, false footprint hit or off-road travel |
| Incident towing | Finish Wrong Way with a real congestion case | Tow hold reason, clearance, cars subsequently moving |
| Illegal parking and cleanup | Complete both missions, revisit street | Original props retired, no lingering invisible obstacle |
| Loaded jam | Save at red/green with cars close to crossing; F9, repeat twice | Same physical positions, no extra cars/rewards, later green releases |
| Free Roam | 10-minute event/crowd run | Max stopped streak, event blockage, frame-time and touch control integrity |
| Android debug APK | Repeat center+outer crossing, map, pause/resume and incident interactions | FPS, device logs, no duplicate touch hold or input dead zone |

## Tracking and evidence log (update per fix)

| Date | Ticket | Commit | Evidence (Godot version/platform/test or video) | Result | Owner/next action |
|---|---|---|---|---|---|
| 2026-11-16 | PHYS-001 | `2d28c95`, `190dfbd` | Source patch + newly committed road-clearance test; **not executed** | SOURCE-FIX-PENDING-VERIFY | Run Godot test, then segment sidewalk |
| 2026-11-16 | PHYS-002 to PHYS-014 | — | Source audit; exact live blocker unknown | OPEN | Start ROAD-DIAG-02 after geometry acceptance |

**Release gate:** All P1 items VERIFIED and CLOSED, no unresolved unsafe P0, mandatory tests clean, full fixed-seed regression and physical PC/Android replay attached. **No GitHub Actions were manually triggered by this audit.**
