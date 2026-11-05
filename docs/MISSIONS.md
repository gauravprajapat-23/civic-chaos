# CC-025 Mission Framework

`CivicMissionManager` provides data-driven mission definitions with `id`, `reward` and an array of objectives (`event`, positive integer `target`). Call `register_mission`, `start`, `record_event`, `fail` and `claim_reward`. Missions transition available -> active -> completed/failed. Reward claims are idempotent and persist in `snapshot()`/`restore()`.

The existing `CivicSaveRepository` accepts additional JSON-safe top-level fields, so a caller can include `"missions": manager.snapshot()` beside `"player"` in its save payload. The test verifies disk save/load and duplicate-reward protection. Gameplay event dispatch and menu HUD integration are not yet wired; mission events must be explicitly forwarded by the game world.

Run: `godot --headless --path . --script res://tests/mission_framework_test.gd`.
