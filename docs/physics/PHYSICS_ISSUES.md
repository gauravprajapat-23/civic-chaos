# Civic Chaos — Physics Issue Register
Date: 2026-11-06 | Working branch: `fix/regression-nov05`
Status wording: OPEN = acceptance not proven; PARTIAL = code exists, real contacts not fully verified.

| ID | Priority | Status | Root cause and source | Exit criteria |
|---|---|---|---|---|
| PHYS-001 | P1 | PARTIAL — NOT RUN | Horizontal sweep added at `af04f32`, expanded to player vs NPC and vehicle (mask 12) at `b442124`; real run pending | Player stops/slides around NPC without treating head as floor; physics-frame tests pass |
| PHYS-002 | P1 | PARTIAL — NOT RUN | `f89584b` introduces safe spawn clearance, swept shape sampling, and deterministic side-step/yield recovery in `scripts/npc/district_pedestrians.gd`; source-patched, Godot unverified | Opposing, crossing and multi-NPC groups pass with no overlap or deadlock |
| PHYS-003 | P1 | PARTIAL | `scripts/traffic/vehicle_agent.gd` sampled Node3D movement, static collider child | Vehicle collisions prevented at varied speeds/turns; no tunneling |
| PHYS-004 | P1 | OPEN | `scripts/traffic/traffic_spawner.gd:_spawn_occupied` tests cars only by center distance | Reject full-volume overlapping cars, player, pedestrians and obstacles |
| PHYS-005 | P2 | OPEN | `scripts/world/junction_builder.gd:make_city_graph` shares opposing lane centerlines | Directional left-driving offsets and non-clipping turns |
| PHYS-006 | P2 | PARTIAL | `scripts/world/neighborhood.gd` raised world surfaces; geometry-specific tests insufficient | No z-fighting/falling at intersections, curbs, park |
| PHYS-007 | P2 | PARTIAL — NOT RUN | `9aa948d` queues restore to player physics tick with floor/overlap check and near-spawn fallback | Unsafe/corrupted saves recover to legal ground |
| PHYS-008 | P2 | OPEN | `scripts/npc/pedestrian_navigator.gd` uses direct global_position update | Establish ownership and collision-safe integration |
| PHYS-009 | P1 | PARTIAL — NOT RUN | Player previously collided vertically with vehicle roofs; now world-only mask with actor horizontal sweep at `b442124` | Parked-car contact, player release, roof fall and moving-car contact verified in Godot |
| PERF-PHYS-001 | P2 | OPEN | Pedestrian O(N²) nearby checks and repeated shape probes | PC 60 FPS, Android 30 FPS, 20 cars+30 NPCs (measured) |

## Historical regression failures requiring retest
- `traffic_spawner_test.gd`: isolated traffic throughput regression; simulation-only bypass was introduced.
- `pedestrian_collision_test.gd`: physics-synced body test fixture changed to deterministic segment check.
- `surface_player_test.gd`: generated road mesh was assigned explicit name.
All are **pending a fresh Godot 4.7.2 run** on the current branch. Older 36/36 JSON report is not sufficient to close them.

## Verification checklist
- [x] GitHub source tree and major physics scripts reviewed
- [x] Existing collision layer contract recorded
- [x] Existing regression history reconciled without assuming success
- [ ] Current-branch Godot import passes
- [ ] Full current-branch local regression passes
- [ ] Real player–NPC contact in play scene verified
- [ ] Two opposing NPCs and five-NPC crossing verified
- [ ] Vehicle vs car/player/pedestrian/building verified
- [ ] Frame-rate and Android profiling completed
- [ ] No P1 collisions remain

Never close bugs or check runtime boxes without actual passing evidence. Issue IDs here complement, not replace, preexisting `docs/audits/ISSUE_REGISTER.md`.

## Phase 2 player guard change (2026-11-06)
- Commit `af04f32`: player-side horizontal cast against pedestrian layer 8, leaving vertical collision mask 5 unchanged; added `tests/player_pedestrian_contact_test.gd` and runner registration.
- The regression runs 70 real physics frames into a stationary NPC, moves the NPC out of the way, and drops the player over an NPC to confirm actual-world grounding. A test failure cannot be hidden by the player passing through to the far side.
- **Verification status: NOT RUN**; no headless Godot executable in this environment. Do not mark PHYS-001 closed.

## Phase 2 vehicle contact and recovery (2026-11-06)
- `b442124`: player `collision_mask = 1`, `floor_snap_length = 0.24`; player query targets vehicle layer 4 and pedestrian layer 8. Both types block horizontal motion but neither serves as a floor. Structural tests and `tests/player_vehicle_contact_test.gd` updated/added. **NOT RUN**.
- `9aa948d`: saved player location is queued from input and validated on next physics frame with a world-only floor ray plus complete character-shape check against world, vehicles and pedestrians. Invalid saves/falls attempt deterministic nearby grounded spawn positions. `tests/player_safe_restore_test.gd` added; isolated test save path avoids overwriting real saves. **NOT RUN**.
- **Remaining:** Confirm controller actually moves, hits and releases obstacles. Test moving-car contacts and pedestrian overlaps at different frame rates. Add curb traversal/edge recovery checks. Do not close either P1 issue.

## Phase 2 expanded unsafe restore fixtures
- Commit `1b7f908` broadens safe-load coverage to vehicle and pedestrian occupied volumes, not just static buildings and unsupported coordinates.
- Current status remains **PARTIAL — NOT RUN** until Godot physics-frame verification passes.

## Screenshot follow-up — two or more NPCs visually overlapping
- Source observation: previous pedestrian movement only accepted/rejected a nominal route position; blocked agents did not sidestep, and spawn placement was not reserved against previously created pedestrians. NPCs can remain embedded or stacked if already spawned too close.
- Fix commit `f89584b`: search unoccupied spawn points, add 1.2m personal buffer and 0.72m hard capsule separation, check path geometry plus physics shapes at intervals, and try bounded lateral movement to avoid indefinite blocking.
- Regression commit `f4922dd`: strengthen the existing physics-frame NPC test to 360 frames and add `tests/pedestrian_crowd_avoidance_test.gd` for perpendicular crossing and opposing/head-on movement (420 frames each).
- Follow-up `068a7ee`: avoid statically typing custom test walkers as bare Node3D when accessing script-specific members.
- **Status: PARTIAL — NOT RUN.** GitHub code committed but no Godot 4.7.2 import, headless tests or visual screenshot comparison executed here. Do not close PHYS-002 until both automated tests and a busy crossing playtest pass.
