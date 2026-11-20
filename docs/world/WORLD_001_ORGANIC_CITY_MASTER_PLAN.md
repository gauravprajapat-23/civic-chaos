# WORLD-001 — Nagripur Organic City Map & Believable Streets

**Plan status:** approved for staged implementation, **no world geometry changed by this document**.
**Baseline:** main at `10849439dc2b2dd467e6b253774153d5898fa621`; Godot 4.7.2.
**Implementation branch:** `feature/world-001-organic-city`.
**Constraints:** keep existing 3-mission Market Chowk playable and saves compatible, do not add a second world architecture, no manual GitHub Actions.

## Why the current city looks like a grid

This is a source-confirmed architectural constraint, not just artwork:
- `CivicCityRoadLayout.GRID_COORDINATES = [-120,-46,0,46,120]` supplies five axes per dimension (nominal 25-node rectilinear network).
- `CivicJunctionBuilder.make_city_graph()` generates lane connections from this matrix. New streets can't be decorative only; traffic must use exactly the same geometry.
- `CivicNeighborhood.rebuild()` draws continuous cardinal roads and rectangular blocks using the shared grid coordinates; procedural buildings repeat identical boxes.
- `CivicCityMap` draws straight roads directly from those coordinates and uses `EXTENT_M = 120`, rather than traversing the real graph. The small map and full map will become incorrect if roads change without updating them.
- `junction_scene.gd` creates one central traffic signal controller, plus `CivicOuterTrafficLights` for outer junctions. Traffic rules are currently tuned for this geometry. **Do not remove every signal or globally set green**; instead classify junctions and safely distinguish signalized, priority and uncontrolled local intersections.
- Vehicle spawning, service vans, stop-line priority, pedestrian reservations, scene snapshots, world checkpointing and mission targets all depend on existing world coordinates or lane IDs.

## Design goal

A believable **fictional Indian-inspired Nagripur district**: imperfect, walkable, recognizable, visually rich, and physically traversable. Not a GTA-scale world, an open-world streaming replacement or photorealism. Make roads follow purpose and neighborhoods, not a 5 × 5 spreadsheet.

### Proposed reference map (top = north; schematic, not final mesh)

```text
  NORTH / PARK & SCHOOL EDGE
         [Park Gate]---(quiet school lane)----[School Front]
             |         park footpath                |
             |                                   yield T
 [Old Bus Stop]--(Market Road bend)--[Market Chowk]----[Clinic Lane]
      |                 *                           |         |
  narrow one-way    central landmark            priority T   |
      |                 |                           |         |
 [Residential]---[Temple Turn]====[Main Bazaar Road]---[Service Yard]
         \    curving local lane     /           |
          [Pond Walk]----[Parking Bay]------[Municipal Help Desk]
                    SOUTH / LOCAL SHOPS
```

**Legend:** `*` = preserve legacy central four-arm signal and existing mission anchors; `====` = major collector; smaller roads can be T-junctions, curves, asymmetric and one-way. Named sites are world landmarks, **not new playable missions**.

### Coordinate and gameplay contract

- **WORLD-001A (pilot):** replace one outer road block *within the original roughly ±120 m district* with a curved, non-grid collector + connecting T-junction; retain the central graph and all mission anchors at their original positions. Use deterministic node/edge data for physical road mesh and lane splines.
- **WORLD-001B (expanded district, later):** only after WORLD-001A regression, increase playable bounds gradually (target concept ~360–450 m wide, not an immediate parameter change). Shift map extents using derived bounds; add landmark zones/LOD/culling based on measured device budgets. Do **not** relocate active mission entities silently.
- **Preserve** live Market Chowk junction at (0,0,0), player spawn near (5.7,0,-8), sidewalk/report interactions, wrong-way/tow route, parking and market cleanup anchors, Free Roam activity markers. New buildings/roads must be placed around these locked safety corridors.
- **Stable IDs:** never renumber old lane IDs or intersection IDs in saved traffic snapshots until an explicit versioned migration exists. New segments get a reserved ID range and deterministic ordering. Legacy saves restore to the legacy topology or migrate with validated lane/position mapping; never spawn a restored car in solid geometry.
- **Single authority:** road geometry, navigation lane centerlines, pedestrian footpaths, stop lines, vehicle spawn placement, road markings, scene map and mini-map derive from one read-only `CityNetworkDefinition` (new, versioned data-driven resource or GDScript fixture), not separately-coded line grids.

