# MAP-UI-03 — Interactive Full-City Map Navigation

**Date:** 2026-11-17  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source and regression committed. Local Godot, Android/touch and gameplay verification pending.

## Reported issue

The earlier `CivicCityMap` full-screen panel drew a fixed 5×5 district overview with roads, selected locations and active mission route, but offered **no pan or zoom controls**. This made it difficult to inspect specific neighborhoods, crossroads and roadworks, especially on mobile. The bottom-left minimap is intentionally player-following and does not replace a navigable district map.

## Implementation

`scripts/ui/civic_city_map.gd` now has an independent, UI-only full-map camera:

- `map_zoom` ranges from **1× (entire map)** to **5× (detailed area)**, with 1.25× increments and hard clamping.
- `map_center` stores map-space X/Z center. A bounded camera prevents the user from panning entirely off the city; zoom 1× always centers the whole map.
- `full_view_project` and `full_view_unproject` are pure matching transforms; all roads, route lines, S-bend caution dots, landmarks, civic zones, objective pin and player arrow now share the same zoomed/panned viewport.
- Desktop: drag with left mouse button, scroll up/down to zoom around cursor, or use keyboard `+`/`-` while map is expanded.
- Mobile: one-finger drag to pan, **two-finger pinch to zoom around the touch midpoint**. Touch IDs clear on release or map close.
- Explicit large-map toolbar: `+`, `−`, **CENTER** (player's actual position), **ALL** (fit the entire city), and Close. It uses a wrapping `HFlowContainer` for narrow Android screens.
- Selecting an existing landmark/exploration area automatically zooms into and centers that real location without changing it to a fabricated point.
- The bottom-left minimap, its heading orientation and its normal real-time position updates are unchanged. Expanding/collapsing the full map does not change traffic, missions, route graph, checkpoint data or civic scores.
- The map's drawing control clips geometry at its borders instead of clamping distant roads into false on-screen endpoints.

## Changed files

- `scripts/ui/civic_city_map.gd`
- `tests/map_ui_03_pan_zoom_navigation_test.gd`

Regression verifies coordinate projection round trip, camera bounds, real City Map opening, zoom buttons, mouse-wheel zoom, drag pan, pointer-anchored zoom, touch pinch, touch cancellation, player recenter, landmark auto-focus, full-city reset and minimap restoration.

## Local Windows regression

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Git update failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$code = $LASTEXITCODE
$log | Out-Host
if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Godot import failed"
}

$tests = @(
    "map_ui_03_pan_zoom_navigation_test.gd",
    "aud3_city_map_test.gd",
    "aud3_city_map_routes_test.gd",
    "ui_hud_01_compact_minimap_test.gd",
    "ui_responsive_civic_test.gd",
    "map_challenge_01_bends_and_turns_test.gd",
    "map_challenge_02_roadworks_detour_test.gd",
    "world_junction_checkpoint_test.gd"
)
foreach ($test in $tests) {
    Write-Host "Running $test" -ForegroundColor Cyan
    $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $code = $LASTEXITCODE
    $log | Out-Host
    if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
        -not ($log | Select-String '_PASS')) {
        throw "FAILED: $test"
    }
}
Write-Host "MAP-UI-03 FOCUSED TESTS PASSED!" -ForegroundColor Green
```

## Visual and usability acceptance

- [ ] Open MAP / M and see the entire city at 1×, including all outer streets, civic landmarks and mission objective.
- [ ] Desktop mouse wheel zooms around cursor while the map is expanded. Left-drag changes the inspected area, without moving the actual character in the world.
- [ ] `+`/`−` buttons work at bounds 1×–5×, CENTER focuses the actual player, ALL restores whole-city overview.
- [ ] Tap a landmark/area tab; the map jumps to that *actual* location and the existing route-destination UI remains valid.
- [ ] Android one-finger drag and two-finger pinch work without treating touch gestures as world movement or opening an unrelated HUD button.
- [ ] On a narrow phone viewport the controls wrap visibly and remain large enough to tap; zoomed roads/markers do not spill over the map panel.
- [ ] Existing city roads, S-bend indicators, route path, mission pin and player arrow stay aligned throughout zoom/pan.
- [ ] M or Close returns to unchanged bottom-left minimap and traffic simulation continues appropriately.

**Source committed; runtime acceptance not yet verified.** No manual GitHub Actions invocation.


## 2026-11-17 Godot gate follow-up — MAP-UI-03 zoom initialization (MAP-UI-03A)

The first user-local `map_ui_03_pan_zoom_navigation_test.gd` failed on `zoom in button did not change full-map camera`, with a successful headless editor import immediately before it. Code inspection found that `zoom_at()` returned early if `_large_map_rect()` reported a zero or negative area; this can happen when the full-map container has not yet assigned `FullMapDrawing.size` during headless/first-frame layout. The button signal was wired but its camera operation could be silently discarded. `_large_map_rect()` now calculates a strictly positive viewport-based fallback rectangle until drawing layout settles; regular sized drawing controls still use their actual dimensions. The regression explicitly sets `_map_area.size = Vector2.ZERO`, verifies a positive fallback rect, then presses Zoom In. No changes to traffic or map destination data.

**Status:** corrective source and test committed, **user-local rerun pending**. Verify `map_ui_03_pan_zoom_navigation_test.gd` first, followed by the existing overview, HUD and route regressions. If it fails again, capture the next actual test error instead of assuming the map interaction is fully resolved.
