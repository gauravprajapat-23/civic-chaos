# Player controller and camera (CC-004)

## Controls
- WASD / arrows: walk
- Shift: sprint
- Space: jump
- Mouse: orbit camera
- Escape: release or recapture mouse
- E: raycast interaction
- Gamepad left stick: move; right stick: look (where mapped)

## Architecture
`CivicPlayerController` is a `CharacterBody3D`. Movement is relative to camera yaw, uses `move_and_slide()`, and turns the placeholder capsule toward the movement vector. The `SpringArm3D` is set to collide with environment layer 1, preventing the third-person camera from passing through static geometry. The player collision is on layer 2.

The interaction ray originates at screen center and checks objects exposing `interact(player)`. `CivicInteractionTarget` is a sample target for the scene.

## Known limitations
This is a placeholder capsule, not a finished character. Mobile touch controls, animation and proper interaction HUD are future work. Camera and collision behavior still require manual gameplay verification.

## Validate
```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/player_controller_test.gd
```
