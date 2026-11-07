# Civic Chaos — Collision and Physics Audit
Date: 2026-11-06 · Static/source analysis; Godot runtime **NOT RUN**.

## Collision configuration observed
| Entity | Physics body | Layer | Mask | Evidence |
|---|---|---:|---:|---|
| Player | CharacterBody3D, capsule radius 0.35 height 1.8 at y=0.9 | 2 | 13 (layers 1,3,4) | `scenes/player/player_root.tscn:24–31` |
| Pedestrian | AnimatableBody3D, capsule radius 0.32 height 1.75 at y=0.87 | 8 | 3 (layers 1,2) | `scripts/npc/district_pedestrians.gd:25–39` |
| Vehicle | Node3D root with child StaticBody3D, box 1.6x1.2x3.0 at y=0.7 | 4 | 0 | `scenes/traffic/vehicle_agent.tscn:8–11,65–76` |
| Neighborhood buildings/roads/terrain | StaticBody3D with BoxShape3D | default 1 | default 1 | `scripts/world/neighborhood.gd:125–140` |
| Boundary walls | StaticBody3D with BoxShape3D | default 1 | default 1 | `scripts/world/neighborhood.gd:107–123` |
| Traffic signal | StaticBody3D | 1 | 0 | `scripts/world/street_furniture.gd:66–73` |
| Streetlights/trees/bins/benches | **Node3D root passed to StaticBody3D-only collider helper** | not valid as implemented | — | `scripts/world/street_furniture.gd:58–64,94–133` |

Layer bit values: world=1, player=2, vehicle=4, pedestrian=8. A mask is the set of layers a body scans; one-way collision settings and motion strategy must be verified in engine.

## Pairwise contact matrix
| Pair | Configuration / observed limitation | Assessment |
|---|---|---|
| Player–world | player mask includes 1; static world colliders exist | structurally configured; runtime unverified |
| Player–vehicle | player mask includes 4; vehicle child static collider layer 4 | configured; vehicle teleports along lane each tick, response unverified |
| Player–pedestrian | player mask includes 8; NPC mask includes 2 | configured; direct NPC position assignment can still produce contacts/overlap |
| NPC–NPC | NPC mask 3 excludes layer 8 | **no physics NPC–NPC blocking**; only approximate script proximity checks |
| NPC–vehicle | NPC mask 3 excludes layer 4; vehicles mask 0 | **no physics NPC–vehicle blocking** |
| Vehicle–vehicle | vehicle static body mask 0 | simulated car-following only; no physical response |
| Player–props | only traffic signals confirmed StaticBody3D; other props are Node3D | broken/invalid helper invocation |
| Player–ground edges | terrain and boundary colliders present | geometry and spawn/recovery playtest needed |

## Root causes and fixes
1. **BUG-001/P0:** Correct all furniture roots to `StaticBody3D` or create child `StaticBody3D` and attach shape to it. Add type-checked headless scene instantiation tests.
2. **BUG-002/P1:** Replace direct NPC `position = ...` with a movement/avoidance controller using a valid physics body strategy; avoid player feet/head overlap and initial spawn penetration; validate contact normals and `is_on_floor()` for the player.
3. **BUG-003/P1:** Vehicle agent currently moves the `Node3D` root directly. Integrate a deliberate collision/obstacle policy (swept shape/raycast, vehicle stop, contact response) and test against player/NPC/other cars. Do not change traffic determinism without a replay test.
4. **BUG-005/P2:** Remove redundant ground collider from main scene after proving terrain has no gaps; align road/sidewalk top surfaces. Avoid z-fighting and multiple near-coplanar floor contacts.
5. **BUG-006/P2:** Validate loaded positions against map limits, ground, and occupied collision space; recover to a safe spawn if invalid.

## Reproduction and acceptance
- Player walks into stationary and moving cars without passing through, becoming trapped, or riding a collider.
- NPCs start without overlap; player cannot stand on their heads during ordinary movement; NPCs avoid each other and vehicles.
- Collision shapes for all props exist and match visible geometry.
- Walk to every outer edge and test jumping, save/load near boundaries, and falling recovery.
- Run fixed-seed NPC+vehicle scenarios for several minutes; assert no intersections of body volumes and no stuck entities.
- Test with physics interpolation on/off and low FPS. Record actual engine logs.

## Verification status
Static code inspected. **Godot import NOT RUN; physics playtest NOT RUN; Android NOT RUN.** Existing `world_collision_test.gd` checks type and shape presence, not actual collision resolution; it may also expose BUG-001.
