# Civic Chaos — Next Physics Audit (Source-Level)
Date: 2026-11-06 | Audited branch: `fix/regression-nov05` | Base commit: `5ecb184`

## Audit boundaries
- Reviewed live traffic flow (`scripts/world/junction_scene.gd`; `scripts/traffic/{traffic_spawner,vehicle_agent,traffic_sensor,traffic_signal_controller,intersection_reservations}.gd`), city lane builder, player physics, NPC movement, safe restore, main scene, world colliders, and tests.
- **No code fixes in this audit.** No Godot engine / PC / Android execution by the auditing agent. GitHub Actions not run.
- **User-reported runtime baseline:** Godot 4.7.2 imported successfully at earlier commit `927fc8f`; 45 tests passed, 1 failed (`pedestrian_spawn_separation_test.gd` at deliberately stacked NPC recovery). A candidate fix was later pushed as `5ecb184`; no verified rerun of that head has been supplied.
- Classification: **Confirmed code path** means the mechanism is directly evidenced in source; **Runtime risk** means gameplay impact is plausible but not reproduced. Passing a unit test does not verify the integrated city.

## Priority findings

### PHYS-010 / P1 — All city-entry stop-line approaches resolve to red
**Confirmed code path; integrated traffic behavior still to be tested.**
- `scripts/world/junction_builder.gd:46-88` generates 80 directed city lanes, IDs beginning at 100.
- `scripts/world/junction_scene.gd:19-31` enables this graph and the expanded traffic spawner in the playable city.
- `scripts/traffic/traffic_spawner.gd:93-111` maps only lane IDs 1, 3, 5, 7 to N/E/S/W on route index 0; every expanded lane ID maps to the empty string.
- `scripts/traffic/traffic_signal_controller.gd:46-61` treats unknown approaches as red.
- **Impact:** expanded-city vehicles receive a virtual red-light observation on the first route segment near its end, regardless of displayed signal phase. This can create artificial permanent queues at perimeter-to-interior junctions.
- **Acceptance:** derive approach and stop lines from geometry/intersection metadata, not legacy lane IDs. At a known city intersection, correct green vehicles pass, red/amber stop with distance to line, and all approaches release when phase changes. Add executable expanded-city signal tests.

### PHYS-011 / P1 — Opposing traffic shares the same geometric centerline
**Confirmed geometry; head-on penetration/deadlock risk.**
- `scripts/world/junction_builder.gd:67-73` builds two opposite directions with identical geometric endpoints reversed.
- `scripts/traffic/vehicle_agent.gd:179-189` positions a 1.6 m wide collision body directly on those centerlines.
- `scripts/traffic/traffic_sensor.gd:9-23` only follows cars on the identical directed lane ID, so oncoming traffic is not handled by following logic.
- **Impact:** two-way traffic is scripted to use the same space; shape obstacle probes may stop opposing vehicles, but no correct left-side lane separation or passing route exists.
- **Acceptance:** implement left-side lane centerlines with a consistent junction offset and turn curves; verify two opposing cars complete without penetration, paralysis or sidewalks/buildings clipping at every graph edge.

### PHYS-012 / P1 — Vehicle obstacle probe excludes solid city geometry
**Confirmed missing collision mask category; runtime penetration risk.**
- `scenes/traffic/vehicle_agent.tscn:70-76` has a scripted moving StaticBody3D collider on vehicle layer 4, mask 0.
- `scripts/traffic/vehicle_agent.gd:112-156` probes mask `2 | 4 | 8` (player, vehicles, NPCs); world layer 1 (buildings, walls, signs, trees) is absent.
- `scripts/world/neighborhood.gd:126-141` and `scripts/world/street_furniture.gd:66-73,94-141` generate world static colliders on layer 1.
- **Impact:** gameplay cars can enter a world obstacle without the movement probe noticing it, unless lane geometry happens to avoid the obstacle.
- **Acceptance:** select a geometry-aware collision policy that ignores road/terrain *support surfaces* but blocks building/prop/wall volume. Use swept/interval queries at several speeds and curved corners. Never naïvely add world bit without filtering roads (that could freeze every car).

### PHYS-013 / P1 — Car spawn clearance checks only other car center distances
**Confirmed missing spawn coverage.**
- `scripts/traffic/traffic_spawner.gd:113-151` adds/configures each vehicle, then invokes `_spawn_occupied`.
- `scripts/traffic/traffic_spawner.gd:169-177` checks only other active cars by horizontal center distance; it does not inspect player, pedestrians, rotated car footprint, static props or world supports.
- **Impact:** no guarantee a spawned car is free of occupied actor or obstacle space. Current city spawns at perimeter, so incidence must be tested before asserting visible collisions.
- **Acceptance:** validate full oriented 1.6 x 1.2 x 3m collider footprint with physics-space queries plus deterministic spawn priority; attempt spawn next to player, NPC, another car, prop, and off-road, then assert rejection and no one-frame overlap.

### PHYS-014 / P1 — Crosswalk occupancy may remain held by blocked pedestrians
**Confirmed missing release condition.**
- `scripts/npc/district_pedestrians.gd:118-146` may acquire crossing occupancy before checking separation/player yielding; it releases only after progress >= +6.
- `scripts/npc/district_pedestrians.gd:522-541` reserves and occupies global named crossing zones.
- `scripts/traffic/intersection_reservations.gd:59-64` expires reservation *windows*, but does not release occupied zones; occupancy is explicitly released by its owner.
- **Impact:** an NPC that yields indefinitely or gets stuck mid-crossing can hold an occupied zone and suppress other crosswalk users; city-wide global names cannot represent multiple intersections.
- **Acceptance:** finite dwell timeout + explicit cancellation/recovery with physical occupancy validation, never blindly release while pedestrian remains in the conflict zone. Test blocked actor, player standing across path, expired reservation, and queued pedestrians.

