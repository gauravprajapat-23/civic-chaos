# MAP-002C — On-Map GPS Waypoints and Navigation Cues

**Base:** MAP-002A/B on PR #91, branch `feature/map-002-gta-style-overhaul`. This milestone is purely UI. It preserves the canonical street graph, mission dispatch and route authority.

## Added
- `scripts/ui/civic_map_navigation_guide.gd`: deterministic, pure distance-to-route calculations, nearest segment, upcoming left/right cue, arrival and route-rejoin warning. The next turn is estimated from existing route polyline segments and 28° threshold; it is not turn-by-turn road/legal driving guidance and does not change vehicle routing.
- Full-map controls now offer selectable **Old Bus Stop** and **Public Parking** destinations grounded in `CivicMapDistricts.SERVICES`; existing mission, four landmarks, four exploration destinations remain.
- `CivicCityMap._update_route()` exposes GPS instruction and remaining distance without altering `mission_state`. The minimap shows a compact current instruction while a route is active; full map continues displaying the existing green highlighted route. Service markers have typed colors and letter identifiers; existing mission markers use the mission color.
- User position, objective and selected destination remain the only inputs to navigation hints; no internet GPS, pathfinding changes, traffic AI or save fields added.

## Verified by source inspection; native verification pending
- `tests/map_002c_gps_navigation_test.gd`: deterministic nearest point/distance, right and left turn, arrival, reroute instruction, selection of known bus/parking points, no arbitrary empty position, route state and modal/mission parity.
- Prior suites `map_002a_visual_foundation_test.gd`, `map_002b_districts_landmarks_test.gd`, `world_001e_map_parity_test.gd`, `aud3_city_map_test.gd`, `ui_003_safe_geometry_test.gd`, `ui_003_modal_reflow_test.gd`, `master_hud_004_safe_area_test.gd`, `touch_controls_test.gd`, and `touch_layout_test.gd` must be rerun against the new head.
- Previous MAP-002A/B tests were reported PASS by developer; they are not evidence of MAP-002C verification. No local Windows Godot runtime is available to this worker.

## PowerShell verification (existing clean review worktree)
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
$path = "C:\Users\gauravp\Projects\civic-chaos-map-002a-review"
$changes = @(git -C $path status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $changes.Count -gt 0) { throw "Review tracked edits first" }
git -C $path switch --detach origin/feature/map-002-gta-style-overhaul
if ($LASTEXITCODE -ne 0) { throw "Worktree update failed" }
Push-Location $path
try {
    $godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
    & $godot --headless --path . --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Import failed" }
    foreach ($test in @(
        "map_002c_gps_navigation_test.gd",
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
        $log = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
        $code = $LASTEXITCODE
        $log | Out-Host
        if ($code -ne 0 -or $log -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)' -or
            $log -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
            throw "FAILED: $test"
        }
        Write-Host "PASS: $test" -ForegroundColor Green
    }
} finally { Pop-Location }
```

## Visual acceptance
On Windows select MISSION, Old Bus Stop and Public Parking and check heading/distance and green line. Walk/ride toward destination; remaining distance should progress, arrival cue display, and turns should not flash excessively at junctions. Test player-up minimap, camera rotation, pan/zoom, mobile portrait/landscape safe areas and long-running FPS. Some route instructions are simplified because the current route planner uses road-graph node positions; a full lane-centerline-accurate turn-by-turn guidance planner is a later milestone. Keep PR draft until verification.

**Restrictions:** no `scripts/core/main.gd`, traffic/world mesh edits, manual GitHub Actions or merges.
