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
| **PHYS-001** | **P1** | **SOURCE-FIX-PENDING-VERIFY** / source fix committed in ROAD-FIX-01 | Previous continuous sidewalks crossed secondary/perimeter streets. `neighborhood.gd` now builds 16 solid, segmented pieces from shared `CityRoadLayout.sidewalk_intervals`, and curbs use the same gaps. | Execute new physics test; verify pedestrian floor and real cars at all intersections. | `road_fix_01_segmented_sidewalks_test`, updated `aud3_secondary_road_clearance_test`, `neighborhood_test`, `city_road_alignment_test`; full PC/Android crossing replay. |
| **PHYS-002** | **P1** | **SOURCE-FIX-PENDING-VERIFY** / diagnostic source committed; live jam still unconfirmed | The spawner now records actual stop-line decision labels; car movement probes record the actual obstructing collider path/layer. Read-only `stop_diagnostics()` exposes fleet slot, lane, tick, phase, position, hold reason and streak. Throttled `CIVIC_TRAFFIC_HOLD` lines appear after six uninterrupted seconds of one cause. | Run focused test, capture the user’s 60-second jam and address the *measured* root cause (no green-light permission overrides). | `road_diag_02_stop_diagnostics_test`, `city_signal_stop_line_test`, `vehicle_world_obstacle_test`; capture a stopped car’s named collider/stop reason and show clear-path release. |
| **PHYS-003** | **P1** | **SOURCE-FIX-PENDING-VERIFY** / targeted queue-spillback fix | `outer_intersection_priority.gd` now checks that the intended exit has room after its 7 m conflict zone. A blocked-outbound candidate no longer monopolizes priority; green approaches with clear exits may enter, but actual occupied zones and red remain authoritative. | Run focused test and ten-minute seeded traffic replay; investigate remaining unknown/gridlock holds without teleport or signal override. | `junction_fix_03_outbound_capacity_test`, `outer_intersection_movement_test`, `outer_intersection_priority_test`, `outer_intersection_restore_test`; green throughput and collision-free checkpoint replay. |
| **PHYS-004** | **P1** | **OPEN** / risk | Vehicle shape probe treats any non-world collider as blocking and any non-Box world hit as blocking; surfaces are classified using a global Y top calculation (`vehicle_agent.gd:215-250`). Complex/rotated parent shapes may be misclassified; collider names are not logged. | Make an explicit support-vs-obstacle classifier using each shape's world transform and actual height; report offending collider path/layer. Preserve real prop and building stops. | `vehicle_world_obstacle_test`, `vehicle_obstacle_test`, `vehicle_spawn_occupancy_test` plus sloped/offset/rotated fixtures; floor clear, actual solid obstruction blocks. |
| **PHYS-005** | **P1** | **SOURCE-FIX-PENDING-VERIFY** / reproducible from source; live screenshot confirms symptom | Every central approaching car and scripted municipal tow was previously blocked by occupancy of **either** pedestrian zone, even if the walker was parallel to that vehicle axis. Late starts also occupied the next green. | `crossing_blocks_approach` now checks only the conflicting directional zone; pedestrian entry requires at least 13 seconds until that axis next turns green. Occupied crossing protection remains unchanged and physical probes still guard people. | `traffic_fix_06_axis_crossing_release_test`, `traffic_fix_06_pedestrian_entry_window_test`, central/tow/pedestrian/save regressions; 5-minute playable mission replay with both axes moving on applicable greens. |
| **PHYS-006** | **P1** | **OPEN** / integration risk | Stop/lead observation is frozen once per tick then each car advances sequentially (`traffic_spawner.gd:114-132`); nearest lead only checks the same directed lane (`traffic_sensor.gd`). Near an intersection or lane change, lead position/occupancy may become inconsistent. | Verify same-tick lane handoffs, following gaps, and merge conflicts under dense traffic; reserve a deterministic junction entry before movement if required. | `traffic_braking_test`, `traffic_stop_line_test`, `vehicle_actor_safety_test`, `traffic_transaction_stress_test`; no overlap, bounded gap, deterministic replay after F9. |
| **PHYS-007** | **P2** | **OPEN** / risk | `_outer_pedestrian_occupied` spheres around each junction and `_routine_rest_at_safe_sidewalk` can interact with waiting pedestrians (`traffic_spawner.gd:195-208`, `district_pedestrians.gd:299-341`). A sidewalk rest must never be interpreted as occupancy of the carriageway. | Test each outer junction with waiting/crossing NPCs; tighten conflict geometry only when supported by actual collider positions. | `outer_intersection_movement_test`, `pedestrian_crowd_avoidance_test`, `pedestrian_crossing_recovery_test`, `game025_living_city_routines_test`; stationary sidewalk NPC doesn't indefinitely block its nearby green. |
| **PHYS-008** | **P2** | **OPEN** / risk | Street furniture colliders (`street_furniture.gd:66-146`) and civic mission props can be solid. Even sidewalk-local objects can clip turning clearance at narrow junctions. | Generate collision-volume clearance report for road graph paths, curb, lamps, signs, trees, bins, benches and mission objects. Move only offending objects to safe sidewalk locations. | `world_collision_test`, `aud3_road_marker_clearance_test`, `aud3_secondary_road_clearance_test`, `vehicle_world_obstacle_test`; no object intersects driven vehicle swept footprint, real urban props remain interactable. |
| **PHYS-009** | **P1** | **SOURCE-FIX-PENDING-VERIFY** / user reports five-minute stalled tow | The municipal convoy was incorrectly routed through ordinary fleet-slot priority despite not being in the fleet, and its hold reason was misreported as a signal/crossing. Dedicated `municipal_service_observation` now checks actual signal, real crossing reservations and occupied central junction, while collision sweeps still protect all vehicles and pedestrians. | Run real five-minute Wrong Way reproduction and prove green-phase tow progress plus follower releases; capture exact blocker reason on failures. | `wrong_way_tow_service_priority_test`, `aud3_wrong_way_tow_gridlock_recovery_test`, `authorized_tow_obstacle_test`, `aud3_wrong_way_signal_recovery_test`; no red/crosswalk bypass or duplicate rewards. |
| **PHYS-010** | **P2** | **OPEN** / risk | World restore applies saved vehicle, signal, reservations and walker states together (`junction_scene.gd:55-111`), but restart while a green junction is occupied can change physics contacts when all bodies re-enter the tree. | Save/load under stopline occupancy, pedestrian crossing, high density and active mission; validate collision-free post-load positions and unchanged clock/ownership. | `world_traffic_checkpoint_test`, `world_pedestrian_checkpoint_test`, `outer_intersection_restore_test`, `traffic_checkpoint_invariants_test`, `checkpoint_transaction_test`; no new stuck cars and no duplicate actor or score. |
| **PHYS-011** | **P2** | **OPEN** / diagnostic risk | Congestion backpressure counts all near-zero-speed cars including ordinary red-light waiters (`traffic_spawner.gd:34-53,143-148`), so blocked arrivals might appear when no physical gridlock exists. | Track justified red/amber/clearance waiting separately from *abnormally long* physical blockage; throttle only genuinely unsafe queues. | `traffic_spawner_test`, `traffic_budget_test`, `city_traffic_test`; fixed-seed arrival counts and no runaway queue or idle city on ordinary red. |
| **PHYS-012** | **P2** | **OPEN** / integration/performance risk | Per-car sweep uses shape queries at <= 0.4 m steps and NPCs at <= 0.2 m; both may scale badly with crowds, especially on Android (`vehicle_agent.gd:139-177`, `district_pedestrians.gd:689-724`). | Measure p50/p95/p99 physics step cost, query counts and FPS on a real phone; optimize only with replay-safe batching and no weaker human collision checks. | Android 10-minute traffic/Free Roam soak, report FPS and collisions; regression parity and no crashes/stuck touch after pause. |
| **PHYS-013** | **P2** | **SOURCE-FIX-PENDING-VERIFY** / visuals segmented | Previous full-length sidewalk and curb ribbons were visible through junction openings. Both now use matching gap intervals; center zebra stripes remain as before. | Inspect all 5×5 road intersections in PC/Android, adjust any visual discontinuities. | Screenshots from central, ±46 and perimeter road junctions; no pavement/curbs crossing open carriageways. |
| **PHYS-014** | **P2** | **OPEN** / test reliability risk | New road-clearance test from `190dfbd` has not been run in Godot, and the full suite must be verified against latest GAME-025 changes before release. | Fix tests if they expose real script/geometry mismatches; keep *at least* one physics-frame integration case, not bare assertions or source-string checks. | All test commands below clean (0 nonzero exits, 0 `ERROR:`, expected PASS marker); attach console output and tested commit SHA. |

