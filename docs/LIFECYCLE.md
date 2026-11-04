# Lifecycle and Save Framework (CC-005)

## Controls
From the menu select **Start Game**. In the prototype, F1 toggles pause; F5 saves player position; F9 loads it; F10 restarts the game; F12 returns to the menu. Gameplay pause stops the player and simulation; the UI and lifecycle manager remain responsive.

## Save schema
`CivicSaveRepository` writes JSON to `user://civic_chaos_save.json` via a temporary file and rename. Version 1 stores the player position and yaw. Missing, invalid, corrupt and incompatible saves are rejected without applying partial state. The current version is intentionally minimal; traffic, NPC and mission snapshots are future work.

## Testing
```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/lifecycle_test.gd
```

The tests exercise save round-trip, invalid payloads, corrupt files and menu/lifecycle API presence. Manual tests are required for pause, scene transitions, restart and save/load in the editor.

## Known limitations
The framework does not yet persist NPCs, traffic or missions. A production save migration strategy is needed when the schema changes.
