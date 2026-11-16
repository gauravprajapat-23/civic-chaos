# CAR-ART-05 — Drivers, Cockpit & Vehicle Design Audit

**Date:** 2026-11-16  
**Repository:** `gauravprajapat-23/civic-chaos`  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** First code slice committed; Godot 4.7.2 and Android visual/performance verification pending.

## Audit findings: what the existing car actually had

Source inspected: `scenes/traffic/vehicle_agent.tscn`, `scripts/traffic/vehicle_visuals.gd`, `scripts/traffic/vehicle_agent.gd`, `tests/vehicle_visuals_test.gd`, `tests/car_art_04bc_visual_test.gd`, `tests/car_art_04d_materials_test.gd`, and `tests/vehicle_scene_contract_test.gd`.

1. **Confirmed: no driver.** The sedan scene includes paint, wheels, tapered cabin, mirrors, windows, lamps, bumpers and cosmetic detailing, but no occupant, seat, steering wheel or dashboard.
2. **Confirmed: an opaque cabin hid any possible interior.** The cabin was generated as a full closed six-sided paint-colored tapered mesh, while the car windows were explicitly opaque. Simply adding an occupant without changing this structure would not make the driver visible.
3. **Confirmed: simplistic silhouette.** The car already has basic hood/trunk, wheel hubs, rims, bodywork, trim and brake-light material. Its visual identity is more developed than a placeholder but the windows/interior did not read as an occupied vehicle.
4. **Gameplay boundary: fixed physics.** The authoritative `CollisionBody/CollisionShape3D` remains `BoxShape3D(1.6, 1.2, 3.0)` on collision layer 4. Traffic uses deterministic spline-following and independent collision/people sweeps. Car-art work must not change this scene contract.
5. **Android-performance trade-off.** Earlier CAR-ART-04D deliberately used opaque windows to avoid transparency cost. Showing real occupants through tinted windows requires a measured compromise in overdraw and mesh/material counts. Without a device capture, **do not claim 60 FPS or a performance improvement**.

## CAR-ART-05A — First functional visual slice (source implemented)

- [x] Add low-poly right-hand driver: geometry for torso, neck, head, dark hair and arms inside the cabin.
- [x] Add visible front seats/headrests, dashboard, right-side steering wheel and window pillars.
- [x] Convert cabin shell/window glass from opaque to restrained dark tinted alpha blending, so actual 3D driver can be seen rather than painting a fake driver silhouette on a window.
- [x] Position driver's head **below** roof and keep right-hand steering correct for Indian left-side traffic.
- [x] Preserve all original detailed car parts (headlights, mirrors, bumpers, plate, trim, paint variants, wheel hubs, brake cues).
- [x] Add `tests/car_art_05_driver_cabin_test.gd`; update CAR-ART-04D glass assertion for the intentional transparency change.
- [ ] Run Godot import and all focused art + vehicle-physics tests.
- [ ] Inspect car from front, right-side, left-side, back and elevated camera angles in a running Godot scene. Verify head is actually visible rather than depth-sorted behind full cabin transparency.
- [ ] Profile 8, 12 and 20 simultaneous traffic vehicles on a real Android test device. If transparency overloads the GPU, replace it with optimized opaque cutaway windows or a lower-detail impostor; do **not** silently hide drivers.

## Remaining design roadmap

