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
| **CAR-ART-05B** | P1 | Refine cabin shape, glass blending and occlusion | Driver visible in front/side views; no see-through roof, transparency sorting or head clipping | OPEN |
| **CAR-ART-05C** | P2 | Improve vehicle identity: distinct bumpers/grille, correctly proportioned doors, windshield angle, tail surfaces, wheel arches and front/rear readability | 3D screenshots with intact 1.6×1.2×3 m collision and no decorative colliders | OPEN |
| **CAR-ART-05D** | P2 | Driver variants (hair/skin/shirt) tied deterministically to lane/route, not runtime RNG or gameplay clock | Same saved route restores same visual driver, no state-schema changes | OPEN |
| **CAR-ART-05E** | P2 | LOD/mobile optimization: combine repeated mesh pieces, share material resources, limit transparent faces and detail distance | Stable FPS and bounded draw calls for 8/12/20 cars on Android | OPEN |
| **CAR-ART-05F** | P2 | Steering/wheel visual response and lights consistency | Steering cosmetic-only, existing brake signals never misreport state, no traffic physics changes | OPEN |
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
