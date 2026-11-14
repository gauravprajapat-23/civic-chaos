# CAR-ART-04 — Vehicle Collision & Visual Redesign Tracker

**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** IN PROGRESS — 04A and 04B/C implementation committed; Godot/device acceptance pending  
**Scope:** Fix character sinking through open sedan; improve cabin, mirrors, materials and physical reliability without changing traffic/checkpoint behavior.  
**Working rules:** Same branch, commits `[skip ci]`, no manual GitHub Actions, no merge without approval.

## User-visible problem and root-cause hypothesis

Screenshot (2026-11-14): player appears embedded in open-looking red car, side mirrors resemble detached dark rods, and bright paint/glass materials are too flat. Source inspection establishes that `player_root.tscn` collides with **world layer 1 only**, deliberately not vehicle layer 4; `player_controller.gd` used a horizontal-only vehicle sweep at one vertical height. It did not protect against **falling into a vehicle footprint from above**. The vehicle still uses the fixed body box and route simulation. Claims about successful visual restoration require live screenshots.

## Workstream and acceptance register

| ID | Priority | Task | Code status | Evidence and exit gate |
|---|---|---|---|---|
| CAR-ART-04A-01 | P0 | Airborne horizontal vehicle sweep at current/projected vertical positions | **COMMITTED** `8c33548` | `player_vehicle_contact_test.gd`, new airborne test |
| CAR-ART-04A-02 | P0 | Safe non-climbable descent recovery beside car; never push into another solid body | **COMMITTED** `8c33548` | `car_art_04a_jump_clearance_test.gd` and actual jumping gameplay |
| CAR-ART-04A-03 | P0 | Regression for jump into center and car side; world ground remains the only floor | **TESTS COMMITTED** `2be2bfd`, `1a1b890` | PASS in Godot 4.7.2, no SCRIPT ERROR |
| CAR-ART-04A-04 | P0 | Verify existing checkpoint, traffic, player-car collision behavior unaffected | **PENDING** | Exact revision full GAME-024 gate + regression |
| CAR-ART-04B | P1 | Refine tapered cabin, inset windscreen/rear/side glass, pillar and roof positioning | **CODE COMMITTED** `485f392` | `car_art_04bc_visual_test.gd`, screenshots front/rear/side/3/4 |
| CAR-ART-04C | P1 | Replace oversized mirrors with compact mounts, casing and rear-facing reflective glass | **CODE + TEST COMMITTED** `485f392`, `cb0d7e4` | `car_art_04bc_visual_test.gd`; review both sides in Godot |
| CAR-ART-04D | P1 | Restrained real-world-inspired paint, window, trim, wheel and lighting palette | **TODO** | PC and Android GL-compatibility screenshot comparison |
| CAR-ART-04E | P0 | Full visual regression / Android APK playtest and performance comparison | **TODO** | Collision tests, GAME-024 and device measurement |

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

## Review notes and decisions

- **2026-11-14:** Screenshot and source diagnosis complete. Implemented 04A before visual changes to isolate a gameplay P0. The prior parking/traffic acceptance remains separate; the newly authored code has **not** yet received user-reported Godot test results.
- **2026-11-14:** CAR-ART-04B/C code committed: repositioned glass within tapered cabin, reduced mirror projection, added attachment mounts, separate casing and blue-gray rear-facing metallic mirror glass. New geometry/material contract test; no colliders or traffic logic changed. **Test and visual results pending.**
- Next implementation: **CAR-ART-04D — automotive paint, glazing and trim**, followed by 04E Android and full regression verification.