| ID | Priority | Description | Acceptance | Status |
|---|---|---|---|---|
| **CAR-ART-05B** | P1 | Refine cabin shape, glass blending and occlusion | Driver visible in front/side views; no see-through roof, transparency sorting or head clipping | SOURCE IMPLEMENTED — PC/Android VISUAL QA PENDING |
| **CAR-ART-05C** | P2 | Refine low-poly wheel faces, door lines/handles, grille surround and rear tail silhouette | 3D screenshots with intact 1.6×1.2×3 m collision and no decorative colliders | SOURCE IMPLEMENTED — GODOT/ANDROID VISUAL QA PENDING |
| **CAR-ART-05D** | P2 | Deterministic driver clothing, hair/skin tones, upholstery and rim finish from saved first route lane | Same saved route restores same visual driver, no state-schema changes | SOURCE IMPLEMENTED — GODOT/ANDROID QA PENDING |
| **CAR-ART-05E** | P2 | Batch 20 wheel spokes into one MultiMesh group per car, keep six glass panes, implement near/mid/far camera LOD with hysteresis | Godot regression, visual reversibility and measured FPS/draw calls at 8/12/20 cars on Android | SOURCE IMPLEMENTED — GODOT/ANDROID QA PENDING |
| **CAR-ART-05F** | P1 | Recess cage-like roof bars, enlarge readable side mirrors, animate visible tire/steering wheel and tow-convoy wheels | No new physics, frozen cars have stationary wheels, tow obeys signals, image/gameplay acceptance | SOURCE IMPLEMENTED — GAMEPLAY & ANDROID VERIFICATION PENDING |
| **CAR-ART-05G** | P1 | Full QA/regression + debug APK | Godot import/test pass, Android renders true occupants, collisions/traffic/checkpoints unchanged | OPEN |

## Required PowerShell verification

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
$branch = "fix/aud-001-game024-gate-hardening"

git -c remote.origin.fetch= fetch --no-tags origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Update failed" }

& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

