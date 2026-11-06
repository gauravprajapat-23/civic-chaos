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
| Player | 2 | 5 | Must stay world+vehicle for vertical resolution; horizontal pedestrian avoidance uses a separate query with mask 8 |
| Pedestrian | 8 | 15 | Existing source mask; actual motion still controlled by script |
| Vehicle collider | 4 | 0 | Queryable solid to player; motion handled by route agent + explicit queries |
| World generated block | 1 | 1 | Default Godot StaticBody3D values |
| Furniture | 1 | 0 | World obstacle queried by actors |
| Vehicle probe | n/a | 14 (2+4+8) | Explicit `PhysicsShapeQueryParameters3D` mask |
| Pedestrian probe | n/a | 15 (1+2+4+8) | Explicit `PhysicsShapeQueryParameters3D` mask |
| Player horizontal probe (Phase 2) | n/a | 8 | Explicit query only, no standing on NPC heads |

### Design restrictions
- Never add pedestrian bit 8 to the player's global collision mask as a shortcut: it permits pedestrian floor normals.
- Collision masks are not substitutes for physically safe movement.
- Physics queries must exclude their owner RID.
- Sensors/triggers should not collide as solid geometry.
- Keep simulated traffic tests separate from gameplay collision-physics tests; do not disable active gameplay obstacle checks to pass a throughput test.
- Every layer change must update scripts, scenes, query masks and actual-frame regression tests together.
