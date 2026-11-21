# MAP-002B — Grounded Neighborhood Shapes & Landmark Overlays

**Dependency:** MAP-002A on `feature/map-002-gta-style-overhaul` (PR #91). All content remains a non-authoritative cartographic layer. The physical city is not replaced; the canonical network still contains its 40 road segments and the western curved pilot.

## Source-of-truth inventory
`CivicMapDistricts.REGIONS` creates **six decorative neighborhood patches** anchored to already implemented points: Community Garden, Community Kiosk, Solar Corner, South Market Walk from `CivicLivingCityZones.LOCATIONS`, Old Bus Stop from `CivicNeighborhoodDetails._bus_stop`, and Public Parking from `CivicNeighborhoodDetails._parking_court`. The shapes use bounded, beveled polygons inside pre-existing world blocks, separated from current road axes by at least 5m. Names describe the visible precinct around these objects; they are NOT new district-gameplay IDs, collision volumes, traffic regions or discoverable quests.

`CivicMapDistricts.SERVICES` adds only the two existing world objects missing from the old full map. Original mission, LANDMARKS and LivingZones selectable buttons, route planner, waypoint selection and gameplay status remain untouched.

## Rendering order
1. Dark background from MAP-002A
2. Decorative district shapes in six locations (translucent in minimap, more legible on full map)
3. All real sampled road centerlines from `CityNetwork.roads()`; no substitutions
4. Known public-service dots, challenge points, existing navigation route and mission markers
5. Player orientation marker (player-up on minimap, true world heading on full map)

The full map labels regions and two service landmarks. The minimap keeps label clutter out and only adds subtle colored shapes and nearby service markers. Both use existing world-to-screen map projections; polygons entirely outside viewport are culled before drawing. No additional physics or traffic scripts are touched.

## Focused native verification — Windows Godot 4.7.2
The hosted agent cannot run Windows Godot. Tests have been committed but are **not claimed PASS**. Run from a detached review worktree (existing MAP-002A worktree can be reused if clean):
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$path = "C:\Users\gauravp\Projects\civic-chaos-map-002a-review"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
$changes = @(git -C $path status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $changes.Count -gt 0) { throw "Review tracked changes first" }
git -C $path switch --detach origin/feature/map-002-gta-style-overhaul
if ($LASTEXITCODE -ne 0) { throw "Could not update review worktree" }
Push-Location $path
try {
  & $godot --headless --path . --editor --import --quit
  if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
  foreach ($test in @(
    "map_002b_districts_landmarks_test.gd",
    "map_002a_visual_foundation_test.gd",
    "world_001e_map_parity_test.gd",
    "aud3_city_map_test.gd",
    "ui_003_safe_geometry_test.gd",
    "ui_003_modal_reflow_test.gd",
    "master_hud_004_safe_area_test.gd",
    "touch_controls_test.gd",
    "touch_layout_test.gd"
  )) {
    $output = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
    $code = $LASTEXITCODE
    $output | Out-Host
    if ($code -ne 0 -or $output -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)' -or
        $output -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
      throw "FAILED $test"
    }
    Write-Host "PASS $test" -ForegroundColor Green
  }
} finally { Pop-Location }
```

## Rendered acceptance before merge
Open full-screen map and minimap, check the six visible neighborhood patches remain aligned to Garden/Kiosk/Solar/South Walk/Bus Stop/Parking during pan/zoom, and never cover a road. At minimum verify at overview and 2× zoom. On Android check landscape and portrait readability, screen edge clipping, safe-area HUD and frame time in dense traffic. These are **pending manual verification**; do not merge PR #91 until independent acceptance and review.