## Work packages (tick each only after test evidence)

- [x] **ROAD-FIX-01 (PHYS-001/013) — source implemented; runtime verification pending:** Replace collider-disabled crossing sidewalk ribbons with 16 physically solid segments and matching non-colliding curbs. Recheck 5×5 road grid and car clearance in the acceptance gate before closing either issue.
- [x] **ROAD-DIAG-02 (PHYS-002/011) — source implemented; verification pending:** Add per-car stop classification, in-memory inspection with `stop_diagnostics()`, and throttled six-second `CIVIC_TRAFFIC_HOLD` console evidence. Run the local engine regression and reproduce the user’s jam before closing PHYS-002. A gameplay overlay/CSV exporter is not included in this initial diagnostic slice.
- [x] **JUNCTION-FIX-03A (PHYS-003) — source implemented, runtime verification pending:** Detect blocked outbound lanes and avoid granting the junction to a queue-head that cannot exit.
- [x] **JUNCTION-FIX-03B (PHYS-005/006/007) — source implemented; runtime verification pending:** Serialize central conflict-zone entry after existing signal/pedestrian checks and separate opposing lanes in the isolated legacy graph. Do not change pedestrian ownership or signal timing.
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
    "road_fix_01_segmented_sidewalks_test.gd",
    "road_diag_02_stop_diagnostics_test.gd",
    "aud3_secondary_road_clearance_test.gd",
    "neighborhood_test.gd",
    "city_road_alignment_test.gd",
    "vehicle_world_obstacle_test.gd",
    "vehicle_obstacle_test.gd",
    "vehicle_actor_safety_test.gd",
    "city_signal_stop_line_test.gd",
    "junction_fix_03_outbound_capacity_test.gd",
    "junction_fix_03b_central_release_test.gd",
    "traffic_spawner_test.gd",
    "traffic_braking_test.gd",
    "traffic_stop_line_test.gd",
    "junction_test.gd",
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

