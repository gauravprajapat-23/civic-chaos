# Civic Chaos — Physics Audit and Baseline
Date: 2026-11-06 | branch: fix/regression-nov05 | inspected head: `75df6ee`
Evidence classification: **source-confirmed**, **reported gameplay**, **runtime-unverified**.

## Scope and architecture
Reviewed the real scene tree, player controller, pedestrian agent generator, lane graph, vehicle agent and spawner, neighborhood collision generation, existing audit documents, and relevant executable tests. Godot 4.7.2 is **not installed in this execution environment**; no import, physics playtest or Android run has been performed here. Existing regression reports must not be treated as verification of this head.

```mermaid
flowchart LR
  Input[Keyboard/touch input] --> Player[CharacterBody3D player]
  Player --> World[StaticBody3D terrain/roads/buildings]
  Player --> Cars[Vehicle StaticBody3D child]
  Player -. horizontal query needed .-> Walkers[AnimatableBody3D pedestrians]
  Walkers --> Avoid[Script proximity + shape queries]
  Planner[Lane graph / traffic spawner] --> CarAgent[Node3D route follower]
  CarAgent --> Cars
  CarAgent --> Probes[Sub-metre obstacle shape probes]
  Signals[Traffic signal / crossing reservations] --> Planner
  Signals --> Walkers
```

## Source-verified collision inventory
| Body | Shape and position | Layer bit | Mask bit | Evidence |
|---|---|---:|---:|---|
| Player CharacterBody3D | Capsule radius 0.35, height 1.8, collider y=0.9 | 2 | 5 (world+cars) | `scenes/player/player_root.tscn` |
| NPC AnimatableBody3D | Capsule radius 0.32, height 1.75, collider y=0.87 | 8 | 15 (world+player+cars+NPCs) | `scripts/npc/district_pedestrians.gd` |
| Vehicle child StaticBody3D | Box 1.6 x 1.2 x 3.0, collider y=0.7 | 4 | 0 (solid only for querying bodies) | `scenes/traffic/vehicle_agent.tscn` |
| Terrain, roads, sidewalks, buildings | Generated StaticBody3D/BoxShape3D | 1 (default) | 1 (default) | `scripts/world/neighborhood.gd:_block` |
| Boundary walls | StaticBody3D/BoxShape3D | 1 (default) | 1 (default) | `scripts/world/neighborhood.gd:_boundary_wall` |
| Furniture | StaticBody3D, shape assertions added previously | 1 | 0 | `scripts/world/street_furniture.gd`, `tests/world_collision_test.gd` |

## Movement and contact gaps
1. **PHYS-001 / P1:** The player has no pedestrian layer in its solid mask (correctly avoids NPCs becoming floors), and previously had no player-side horizontal avoidance. **Phase 2 candidate commit `af04f32`** now adds collision-layer-8 horizontal shape sweep while leaving vertical floor resolution world-only. Runtime behavior is **NOT RUN**.
2. **PHYS-002 / P1:** `district_pedestrians.gd` moves `AnimatableBody3D.position` directly and uses O(N²) proximity, a destination intersection test and basic path geometry. When blocked it waits; it does not attempt sidesteps or route recovery. Initial spawn has no general spatial rejection loop.
3. **PHYS-003 / P1:** `vehicle_agent.gd` advances a Node3D along centerlines and samples a child StaticBody shape at approximately 0.4 m intervals. Other cars, player and NPCs are in query mask, but this is not swept continuous physics or a dynamic contact response. `traffic_spawner.gd` bypasses these checks in isolated graph simulation mode; gameplay mode remains enabled.
4. **PHYS-004 / P1:** `traffic_spawner.gd:_spawn_occupied` compares horizontal center distance to existing cars only. It does not test player, pedestrian, props or full oriented car footprints.
5. **PHYS-005 / P2:** `junction_builder.gd:make_city_graph` creates 80 directed segments using the same centerline in opposite directions. This is not a left-driving lane layout; no curved intersection connectors.
6. **PHYS-006 / P2:** Surface heights differ across road arms and sidewalk; source shows terrain and raised roads. Need dynamic grounding/curb tests, not just height assertions.
7. **PHYS-007 / P2:** `game_lifecycle.gd:load_player` assigns saved position without validating floor support or obstructed space.
8. **PHYS-008 / P2:** `scripts/npc/pedestrian_navigator.gd` directly sets `global_position` and is a separate waypoint abstraction; verify integration before changing it.
9. **PERF-PHYS-001 / P2:** O(N²) pedestrian candidate checks and car probes scale with traffic count; benchmark before spatial-grid optimization.

## Contact graph
Player–world: physical; player–car: physical; player–NPC: no solid contact by mask, horizontal guard required; NPC–NPC: scripted clearance and query; NPC–car: scripted clearance and query; car–car: fixed-step following and sampled shape probe, not dynamic rigid-body response.

## Known baseline caveat
`build/regression-report.json` checked into the repository contains **36 passing test entries** from an earlier run, with successful import and negative-path checks. The more recent `docs/audits/ISSUE_REGISTER.md` describes a later user run with **38/41 passing** and failures in `traffic_spawner_test.gd`, `pedestrian_collision_test.gd` and `surface_player_test.gd`. Source changes followed, but no retest of those latest changes is established. Treat **current full-suite outcome = NOT RUN / UNVERIFIED**.

## Next action
After a small Phase 2 player-side horizontal avoidance patch, run `tests/player_pedestrian_contact_test.gd`, full local regression, then inspect actual collisions at 30/60/120 FPS. Do not mark any issue completed merely from a static source inspection.
