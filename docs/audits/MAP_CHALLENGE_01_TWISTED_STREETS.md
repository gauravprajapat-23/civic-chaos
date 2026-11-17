# MAP-CHALLENGE-01 — Winding Streets, Unexpected Turns & Road Warnings

**Date:** 2026-11-17  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source and focused regression committed; PC/Android import and gameplay acceptance pending.

## Goal

The original Civic Chaos city is a visually flat 5×5 Manhattan grid, with very few unexpected turns and no identifiable challenging road segments. The user requests some difficulty, surprising turns and a more interesting map. The critical constraint is to **not reintroduce stationary traffic gridlock** after several traffic and Wrong Way convoy fixes: every visual road must align with a legally connected NPC lane, stay within the paved road width, and permit pedestrians/mission actors to coexist safely.

## Delivered

1. **Eight bidirectional S-bend streets (16 directed lanes).** On outer neighborhood edges at x/z=±46, the four-long-block roads connecting ±46 to ±120 now have a real multi-point winding centerline. Vehicles physically steer through the curve, reduce their speed from 8.0 to 5.5 m/s, and remain inside the existing 8m road. The 4m junction entry/exit ramps and exact node endpoints remain unchanged, so both outer and central junction policies continue to receive the expected directed approaches.
2. **Roadside warning design.** Each of the eight sections has a yellow `S BEND` sign, upright post and three painted road chevrons. These are 3D visual nodes **without any collision bodies**, positioned off the traffic route or flat on the pavement. A gameplay challenge is a safe lane bend, not an invisible road block.
3. **Less predictable journeys.** In expanded city mode only, when a junction offers legal turning choices, the seeded traffic spawner prefers a right/left turn with 70% probability. The choices still come from the validated graph and obey active incident lane closures, traffic signal priority and car-following physics. Isolated test junction routes preserve their prior deterministic selection.
4. **Navigation awareness.** Both the bottom-left minimap and large map display gold caution markers on the challenge road segments, allowing players to spot turns before reaching them. The existing mission waypoint and route display are not replaced.

**Files:** `scripts/world/city_road_layout.gd`, `scripts/world/junction_builder.gd`, `scripts/world/neighborhood.gd`, `scripts/traffic/traffic_spawner.gd`, `scripts/ui/civic_city_map.gd`.

**Scope:** No changes to civic mission rewards, existing wrong-way incident staging lane, save-schema versions, vehicle/pedestrian collision layer, outer signal clocks, or automatic traffic admission limits.

## Regression and local gate

New: `tests/map_challenge_01_bends_and_turns_test.gd`. Checks valid graph connectivity, 16 S-bend directed lanes and 8 road signs, all turn points inside drivable width, consistent lane endpoints, no physical warning barriers, and varied legal choices.

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Git update failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$exit = $LASTEXITCODE
$log | Out-Host
if ($exit -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
  throw "Import failed"
}
$tests = @(
  "map_challenge_01_bends_and_turns_test.gd",
  "neighborhood_test.gd",
  "traffic_spawner_test.gd",
  "traffic_fix_13_post_completion_traffic_test.gd",
  "traffic_fix_11d_wrong_way_follower_release_test.gd",
  "traffic_fix_09_single_approach_rules_test.gd",
  "outer_intersection_movement_test.gd",
  "outer_intersection_restore_test.gd",
  "aud3_city_map_test.gd",
  "world_junction_checkpoint_test.gd"
)
foreach ($test in $tests) {
  Write-Host "Running $test" -ForegroundColor Cyan
  $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
  $exit = $LASTEXITCODE
  $log | Out-Host
  if ($exit -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
      -not ($log | Select-String '_PASS')) { throw "FAILED: $test" }
}
Write-Host "MAP-CHALLENGE-01 focused gate passed!" -ForegroundColor Green

New-Item -ItemType Directory -Force build | Out-Null
$apk = "build/civic-chaos-map-challenge-01-debug.apk"
& $godot --headless --path . --export-debug "Android Debug" $apk
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $apk)) { throw "APK export failed" }
Get-Item $apk
```

## Live acceptance

- [ ] In PC/Android game explore the outer streets around x/z 46 and -46. The player sees the roadside yellow S BEND warning and chevrons; cars visibly steer in an S shape, not pass straight through the warning.
- [ ] Every car stays on pavement, holds its left-side lane and does not collide head-on with its opposite-direction neighbor.
- [ ] Left/right traffic turns at other intersections are noticeably more frequent; no U-turns, illegal or disconnected route choices appear.
- [ ] Yellow caution dots appear on the minimap and expanded map at matching outer S-bends. The route and objective remain usable.
- [ ] Check signals and pedestrian crossings on bends and the neighboring outer junctions; no early wrong-way signal overrides, blind lane departures or NPC collisions.
- [ ] Start Wrong Way and Illegal Parking. The local street involved in their physical missions remains unchanged. Both missions, authorized marshal action and traffic recovery still function.
- [ ] After 5 minutes the city still has controlled inflow and an increasing number of completed journeys, rather than filling with stopped cars.
- [ ] Test two full signal rotations, F5/F9 reload, Android Compatibility frame times, 8/12 active cars and all road warning signs.

**No Godot runtime executed in the GitHub-editing environment. The source implementation is not proof of a safe release.** If tests fail, fix before exporting the APK. Do not manually trigger GitHub Actions.