### ROAD-FIX-01 implementation note — 2026-11-16

- **Code:** `scripts/world/city_road_layout.gd` introduces deterministic `sidewalk_intervals()` using all five road axes, half road width and 1.5 m turn clearance. `scripts/world/neighborhood.gd` now creates 16 sidewalk `StaticBody3D` slabs with layer 1 only **between** crossing openings; the prior four continuous noncolliding sidewalk bodies are eliminated. Curb meshes also use the exact segment intervals so their visual geometry never spans perpendicular roads.
- **Regression:** New `tests/road_fix_01_segmented_sidewalks_test.gd` checks all intervals, floor shape/visual parity, real raycast support at sidewalk positions, and no sidewalk colliders in intersection openings. The existing `tests/aud3_secondary_road_clearance_test.gd` was updated to expect 16 legitimate solid sections rather than the previous noncollidable full-length ribbons.
- **Acceptance:** Run import, new and existing road tests, NPC crossing, vehicle obstacle, and central/outer signal tests. In the full city, observe vehicles driving through green on all ±46 and perimeter nodes and pedestrians stepping down to the supported road/terrain at crosswalks. Record Android visual checks. This work **does not** modify signals, traffic priority, vehicle safety sweeps, pedestrian reservations, saves, or civic economy.
- **Status:** `SOURCE-FIX-PENDING-VERIFY`. Do not mark CLOSED solely because the GitHub commit exists. Commit source evidence: `f6adfab`, `231d7e5`, `0d6c347`, `08c6ab6`.

### ROAD-DIAG-02 implementation note — 2026-11-16

- **Actual decision evidence:** `scripts/traffic/traffic_spawner.gd` labels a stop-line hold according to the *same* outer priority, pedestrian occupancy, central signal and nearest-lead observations used to brake the car. The debug label does not modify the observation sent to vehicle physics. In case of a nearer lead, the lead label takes priority.
- **Physical-blocker provenance:** `scripts/traffic/vehicle_agent.gd` captures the actual collider path/layer when the existing people/shape probe rejects a move. This is read-only and uses no extra speculative physics queries. Categories: `player`, `pedestrian`, `lead_vehicle` (physical car contact), and `world_collider`.
- **Other categories:** `red_signal`, `crossing_occupied`, `outer_pedestrian`, `outer_zone_occupied`, `outer_priority`, `mission_hold`, `route_end`, or `unknown`. An `unknown` is a diagnostic limitation, **not** proof that traffic is clear.
- **Read live data:** `FourWayJunction.traffic_spawner.stop_diagnostics()` returns the current fleet in slot order, including speed/position/route step/stop streak/phase/blocker. `diagnostics_enabled` is on for this debug phase. Lines prefixed `CIVIC_TRAFFIC_HOLD` print only after 120 consecutive stopped fixed ticks (nominally six seconds at 20 Hz) and every 120 additional unchanged-cause ticks. A change of reason or actual movement resets the streak.
- **Existing save schema unchanged:** all diagnostic properties and dictionaries are runtime-only. There is **no** forced recovery, despawn, route change, signal override or civic score impact.
- **Test:** `tests/road_diag_02_stop_diagnostics_test.gd` verifies red-to-green classification, bounded logger cadence, physical obstruction name and resumption after removal; run existing center/outer signal, world obstacle and spawner regressions too. This source patch was committed but Godot import and runtime tests are **not yet executed** here.
- **Manual evidence:** start PC scene from headless console Godot or the editor Output. After a car stalls >6s, save `CIVIC_TRAFFIC_HOLD` lines and include lane, step, distance, phase, `reason` and `blocker` in the next issue. If no lines appear while visually stalled, inspect `diagnostics_enabled` and ensure the car is managed by the city `CivicTrafficSpawner`; mission-only convoy vehicles use separate logic. Do not close PHYS-002 until the actual jam has a demonstrated cause and safe fix.


### JUNCTION-FIX-03A — Outbound Queue Capacity & Safe Priority (2026-11-16)

- **Confirmed source behavior:** Previously, the nearest approach could receive green priority when the outgoing lane was backed up *just outside* the 7-metre intersection occupancy boundary. This may waste available green time and cause a jam to spread upstream.
- **Implemented:** `scripts/traffic/outer_intersection_priority.gd` adds `exit_available()` and `OUTBOUND_QUEUE_CLEARANCE_M = EXIT_CLEARANCE_M + 2.0`. A candidate with insufficient outbound clearance receives `outbound_blocked`; other green-axis contenders with open exits are still eligible. Already committed cars and real pedestrians keep highest priority. Red and clearance phases never authorize entry. The check depends only on existing fleet route/distance snapshots, so no new saved fields or unsaved arbitration timers are introduced.
- **Diagnostic:** `scripts/traffic/traffic_stop_diagnostics.gd` maps `outbound_blocked` into existing `CIVIC_TRAFFIC_HOLD` reporting.
- **New regression:** `tests/junction_fix_03_outbound_capacity_test.gd` validates blocked exits, alternative green progress, occupied-zone protection, red-light stop, downstream release, and deterministic replay. Run existing `outer_intersection_priority_test.gd`, `outer_intersection_movement_test.gd`, `outer_intersection_restore_test.gd`, `road_diag_02_stop_diagnostics_test.gd`, `city_signal_stop_line_test.gd` and `intersection_reservations_test.gd` as well.
- **Verification still required:** Godot import/regressions, real populated 5×5 traffic replay for at least 10 minutes, saved-intersection F9 restoration, and Android validation. A direct player capture of the affected cars' `CIVIC_TRAFFIC_HOLD` records is still needed to determine whether central reservation, pedestrian, or geometry issues remain. **No central reservation or pedestrian safety permission has been relaxed.** Do not mark PHYS-003 closed yet.


