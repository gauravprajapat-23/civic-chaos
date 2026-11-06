# Civic Chaos — Prioritized Issue Register
Date: 2026-11-06 · Branch: `fix/regression-nov05`

**Evidence status:** "Confirmed" means source-level mismatch observed; it does not mean reproduced in Godot. "Risk" requires a runtime test. All Godot runtime verification is **NOT RUN**.

| ID | Priority | Status | System | Evidence (file:lines) | Root cause / impact | Acceptance |
|---|---|---|---|---|---|---|
| BUG-001 | P0 | Fix committed; runtime verification pending | Street props | `scripts/world/street_furniture.gd:58–64,94–133` | All street prop roots converted to StaticBody3D; regression expanded; local Godot run still required | Godot imports; every prop has a valid physics collider |
| BUG-002 | P1 | Partial fix committed; runtime verification pending | NPC/player | `scripts/npc/district_pedestrians.gd:77–125,146–162` | direct movement and incomplete avoidance, NPCs can overlap/stack | live player/NPC contact tests pass |
| BUG-003 | P1 | Confirmed design gap | Vehicle physics | `scripts/traffic/vehicle_agent.gd:125–135`, `scenes/traffic/vehicle_agent.tscn:65–76` | teleport-style lane positioning, no swept physical obstacle response | vehicle/player/NPC contact tests pass |
| BUG-004 | P2 | Confirmed | Map/traffic | `scripts/world/junction_builder.gd:8–33`, `scripts/world/neighborhood.gd:75–99` | visual streets not represented in traffic graph | every driveable road connected and routed |
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
