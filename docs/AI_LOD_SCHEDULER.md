# CC-019 AI Simulation LOD Scheduler

`CivicAiLodScheduler` assigns NPCs to distance tiers: near (0–25 m, every tick), middle (25–80 m, every 4 ticks), far (80+ m, every 20 ticks). At 20 Hz these correspond to 20, 5 and 1 decision updates per second. Distances are supplied by the world and can change without resetting decision state. `advance_to(tick)` returns sorted NPC IDs due for a utility/decision update; duplicate and backward ticks are ignored. `snapshot(id)` and `metrics()` expose counts for profiling.

**Critical:** This scheduler throttles *decision evaluation only*. Movement, collision avoidance, crossing reservations, signals and other safety-critical simulation must continue at full fixed-step frequency. It does not freeze far agents. The calling world must integrate registration, camera/player distances and decision dispatch; these are not yet connected to live NPCs.

Test: `godot --headless --path . --script res://tests/ai_lod_scheduler_test.gd`.
