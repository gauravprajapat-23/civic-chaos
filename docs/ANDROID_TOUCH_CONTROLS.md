# CC-034 Android touch controls

The main scene mounts `CivicTouchControls`, providing eight touchscreen action buttons for movement, sprint, jump, interact and pause. The right half of the screen supports swipe-to-orbit camera input. Button placement follows viewport size and mobile display safe area. The buttons use `TouchScreenButton` and therefore inject existing InputMap actions; desktop keyboard controls remain available.

**Limitations:** No driving-mode input mapping exists yet. Touch control artwork is placeholder labels, not production art. Manual Android hardware tests, aspect ratio coverage, simultaneous multitouch and pause/resume verification are pending. Run `godot --headless --path . --script res://tests/touch_controls_test.gd`.
