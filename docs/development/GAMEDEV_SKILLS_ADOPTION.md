# Civic Chaos — Game-development skills adoption

**Source reviewed:** user-supplied `awesome-gamedev-agent-skills-main.zip`, an Apache-2.0 catalog by Abhishek Barali and contributors. Its `router/SKILL.md` selects specific skills; it is not a Godot addon or drop-in game runtime. We integrate its methods into Civic Chaos, **not** its unrelated Unity/Unreal/Roblox code or GitHub Actions.

## Install optional local skill references

From the repository root in Windows PowerShell, with the uploaded ZIP saved locally:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\install_gamedev_skills.ps1 -ZipPath "C:\path\to\awesome-gamedev-agent-skills-main.zip"
```

The installer copies only relevant Markdown skill instructions/references and the original license/notice to `.agent-skills/`, which is gitignored. It does **not** execute scripts, copy workflow definitions, install packages, change game assets or trigger CI. The repository's own `AGENTS.md` remains the enduring routing guide.

## Skill selection and acceptance criteria

| Priority | Relevant skills from uploaded pack | Where applied / expected behavior |
| --- | --- | --- |
| P0, AUD-001 | `godot-gdscript-headless-testing`, `godot-gdscript` | `tools/run_regression.py` requires nonzero failure exit, test-specific PASS marker, no engine errors, headless import, bounded runs, and **identical recorded gameplay state** on deterministic replays. `wrong_way_mission_test.gd` no longer relies on bare assertions. |
| P0, AUD-001 | `godot-physics`, `physics-tuning` | Real collision-space queries run on physics frames. Car spawning, walker restore, F9 restore and player placement must not collide or modify live actors on rejected checkpoints. |
| P0, AUD-002 | `save-systems`, `godot-resources` | F5/F9 across wrong-way, illegal parking, cleanup, finale, free roam. Verify v1->v2 save migration, checksum/fallback, duplicate rewards, exact player/world state, and rollback with real colliders. |
| P1, GAME-025 | `ai-behavior-trees-utility-ai`, `game-ai` | NPCs pick safe actions from the blackboard, use normalized considerations, deterministic seeds and action hysteresis against decision flicker. Keep daily routines opt-in until campaign tests pass. |
| P1, GAME-026 | `game-ui-ux`, `godot-ui-control`, `input-systems` | Audit mission guide/HUD/on-screen controls on 16:9, tall Android, tablets; add safe areas, readable contrast and touch/gamepad focus behavior. |
| P1, performance | `performance-optimization`, `godot-3d-essentials` | Capture measured CPU/physics/GPU/VRAM metrics with crowd/city worst-case. Set mobile frame and entity budgets from actual measurements, not guessed optimizations. |
| P2, polish | `game-feel`, `audio-design`, `camera-systems` | Improve feedback, ambient civic reactions and camera stability after acceptance, without affecting mission scoring or determinism. |

## Applied in this milestone: deterministic headless acceptance

The uploaded headless-testing skill explicitly warns that bare `assert()` can halt `SceneTree` execution before `quit()`, and that the exit code must be checked. We use explicit `_fail()` + `quit(1)`, positive `quit(0)`, and failure logs. We additionally harden the existing replay harness:

- `determinism_test.gd` records deterministic clock tick log and seeded RNG sequence.
- `wrong_way_mission_test.gd` performs explicit checks for reports, queue clearance, intervention, completion and one-time rewards; it records mission state, incident state, queue and rewards.
- `traffic_budget_test.gd` records deterministic sample counts, peaks, averages and limits.
- `tools/run_regression.py` compares nonempty `CIVIC_CHAOS_REPLAY_STATE ` trace lines between both runs and refuses identical PASS markers with different gameplay states.
- `tests/test_regression_runner.py` verifies correct trace extraction and rejection of missing, divergent or errored replays.

Keep the deterministic trace small, canonical and free of wall time, node instance IDs, frame durations, file paths or memory addresses. The regression log is evidence of logical determinism on one Godot release, not a cross-version binary-identical promise.

## Release gate and evidence

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/aud-001-game024-gate-hardening
git pull --ff-only origin fix/aud-001-game024-gate-hardening
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_game024.ps1 `
  -ExpectedBranch "fix/aud-001-game024-gate-hardening" -Timeout 120
Get-Content .\build\game-024-verification.json
```

The gate checks Python unit tests, resource preflight, Godot 4.7.2 import, focused tests, all discovered mandatory GDScript fixtures, state replays, intentional negative-path, and exact Git revision. Keep PR #49 draft until the real Windows Godot/Android evidence passes. **Do not run GitHub Actions.**

**Current evidence limitation:** Godot 4.7.2 and Windows PowerShell are unavailable in the authoring environment. The new source/test contracts are committed, but engine execution and full gameplay playthrough still need to happen locally.
