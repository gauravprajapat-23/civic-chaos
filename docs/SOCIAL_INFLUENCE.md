# CC-018 Social Influence and Contextual Decisions

`CivicSocialInfluence.calculate(events, attentiveness)` aggregates nearby observed civic behaviors into a deterministic value in [-1, 1]. Events have a `kind` and `proximity` (0..1); positive events include waiting for green, helping others and using crosswalks; negative events include ignoring signals, blocking sidewalks and littering. `apply_to_observations(...)` copies observations and adds `social_influence`.

The utility engine uses this value to modulate waiting and legal crossing scores. Safety checks remain absolute: an unsafe crossing or unsafe help action is not considered, regardless of social influence.

Observation collection and live NPC sensor integration are future work. Test: `godot --headless --path . --script res://tests/social_influence_test.gd`.
