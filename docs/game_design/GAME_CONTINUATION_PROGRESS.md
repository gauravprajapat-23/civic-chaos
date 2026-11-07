# Civic Chaos — Continued Development Progress
Date: 2026-11-06 · branch `fix/regression-nov05` · **Engineering changes pushed, latest Godot 4.7.2 run pending**.

## Delivered in this batch (source-level, not accepted)
| Task | What changed | Evidence created | State |
|---|---|---|---|
| GAME-003 / PHYS-011 | Opposite-direction city traffic now has 2.5 m mid-road centerline separation (left-hand traffic). Tapers into exact intersection endpoints to preserve route connectivity and existing tests; immediate U-turn exits remain excluded. | `tests/two_way_lane_separation_test.gd` | CODE ADDED / ENGINE NOT RUN |
| GAME-005 / PHYS-014 | Stalled pedestrian may relinquish a crossing reservation **before entering** road conflict zone after a bounded timeout; cannot time-release physically occupied crosswalk. | `tests/pedestrian_crossing_recovery_test.gd` | CODE ADDED / ENGINE NOT RUN |
| GAME-010 | Composite F5/F9 saves player + versioned civic mission/incident/city metrics state, validates snapshot, preserves duplicate-reward prevention. Normalizes JSON whole-number fields locally rather than weakening strict manager contracts. | `tests/gameplay_persistence_test.gd` | CODE ADDED / ENGINE NOT RUN |
| GAME-009 | Civic HUD now shows live Safety, Efficiency, Trust and Cooperation, alongside reputation, incident and traffic status. | `tests/civic_hud_test.gd` extended | CODE ADDED / ENGINE NOT RUN |

## Known limitations / next coding priorities
1. **GAME-001 is not verified:** last user-supplied Godot run at earlier commit `927fc8f` had 45 PASS / 1 FAIL (`pedestrian_spawn_separation_test.gd`). New NPC recovery and LOD fixes await a fresh run.
2. **GAME-003 is partial:** opposite lanes separated mid-road, but they rejoin center for junction continuity; full curved left/right-turn connectors, right-of-way at noncentral intersections, and traffic/terrain playtests remain.
3. **GAME-005 is partial:** crossing timeout only reclaims *pre-entry* stale reservations; a person stuck **inside** the road keeps collision priority, as required for safety. Future recovery must provide a physically safe way to leave the road. NPC overlap recovery still has visible teleport risk.
4. **GAME-006 is partial:** first player-facing footpath report/cleanup scenario lives in `scripts/civic/gameplay_session.gd`; actual 3D interaction must be verified. It is not the complete wrong-way car mission.
5. **GAME-008 / 011:** build a focused incident detail card, safe action choices, tutorial guidance and touch input.
6. **GAME-010 follow-up:** do save/load tests after corruption, old player-only saves, paused save, recovery to safe spawn; protect atomicity of session/player restore on unexpected scene faults.
7. **GAME-012–015:** integrate **actual** illegal-route vehicle, real queue telemetry, authorized marshal response and safe traffic recovery; never award a mission for synthetic queue counters.
8. **G3 onward:** parking/litter missions, district feedback, NPC reactions, audio/art and Android performance/release.

## Local PowerShell validation
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit

& $godot --headless --path . --script res://tests/pedestrian_spawn_separation_test.gd
& $godot --headless --path . --script res://tests/building_distance_lod_test.gd
& $godot --headless --path . --script res://tests/two_way_lane_separation_test.gd
& $godot --headless --path . --script res://tests/pedestrian_crossing_recovery_test.gd
& $godot --headless --path . --script res://tests/gameplay_session_test.gd
& $godot --headless --path . --script res://tests/gameplay_persistence_test.gd

python tools/run_regression.py --godot $godot --timeout 60 --report build/game-continuation-report.json
Write-Host "Regression exit: $LASTEXITCODE"
```

`graphics_lod_test.gd` and `civic_hud_test.gd` are discovered by the regression runner from the existing workflow manifest. The separate `--report` path avoids overwriting a locally modified `build/regression-report.json`.

## Manual walkthrough
1. Start main game from the menu. Confirm no NPC overlap and no distant building shell disappearance.
2. At Market Chowk, approach the orange **FOOTPATH BLOCKED** crate at x≈5 z≈−14. Press E to inspect, E again to report. The city service should remove it after the response period.
3. Observe objectives, incident count, reputation and the **four** civic scores on the HUD; one report/reward only.
4. Mid-report press F5 (save), restart, F9 (load); confirm progress and the obstruction state survive.
5. Walk near oncoming vehicles and crossings; look for head-on overlaps, near-intersection snapping, stuck NPCs and traffic stops. Capture screenshots and errors.

## Verification statement
All source changes were pushed through GitHub. They have **not** been executed in a Godot 4.7.2 runtime in this assistant environment; any direct statements about passing test results must come from the user's supplied output. No workflow was manually dispatched; a push-triggered GitHub Actions configuration exists, so automated runs could occur independently of manual dispatch.