### JUNCTION-FIX-03B — Central Signal/Crossing Release and Legacy Test Gridlock (2026-11-16)

**New user-supplied Godot 4.7.2 evidence, source revision `b0df3cf`:** `road_diag_02_stop_diagnostics_test.gd`, `city_signal_stop_line_test.gd`, and `vehicle_world_obstacle_test.gd` reported PASS. `traffic_spawner_test.gd` failed with `ERROR: 20-agent demand or throughput assertion failed`. The console repeatedly shows the same stopped cars on lanes 1/2/3/5/7/8 with `reason=lead_vehicle` and `phase=no_central_signal`, unchanged over many six-second reporting periods. This is confirmed persistent head-on gridlock in the **isolated legacy junction test**, not proof that the production city's pedestrian reservations are stale.

**Root causes found in source:** Legacy `make_test_graph()` used exactly coincident centerlines for opposite-direction vehicle lanes, making physical vehicles occupy each other's path. With no signal controller in the isolated spawner test, the central stop-line helper had no mechanism to serialize simultaneous crossing entries. The real central intersection could also admit opposite-approach green traffic without considering another car's committed crossing occupancy.

**Changes implemented:** `scripts/world/junction_builder.gd` now uses left-side shoulder separation of 1.6 m (3.2 m between opposite-direction carriageways) for the isolated 20 m arms, keeping eight lanes and legal shared junction endpoints. The main 5×5 city graph keeps its existing 1.25 m default. `scripts/traffic/central_intersection_priority.gd` provides stateless, checkpoint-compatible single-entrant central arbitration: 5 m inbound stop line, 7 m outbound clearance, nearest waiting contender and deterministic lane/slot tiebreak, with red-axis contenders excluded when signals exist. `scripts/traffic/traffic_spawner.gd` enforces existing red/amber/all-red and **real pedestrian reservations first**, then central car occupancy; no unsaved priority cursor, collision bypass, forced despawns, or reward edits.

**New regression:** `tests/junction_fix_03b_central_release_test.gd` checks one entrant at a time, green permission, red blocking, occupied pedestrian crossing hold, immediate release after a genuinely released crossing and deterministic policy. Updated `junction_test.gd`, `traffic_stop_line_test.gd`, `traffic_braking_test.gd` to use measured lane length after left-side separation rather than assume a physically overlapping 20 m straight centerline.

**Acceptance still required:** Godot import, `traffic_spawner_test.gd` (at least 20 arrivals and one actual completed vehicle), the new central release test, `traffic_stop_line_test.gd`, `traffic_braking_test.gd`, `junction_test.gd`, `pedestrian_crossing_recovery_test.gd`, `outer_intersection_movement_test.gd`, `outer_intersection_restore_test.gd`, `traffic_transaction_stress_test.gd`, full city PC + Android traffic acceptance, and zero Godot errors. **Do not close PHYS-005/006/007 until local tests and real signal release are verified.**


### User-observed Wrong Way tow deadlock — TOW-FIX-05F-01 (2026-11-16)

The attached DEBUG screenshot shows four stopped cars and a persistent municipal tow hold after about five minutes. Source confirms the tow vehicle was outside `active_vehicles` yet passed into the normal central lane-slot arbiter, which can starve that mission convoy behind unrelated waiting fleet traffic. Fixed by a separate service observation that respects red/amber/all-red, physically occupied central conflict zones, and actual pedestrian reservation ownership without using the normal fleet queue tie-breaker. Real forward collision sweeps and grounded service recovery remain in effect. New `wrong_way_tow_service_priority_test.gd` checks red, green release, pedestrians, physical central occupancy and committed crossing; specific hold reasons now appear in mission feedback. **No Godot/Android reproduction run was performed on this fix**. Treat it as an important source fix, not proof the player’s case has fully resolved. HUD text crowding in screenshot recorded separately as `HUD-READ-01` in `docs/qa/CAR_ART_05_DRIVER_AND_VEHICLE_REDESIGN.md`.


### TRAFFIC-FIX-06 — All-approach green starvation / Wrong Way tow deadlock (2026-11-16)

**User proof:** 2026-11-16 13:00 debug screenshot shows signal intersection with vehicles stopped on all four approaches, municipal tow parked at the crosswalk, four mission followers queued, `sustained_recovery 0/1`. Accompanying local PC Godot 4.7.2 game log shows `CIVIC_TOW_HOLD` continuously at `progress=41.38/92.76 queue=4 released=0` through ticks >7300. The reason alternates between `red_signal` and `pedestrian_crossing` as the central signal cycles; many background cars remain at `lane_distance=41.38` with repeated `red_signal` / `crossing_occupied`. The live test also reports `traffic_spawner_test.gd` PASS (throughput alone does not prove central mission recovery). User's CAR-ART-05F spokes test remains separately failing; not solved by this traffic patch.

