# MAP-002A — Open-world City Atlas Visual Foundation

**Branch:** `feature/map-002-gta-style-overhaul` (based on merged `main`).  
**Scope:** visual/UI rendering only. Inspired by the legibility and contrast of open-world action game maps; not a reproduction of GTA assets or its actual geography.

## What changed

- **Canonical roads remain authoritative:** both `_draw_small()` and `_draw_map()` still use `CityNetwork.roads()` and each road's full `centerline`, including WORLD-001E/F's sampled western S-bend. Road layout, checkpoint IDs, traffic rules and 3D city meshes are unmodified.
- **Two true road classes:** map styling reads the `road_type` provided by the current network. Market streets are lighter and thicker, collector streets are narrower/muted; both have contrasted edge outlines. No fictional expressways or routes are invented.
- **Improved cartography:** deep charcoal/blue canvas, subtle inset frame, bright green route halo, prominent cyan player arrow, gold mission destination; minimap remains rotated player-up, while full-map arrow follows actual heading.
- **Mobile-safe rendering:** stroke widths capped, segments wholly outside the viewport culled before drawing; the existing safe-area layout, full-map scroll, pan, pinch, zoom, focus transitions and mission/route contracts remain.
- **Scope boundaries:** MAP-002A is a *visual foundation*, not district polygon generation, POI discovery, new highways, free waypoint selection or a replacement of existing 3D city geometry. The mostly rectangular real network will remain recognizable until those later, separately validated WORLD/MAP milestones.

## Files

- `scripts/ui/civic_map_visual_style.gd` — shared road palette, class rank, width/LOD caps, segment-visibility check, player triangle and frame style.
- `scripts/ui/civic_city_map.gd` — map/minimap integration and drawing layers.
- `tests/map_002a_visual_foundation_test.gd` — visual contracts and live map UI parity.

## Native verification on Godot 4.7.2 Windows

This environment does not provide the native Godot runtime. Run on a **fresh detached review worktree**, not on `main`. This script also checks engine errors rather than trusting only process exit status:

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
$review = "C:\Users\gauravp\Projects\civic-chaos-map-002a-review"
if (-not (Test-Path $review)) {
    git worktree add --detach $review origin/feature/map-002-gta-style-overhaul
    if ($LASTEXITCODE -ne 0) { throw "Worktree creation failed" }
} else {
    $changed = @(git -C $review diff --name-only HEAD)
    if ($LASTEXITCODE -ne 0 -or $changed.Count -gt 0) {
        throw "Review worktree has tracked edits"
    }
    git -C $review switch --detach origin/feature/map-002-gta-style-overhaul
    if ($LASTEXITCODE -ne 0) { throw "Could not update review worktree" }
}
Push-Location $review
try {
    $godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
    & $godot --headless --path . --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
    foreach ($test in @(
        "map_002a_visual_foundation_test.gd",
        "aud3_city_map_test.gd",
        "world_001e_map_parity_test.gd",
        "ui_003_safe_geometry_test.gd",
        "ui_003_modal_reflow_test.gd",
        "master_hud_004_safe_area_test.gd",
        "touch_controls_test.gd",
        "touch_layout_test.gd"
    )) {
        $out = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
        $code = $LASTEXITCODE
        $out | Out-Host
        if ($code -ne 0 -or $out -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)' -or
            $out -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
            throw "MAP-002A regression failed: $test"
        }
        Write-Host "PASS $test" -ForegroundColor Green
    }
} finally { Pop-Location }
```

## Rendered acceptance (not covered by headless tests)

1. Open map on Windows; compare primary market streets and collector streets at overview and 2×/5× zoom. Verify real curve on west edge.
2. Drive and turn: player-up minimap should rotate road geography while arrow stays up; full-map arrow points toward real heading.
3. Select existing landmarks/mission; verify route does not disappear behind street stroke, gold destination visible, pan/zoom/center and modal close work.
4. On Android portrait/landscape, test map clipping, touch gestures, safe-area overlap, readability and rendering performance in congested districts. Measure FPS and draw calls rather than assuming performance.

**Status:** code/test implemented. Engine import, focused tests, rendered visual and physical-device acceptance **not executed** here. PR must remain draft until review and verification. No GitHub Actions manually triggered; do not merge.
