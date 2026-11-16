# UI-HUD-01 — GTA-Style Bottom-Left Minimap & Compact Mission HUD

**Date:** 2026-11-16  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source changes and focused regression committed; Godot and Android screenshot verification pending.

## Screenshot audit

The player screenshot showed a large minimap near the top center, permanent keyboard instructions, a verbose civic metrics/mission-progress panel on the left, and a second mission/dialogue overlay at top-right. The overlays obscure roads, vehicles, NPCs, street signals and the current waypoint. Nothing in these text walls changes gameplay: all content was already available in the real civic state, active mission actors, and map route planner.

## UI changes

1. **Minimap — bottom-left:** `CivicCityMap` now positions the square map at the bottom-left on desktop and above bottom touch controls on narrow/mobile screens. An adjacent MAP button still expands the original full-city map, also accessible by M.
2. **Local, player-centered projection:** the minimap renders actual 5×5 road coordinates around the player within a 74m world window. Streets rotate with the player's forward direction, player arrow stays centered pointing up, the computed road route remains visible, and the true mission/selected waypoint is clamped inside the square. No invented road segments/mission marker locations; the full map still uses its original world-to-map projection.
3. **Compact civic stats:** `CivicStatusHUD` displays exactly two rows: `REP / INCIDENTS` and `SAFETY / FLOW`. Existing mission/traffic/free-roam/debug text labels are still populated and `current_state()` still returns the complete authoritative data, but the verbose labels are invisible during gameplay. This preserves existing HUD data contracts and diagnostic tests.
4. **Compact mission guide:** `CivicMissionGuide` retains the real mission title, two lines of current objective and waypoint; hides repeating Neighborhood Radio dialogue by default. Recovery controls are still offered only when the mission declares `recovery_available`, with their existing confirmation and reload pathways. Full mission/guide state is retained.
5. **Legacy overlay:** `scripts/core/main.gd` hides the old `CanvasLayer/HUD` district-preview/keyboard/status banner. The existing status label still receives updates for compatibility; the full mission is in the compact guide instead.
6. **Responsive placement:** viewport-specific `minimap_bounds`, `CivicStatusHUD.layout_for`, and `CivicMissionGuide.panel_bounds` keep the map, score strip and objective panel disjoint on 320×568, 360×740, 740×360, 1280×720, and 1920×1080 layouts. The minimap drawing surface clips road lines to its bounds.

No mission logic, player movement, physical vehicle collision, traffic signals, civic score values or checkpoint state was changed by this milestone.

## Code changes

- `scripts/ui/civic_city_map.gd`: `minimap_bounds`, player-centred `minimap_project`, local map renderer, responsive bottom-left positioning, clipped map drawing.
- `scripts/ui/civic_status_hud.gd`: compact civic score layout; full data kept hidden.
- `scripts/ui/civic_mission_guide.gd`: short objective layout and hidden repeated radio dialogue.
- `scripts/core/main.gd`: hide duplicate legacy top-screen banner.
- `tests/ui_hud_01_compact_minimap_test.gd`: five viewport sizes, no overlap, local map heading projection, score and target preservation, full-map toggle.

## Local gate

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Git fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Git merge failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$code = $LASTEXITCODE
$log | Out-Host
if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Godot import failed"
}

$tests = @(
    "ui_hud_01_compact_minimap_test.gd",
    "civic_hud_test.gd",
    "ui_responsive_civic_test.gd",
    "game_qa_mission_guide_test.gd",
    "mission_guide_test.gd",
    "aud3_city_map_test.gd",
    "aud3_city_map_routes_test.gd",
    "mission_guidance_flow_test.gd"
)
foreach ($test in $tests) {
    $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $code = $LASTEXITCODE
    $log | Out-Host
    if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
        -not ($log | Select-String '_PASS')) { throw "FAILED: $test" }
}
Write-Host "UI-HUD-01 focused gate passed" -ForegroundColor Green

New-Item -ItemType Directory -Force "build" | Out-Null
$apk = "build/civic-chaos-ui-hud-01-debug.apk"
& $godot --headless --path . --export-debug "Android Debug" $apk
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $apk)) { throw "APK failed" }
```

## Visual acceptance

- [ ] PC (1280×720): local minimap at bottom-left; top-left two-line REP / INCIDENTS / SAFETY / FLOW; top-right mission title, short NEXT and waypoint; no old banner or radio wall.
- [ ] Map rotates according to real player facing; moving north/south/east/west scrolls correctly. Player centered, gold objective clamped to map edge when far away.
- [ ] M or MAP opens existing full city map with real road graph route and selectable landmarks; Close restores minimap.
- [ ] 320×568/360×740 Android: bottom-left minimap is above joystick and safe-area controls; guide and stats don't obscure one another or road center.
- [ ] Incident cards and Traffic Marshal panel remain full-accessible and on top when opened; Pause and Checkpoint dialogs still work.
- [ ] A stalled Wrong Way / Illegal Parking mission still exposes existing authorized recovery controls, despite hiding verbose radio dialogue.
- [ ] Test Android Compatibility graphics, no viewport clipping/flicker, no frame regression from drawing local roads.
- [ ] Capture screenshots and compare with the user-provided crowded gameplay reference.

**Source committed; no Windows Godot tests nor Android APK run here.** If the local gate fails, fix first; do not mark this milestone released based on source alone.