**Root cause confirmed in source:** In `traffic_spawner.gd`, both `apply_stop_line_observation` and `municipal_service_hold_reason` treated **either** `pedestrian_crossing_ns` or `pedestrian_crossing_ew` as blocking all center-bound traffic. But `district_pedestrians.gd` explicitly assigns each crossing zone to the axis it conflicts with, and permits entry when that specific vehicle axis is red. Parallel traffic then lost its green permission unnecessarily, allowing continuous pedestrian rotations to starve the entire intersection. Another scheduling defect allowed a walker to reserve a crossing at the end of red and carry that occupancy into most of the next green.

**Source fixes:**
- `CivicTrafficSpawner.crossing_conflict_zone(approach)` and `crossing_blocks_approach(reservations, approach)` map N/S to `pedestrian_crossing_ns` and E/W to `pedestrian_crossing_ew`. Only the **relevant** zone blocks that traffic axis in normal traffic and municipal service. Opposite-axis crossing remains physically protected via per-car `people_clear_at` and `footprint_blocked_at`, conflict-owner policy and incoming sweep checks. Real occupants on the same conflict axis still stop cars instantly.
- `CivicTrafficSignalController.seconds_until_green(approach)` computes the next green transition from the existing immutable six-phase signal clock (pure read-only; no phase duration changes).
- `CivicDistrictPedestrians._can_cross(side)` denies **new** reservations when fewer than 13 seconds remain before the relevant approach next turns green; current walkers remain protected until they physically exit. No reservation cancellation timer, collider disabling, or forced tow permission.
- `junction_fix_03b_central_release_test.gd` uses the matching EW-conflicting pedestrian zone in its preexisting EW car fixture; cross-axis occupancy is now explicitly tested rather than globally blocking both green directions.

**New regression:** `traffic_fix_06_axis_crossing_release_test.gd` tests both phases and both pedestrian zones, blocking real conflicting movement and releasing parallel movement for background cars and municipal service. `traffic_fix_06_pedestrian_entry_window_test.gd` tests safe beginning-of-red crossing entry, late-red rejection, signal alternation, and reopening on the next safe phase. Existing tests to run: `signal_phases_test.gd`, `city_signal_stop_line_test.gd`, `junction_fix_03b_central_release_test.gd`, `pedestrian_crossing_recovery_test.gd`, `intersection_reservations_test.gd`, `wrong_way_tow_service_priority_test.gd`, `aud3_wrong_way_tow_gridlock_recovery_test.gd`, `traffic_spawner_test.gd`, `world_junction_checkpoint_test.gd` and `world_pedestrian_checkpoint_test.gd`.

**Acceptance:** Run an actual PC mission at least 3 complete 34-second signal cycles (and a 5-minute stress observation) with marshals, pedestrians and traffic present. Both directions must proceed on their green except for a *real conflicting* physical pedestrian, car or solid obstacle; tow must move off 41.38 m and physically clear the wrong-way offender; at least two followers must pass the incident, `sustained_recovery` must reach 1/1 and payout occur exactly once. Replay from checkpoint and rerun on Android. If mission remains blocked, capture `CIVIC_TOW_HOLD` plus corresponding `CIVIC_TRAFFIC_HOLD` and the reservation snapshot with actual walker positions before attempting further changes. **Not yet runtime-tested on the new patch; keep PHYS-005/009 open until verified.**


### ROAD-GAME-01 — Player-operated, verified Traffic Marshal (2026-11-16)

The player requested an interactive civic-sense response to multi-approach traffic congestion with reputation earned only for clearing **real** traffic. Source code now exposes a sidewalk Traffic Marshal post at (-5.5, 0.21, -10), E/USE activation after a persistent physical central obstruction, 20-second bounded spawn metering (no extra cars arriving while the existing lawful queue drains), and a once-only civic reputation event requiring two real completed routes, fewer stopped cars, and fewer physically blocked central cars. No red-light override, forced despawn of active cars, pedestrian reservation bypass, or passive score farm.

**Additional confirmed source bug PHYS-006/009:** Completed Wrong Way mission follower nodes were not removed like normal spawner cars; their inactive StaticBody3D colliders stayed on layer 4 indefinitely and could appear in actual `lead_vehicle` blockers against `WrongWayLiveMission/QueuedVehicle_1/CollisionBody`. The new `_sync_follower_presence` retires only route-*completed* follower collision/rendering and reapplies state on checkpoint restoration, retaining the logical follower receipt and preserving still-active obstruction physics.

**Track details:** `docs/audits/ROAD_GAME_01_TRAFFIC_MARSHAL_GAMEPLAY.md`, `tests/road_game_01_traffic_marshal_test.gd`. **Source committed, Godot/Android replay pending**; real-world mission state shown by the user was active *Footpath First*, which still requires examining the parked car and speaking to its owner. Traffic marshal cannot lawfully remove that car and awards no reputation until verified clearance. The visual impression of both-side green requires an axis-specific head comparison; opposite parallel N+S green is valid, but simultaneous perpendicular N/E green is forbidden.


### TRAFFIC-GAME-02 — Player manual intersection-management panel (2026-11-16)