## Road hierarchy and intersection types

| Road type | Visual/mechanical role | Traffic rules |
|---|---|---|
| Primary collector | 8–10 m asphalt, two-direction traffic, bus stop bays, zebra crossings | Signalized only at major high-conflict intersections; explicit stop lines and amber/all-red clearance |
| Market street | 6–8 m, slower speed, dense shops, loading bays | Central Market Chowk signal retained; elsewhere priority with marked crossings and reduced speed |
| Residential street | 5–6 m, curves, parked vehicles, sidewalk breaks | Give-way / stop at T-junctions, no automatic traffic light |
| Service alley | ~3.5–4.5 m, limited access and occasional one-way | Entry rules, slow approach, controlled crossing; no duplicate full-sized car spawns |
| Walking route/park lane | Footpath, park and shop arcades | Pedestrians only; physical barriers to cars without cutting emergency access |

### Signal modernization (must be independent of map visuals)

1. Categorize each junction as `SIGNALIZED`, `PRIORITY`, `ALL_WAY_STOP`, `PEDESTRIAN_ONLY`, or `NO_INTERSECTION`.
2. Signalized junctions have distinct deterministic controllers and crossing reservations; **not every road node gets a light**.
3. Priority junctions implement approach yield/stop and gap acceptance with occupancy checks. Never implement by `return true` or permanently green lights. Ensure two conflicting approaches cannot be granted at once.
4. Keep central four-way signal/one-approach mode unchanged until an explicit regression proves a replacement safe.
5. Preserve red/yellow/all-red behavior, downstream spillback, emergency responder fail-closed permissions, and safe waiting if route context cannot resolve junction identity.
6. NPC walkers use dedicated crosswalk/crossing eligibility and do not wait for a nonexistent traffic-signal controller.

## Build system design

**Proposed** new files (final names subject to review):
- `scripts/world/city_network_definition.gd` — immutable graph nodes, typed road segments and intersections, coordinate bounds, stable IDs, deterministic seed.
- `scripts/world/city_road_mesh_builder.gd` — asphalt/curbs/markings using actual centerlines, no crossing overlaps or invisible collision slabs.
- `scripts/world/city_parcel_generator.gd` — plot polygons set back from carriageways, varied-but-seeded storefronts, laneside props, park/parking terrain.
- `scripts/world/city_landmark_registry.gd` — canonical landmark IDs and actual world positions for HUD/map/missions.
- `scripts/traffic/junction_priority_rules.gd` — yield/stop/occupancy for non-signalized nodes; existing signal logic stays authoritative for signalized nodes.
- Update `junction_builder.gd` through an **adapter** while retaining `make_test_graph()`, legacy city fixtures and regression contracts.
- Update `civic_city_map.gd` to draw canonical road polylines and compute bounds from network; no fabricated roads or hard-coded fallback grid.

**Ownership:** World worker: `scripts/world/**`, `scenes/world/**`, new `tests/world_*`; Traffic worker: `scripts/traffic/**`, new traffic tests; UI worker: `scripts/ui/**`, map tests; Master only: `scripts/core/main.gd`, `scenes/core/main.tscn`, checkpoint version negotiation. No worker edits other domains.

## Phased work and acceptance gates

