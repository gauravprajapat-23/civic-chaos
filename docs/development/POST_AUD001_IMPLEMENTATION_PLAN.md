# Civic Chaos — Post-AUD-001 development sequence

This sequence applies the uploaded **utility-AI**, **game UI/UX/input**, and **performance-optimization** skills to the actual Godot 4.7.2 game. These are **future gameplay changes**, not part of the current AUD-001 stabilization commit.

## Release condition (must happen first)

PR [#49](https://github.com/gauravprajapat-23/civic-chaos/pull/49) is draft. Do not enable any of the three following gameplay changes until its precise branch SHA passes:

1. Godot 4.7.2 headless import and all 20 focused checks.
2. All 100 mandatory GDScript tests, four nonempty matching deterministic state replays and the deliberate negative-path failure.
3. At least 30 Python QA tests, static resource preflight, clean source tree and matching `source_commit`/Git HEAD.
4. Manual district playthrough, F5/F9 and Free Roam checkpoint acceptance before releasing to users.

The local verifier now calls `tools/check_game024_gate.py` at its end. This independent **read-only** checker will fail closed on absent, incomplete, mismatched, stale or malformed evidence and produce a nonzero exit. It never runs GitHub Actions or writes a passing report.

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git switch fix/aud-001-game024-gate-hardening
git pull --ff-only origin fix/aud-001-game024-gate-hardening
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_game024.ps1 `
  -ExpectedBranch "fix/aud-001-game024-gate-hardening" -Timeout 120
python .\tools\check_game024_gate.py
```

If either command exits nonzero, **resolve the first actual log failure on this branch first**. Never mark gameplay milestones ready based on source review or passing test markers alone. The current authoring environment does not have the Godot binary; Godot acceptance has not happened here.

## Post-gate milestones

| Sequence | GitHub issue | Skill-driven implementation | Acceptance |
| --- | --- | --- | --- |
| 1. AI stability | [#50](https://github.com/gauravprajapat-23/civic-chaos/issues/50) | Deterministic NPC utility action hysteresis with instant safety overrides; integrate with walking routines only after standalone tests | 120-tick near-tie stability, instant red-signal refusal, deterministic replay, no score/save mutation |
| 2. Mobile UI | [#51](https://github.com/gauravprajapat-23/civic-chaos/issues/51) | Responsive touch/safe-area layout and mission/HUD coexistence on phones/tablets | Simulated viewport geometry tests, real Android orientation/safe-inset screenshots, no input hitbox overlap |
| 3. Performance | [#52](https://github.com/gauravprajapat-23/civic-chaos/issues/52) | Baseline profiling, then fix only the measured leading crowd/traffic bottleneck | Same-scene before/after median/p95 frame time, physics/scripts/render split, draw calls, actor counts, no regression |

### Measurements and rollback discipline

- **AI:** Use `CivicNpcUtilityEngine` as the single raw scoring source; never use timers or wall-clock randomness to break ties. Give safety constraints precedence over hysteresis and preserve checkpoint determinism.
- **UI:** Drive positions from visible safe rectangle, not platform-specific magic offsets. Touch targets and captions must derive from the same calculated rectangles. Maintain keyboard/gamepad as first-class input.
- **Performance:** Profile representative desktop and Android devices **before** changing `district_pedestrians.gd`, `traffic_spawner.gd`, physics layers, asset LOD or node pooling. Suggested design targets (not achieved): 60 FPS desktop (~16.7ms/frame), 30 FPS mobile (~33.3ms/frame). Report hardware, viewport, release/debug build, count and seed. Optimize one identified hotspot, then repeat the measurement.
- Keep each milestone's code/tests/docs separate and committed `[skip ci]` on its requested branch. Do not edit/dispatch GitHub workflows. Do not merge a PR until its own regressions and target-device acceptance pass.

**Status as of this document:** Gate tooling and follow-up issues prepared; a standalone NPC stability policy and headless regression are staged, but live NPC AI, mobile UI behavior and performance optimization have **not** been activated. See `AI_01_NPC_DECISION_STABILITY.md`. No measured FPS claims are made.