**Status:** SOURCE IMPLEMENTED, TEST & DEVICE QA PENDING. ROAD-GAME-01 traffic marshal station now opens a panel with N/S or E/W **next green** requests, temporary new-arrival metering, and Close. A direction request only shortens an opposite green after its four-second minimum; normal amber and all-red stay mandatory before the opposite axis gets green. It is rejected if either crosswalk has an occupant or a real background/scripted car occupies the central intersection; no red/pedestrian collision override. All existing background traffic and mission vehicles still obey their physics and signal arbiter. Panel reports safe refusal explanations. Reputation remains strictly linked to measurable recovery and existing idempotent ROAD-GAME-01 receipts, not tapping signal buttons. Source: `scripts/traffic/traffic_signal_controller.gd`, `scripts/civic/traffic_marshal_control.gd`, `scripts/ui/traffic_marshal_panel.gd`, `scripts/core/main.gd`. Tests: `tests/traffic_game_02_manual_signal_test.gd`, existing signal/reservation and traffic marshal suites. Full checklist and APK commands in `docs/audits/TRAFFIC_GAME_02_INTERACTIVE_INTERSECTION_MANAGEMENT.md`. **No Windows Godot/Android testing run here.**


### TRAFFIC-FIX-07 — Cross-fleet physical junction ownership (2026-11-16)

**User's latest live Godot evidence:** `CIVIC_CHAOS_MAIN_READY` (launch successful), repeated expected `red_signal` holds on different approaches as the controller rotates NS/EW phases, but **one vehicle slot 3 on lane 142, step 1, at 44.06 m**, stays at speed zero across ticks 836/956/1076/1196/1316. Its physical obstruction is consistently `/root/Main/WrongWayLiveMission/QueuedVehicle_2/CollisionBody layer=4`. This is **not** evidence that both axes are permanently red; it shows a real mission car blocking background traffic over multiple greens. It is also not evidence that the mission-owned follower has finished its route; only inactive route-complete mission followers are permitted to become non-colliding.

**Source defect confirmed:** `CivicTrafficSpawner` performed nearest-lead and central/outer intersection occupancy arbitration only over its own `active_vehicles`, while `CivicWrongWayLiveMission` advanced four independent physical follower cars and municipal tow actors. As a result, a regular car could legally enter a junction already occupied by a mission-owned car, then physically block the other car. Conversely, mission followers did not predict live background leads in their initial observation, only discovering the obstruction via final colliders.

**TRAFFIC-FIX-07 source change:** `CivicTrafficSpawner.register_road_user`, `unregister_road_user` and `traffic_road_users` maintain a runtime-only, de-duplicated ordered list of mission cars alongside normal fleet cars for sensor probes and central/outer node permissions. Wrong Way registers followers after valid staging and tow trucks on authorized creation; unregisters them when its mission node exits. Mission follower lead sensors use the same road-user list. Completed or inactive followers are automatically excluded. Spawner-owned `active_vehicles` remains separate, so mission cars are not counted as ordinary spawn/completed journeys and the checkpoint schema does not change. Actual collisions, red and real crosswalk reservations are still enforced. A long-lived physical obstruction **must not** be bypassed with forced collision disabling.

**Regression added:** `tests/traffic_fix_07_cross_fleet_junction_test.gd`: real mission occupant prevents a regular green car from entering the center; after the occupant moves back outside, entry is permitted; unregister/inactive status do not leave phantom blockers; repeated registration is idempotent; background route counters remain unchanged. Run alongside `road_game_01_traffic_marshal_test.gd`, `traffic_game_02_manual_signal_test.gd`, `aud3_wrong_way_tow_gridlock_recovery_test.gd`, `wrong_way_tow_service_priority_test.gd`, `traffic_spawner_test.gd`, `city_signal_stop_line_test.gd` and full world checkpoint verification.

**Acceptance STILL OPEN:** Godot import/test-run, a five-minute PC live replay confirming lane 142's blocker disappears by actual safe vehicle movement, legal NS/EW throughput, no pedestrian/car overlap, and Wrong Way mission reward only after legitimate measured recovery. If `QueuedVehicle_2` remains at the same world position on successive greens, collect that mission car's own speed, lead observation, lane position and physical blocker; do not auto-complete missions or disable active cars. Android acceptance pending. No workflows manually triggered.


### TRAFFIC-FIX-08 — Outbound Capacity & Mission Lane Isolation (2026-11-16)

**Local log evidence:** The user's `traffic-fix-07.log` shows recurring stuck cars at 35.33/38.36/41.38m on central approaches (lanes 142/147), many `lead_vehicle` collisions with *background* cars across multiple NS and EW green phases. The same log shows real Wrong Way mission followers on lane 126 stopped behind the active offender. Signals rotate; this is an occupancy/queue spillback problem, not a frozen signal clock. A player collision also appears and must remain authoritative.

**Fixes committed:** `CivicCentralIntersectionPriority.exit_available` now requires the chosen outbound lane to be clear beyond the central conflict zone before green entry and skips an exit-blocked competitor during priority selection. `CivicTrafficSpawner` now supports owner-scoped, transient incident-lane closures that affect **only future route selection**. `CivicWrongWayLiveMission` blocks new background routes into its offender approach until the authorized tow genuinely removes it; restoration recreates/clears that closure according to validated tow state. Existing stopped cars, mission followers, people, signals, and collisions remain real.