foreach ($test in @(
    "car_art_05_driver_cabin_test.gd",
    "car_art_05b_cabin_polish_test.gd",
    "car_art_05c_exterior_test.gd",
    "car_art_05d_driver_variants_test.gd",
    "car_art_05e_mobile_lod_test.gd",
    "vehicle_visuals_test.gd",
    "car_art_04bc_visual_test.gd",
    "car_art_04d_materials_test.gd",
    "car_art_04a_side_contact_test.gd",
    "car_art_04e_airborne_guard_test.gd",
    "vehicle_scene_contract_test.gd",
    "vehicle_world_obstacle_test.gd",
    "vehicle_actor_safety_test.gd",
    "city_signal_stop_line_test.gd"
)) {
    $output = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $exitCode = $LASTEXITCODE
    $output | Out-Host
    if ($exitCode -ne 0 -or ($output | Select-String 'ERROR:|SCRIPT ERROR:') -or
        -not ($output | Select-String '_PASS')) { throw "FAILED: $test" }
}
Write-Host "CAR-ART-05 focused gate passed!" -ForegroundColor Green
```

## Device acceptance matrix

- **PC:** inspect from the near-side and far-side; driver's head, shoulders and steering must be visible behind tinted glass with the roof opaque.
- **Android:** repeat at 8/12/20 simultaneous vehicles; record FPS, physics ms, frame spikes, draw calls (if available), and glazing sorting artifacts.
- **Safety:** cars must stop at real barriers/pedestrians; no new `CollisionShape3D`, `StaticBody3D` or input controls inside `DetailVisuals`.
- **Checkpoint:** save/reload preserves route, car type/palette and physical traffic; no new driver state persisted.
- **Milestone closure:** only after passing tests and visual/device evidence. First slice is **source committed, not verified**.

**No GitHub Actions were manually triggered.** All related source commits use `[skip ci]`.

## CAR-ART-05B — Cabin Visibility & Exterior Polish (2026-11-16)

**Problem confirmed in CAR-ART-05A:** The driver was inside a *fully closed* six-face tapered cabin whose entire surface was alpha-blended. Separate windscreen and side-window panes overlapped that shell. This adds transparent overdraw, makes the door area look glass-like, and can cause the driver to be hard to see because of depth sorting. Front seat headrests also exceeded the roof underside.

**Changes in source:**
- `CivicVehicleVisuals._tapered_cabin()` now builds only the low painted body/beltline (still one `ArrayMesh` surface for the existing scene contract), leaving genuine upper window openings. The `Cabin` material is the opaque body paint, while only the windscreen, rear glass, and four side panes use alpha blending. Avoid rendering both front/back sides of panes via backface culling.
- Slim `RoofFrontLip` / `RoofRearLip`, opaque `WindowSill_L/R`, low-poly hood/trunk shoulders, front lamp brows and rear lamp surrounds improve readable car proportions at oblique/elevated game camera angles.
- Passenger/driver headrests now fit below the roof; the right-hand driver remains under the roof with steering wheel and interior unobstructed by a sealed tinted shell.
- No physics scripts, collision layers, vehicle routes, traffic priority or gameplay save format modified. Previous car-detail node names remain intact; all added geometry is cosmetic `MeshInstance3D`.
- A new `tests/car_art_05b_cabin_polish_test.gd` verifies no sealed cabin window faces, exactly six intentional translucent panes, opaque body, correct driver/headrest roof clearance, all polish pieces, and unchanged 1.6×1.2×3 m layer-4 collider. The CAR-ART-05A test was updated to expect an opaque body beltline and transparent windscreen.

**QA still pending:** Run Godot 4.7.2 import and both new/legacy vehicle art tests, then visually inspect driver from front/left/right and top-down camera. Verify transparency sorting in Android Compatibility/Mobile renderers at 8, 12 and 20 cars; capture frame-time and draw calls. Do not label transparent-car performance improved until a real device comparison is available. If visual driver is hard to see behind tinted windows, tune *only* the six glass panes and cabin materials, not the collision body.

**Debug APK:** Once the import and focused tests pass, use `godot --headless --path . --export-debug "Android Debug" build/civic-chaos-car-art-05b-test.apk` with installed Android export templates/SDK and an existing matching export preset. No APK was built during this GitHub-only coding step.


## CAR-ART-05C — Exterior Vehicle Redesign (2026-11-16)

**Source implemented:** `scripts/traffic/vehicle_visuals.gd` now adds front grille border pieces, rear trunk lip and tail panel/valance, paired front/rear lower door outlines and handles, and four simplified wheel faces with five rim spokes each. These reuse existing material resources and create only `MeshInstance3D` children; existing front/rear lamps, mirror assemblies, brake lights, windows, right-hand driver and original traffic car physics are unchanged.

**Geometry decision:** The authoritative car collider is intentionally fixed at `BoxShape3D(1.6, 1.2, 3.0)` on layer 4. The visual wheel accents remain centered over the existing wheels and are not used by tire contact, suspension, movement or traffic policy. The inherited wheel nodes from `vehicle_agent.tscn` remain intact; the detailing is an additional non-interactive layer.

**Regression added:** `tests/car_art_05c_exterior_test.gd` checks all exterior nodes, wheel-face and spoke alignment, door trim, six intentional transparent panes, original collision shape, brake-lamp response, paint determinism and real route movement. Also run `car_art_05_driver_cabin_test.gd`, `car_art_05b_cabin_polish_test.gd`, `vehicle_visuals_test.gd`, `car_art_04bc_visual_test.gd`, `car_art_04d_materials_test.gd`, `vehicle_scene_contract_test.gd`, `vehicle_world_obstacle_test.gd`, `vehicle_actor_safety_test.gd`.

**Still pending:** Godot 4.7.2 import/run, front/side/rear visual snapshots with driver visible, visual overlap/culling review, and real Android GPU/frame-time measurements with multiple traffic cars. No screenshots or runtime tests were produced during this GitHub coding pass. If the per-wheel spoke mesh count is expensive on Android, the follow-up **CAR-ART-05E** should merge wheel submeshes or use distance-based LOD rather than changing car collisions.

**Local Android debug export** after tests pass:

```powershell
New-Item -ItemType Directory -Force build | Out-Null
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-debug "Android Debug" "build/civic-chaos-car-art-05c-test.apk"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "build/civic-chaos-car-art-05c-test.apk")) { throw "Debug APK export failed" }
```

**Tracking status:** source/test committed, verification and APK build pending. No manual GitHub Actions.


## CAR-ART-05D — Deterministic Drivers & Vehicle Identity (2026-11-16)

**Implementation committed:** `scripts/traffic/vehicle_visuals.gd` supplies five coordinated palettes for driver shirt, skin appearance, hair, upholstery and metallic wheel finish. It retains the original five lane-based body paint colors and adds limited changes to the existing driver-hair mesh scale. No separate models, textures, scripts, colliders or animation state were created per variant. All cosmetic changes reuse the materials allocated when the vehicle enters the tree, not new materials per tick.

**Stable selection:** `set_lane_variant(lane_id)` derives both paint and driver slots solely from the original first route lane ID (`posmod(lane_id, 5)` for body color, `posmod(lane_id * 7 + 3, 5)` for the driver). The original `CivicVehicleAgent.configure` already calls this once from `lane_ids[0]`, including when the checkpoint restoration reconstructs a vehicle. Future lane changes do not alter its driver's appearance; restoration generates the same slots without consuming the traffic RNG. No snapshot fields or saved schema changes.

**Regression:** `tests/car_art_05d_driver_variants_test.gd` creates vehicles twice from the same route and checks equivalent identity, materials, hair silhouette, reapplication without new material resources, all five distinct driver/paint palettes, unchanged layer-4 1.6×1.2×3 m collider, and no physics bodies in cosmetic children. Run with `car_art_05_driver_cabin_test.gd`, `car_art_05b_cabin_polish_test.gd`, `car_art_05c_exterior_test.gd`, `vehicle_visuals_test.gd`, `car_art_04d_materials_test.gd`, `vehicle_scene_contract_test.gd`, and `traffic_checkpoint_invariants_test.gd`.

**Limitations:** Lane ID is the stable existing identity input, so traffic cars spawned from the same start lane will share a cosmetic driver and paint. A unique per-car identity would require an explicit deterministic spawn serial persisted in checkpoints; that broader change is **out of scope** to avoid changing traffic RNG/save behavior now. No true rigged driver, animation or higher-poly models. The source has not been run in Godot locally here. Real Android screenshots and 8/12/20-car GPU checks are pending. CAR-ART-05D must remain SOURCE IMPLEMENTED until those tests and visual checks pass.

**No GitHub Actions triggered manually.** Commits include `[skip ci]`.


## CAR-ART-05E — Mobile Rendering Budget & Distance LOD (2026-11-16)

**Existing cause:** `scripts/traffic/vehicle_visuals.gd` creates many independent `MeshInstance3D` decorative features for each traffic car, including 20 small metallic wheel spokes, plus six translucent window panes and the right-hand driver. Repeating this 8–20 times can inflate mesh submissions and fragment the Android frame, though no device metrics are yet available.

**Source implementation:**
- `CivicVehicleVisuals._batch_wheel_spokes()` creates **one `MultiMeshInstance3D` containing 20 spokes** using the existing metallic wheel-finish material. Original per-spoke nodes remain available for compatibility tests but stay invisible, avoiding their individual draw submissions. Each car has exactly one new batched wheel-spoke rendering node; no collision geometry.
- `CivicVehicleVisuals.update_lod_distance()` implements three reversible camera-distance levels with a **4-metre hysteresis band**: **near** below ~24 m (full driver, panes and trim), **mid** from ~24–54 m (driver and windows remain; small trim and spokes hidden), **far** beyond ~54 m (body, roof, hood/trunk and safety lamps remain; interior/glass and trim are hidden). LOD changes occur only when crossing thresholds.
- `scripts/world/junction_scene.gd` samples the actual viewport's active `Camera3D` every **10 fixed ticks** (nominally twice per second at 20 Hz) and asks `CivicTrafficSpawner.update_fleet_visual_lod(camera.global_position)` to apply levels. A missing active camera (e.g., headless verification) leaves vehicles in their default near/full-detail mode. All LOD state is transient; none is saved or consulted by traffic or physics.
- Existing car meshes `Visual`, `Cabin` and four wheel nodes live outside `DetailVisuals` and are **never hidden**. Nearby cars retain the five stable driver/paint palettes and readable front/side views. Far cars retain the raised roof and active lamps rather than becoming wheel-and-box placeholders.
- No changes to `vehicle_agent.gd`, `vehicle_agent.tscn`, collision layers/shapes, signal phases, mission rewards, traffic RNG or checkpoint format. Existing brake light material remains operational even when a distant visual element is hidden.

**Regression:** Added `tests/car_art_05e_mobile_lod_test.gd` for the one-group/20-spoke batch, permanent hiding of 20 unbatched spokes, near/mid/far and hysteresis, returning from far to near, fleet updater, driving movement, vehicle layer-4 1.6×1.2×3 m collider and unchanged paint/driver identity. Also run `car_art_05d_driver_variants_test.gd`, `car_art_05c_exterior_test.gd`, `car_art_05b_cabin_polish_test.gd`, `car_art_05_driver_cabin_test.gd`, `vehicle_visuals_test.gd`, `car_art_04d_materials_test.gd`, `vehicle_scene_contract_test.gd`, `vehicle_world_obstacle_test.gd`, `traffic_checkpoint_invariants_test.gd`.

**Physical verification:** The code changes *intend* to reduce rendering work but **do not establish measured performance**. On a real Android phone inspect nearby drivers, moving cars at 30 m and far traffic at 65 m, including oscillation around 24/54 m. Profile 8/12/20 visible cars, record p50/p95 frame times, FPS, GPU and draw calls for the same fixed scene before/after. If static hidden spoke nodes remain too expensive in object count, a later phase can move them behind a test-only compatibility fixture and keep the MultiMesh in production. Measure occlusion and glass sorting on Android Compatibility and Mobile renderers.

**Status:** SOURCE IMPLEMENTED, focused Godot and Android verification pending. No APK built by GitHub coding; no GitHub Actions manually triggered.


## CAR-ART-05F — Player Screenshot Audit, Tow Gridlock and Motion Feedback (2026-11-16)

**Grounded user screenshot:** Debug gameplay shows four stopped Wrong Way mission cars after several minutes, municipal service reporting `Tow delayed: traffic signal or pedestrian crossing`, exposed dark bars rising above the sedan windows, and side mirrors not visibly projecting. The upper-right mission panel and left debug HUD also cover large parts of the road view. These are actual observed symptoms; the exact vehicle/mission runtime blockage is not independently verified by a new Godot run.

### TOW-FIX-05F-01 — Wrong Way sustained waiting (P0 gameplay)

**Confirmed source hazard:** `CivicWrongWayLiveMission._advance_tow_convoy` called `traffic_system.apply_stop_line_observation` with the tow vehicle, although that truck is not a member of `traffic_spawner.active_vehicles`. The standard central arbiter compares fleet slots/nearest contenders and can repeatedly yield to stopped background vehicles, even when the truck needs to clear the incident. This generic stopped observation was misleadingly labeled `traffic signal or pedestrian crossing` and could persist across green phases.

**Implemented:** `CivicTrafficSpawner.municipal_service_observation` and `municipal_service_hold_reason` are independent of ordinary background fleet-slot priority. They still **block on red/amber/all-red, reserved pedestrian crossings, and physical central-zone occupants**, and do not stop a truck that is already past the stop line. Actual mission sweeps in `_advance_tow_convoy` still check both tow-truck and offender collision footprints at 0.30 m intervals. A physical route obstruction still invokes the existing grounded roadside collection; no forced red-light crossing or collision bypass. Hold messaging now reports `red_signal`, `pedestrian_crossing` or `central_zone_occupied` instead of falsely conflating them.

**Regression added:** `tests/wrong_way_tow_service_priority_test.gd` verifies ordinary waiting fleet cars don't starve a legal green service move; red blocks; pedestrian reservation blocks and releases on verified departure; genuinely occupied central zone blocks; cleared zone releases; already-committed truck isn't frozen inside the junction. Also run `aud3_wrong_way_signal_recovery_test.gd`, `aud3_wrong_way_tow_gridlock_recovery_test.gd`, `authorized_tow_obstacle_test.gd` and all relevant checkpoint tests. **The user’s five-minute stall must be reproduced and timed from start to real mission completion before closure.**

### CAR-ART-05F — Better mirrors, fewer window bars and motion

- Recess painted `RoofFrontLip` / `RoofRearLip` into solid roof material rather than exposed black cage-like bars. Slim both windshield/rear pillars with body-colored finish. Retain existing node names for backward compatibility.
- Bring `Mirror_L/R` and reflective `MirrorGlass_L/R` visibly outside the doors, still as cosmetic-only nodes, without expanding authoritative collision footprint.
- `CivicVehicleVisuals.update_motion_visuals(actual_travel_m, yaw_delta_rad)` rotates four physical-appearance wheel meshes, hub and wheel-face visuals, and nearby batched 20 spoke instances by accepted travel distance; modest front-wheel yaw and steering-wheel angle follow actual route heading changes. This does **not** steer physics or modify route distance.
- Regular `CivicVehicleAgent.advance_fixed` invokes visual motion after its accepted movement. The scripted municipal truck and towed offender also receive visual wheel motion from real accepted tow progress (no spinning tires while held at a signal).
- `tests/car_art_05f_motion_mirrors_test.gd` checks both mirrors, roof bar finish, wheel spin, turn sign, spoke movement, stopped wheel hold, unchanged physics and normal vehicle motion.

### Known remaining issue: HUD readability (P1 UI backlog)

The screenshot includes overlapping mission/debug/waypoint text boxes obscuring scenery. **Not fixed by car-art milestone.** Track separately as `HUD-READ-01`: one compact mission summary + expandable telemetry, mobile safe-area anchors, no overlapping map/calls controls, readable objective state. Do not mark user-facing screen polished until screenshot comparison on the requested Android resolution.

### Verification and release gate

1. Run Godot 4.7.2 import with zero `SCRIPT ERROR:`, then `wrong_way_tow_service_priority_test.gd`, `aud3_wrong_way_tow_gridlock_recovery_test.gd`, `authorized_tow_obstacle_test.gd`, `car_art_05f_motion_mirrors_test.gd`, `car_art_05e_mobile_lod_test.gd`, `car_art_04bc_visual_test.gd`, `car_art_05b_cabin_polish_test.gd`, `car_art_05d_driver_variants_test.gd`, `vehicle_world_obstacle_test.gd`, `traffic_spawner_test.gd`, and checkpoint safety tests.
2. **Real Wrong Way gameplay:** leave the officer and convoy at each signal and see movement on the next safe green; physically obstruct the street with a solid prop to ensure no clipping; after authorized grounded recovery measure actual follower clearance and mission reward exactly once. No five-minute wait.
3. **PC/Android visuals:** front, side, elevated, rear screenshots with visible side mirrors/driver, no cage bars, spinning tires on moving cars, zero tire spin at stopped signals, and preserved red brake light cue.
4. **Android performance:** measure frame time and draw-call cost for 8, 12, 20 cars; note that batched wheel spokes now update their transforms when near the camera and must be profiled. No FPS improvement is claimed until measured.
5. **APK:** existing preset is named `Android Debug`; build after test gate with `--headless --path . --export-debug "Android Debug" "build/civic-chaos-car-art-05f-debug.apk"` and verify output exists.

**Status:** Changes and source tests committed on existing branch using `[skip ci]`. Godot runtime tests/real screenshot replay/Android export have not been executed here. Do not mark TOW-FIX-05F-01 or CAR-ART-05F verified until acceptance evidence is recorded.


### CAR-ART-05F verification blocker — mixed indentation (2026-11-16)

**User Godot 4.7.2 local failure:** headless editor import reported `SCRIPT ERROR: Parse Error: Used space character for indentation instead of tab as used before in the file` at `scripts/traffic/traffic_spawner.gd:97` and `:294`. Consequently `wrong_way_tow_service_priority_test.gd` failed to preload `CivicTrafficSpawner` before any tow behavior or regression could run. No APK was built. Root cause is 39 space-indented lines added by CAR-ART-05E's fleet LOD helper and TOW-FIX-05F's municipal service helpers in a tab-indented GDScript.

**Fix committed:** `df67713` reindents the complete two affected method groups (39 lines) to tabs, matching the rest of the file without changing stop permissions, traffic behavior, or visual logic. Source inspection shows `scripts/world/junction_scene.gd` and `scripts/civic/wrong_way_live_mission.gd` consistently use spaces, so no change was needed there. **Verification pending:** rerun the import and focused gate from the updated branch. Note that a Godot editor import can print script errors while exiting with status zero: inspect both the exit code and `SCRIPT ERROR:` / `ERROR:` text before running any tests or APK export.
