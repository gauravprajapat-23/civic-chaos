# CAR-ART-04 — Vehicle Collision & Visual Redesign Tracker

**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** IN PROGRESS — 04A side-contact fixture fix committed; 04E local gate prepared, device acceptance pending  
**Scope:** Fix character sinking through open sedan; improve cabin, mirrors, materials and physical reliability without changing traffic/checkpoint behavior.  
**Working rules:** Same branch, commits `[skip ci]`, no manual GitHub Actions, no merge without approval.

## User-visible problem and root-cause hypothesis

Screenshot (2026-11-14): player appears embedded in open-looking red car, side mirrors resemble detached dark rods, and bright paint/glass materials are too flat. Source inspection establishes that `player_root.tscn` collides with **world layer 1 only**, deliberately not vehicle layer 4; `player_controller.gd` used a horizontal-only vehicle sweep at one vertical height. It did not protect against **falling into a vehicle footprint from above**. The vehicle still uses the fixed body box and route simulation. Claims about successful visual restoration require live screenshots.

## Workstream and acceptance register

| ID | Priority | Task | Code status | Evidence and exit gate |
|---|---|---|---|---|
| CAR-ART-04A-01 | P0 | Airborne horizontal vehicle sweep at current/projected vertical positions | **COMMITTED** `8c33548` | `player_vehicle_contact_test.gd`, new airborne test |
| CAR-ART-04A-02 | P0 | Safe non-climbable descent recovery beside car; never push into another solid body | **COMMITTED** `8c33548` | `car_art_04a_jump_clearance_test.gd` and actual jumping gameplay |
| CAR-ART-04A-03 | P0 | Regression for jump into center and car side; world ground remains the only floor | **SIDE FIX COMMITTED** `3d436d7` | 04A direct-fall PASS reported; side test failed before fix, must rerun |
| CAR-ART-04A-04 | P0 | Verify existing checkpoint, traffic, player-car collision behavior unaffected | **PENDING** | Exact revision full GAME-024 gate + regression |
| CAR-ART-04B | P1 | Refine tapered cabin, inset windscreen/rear/side glass, pillar and roof positioning | **CODE COMMITTED** `485f392` | `car_art_04bc_visual_test.gd`, screenshots front/rear/side/3/4 |
| CAR-ART-04C | P1 | Replace oversized mirrors with compact mounts, casing and rear-facing reflective glass | **CODE + TEST COMMITTED** `485f392`, `cb0d7e4` | `car_art_04bc_visual_test.gd`; review both sides in Godot |
| CAR-ART-04D | P1 | Restrained paint with clearcoat, opaque window/mirror glass, tire/hub material contrast, light emission | **CODE + TEST COMMITTED** `a78ae39`, `d2bf7d6`, `8640e9b` | `car_art_04d_materials_test.gd`; PC/Android screenshots pending |
| CAR-ART-04E | P0 | Full vehicle QA with fail-closed local Godot gate and optional debug APK | **QA RUNNER COMMITTED** `dd8e295`, `0653352` | `tools/car_art_04e_verification.ps1`; full GAME-024 and device evidence pending |

**Important:** A committed change is not a passed test. Keep status **PENDING** until local outputs are recorded. Do not assert that the new player recovery eliminates all penetrations without a full playthrough.

## Implementation details: phase 04A

- `scripts/player/player_controller.gd` now checks the requested horizontal motion both at the current capsule height and the predicted vertical height. It takes the most restrictive safe travel fraction.
- The player remains layer 2 with mask 1; the car remains layer 4, and **car roofs remain non-climbable**.
- While descending, if a capsule is already intersecting a vehicle body, a recovery helper chooses a nearby car perimeter candidate, shortest displacement first. It checks full destination occupancy against world, vehicles and pedestrians before moving; if no candidate is safe it does not move. This avoids adding rigid collision to the pedestrian/traffic simulation.
- No vehicle path, collision shape, save schema, lane data, or random state changed in this batch.

## Local test commands (Windows)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git merge --ff-only origin/fix/aud-001-game024-gate-hardening
if ($LASTEXITCODE -ne 0) { throw "Git update failed" }

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
$import = & $godot --headless --path . --editor --import --quit 2>&1 | Out-String
$importExit = $LASTEXITCODE
$import
if ($importExit -ne 0 -or $import -match 'SCRIPT ERROR:|ERROR:') { throw "Import failed" }

