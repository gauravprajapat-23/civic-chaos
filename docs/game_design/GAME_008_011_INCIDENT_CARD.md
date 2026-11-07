# GAME-008 / GAME-011 — Guided Incident Card
Date: 2026-11-06 | Branch `fix/regression-nov05` | Status **CODE COMMITTED; ENGINE NOT RUN**.

## What was built
- `scripts/ui/civic_incident_card.gd`: responsive, elevated CanvasLayer modal with location, visible evidence, active incident status, safe-action instructions, explicit **Inspect Evidence**, **Report to Municipal Service**, and **Close** buttons. UI blocks clicks behind the card and uses 52 px high buttons for touch.
- `scripts/civic/gameplay_session.gd`: opening a marker now emits a card request, not an automatic civic report. The explicit `perform_incident_action(player, action)` checks the actual actor, current distance, incident stage, prior evidence and duplicate reports. Old direct regression helper retains the same checked two-step flow.
- `scripts/core/main.gd`: mounts the modal above HUD and touchscreen controls, switches to visible cursor while open, temporarily freezes player movement/input, and restores controls when dismissed. Closes the modal before pausing or loading another snapshot.
- `scripts/civic/incident_marker.gd`: an in-world **E / USE • INSPECT** instruction over the orange footpath obstruction.
- `tests/gameplay_incident_card_test.gd`: exercises out-of-range opening, locked report, evidence unlock, moved-away denial, valid report, duplicate denial, close, and actual node removal. Registered in local regression runner.

## How to play
1. Start Civic Chaos in Godot. Follow the orange obstruction on the north footpath, roughly x=5, z=-14.
2. Aim toward the orange crate; press **E** on PC or **USE** on the touch HUD. The incident detail card should open.
3. Press **Inspect Evidence**. Only then should **Report to Municipal Service** become available.
4. Submit the report, close the card, and observe the municipal service outcome after the delay. The obstruction should disappear only when the simulation reaches the intervention stage.
5. Check the mission objective, Safety/Efficiency/Trust/Cooperation HUD and F5/F9 save/load. A second report must not grant points.
6. On PC, Escape or the Close button should dismiss the card. On mobile, touch buttons must be usable without pressing movement controls underneath.

## Scope / limitations
This is an explicit-action tutorial UI, **not yet a branching dialogue system**. A cooperative owner-request path, simulated helper arrival, wrong-way vehicle and real traffic recovery are separate GAME-012 onward tasks. Full Android touch verification and a human game walkthrough remain outstanding.

## Commands (PowerShell)
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/gameplay_incident_card_test.gd
python tools/run_regression.py --godot $godot --timeout 60 --report build/game-008-011-regression.json
Write-Host "Exit code: $LASTEXITCODE"
```

User's existing `build/regression-report.json` remains separate. No manual GitHub Actions dispatch. The repository has an automatic push-triggered workflow that may run independently.
