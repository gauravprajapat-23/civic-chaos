# GAME-001 — Verification Gate (2026-11-06)
Branch: `fix/regression-nov05`. Scope: NPC crowd/separation and distant-building LOD. **Status: REQUIRES USER GODOT RUN**.

## Baseline
- Most recent user engine report on older commit `927fc8f`: Godot 4.7.2 import passed, 45 tests passed, 1 failed in forced overlapping pedestrian recovery. Subsequent fix `5ecb184` not verified by user.
- Building LOD fix at `79b2148` adds distant visibility integration coverage; no user-engine result provided for that commit.
- Source review confirms: NPCs use soft collisions and recovery search; LOD controller preserves meshes lacking proxies. These are structural checks, not proof of actual on-device behavior.

## Local commands (PowerShell)
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/pedestrian_spawn_separation_test.gd
& $godot --headless --path . --script res://tests/graphics_lod_test.gd
& $godot --headless --path . --script res://tests/building_distance_lod_test.gd
python tools/run_regression.py --godot $godot --timeout 60 --report build/game-001-regression.json
Write-Host "Exit code: $LASTEXITCODE"
```
Do not overwrite the user's modified `build/regression-report.json`. Do not use GitHub Actions. Check actual game by approaching two NPCs near the crossing and viewing buildings from >150 m in PC HIGH and mobile LOW quality.

## Exit
- [x] Source paths, regression registrations and latest commits inspected
- [ ] Latest Godot import passes
- [ ] NPC overlap forced test passes on latest head
- [ ] Building distance tests pass on latest head
- [ ] Full local regression passes
- [ ] In-game NPC spacing and distant building visuals acceptable

GAME-001 cannot be labeled verified until the checks above are supplied.
