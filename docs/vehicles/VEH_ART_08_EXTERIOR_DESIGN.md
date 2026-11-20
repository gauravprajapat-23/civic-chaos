# VEH-ART-08 — Car and motorcycle exterior identity

## Scope
A narrow, render-only vehicle design improvement layered on the **verified WORLD-001F** code at branch point `9b51f452`. No edits to `scripts/core/main.gd`, traffic permissions, route graph, checkpoints, physical collision bodies, steering logic, rider mounting, or Godot Actions.

### Cars
The new `scripts/traffic/vehicle_exterior_identity.gd` builds a `BodyDesign08` visual child of `CivicVehicleVisuals`: lower intake, front/rear number plates, fog-lamp-like reflectors, bumper-side vents, side rocker panels, door belt accents, rear reflectors, mud flaps, trunk badge, roof antenna. Materials reuse the existing deterministically selected paint/trim/lamps; no simulation RNG or save schema added. `set_detail_level()` calls `Exterior08.apply_lod()`: near = full detail; mid = 5 major silhouette pieces; far = details hidden. Existing driver and cabin remain.

### Motorcycles
`scripts/world/rideable_bike.gd` adds a visual-only rear cowl, number plate/support, chain guard, rear reflector, side tank insets and passenger footpegs. Steering fork, handlebar grips, rider hand-follow rig, tire animation and collision footprint are not touched.

### Acceptance
Source implemented with `tests/veh_art_08_exterior_design_test.gd`, checking visible parts, LOD transitions, identical identity before/after LOD, no new collision nodes and retained bike steering rig.

**Engine verification is still pending**. No test pass claimed on this feature commit. Run on Windows Godot 4.7.2:
```powershell
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Import failed" }
& $godot --headless --path . --script res://tests/veh_art_08_exterior_design_test.gd
if ($LASTEXITCODE -ne 0) { throw "Vehicle art regression failed" }
& $godot --headless --path . --script res://tests/vehicle_ride_07_impact_contact_stress_test.gd
if ($LASTEXITCODE -ne 0) { throw "Bike collision regression failed" }
& $godot --headless --path . --script res://tests/vehicle_ride_07_sustained_grip_stability_test.gd
if ($LASTEXITCODE -ne 0) { throw "Bike rider regression failed" }
```
After tests, inspect car close-up in daylight, front/rear plates and bumper orientation, visible seated driver, sedan glass, wheel motion and car/motorcycle contacts on Windows and Android. Measure draw calls and frame spikes at crowded intersections before acceptance.

## Integration
This branch intentionally depends on `feature/world-001-organic-city` (WORLD-001F). PR should target that branch, not `main`; only integrate after world and vehicle acceptance. Do not merge or manually run GitHub Actions.