**Regression and documentation:** `tests/traffic_fix_08_central_spillback_test.gd`, `tests/traffic_fix_08_incident_detour_test.gd`, full checklist and local commands in `docs/audits/TRAFFIC_FIX_08_JUNCTION_GRIDLOCK_AND_INCIDENT_ISOLATION.md`. **Source implemented, not yet runtime-verified**. Pending: Godot import, focused/full regressions, five-minute in-game junction replay, parking incident footprint check, checkpoint restore and Android throughput. Do not close the gridlock finding or claim civic reputation until measured live progress.


### UI-HUD-01 — Compact Civic HUD and GTA-style Bottom-Left Map (2026-11-16)

User screenshot reveals overlapping permanent district-preview commands, verbose seven-row civic HUD and large mission radio panel; minimap at top center obscures signals and mission action. Source redesign committed: `CivicCityMap` bottom-left, player-centered heading-aligned local road projection, mission waypoint and route highlight, retained M/full-map navigation; `CivicStatusHUD` two-row score strip hiding populated verbose telemetry labels; `CivicMissionGuide` short title/objective/waypoint with radio transcript hidden by default and recovery buttons preserved; legacy top-center `Main.CanvasLayer/HUD` hidden. Added `tests/ui_hud_01_compact_minimap_test.gd` across desktop and mobile viewports and documentation `docs/audits/UI_HUD_01_COMPACT_HUD_AND_MINIMAP.md`. **Source committed; Godot 4.7.2 runtime, mobile visual acceptance and APK pending.** This does not alter the separate unresolved traffic-gridlock issues.


### TRAFFIC-FIX-09 — Exclusive four-approach central signal and NPC civic road rules (2026-11-16)

User requested exactly **one direction green** rather than both opposite approaches green concurrently, after sharing a screenshot of two lit heads and stopped traffic. Source audit verified this is currently intentional legacy `NS_GREEN` / `EW_GREEN`, with `StreetFurniture` rendering the actual controller state. The expanded playable junction now opts into N -> E -> S -> W exclusive phases with amber and all-red after each approach; isolated test junctions retain old paired mode. Ordinary cars and municipal service share the same `aspect_for_approach`, so NPCs stop at a red or amber approach; central priority/downstream clearance and physical pedestrian checks remain authoritative. Pedestrians must observe BOTH opposing approaches red and have time to finish before the next conflicting green. Manual Traffic Marshal panel now offers four directional controls, constrained by the safe phase order and minimum four-second green service. Existing Wrong Way and Illegal Parking remain intentional NPC rule violations to investigate, without making background cars randomly run red.

New regressions: `traffic_fix_09_single_approach_rules_test.gd`, `traffic_fix_09_visual_marshal_test.gd`; specification and Windows command: `docs/audits/TRAFFIC_FIX_09_SINGLE_APPROACH_SIGNAL_AND_NPC_RULES.md`. **Source changes committed; no Godot import/test/gameplay/Android verification performed yet.** Reducing concurrent greens to one direction may lower throughput; five-minute congestion replay is REQUIRED and previous traffic queue audit remains open until real cars move, followers clear and civic missions complete.


### OUTER-SIGNAL-10 — Single-approach outer-junction signal rollout (2026-11-16)

**Context:** User confirmed the TRAFFIC-FIX-09 central single-green regression suite passes and requested the next task. The previously OPEN OUTER-SIGNAL-10 work has now been implemented in source. All 24 outer nodes use **North -> East -> South -> West**, one exclusive 120-tick/6-second green per approach and a 40-tick/2-second all-red clearance between approaches, at the existing 20 Hz deterministic simulation clock. `CivicOuterIntersectionPriority` derives the arrival direction from lane geometry, gates only that incoming approach, and retains committed crossing ownership, downstream capacity, real pedestrian collision handling and deterministic tie-breaking. `CivicOuterTrafficLights` draws 96 four-direction heads instead of 48 paired-axis heads; light materials derive from the identical pure fixed-tick policy that controls vehicle entry. No checkpoint state fields change. This reduces how often each direction is served and requires actual throughput measurement, not assumed decongestion.

**Regressions:** New `tests/outer_signal_10_four_approach_test.gd`, plus updated `outer_intersection_priority_test.gd`, `outer_intersection_movement_test.gd`, and `outer_intersection_restore_test.gd`. Specification and local commands: `docs/audits/OUTER_SIGNAL_10_FOUR_DIRECTION_INTERSECTIONS.md`. **Source committed, Godot import/runtime/Android verification pending.** Do not mark outer traffic, overall city gridlock or civic missions complete until regression and five-minute live gameplay evidence pass.


### TRAFFIC-PERF-11A — Authorized tow progress starvation (2026-11-16)

**Live evidence:** In the 433-line user's `traffic-fix-07.log`, the municipal tow remains at 41.38/92.76m, `queue=4 released=0`, as `red_signal` and `pedestrian_crossing` alternate during several full N/E/S/W central cycles. The four actual followers remain behind the physical WrongWayOffender on lane 126. Existing `_note_tow_hold` fallback only handles 180 consecutive `physically occupied` frames, not alternating lawful signal/people holds.