foreach ($test in @(
    "car_art_04a_jump_clearance_test.gd",
    "car_art_04a_side_contact_test.gd",
    "car_art_04bc_visual_test.gd",
    "car_art_04d_materials_test.gd",
    "vehicle_visuals_test.gd",
    "player_vehicle_contact_test.gd",
    "car_character_clearance_test.gd",
    "vehicle_actor_safety_test.gd",
    "vehicle_pedestrian_recovery_test.gd",
    "car_safe_04_checkpoint_test.gd",
    "outer_intersection_movement_test.gd",
    "traffic_checkpoint_invariants_test.gd"
)) {
    $result = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $result
    if ($exitCode -ne 0 -or $result -match 'SCRIPT ERROR:|ERROR:') {
        throw "FAILED: $test"
    }
}
```

After focused checks, run the full `tools/verify_game024.ps1` gate on the **current** exact SHA. Manual follow-up: test drop onto red/blue cabin, sideways jump, walking around a stationary and moving car, checkpoint restoration next to vehicles. Record video/screenshots from PC and Android before marking 04A done.

## CAR-ART-04E generated Godot test UID preflight fix (2026-11-14)

The user's CAR-ART-04E local gate at `748b5bb` stopped **before Godot import or any focused test** due to six newly generated untracked `tests/*.gd.uid` files. This is a source-cleanliness false positive, **not** a collision, materials, or jump regression result.

- Added a narrow `.gitignore` rule: `/tests/*.gd.uid`. It covers Godot-generated UID sidecars for test scripts (including future tests), **not** `tests/*.gd`, `scripts/*.gd.uid`, scenes, resources, or other source.
- Kept both CAR-ART-04E and GAME-024 clean-SHA requirements strict. Git respects `.gitignore` for untracked files, so neither gate must suppress or delete legitimate changes.
- Added `tests/test_godot_uid_clean_gate.py`, asserting the six reported files and future test UIDs are ignored while real scripts and non-test resource UIDs are not. This is part of GAME-024 Python unittest discovery.
- Existing locally generated files can remain untouched. **Do not use** `git clean -fd` or `git add -f` on generated test UIDs. If any have already been deliberately tracked, the rule does not hide their modifications.
- **Local verification still pending:** run `git status --short` after pulling to verify only ignorable UIDs were present, then rerun `tools/car_art_04e_verification.ps1`; the next actual Godot test failure, if any, requires its log and new diagnosis.

## CAR-ART-04E verification and Android acceptance

The user's local Godot 4.7.2 results at `e8c7511` confirmed **PASS** for `car_art_04d_materials_test.gd`, `car_art_04bc_visual_test.gd`, `vehicle_visuals_test.gd`, and `car_art_04a_jump_clearance_test.gd`. The side-jump fixture instead failed with `jump test never left the ground`. This is not evidence that the player-car clipping bug is resolved; later fixtures were not executed.

**Fixture fix:** `car_art_04a_side_contact_test.gd` now waits for actual `is_on_floor()` after spawn, requires an airborne impulse while jump is pressed, and performs collision assertions only after the jump has occurred. No gameplay collision code was changed in this fix.

Execute the consolidated QA script on the committed source:

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git merge --ff-only origin/fix/aud-001-game024-gate-hardening
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\car_art_04e_verification.ps1
```

The runner rejects dirty source, captures each Godot test log under `build/car-art-04e/`, requires an explicit PASS marker, and calls the full GAME-024 independent evidence gate. To **optionally build a debug APK after the full gate passes**, rerun with `-BuildApk`. An exported APK is **not** a device-test pass. No GitHub Actions.

**Actual Android acceptance:** test cold start, 3 perspectives of each car color, mirrors/roof geometry, walking/jumping toward parked and moving cars, stop/resume at crowded crossings, save/load adjacent to traffic, touch controls, warm-device FPS/hitches and background/restore. Record device, renderer, Android version, screenshots/video, representative FPS and error logs; until then 04E remains **IN PROGRESS**.

## Review notes and decisions

- **2026-11-14:** Screenshot and source diagnosis complete. Implemented 04A before visual changes to isolate a gameplay P0. The prior parking/traffic acceptance remains separate; the newly authored code has **not** yet received user-reported Godot test results.
- **2026-11-14:** CAR-ART-04B/C code committed: repositioned glass within tapered cabin, reduced mirror projection, added attachment mounts, separate casing and blue-gray rear-facing metallic mirror glass. New geometry/material contract test; no colliders or traffic logic changed. **Test and visual results pending.**
- **2026-11-14:** CAR-ART-04D committed: subdued paint palette with restrained clearcoat, separate opaque mobile-friendly glazing and metallic mirror faces, more natural rubber/hub materials, less aggressive idle headlamp emission, higher wheel cylinder segments and PBR contract regression. **No actual rendered quality or Android FPS measured.**
- **2026-11-14:** User supplied local test failure `jump test never left the ground` in 04A side fixture (while four other car/visual tests passed). Fixed setup to wait for grounded body and measure an actual jump before asserting penetration. CAR-ART-04E verification script added. All new code still awaits local verification; full gate and Android acceptance remain unverified.
