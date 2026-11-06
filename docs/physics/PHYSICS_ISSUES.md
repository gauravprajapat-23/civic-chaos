# Civic Chaos — Physics Issue Register
Date: 2026-11-06 | Working branch: `fix/regression-nov05`
Status wording: OPEN = acceptance not proven; PARTIAL = code exists, real contacts not fully verified.

| ID | Priority | Status | Root cause and source | Exit criteria |
|---|---|---|---|---|
| PHYS-001 | P1 | OPEN | Player mask 5 excludes NPCs; no explicit horizontal contact guard in `scripts/player/player_controller.gd` | Player stops/slides around NPC without treating head as floor; physics-frame tests pass |
| PHYS-002 | P1 | PARTIAL | `scripts/npc/district_pedestrians.gd` direct Animatable position and proximity-only stall | Opposing, crossing and multi-NPC groups pass with no overlap or deadlock |
| PHYS-003 | P1 | PARTIAL | `scripts/traffic/vehicle_agent.gd` sampled Node3D movement, static collider child | Vehicle collisions prevented at varied speeds/turns; no tunneling |
| PHYS-004 | P1 | OPEN | `scripts/traffic/traffic_spawner.gd:_spawn_occupied` tests cars only by center distance | Reject full-volume overlapping cars, player, pedestrians and obstacles |
| PHYS-005 | P2 | OPEN | `scripts/world/junction_builder.gd:make_city_graph` shares opposing lane centerlines | Directional left-driving offsets and non-clipping turns |
| PHYS-006 | P2 | PARTIAL | `scripts/world/neighborhood.gd` raised world surfaces; geometry-specific tests insufficient | No z-fighting/falling at intersections, curbs, park |
| PHYS-007 | P2 | OPEN | `scripts/core/game_lifecycle.gd:load_player` unvalidated saved transform | Unsafe/corrupted saves recover to legal ground |
| PHYS-008 | P2 | OPEN | `scripts/npc/pedestrian_navigator.gd` uses direct global_position update | Establish ownership and collision-safe integration |
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