**11A source committed, QA pending:** `scripts/civic/wrong_way_live_mission.gd` now prints structured `CIVIC_TOW_GATE` every 6 no-progress seconds (approach, signal aspect, next-green wait, two crosswalk occupants, central occupancy, exact convoy progress); counts only actual stationary time and resets it on successful tow travel. After at least two full central light cycles (minimum 136 seconds) and only after verified reported/intervened service, it may begin the existing two-second **stationary** roadside collection if both crossing reservations are free, no unrelated car occupies the central junction, and the layer 2/4/8 worksite probes find no player, pedestrian or another car immediately overlapping either collection position. Collection freezes if anybody enters during the service window; no red override, person collision suppression, tow teleport or artificial follower release. Existing civic mission still pays only after at least two actual follower cars have resumed and recovery is sustained. No new checkpoint fields; timer starts anew after tow reconstruction.

**New test:** `tests/traffic_perf_11a_tow_starvation_test.gd` reproduces W-approach tow at red, checks refusal for early red, occupied pedestrian zone and actual pedestrian body, then checks grounded collection and zero premature mission reward. **Full checklist:** `docs/audits/TRAFFIC_PERF_11A_TOW_STARVATION_RECOVERY.md`. **Status remains OPEN** until Godot import/tests + live Wrong Way replay + Android test pass. After that, TRAFFIC-PERF-11B should measure throughput/queue age before changing green lengths.


### TRAFFIC-FIX-11C — Central municipal tow admission / mission queue deadlock (2026-11-16)

User's new screenshot shows **Wrong Way, Wrong Day** active with a stationary municipal service convoy, several stopped NPCs and the message `No service/traffic progress for about 30 seconds`. The visible console line identifies a real mission follower stopped behind `WrongWayLiveMission/QueuedVehicle_1/CollisionBody`; changing traffic signals cannot remove physical road occupancy. Source inspection confirmed that (a) active municipal service did not reserve a central entry window, so unrelated cars continued entering the junction on subsequent greens, and (b) TRAFFIC-PERF-11A's no-progress timer omitted rejected *physical footprint-sweep* movement. This can indefinitely defer safe service recovery when stop causes alternate.

**Implemented:** `CivicTrafficSpawner.set_central_service_priority` gates only *new* central inbound entry behind stop lines during a valid active tow, leaving already-entered cars free to clear and the service itself still bound by its own green and pedestrian protection. The gate is activated when the authorized tow stages, cleared on tow completion/mission removal, and recreated only when reconstructing live service from a checkpoint. Tow no-motion timing now counts every real zero-displacement frame, including alternating signals/pedestrians/physical swept blockers, and resets only on accepted travel. The 180-frame physical fallback now requires the same civic authorization and worksite/crosswalk protection as the measured starvation path; no teleport, no automatic mission completion and no fake civic payout.

**Tests added:** `traffic_fix_11b_municipal_junction_priority_test.gd` (safe stop-line admission, committed car exit, own red/occupied crossing, normal reopening, no stale generation); `traffic_fix_11c_tow_priority_lifecycle_test.gd` (real authorized stage, admission lifecycle, mixed stop clock, no payout). Full local regression command and on-device acceptance checklist: `docs/audits/TRAFFIC_FIX_11C_TOW_JUNCTION_DEADLOCK.md`. **SOURCE COMMITTED, NOT YET VERIFIED IN GODOT/ANDROID**. Keep PHYS-005/009 and Wrong Way mission completion open until replay shows tow and real queued cars advance and reward occurs only after physical recovery.


### TRAFFIC-FIX-11D — Physical Wrong Way follower queue discharge (2026-11-16)

**User screenshot:** `Wrong Way, Wrong Day` active, municipal tow near junction and `CIVIC_MISSION_CAR_HOLD` confirming `QueuedVehicle_0` physically behind `QueuedVehicle_1/CollisionBody layer=4` during `E_AMBER`. A stopped convoy is not necessarily a frozen signal: the issue is a finite roadway queue competing with new city arrivals for scarce West green turns even *after* the offender is lawfully removed. Earlier TRAFFIC-FIX-11C held new central entries during municipal towing but released that protection immediately on tow completion, leaving the physical follower queue again vulnerable to starvation.

**Implemented:** `CivicTrafficSpawner.start_central_recovery` reserves a bounded maximum 2,800-tick/140s post-tow discharge window for **only the actual registered still-active Wrong Way follower vehicles**. Nonparticipating *new central entries* wait behind stop lines, committed cars leave normally, and the mission followers keep all normal signal, crossing-reservation, physical-car/pedestrian and junction-occupancy checks. The priority ends when followers pass the central entrance, the window expires, or the mission completes. Actual tow completion starts it; checkpoint restore reconstructs it from real active follower state; scene reconfigure and mission exit clear it. No teleport, collision bypass, artificial stopped-counter reduction or premature reputation. Test: `tests/traffic_fix_11d_wrong_way_follower_release_test.gd`. Full QA: `docs/audits/TRAFFIC_FIX_11D_WRONG_WAY_FOLLOWER_RELEASE.md`.

**Status:** SOURCE AND REGRESSION COMMITTED, GODOT IMPORT/FOCUSED TESTS/LIVE 5-MINUTE REPLAY/ANDROID NOT YET VERIFIED. The user-reported mission issue remains OPEN until at least two followers physically clear and all pedestrian/signal safety regressions pass.
