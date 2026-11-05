# CC-014 NPC Personality and Blackboard

`CivicNpcPersonality` is a Godot Resource with five normalized traits: patience, rule compliance, aggression, empathy and attentiveness. `validate()` returns trait-specific errors; `to_data()` and `from_data(data)` convert to/from JSON-compatible dictionaries. `seeded(seed)` generates repeatable trait combinations for each NPC.

`CivicNpcBlackboard` stores a snapshot with NPC ID, simulation tick and JSON-safe observation values. `update_snapshot(id, tick, observations)` rejects stale ticks, foreign NPC IDs, negative IDs and unsupported/nonfinite observation values. Input and output are deep-copied to prevent accidental mutation. `to_json()` and `from_json(text)` support save/load.

The blackboard is intentionally perception-only for this milestone. Decision state machines and NPC actions will be implemented in later issues.

Test: `godot --headless --path . --script res://tests/npc_personality_test.gd`.
