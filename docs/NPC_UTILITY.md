# CC-015 NPC Utility Decisions

`CivicNpcUtilityEngine.choose(personality, blackboard, seed)` returns `{ok, action, score, scores, reason}`. It evaluates four candidate actions: wait, cross legally, help person and rush crossing. Unsafe or unavailable actions are omitted *before* scoring: a crossing requires a green pedestrian signal and a clear crossing; helping requires `person_needs_help` and `safe_to_help`.

Blackboard observations: `urgency` (0..1), `pedestrian_green`, `crossing_clear`, `person_needs_help`, `safe_to_help`. Personality traits influence utilities, but cannot override hard safety preconditions. Identical contexts return identical choices; exact ties use a stable seed mixed with NPC ID and tick.

This is a pure decision layer. NPC locomotion, observation sensors and animation are future integration work.

Run: `godot --headless --path . --script res://tests/npc_utility_test.gd`.
