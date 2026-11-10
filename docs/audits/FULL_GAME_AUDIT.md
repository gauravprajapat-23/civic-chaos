> **November 10, 2026 update:** This November 6 historical audit has been **superseded** for the current `fix/aud-001-game024-gate-hardening` branch by [AUD-002 Complete Game Source Audit](AUD_002_COMPLETE_GAME_SOURCE_AUDIT.md). Do not repeat outdated BUG-001/005/007/008 conclusions as current without checking the newer source. AUD-002 includes the complete source/102-fixture QA inventory, current release blockers, confirmed perimeter-road mismatch, mobile layout overflow, four deterministic replay requirements, and Android/performance gaps. **Actual Godot/Android acceptance remains unverified.**

# Civic Chaos — Full Game Audit
Date: 2026-11-06 · Branch: `fix/regression-nov05` · Engine target: Godot 4.7.2

## Executive summary
**Status: prototype, not release-ready.** This is a repository/source audit, not a completed playable-device validation. The central intersection, traffic spawner, player, HUD, save/load, procedural district, and test runner exist, but presence of code is not proof of runtime correctness. The latest additions have unverified collision and integration defects. No GitHub Actions were run; no Godot executable was available in the audit environment. **Godot import, regressions, gameplay, FPS, Android export: NOT RUN.**

## Scope inspected
Repository directory inventory; `project.godot`; `scenes/core/main.tscn`; `scenes/player/player_root.tscn`; `scenes/traffic/vehicle_agent.tscn`; `scenes/world/world_root.tscn`; `scripts/core/main.gd`, `game_lifecycle.gd`, `save_repository.gd`; `scripts/player/player_controller.gd`; `scripts/npc/district_pedestrians.gd`, `pedestrian_navigator.gd`; `scripts/traffic/vehicle_agent.gd`, `traffic_spawner.gd`, `road_graph.gd`; `scripts/world/neighborhood.gd`, `street_furniture.gd`, `junction_builder.gd`; `scripts/rendering/graphics_lod.gd`; `scripts/ui/touch_controls.gd`; `tools/run_regression.py`; and selected test files. **Not every repository source file or asset was line-reviewed.** Additional reviews are listed in the roadmap.

## Confirmed source-level findings
- **BUG-001 (P0):** `street_furniture.gd:58` declares `_collider(parent: StaticBody3D,...)`; `_streetlight`, `_tree`, `_trash_bin`, `_bench` create `Node3D` and pass them to it (lines 94–133). This is a static type/API mismatch. Verify whether Godot rejects it at import or at runtime; do not assume a specific error without logs.
- **BUG-002 (P1):** `district_pedestrians.gd:77–125` directly assigns pedestrian body positions each physics frame. Simple distance checks are not a swept collision/navigation solution; overlaps and unnatural player contact remain plausible. Player-reported standing on NPCs requires reproduction.
- **BUG-003 (P1):** `vehicle_agent.gd:125–135` sets `global_position` directly, while the vehicle collider is a child `StaticBody3D` (`scenes/traffic/vehicle_agent.tscn:65–76`). No swept movement or obstacle avoidance against the player is visible in that movement path.
- **BUG-004 (P2):** `junction_builder.gd:8–33` creates an eight-lane central junction of ~20 m arms; `traffic_spawner.gd:100–133` spawns only on entry lanes 1/3/5/7; `neighborhood.gd:75–99` draws additional roads without adding them to that graph.
- **BUG-005 (P2):** `main.tscn:7–12,42–51` retains a 100x100 ground body while `neighborhood.gd:20–23` adds a larger overlapping terrain body; overlapping collision surfaces can cause contact ambiguity.
- **BUG-006 (P2):** `game_lifecycle.gd:37–47` restores arbitrary finite save coordinates without checking walkable ground, occupied space or current map bounds.
- **BUG-007 (P2):** `graphics_lod.gd:42–55` hides distant high-detail meshes with no replacement unless a low-detail mesh was registered. `main.gd:68–71` registers grouped meshes without substitutes, so distant buildings can disappear.
- **BUG-008 (P3):** `neighborhood.gd:145–146` uses `ends_with("Road")` for road material, but `SecondaryRoad_NS_1` does not end in `Road`. Secondary roads may render with default material.
- **BUG-009 (P3):** `main.tscn:92–94` still labels the game 'DISTRICT PREVIEW', not the expanded city.
- **BUG-010 (P2):** `street_furniture.gd:2` says props are visual-only while recent changes add collision; outdated documentation risks repeat defects.

## Gameplay loop
Intended: **Explore → Observe civic violations → Respond → Earn rewards → Improve city**. Code for interactions, missions and city metrics is present in the repository, but end-to-end completion, persistence, rewards and city upgrades were **not verified**. Do not mark this loop complete.

## Architecture and QA
Main scene builds NPCs and furniture at runtime (`main.gd:73–95`), whereas the neighborhood is a separate scene. Simulation graph and visual city geometry have separate authorship and no verified common topology. Regression runner (`tools/run_regression.py`) uses workflow regex discovery plus three appended tests, headless import, exit codes, PASS markers, replay and a negative-path test. Coverage of live player–NPC–vehicle physical contacts is insufficient; structural smoke tests cannot prove runtime physics.

## Release decision
**NO-GO** until P0/P1 issues are resolved, tests pass locally, map/traffic consistency is established, and PC/Android playtests and profiling are recorded.

See `COLLISION_PHYSICS_AUDIT.md`, `GRAPHICS_PERFORMANCE_AUDIT.md`, `ISSUE_REGISTER.md`, and `IMPLEMENTATION_ROADMAP.md`.
