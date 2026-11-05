# CC-032 NPC animation, audio and feedback

`CivicAgentFeedback` provides a reusable presentation layer for vehicle/NPC states: idle, moving, braking, stopped, alert and completed. It renders billboarded state labels, emits `cue_changed`, and contains an optional positional audio player. Assign an AudioStream to CueAudio to hear alert/braking cues. No audio assets are bundled.

`observe_vehicle(speed_mps, is_active, is_alert)` derives cues from measured speed changes. VehicleAgent attaches this component and calls it after each fixed-step advance. This is a visual feedback prototype, **not skeletal character animation**; animated NPC rigs, sound assets and manual visual review remain future work.

Run `godot --headless --path . --script res://tests/agent_feedback_test.gd`.
