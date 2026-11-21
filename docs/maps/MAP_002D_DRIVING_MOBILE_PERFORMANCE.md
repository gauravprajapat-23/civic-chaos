# MAP-002D — Driving Minimap, Mobile Layout and Performance

**Branch:** `feature/map-002-gta-style-overhaul`, stacked on MAP-002A/B/C in draft PR #91.

## Implementation
- `scripts/ui/civic_map_driving_policy.gd`: deterministic UI-only rules for adaptive minimap radius, bounded movement-speed estimation, route refresh thresholds and visible-canvas redraw.
- `scripts/ui/civic_city_map.gd`: speed is inferred from consecutive world-position samples taken at least 90 milliseconds apart. Pauses/long gaps are treated as invalid samples, avoiding zoom jumps. At walking speed the minimap retains the old 37m viewing radius; fast driving increases this continuously to a capped 72m radius. Both roads and overlays use the same perspective, preserving the player-up minimap, curved street centerlines and real mission waypoints.
- Active GPS route is recalculated on destination change, graph change, or when player moves at least 4m from last route origin. The player arrow, guide cue and location updates continue on every position update; a position update below threshold no longer invokes graph path planning. The full map is only queued for redraw while expanded and the minimap only while actually visible. Existing mobile safe-area placement from `CivicHudSafeLayout.minimap` is unchanged.
- No gameplay or physical road geometry, map marker coordinates, traffic authority, mission state, save schema, steering or player movement modified.

## Limits and manual performance acceptance
The new refresh policy cuts unnecessary route planning and hidden-canvas redraws. It does **not** establish a measured FPS improvement by itself; benchmark representative Android devices at high speed and during 20+ NPC/cars near a dense junction. On mobile portrait/landscape validate minimap does not cover touch controls, route indicators remain legible, heading remains player-up, and increasing speed shows more road. While stationary for >1s, minimap should return smoothly to walking scale (current implementation updates radius at the next valid movement sample; further interpolation is optional). Verify actual mission changes and selected bus-stop/parking routes switch immediately. Windows zoom/pan and Android touch gestures must still work.

## Regression suite: Windows Godot 4.7.2
Reported MAP-002A/B tests passed before MAP-002C; MAP-002C/D remain **not verified** until fresh run on this head.

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$review = "C:\Users\gauravp\Projects\civic-chaos-map-002a-review"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
if (-not (Test-Path $review)) {
    git worktree prune
    git worktree add --detach $review origin/feature/map-002-gta-style-overhaul
} else {
    $status = @(git -C $review status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0 -or $status.Count -gt 0) { throw "Tracked modifications; review first" }
    git -C $review switch --detach origin/feature/map-002-gta-style-overhaul
}
if ($LASTEXITCODE -ne 0) { throw "Review checkout failed" }
Push-Location $review
try {
    $importOutput = & $godot --headless --path . --editor --import --quit 2>&1 | Out-String
    $exit = $LASTEXITCODE
    $importOutput | Out-Host
    if ($exit -ne 0 -or $importOutput -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)') {
        throw "Import failed"
    }
    $tests = @(
        "map_002d_driving_performance_test.gd",
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
    )
    foreach ($test in $tests) {
        $out = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
        $code = $LASTEXITCODE
        $out | Out-Host
        if ($code -ne 0 -or $out -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)' -or
            $out -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
            throw "FAILED: $test"
        }
        Write-Host "PASS: $test" -ForegroundColor Green
    }
    Write-Host "ALL 11 MAP REGRESSIONS PASSED" -ForegroundColor Green
} finally { Pop-Location }
```

**Native status:** New MAP-002D test created; not executed by the hosted agent. PR remains draft/unmerged, no GitHub Actions manually launched and `scripts/core/main.gd` untouched.