### WORLD-001A — Source-of-truth map data (first coding milestone, P0)
- Add versioned network definition with named nodes, edge geometry, widths, roles, directionality, typed junctions, stable lane-id allocation and no overlapping endpoints.
- Represent the entire **current** grid faithfully first, using a compatibility adapter. New data must produce the old lane routes and the same physical/map coordinates before organic alteration.
- Add tests for connectivity, legal turns, lane/mesh centerline tolerance, locked mission anchors, deterministic IDs, no duplicate nodes and no out-of-world drivable segments.
- Gate: old traffic/mission/save and map regressions PASS with no geometry change; signed-off graph diff. No visual enhancement claims.

### WORLD-001B — First organic block (P0)
- Replace one **outer non-mission** area with a winding two-way road + T-junction, one short local lane and a pedestrian-only park connector; use spline tessellation for surfaces and matching lane geometry.
- Keep first iteration within existing playable boundary and legacy central signal. Preserve vehicle swept collision clearance, pedestrian crossing, blocking and spawn rules.
- Gate: actual game screenshot/walkthrough, 2-way legal routing, no floating vehicles, no traffic starvation, no vehicle clipping, new junction driveable without 4-way signal, map correctly follows both lanes.

### WORLD-001C — Road priority and signals (P0)
- Implement typed junction right-of-way under Traffic ownership: major signalized crossings, yield/stop on residential/T, pedestrian crossing reservations, no traffic lights at dead ends/local entrances.
- Gate: conflicts mutually excluded, queue releases, van lawful traversal and fail-closed response, plus red/green/spillback regressions; no fake green for ambiguous connector.

### WORLD-001D — Architecture and neighborhood identity (P1)
- Replace repetitive full-height boxes with varied low-poly façades, storefronts, awnings, street furniture, compound walls, balconies, shop signs, park edges, parking bays, bus stop and footpath height/curb consistency.
- Use a deterministic parcel/road setback process and retain a usable player walking path (minimum clearance).
- Gate: no building collision intersecting active lanes, playable entrances, no duplicate geometry and bounded object count; day/night lighting remains visible.

### WORLD-001E — Full map/minimap/landmarks (P1)
- Render from network graph, not `GRID_COORDINATES`; selectable real destinations, discoverable buildings, true route distances, consistent map bearings, player indicator and GPS mission target.
- Gate: identical roads on the mesh, map and vehicle routes; safe-area hud constraints remain respected, no mission/accepted CALLS reset after map changes; 320/360/740 viewport tests.

### WORLD-001F — Save compatibility + device performance + rollout (P0)
- Stable network schema `version` in checkpoint migration; reproduce save -> switch/map upgrade -> load, reject invalid migration without partial world mutation.
- Profile LOD, static geometry batches, collision count, active AI and draw calls on Windows and representative Android device; measure rather than guessing target FPS.
- Gate: all relevant `GATE-01` and new regressions PASS, full campaign and Free Roam continue, user playtest and Android debug APK accepted. Only then merge Master integrated result.

## Risk table

| Risk | Prevention |
|---|---|
| Cars drive off the road | derive traffic lane splines and road mesh from same edge definition; geometry-accuracy regression |
| Uncontrolled T-junction causes crash/deadlock | Traffic-owned occupancy/yield arbitration, seeded two-vehicle conflict tests, fail closed |
| Signals everywhere | classification per junction, central Market Chowk exception; no pretend traffic light on a mid-block street |
| Mission markers become unreachable | lock the original mission corridor in pilot, validate physical distance/accessibility and road routes |
| Old saves restore wrong lane IDs | preserve legacy IDs or versioned transactional migration with backups, reject invalid mappings |
| HUD shows roads that don't exist | use actual network edges for mini/full map and route overlay; map and mesh parity test |
| Android becomes slow | one-block staging, geometry batching/LOD, measured traffic and render budgets before expanding |
| Worker conflict | strict file ownership, three integration handoffs, Master-only edits to shared scenes/core |

## Implementation checkpoint — WORLD-001B organic pilot (2026-11-20)