### PHYS-015 / P1 — NPC recovery can teleport off route and snap back
**Confirmed movement design gap; visibly abrupt movement is a runtime risk.**
- `scripts/npc/district_pedestrians.gd:194-222` searches landing points 1.55–3.1 m away and assigns `walker.position` immediately, without verifying a traversable walkway/path between start and destination.
- `scripts/npc/district_pedestrians.gd:328-345` next builds intended destination from route progress plus clamped lateral offset; `wraps` is set whenever distance from actual position is >2m, and `_candidate_is_clear` skips path checks when `wraps=true` (`375-384`).
- **Impact:** a recovering NPC may jump to a safe-looking but off-route location, then skip intervening path checks when snapping toward its original route. This is separate from the previously reported failed forced-overlap test.
- **Acceptance:** reserve/reposition on reachable walkable support, then resume from an actual route projection; distinguish genuine loop wrap from displacement due to recovery. Assert maximum allowed per-frame distance (except explicit hidden respawns) and zero new NPC/player intersections over sustained play.

### PHYS-016 / P2 — Player fall recovery has no last-resort safe outcome
**Confirmed failure-mode gap.**
- `scripts/player/player_controller.gd:79-84` repeatedly tries `_recover_near_spawn` when y < -8; on total failure, only sets velocity to zero and returns. `125-135` tries seven fixed offsets.
- `scripts/player/player_controller.gd:139-176` requires a supported raycast hit and clear capsule.
- **Impact:** if every allowed spawn is occupied/invalid, player may remain permanently below map with no retry policy other than repeating the same seven checks.
- **Acceptance:** deterministic safe recovery anchor or explicit reset/menu fallback; force all candidate points occupied and prove user can recover or receive a clear recoverable state.

### PHYS-017 / P2 — NPC spawn probes lack world and vehicle clearance
**Confirmed spawn validation omission.**
- `scripts/npc/district_pedestrians.gd:62-85` calls `_spawn_is_clear` to select the slot.
- `scripts/npc/district_pedestrians.gd:294-309` checks only existing pedestrians and the player, not cars, buildings, street furniture, walkable surface or ground support.
- **Impact:** geometry changes, future increased NPC counts or shifted paths could place an NPC inside a prop/building or over unsupported ground despite safe inter-personal spacing.
- **Acceptance:** validate spawn occupancy against world/vehicle collider volumes and floor support in the playable Neighborhood, preserve nonblocking NPC design and deterministic placement.

### PHYS-018 / P2 — Deadlock recovery service not connected to playable traffic
**Confirmed missing integration.**
- `scripts/traffic/deadlock_detector.gd` and `scripts/traffic/deadlock_recovery.gd` implement isolated cycle detection/route proposals.
- `scripts/world/junction_scene.gd:19-45` only wires traffic spawner, signal controller, reservations, and simulation clock.
- `scripts/traffic/traffic_spawner.gd:62-91` does not feed wait edges into a live detector or call recovery proposals.
- **Impact:** recovery unit tests cannot prove that traffic jam cycles in-game are observed or resolved.
- **Acceptance:** wire real waits with stable IDs and resolve route proposals without violating occupied intersections; reproduce a 2–4 car gridlock and measure release.

### PHYS-019 / P2 — Traffic and pedestrian collision testing has no integrated stress coverage
**Confirmed test gap; performance risk remains unmeasured.**
- `tests/city_traffic_test.gd:11-45` builds/routs/spawns but does not advance city traffic through signal changes and actual obstruction with NPCs.
- `tests/vehicle_obstacle_test.gd:12-60` covers a single straight car/player obstacle.
- `tests/pedestrian_crowd_avoidance_test.gd` and `tests/pedestrian_spawn_separation_test.gd` check synthetic NPC encounters, but not busy, visually rendered city play.
- `scripts/npc/district_pedestrians.gd:400-420,466-501` iterates nearby NPCs and samples physics shapes per movement. Cost grows with population/step size.
- **Acceptance:** seeded 5-minute playable-scene simulation with at least 20 cars + 30 pedestrians; measure min separation, out-of-bounds, stuck duration, car-world intersection, frame time, and repeat after toggling physics interpolation. PC/Android performance requires real devices.

## Recommended sequence
1. **First:** PHYS-010 — restore correct expanded-city signal behavior. Write a failing city-signal regression before changing code. Do not merely bypass red lights.
2. **Second:** PHYS-011 + PHYS-012 — separated lanes and world obstacle policy together; validate two-way approaches, turns, static props, and player/cars.
3. **Third:** PHYS-013 + PHYS-014 — occupancy and crossing lifecycle.
4. **Fourth:** PHYS-015 + PHYS-017 — NPC spawn and recovery continuity, preserving soft person-person contact as requested.
5. **Then:** PHYS-016, PHYS-018, PHYS-019 — edge recovery, integrated deadlocks, long-duration performance.

## Evidence/closure rules
- Do not mark an issue fixed from source review alone or by asserting that current tests pass after a new code change.
- Keep PHYS-002 (forced NPC-overlap recovery) **open** until the head `5ecb184` is tested locally; the user's last reported full suite at `927fc8f` was 45 pass / 1 fail.
- Run engine checks locally only. Do **not** start GitHub Actions.
