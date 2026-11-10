# Civic Chaos — Game development agent guide

Civic Chaos is an **offline-first Godot 4.7.2, 3D, mobile + desktop** civic-sense simulation. Keep its GDScript implementation and existing save format compatible unless a milestone explicitly changes them.

## Skill routing

For each coding task, choose the smallest useful set of skills from **awesome-gamedev-agent-skills** (Apache-2.0, Abhishek Barali and contributors). See `docs/development/GAMEDEV_SKILLS_ADOPTION.md` for local installation and project-specific acceptance criteria.

| Work area | Read these skills |
| --- | --- |
| Godot scripts and scenes | `godot-gdscript`, `godot-nodes-scenes`, `godot-3d-essentials` |
| Traffic, collisions and movement | `godot-physics`, `physics-tuning` |
| NPC routines and civic decisions | `ai-behavior-trees-utility-ai`, `game-ai` |
| Checkpoints / district campaign | `save-systems`, `godot-resources` |
| HUD, controls and Android UI | `game-ui-ux`, `godot-ui-control`, `input-systems` |
| Crowd and city scalability | `performance-optimization`, `godot-3d-essentials` |
| All coding changes | `godot-gdscript-headless-testing` |

Use the catalog's `router/SKILL.md` when the area is unclear. The optional local copy lives under `.agent-skills/` (ignored by Git); the repository remains usable without it.

## Required engineering behavior

- Work on the **existing requested branch**. Do not trigger, modify or run GitHub Actions. Commit messages use `[skip ci]`.
- Keep physics queries and world restoration in safe physics callbacks. Avoid engine work on input/UI events.
- Write headless Godot `SceneTree` regression fixtures with an explicit `quit(1)` on failure, `quit(0)` on success and a unique `CIVIC_CHAOS_*_PASS` marker. Do **not** rely on bare `assert()` in runners.
- For seeded traffic and NPC logic, test observable state replay, not only success messages. Preserve intended randomness with stable seeds.
- Version save data, validate it before applying actors, and preserve recoverable generations/rollback semantics.
- Measure performance with Godot's profiler before optimization; distinguish CPU logic/physics from GPU rendering and maintain mobile budgets.
- Never claim import, Godot regression, Android build or manual playtest success without the actual logs/results. Static source inspection is not runtime acceptance.

## Post-stabilization gameplay development gate

**Do not begin or enable gameplay changes** in utility-AI decision stability, responsive Android touch/HUD layout or crowd/traffic performance optimization while AUD-001 is unverified. Their ordered, executable requirements are in `docs/development/POST_AUD001_IMPLEMENTATION_PLAN.md` and GitHub issues #50, #51 and #52.

After running the full Windows Godot 4.7.2 gate on an exact clean commit, run `python tools/check_game024_gate.py`. It must return `ready: true` with exit code 0 before starting the new milestones. The checker validates matching commit evidence, 100 Godot fixtures (including four state replays), 20 focused checks, 30 Python QA tests, import, preflight and negative path. A report left over from another commit is **not** proof. Live game systems remain unchanged until the gate actually passes; isolated opt-in AI logic and its tests may be staged but must not be wired to pedestrians.

## Local verification (never launch CI)

On the Windows checkout, first import with Godot 4.7.2, then run `tools/verify_game024.ps1 -ExpectedBranch "fix/aud-001-game024-gate-hardening" -Timeout 120` while AUD-001 is active. The gate owns focused tests, discovered full regressions, deterministic replay traces, deliberate failure-path verification and revision-matched evidence. Do not merge draft PR #49 until all required local evidence passes.
