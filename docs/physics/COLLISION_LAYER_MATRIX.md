# Civic Chaos — Collision Layer Contract
Updated: 2026-11-06. This records observed bit masks, not a completed migration.

| Layer index | Decimal bit | Category | Usage |
|---|---:|---|---|
| 1 | 1 | World | Static ground, roads, sidewalks, buildings, furniture |
| 2 | 2 | Player | CharacterBody3D |
| 3 | 4 | Vehicles | StaticBody3D child on each scripted Node3D car |
| 4 | 8 | Pedestrians | AnimatableBody3D |
| 5 | 16 | Interactive | **Reserved / not adopted** |
| 6 | 32 | Sensors | **Reserved / not adopted** |

| Entity | collision_layer | collision_mask | Note |
|---|---:|---:|---|
| Player | 2 | 1 | Grounding and physics slide against world only; actor collision uses separate horizontal sweep mask 12 |
| Pedestrian | 8 | 15 | Existing source mask; actual motion still controlled by script |
| Vehicle collider | 4 | 0 | Queryable solid to player; motion handled by route agent + explicit queries |
| World generated block | 1 | 1 | Default Godot StaticBody3D values |
| Furniture | 1 | 0 | World obstacle queried by actors |
| Vehicle probe | n/a | 14 (2+4+8) | Explicit `PhysicsShapeQueryParameters3D` mask |
| Pedestrian probe | n/a | 15 (1+2+4+8) | Explicit `PhysicsShapeQueryParameters3D` mask |
| Player horizontal probe (Phase 2) | n/a | 12 (4+8) | Query against vehicles and NPCs, no standing on actor roofs |
| Player safe restore occupancy probe (Phase 2) | n/a | 13 (1+4+8) | Reject blocked save/spawn placements with world-supported raycast |

### Design restrictions
- Never add pedestrian bit 8 **or vehicle bit 4** to the player's solid collision mask as a shortcut: it permits actor roofs to become floors.
- Collision masks are not substitutes for physically safe movement.
- Physics queries must exclude their owner RID.
- Sensors/triggers should not collide as solid geometry.
- Keep simulated traffic tests separate from gameplay collision-physics tests; do not disable active gameplay obstacle checks to pass a throughput test.
- Every layer change must update scripts, scenes, query masks and actual-frame regression tests together.

## Updated soft-agent contract (screenshot fix, 2026-11-06)
The earlier observed-contract rows above are a **historical snapshot**. The **current** contract on `fix/regression-nov05` is:

| Actor / query | Layer | Mask | Interaction |
|---|---:|---:|---|
| Player `CharacterBody3D` | 2 | 1 | Solid world only |
| Player horizontal query | n/a | 4 | Stop at vehicles, **not** NPCs |
| NPC `AnimatableBody3D` | 8 | 0 | Non-blocking traffic-detectable sensor; manual navigation |
| NPC obstacle shape query | n/a | 5 | World solids and cars; ground/road/sidewalk surface contacts filtered |
| Vehicle detection query | n/a | 14 | Still sees player, cars and NPC sensors |

Avoidance and local separation are scripted in `scripts/npc/district_pedestrians.gd`; no hard NPC–NPC or NPC–player physics contact is intended. Do not restore old actor collision masks without revisiting tests and the user's explicit design request.