- **Source committed / native Godot verification pending:** One curved, two-direction west-perimeter road pilot, from (-120,-120) to (-120,-46), using `CivicOrganicRoadGeometry` as a shared sampled centerline. Existing lane IDs 102/103, endpoint connectivity and speed limit remain unchanged.
- `CivicCityNetworkDefinition.roads()` now marks the pilot and exposes its true centerline. `CivicJunctionBuilder.make_city_graph()` follows the sampled curve in both travel directions.
- `CivicNeighborhood` replaces the old straight west-perimeter segment with a curved asphalt ribbon with a trimesh collision body. The remainder of the perimeter street remains a straight legacy road, including the junction cap.
- `tests/world_001b_organic_pilot_test.gd` checks the pilot's geometry/traffic/parity contract, existing T-node and visual marker.
- **T-junction pilot:** The curved road already terminates at an **existing physical three-arm perimeter junction** (legacy node `0:1`, x=-120/z=-46). The canonical network now identifies it as `junction_form = "t"`; the world adds a visible marker and retains its existing safe outer priority controller. No unsafe replacement or new stop-phase grant is introduced.
- **Not yet implemented:** New *additional* drivable T-junction/side street. Splitting a currently saved lane at a new T-node would invalidate legacy checkpoint distances and requires new traffic priority/reservation rules (WORLD-001C). Do not attach a drivable branch until lane-ID migration + safe priority arbitration exists. A pedestrian branch may be safely added later, but this pilot does not pretend it is a new car road.
- **Known planned follow-up:** The UI map still plots the legacy straight grid (WORLD-001E), so do not claim visual map parity yet. This is a pilot for the *3D world and vehicle graph only*.
- **No engine tests executed by connector.** Require strict Godot 4.7.2 import and both WORLD-001A/B focused tests plus existing traffic, physics, save and map regressions before preview merge. Keep PR draft until native acceptance.

## Implementation checkpoint — WORLD-001C selective junction pilot (2026-11-20)

- **Source staged, Windows/Android testing NOT RUN:** One explicitly classified T-junction at legacy node `0:1` (x=-120, z=-46) now uses `priority_t` give-way behavior rather than a 4-way green clock. All other outer junctions retain the existing deterministic signal schedule, and the central Market Chowk signal is untouched.
- New `scripts/traffic/junction_priority_rules.gd` prioritizes through traffic over the side road, resolves same-priority arrivals using stop-line distance / stable lane-ID / checkpoint-fleet order, and never generates permission for an unknown node. It stores no mutable priority state.
- `scripts/traffic/outer_intersection_priority.gd` retains the existing physical committed-zone occupancy checks and downstream-exit spillback checks before evaluating give-way permission. The live spawner still performs pedestrian collision checks on the same T-node and records `junction_yield` diagnostics.
- `scripts/traffic/outer_traffic_lights.gd` omits signal heads on the T-node; the existing in-world sign reads `GIVE WAY`. This is **not** a global green-light shortcut.
- `tests/world_001c_priority_junction_test.gd` checks explicit node selection, safe conflicting approaches, bounded deterministic decisions across ticks, committed vehicle, downstream obstruction, other timed signals, physical pedestrian blocking/release, and revised signal-head count.
- **Scope:** One pilot, not all city intersections. Multi-node signal removal, new drivable T-branches, and checkpoint migration remain later tasks. WORLD-001E still needs honest curved-road display on MAP/minimap.
- **Acceptance gate:** import + native WORLD-001A/B/C, existing outer priority, stop-line, one-green, central spillback, CALLS permission, saved-world tests and real manual driving + pedestrian/collision. Do not merge PR #88 before evidence. No manual GitHub Actions.

## First PR scope

**Start only WORLD-001A**: canonical road-network schema + compatibility fixture + tests. No central traffic signal replacement, no existing mission relocation, no new giant map and no rewriting `scripts/core/main.gd`. Implement organic roads in later PRs **after** the architecture and regression contract pass.
