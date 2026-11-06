# Civic Chaos — Audit-Based Implementation Roadmap
Date: 2026-11-06 · Planning only; do not start broad fixes until report is reviewed.

## Phase 1 — Stabilize startup (P0)
**BUG-001:** Fix street furniture StaticBody3D/Node3D type mismatch; test import, instantiate street props and verify every collider exists. **BUG-010:** Update inaccurate comments and add type-safe scene tests. Exit: no parse/script errors and import+smoke passes.

## Phase 2 — Collision and gameplay safety (P1)
**BUG-002:** NPC physics controller: correct capsule contact, spawn clearance, player/NPC avoidance, no riding on NPC heads. **BUG-003:** Define vehicle motion/collision policy and physical obstacle detection; preserve fixed-tick determinism and car-following. Exit: executable contact scenarios with player, cars, NPCs, props; reproducible low-FPS and fixed-seed runs.

## Phase 3 — World consistency (P2)
**BUG-005:** Consolidate ground collision and align terrain/roads/sidewalks. **BUG-006:** Validate safe load positions. **BUG-004:** Build one shared topology source for visual roads and lane graph; connect secondary roads; update spawn, traffic signals, pedestrian crossings, and routing. Exit: connected graph, no out-of-bounds fall, vehicles traverse new streets, pedestrians walk extended blocks.

## Phase 4 — Civic gameplay
Trace actual mission activation, completion, rewards, event director and metrics; add end-to-end tests for **Explore → Observe → Respond → Reward → City improvement**. Mark absent features as backlog, not bugs. Exit: one complete and repeatable gameplay loop.

## Phase 5 — Graphics and animation
**BUG-007:** Fix missing far LOD representation. **BUG-008:** Secondary road material. **BUG-009:** HUD title. Add a cohesive stylized lighting/material pass and animation transitions. Exit: PC/Android visual review with before/after captures and no disappearing buildings.

## Phase 6 — Performance and Android
Profile **PERF-RISK-001/002** first; then reuse resources, batch meshes, spatialize NPC checks if measurements justify it. Benchmark Intel integrated GPU and mid-range Android; verify touch safe areas, orientation, GL Compatibility and export. Exit: documented measurements, no severe spikes, acceptable device behavior.

## Phase 7 — Release validation
Run complete local regression, deterministic replay, negative-path test, long simulation, save/load, collision and boundary stress tests. Validate Windows and Android packaging. Exit: no open P0/P1, documented P2 exceptions, signed release checklist.

## Execution workflow
1. Checkout `fix/regression-nov05`; confirm clean worktree.
2. Do not run GitHub Actions.
3. For each issue, reproduce, write failing regression, implement minimal fix, run import and relevant tests, commit, then update issue status.
4. Do not claim local tests pass unless actual Godot output confirms them.
5. Do not close issues without acceptance evidence.

## Windows verification commands
```powershell
git fetch origin fix/regression-nov05
git merge --ff-only origin/fix/regression-nov05
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --import --quit
python tools/run_regression.py --godot "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --timeout 60
Write-Host "Exit code: $LASTEXITCODE"
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path .
```

**Audit verification:** GitHub source reviewed; Godot import, regressions, gameplay tests and device profiling **NOT RUN** in the audit environment.
