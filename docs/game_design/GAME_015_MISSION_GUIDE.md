# GAME-015 — Navigation, Dialogue and Safe Mission Recovery

Date: 2026-11-06 · Branch: `fix/regression-nov05` · **Source committed; Godot runtime verification pending**

## What changes in gameplay
A player no longer has to guess where the orange tutorial obstruction or yellow wrong-way reporting post is.

- `CivicMissionGuide` displays a clear current-mission title, **NEXT** objective, real-world waypoint **direction + distance**, and conversational feedback from the neighborhood radio or traffic marshal.
- Navigation uses the actor and camera's actual world orientation and physical marker position. It does **not** invent queue telemetry, cheat an objective, or move the player.
- The tutorial guidance updates from finding the obstruction → inspecting evidence → submitting a civic report → waiting safely for municipal cleanup → unlocking Wrong-Way Disaster.
- Wrong-Way Disaster guidance updates from spotting a physical stopped queue → approaching the yellow sidewalk report post → inspecting → reporting → marshal response → authorized towing → checking actual traffic recovery → completion.
- Existing `CivicStatusHUD` continues to show live city scores and actual stopped cars; the new guide complements it with accessible instructions rather than internal event identifiers.
- The marshal receives a simple visible speech label that repeats recent feedback. Full voice acting and animation remain future art/audio tasks.

## Stalled-service recovery
A new **non-destructive watchdog** detects approximately 1,800 physics ticks without meaningful advancement after an authorized report (approximately 30 seconds at 60 physics ticks/sec). A stop/go traffic-signal delay or blocked tow does **not** automatically create failure points, award a mission, remove physical vehicles, or reset a save.

If service is stalled:
1. The mission guide explains that real traffic or obstacles are preventing progress.
2. **Reload checkpoint** asks the existing F9 load implementation to restore a valid saved civic/physical mission state. If no valid saved checkpoint exists, nothing is claimed as restored.
3. **Restart level** opens a `ConfirmationDialog` warning that unsaved progress will be lost. Only confirmation invokes the existing level restart action.
4. If the service resumes naturally, the watchdog hides the recovery controls and announces that progress is continuing.
5. During healthy play and before a report, retry/restart recovery buttons are hidden and cannot be invoked from the guide.

**This is soft stalled-state recovery, not a punitive GAME-015 failure state.** No change to `CivicMissionManager` reward semantics and no background auto-teleports are introduced.

## Code and test coverage
- `scripts/ui/civic_mission_guide.gd`: UI panel, direction helper, accessibility-sized buttons, radio/marshal messages, confirmation dialog and only two permitted recovery action signals.
- `scripts/civic/gameplay_session.gd`: tutorial `guidance_state` derived from actual mission objective progress and obstruction node.
- `scripts/civic/wrong_way_live_mission.gd`: event-phase `guidance_state`, `_update_recovery_watchdog`, safe stalled/recovered feedback, visible marshal speech.
- `scripts/core/main.gd`: mounts the guide, updates from player/camera + real mission, hides the guide during pause, and maps recovery actions through existing validated F9 and restart paths.
- `tests/mission_guide_test.gd`: directional hints, visible speaker/objectives, no premature recovery, opt-in reload, restart confirmation signaling.
- `tests/mission_guidance_flow_test.gd`: tutorial objectives, physical report-post referent, no premature retry, timeout without rewards, and recovery after measurable towing progress.
- `tools/run_regression.py`: both new regressions registered. Existing strict Godot `ERROR:/SCRIPT ERROR:` checks remain in force.

## Local Godot 4.7.2 acceptance (Windows PowerShell)
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
& $godot --headless --path . --script res://tests/mission_guide_test.gd
if ($LASTEXITCODE -ne 0) { throw "Mission guide test failed" }
& $godot --headless --path . --script res://tests/mission_guidance_flow_test.gd
if ($LASTEXITCODE -ne 0) { throw "Guidance flow test failed" }
& $godot --headless --path . --script res://tests/wrong_way_checkpoint_test.gd
if ($LASTEXITCODE -ne 0) { throw "Checkpoint regression failed" }
python tools/run_regression.py --godot $godot --timeout 90 --report build/game-015-guide-regression.json
Write-Host "Exit code: $LASTEXITCODE"
```

Expected new markers:
- `CIVIC_CHAOS_MISSION_GUIDE_PASS`
- `CIVIC_CHAOS_MISSION_GUIDANCE_FLOW_PASS`

Use a separate report file, leaving your modified `build/regression-report.json` alone.

## Manual walkthrough
1. Play Market Chowk with PC controls. Check upper-right mission panel shows distance/LEFT/RIGHT/AHEAD to the **orange footpath crate**.
2. Press E near the crate; inspect evidence, then report. The objective text should change after each action; the path remains blocked until municipal cleanup.
3. Follow the updated objective and actual world waypoint to the yellow report post. Confirm it does not enable reporting before the real queue forms.
4. Inspect and report. Watch the marshal's text change as the service responds, and observe tow and follower movement.
5. For a reproducible *test-only* stalled service, use a controlled environment or temporary obstruction; the guide should offer checkpoint recovery after sufficient no-progress time and hide it once physical progress resumes.
6. In normal play, verify that **Restart level** requires confirmation, the mission doesn't grant points on a stall, and the guide hides when F1 pause is active. Check camera-relative direction in several orientations and mobile touch button sizes.

## Remaining limitations / next iterations
- This is a text-and-waypoint mission guide, not a minimap with pathfinding; it points to the genuine marker, not a safe route through every building/traffic obstacle.
- Background traffic and signal phases are still independent of the GAME-014 checkpoint; a staged reload may defer if vehicles obstruct it.
- No sound effects/voice recording, lip sync, localization text table, cinematic camera or elaborate branching dialogue in this batch.
- Full 3D NPC movement, visual tow completion and Android device UI need hands-on testing.
- **GAME-013/014 runtime verification is still pending** from the latest branch. Do not mark GAME-015 accepted until the fresh import, focused tests, full strict runner and PC walkthrough pass.

## Checklist
- [x] Feature source pushed to GitHub
- [x] Focused regression tests written and registered
- [x] Static repository consistency reviewed
- [ ] Godot 4.7.2 import passes on latest commit
- [ ] New tests and full strict suite pass
- [ ] PC walkthrough with accessible controls and correct waypoints
- [ ] Recovery reload and level restart confirmation manually checked
- [ ] Mobile display, focus and touch interaction checked

No GitHub Actions were manually triggered; repository push workflows may run automatically.
