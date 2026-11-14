# MOB-CTRL-01 — Android Joystick & Touch Controls Tracker

**Branch:** `fix/aud-001-game024-gate-hardening`  
**State:** Source/test implementation committed — local Godot and physical Android verification pending  
**Policy:** No new branch, no manual GitHub Actions, commit messages `[skip ci]`; keep GAME-024 and CAR-ART-04 acceptance separate.

## User goal
Replace the existing four-arrow virtual D-pad with a familiar circular thumbstick for walking, improve the clarity/placement of Jump, Run, Use, Pause, and keep a dedicated right-side swipe-look region working simultaneously with movement. "PUBG-like" describes touch familiarity only; all graphics and code are original.

## Implementation register

| ID | Priority | Task | Status | Acceptance |
|---|---|---|---|---|
| MOB-CTRL-01A | P0 | Circular analog joystick with directional strengths and deadzone | **CODE COMMITTED** | `mobile_joystick_test.gd`; controlled walking and diagonals |
| MOB-CTRL-01B | P0 | Replace four arrow hitboxes; circular Jump/Run/Use/Pause | **CODE COMMITTED** | `touch_controls_test.gd`; no missing actions |
| MOB-CTRL-01C | P0 | Portrait/landscape safe-area positioning and nonoverlap | **CODE COMMITTED** | `mobile_joystick_layout_test.gd`, real device rotation |
| MOB-CTRL-01D | P0 | Right side independent camera swipe; action taps don't steal look | **CODE COMMITTED** | `player_controller.gd` touch area; two-finger device acceptance |
| MOB-CTRL-01E | P1 | Reuse button texture; release stick when destroyed/hidden | **CODE COMMITTED** | No phantom movement after releasing thumb, pause or scene exit |
| MOB-CTRL-01F | P0 | Full GAME-024 + CAR-ART-04E regression | **PENDING** | Exact HEAD import, focused tests, clean game acceptance |
| MOB-CTRL-01G | P0 | Physical Android thumbstick/camera UX acceptance | **PENDING** | Touch test + screenshots, orientation, display cutouts, FPS |

## Design and behavior

- `scripts/ui/mobile_joystick.gd`: original vector-drawn ring/knob. A touch within 1.4 × base radius claims a single finger ID; dragging updates `Input.action_press(action, strength)` for orthogonal movement, with analog deadzone and bounded diagonal length. Releasing resets all four directions. Other touches are not consumed, allowing simultaneous right-side actions and camera movement.
- `scripts/ui/touch_controls.gd`: now builds four circular `TouchScreenButton` actions and captions instead of four directional arrow buttons plus four actions. One generated opaque-translucent texture is reused. Joystick and action captions appear on touch devices. `look_touch_allowed()` prevents action-button fingers becoming camera-look fingers.
- `scripts/ui/touch_layout.gd`: `joystick_plan()` is a separately validated responsive layout; old `plan()` is left untouched for compatibility with existing UI-01 regression.
- `scripts/player/player_controller.gd`: retains existing touch look behavior, but checks the action-button exclusion when starting a new right-screen look gesture.
- No lane logic, checkpoint persistence, player vehicle collision, player keyboard movement or gamepad movement changed.

## Windows local gate

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git merge --ff-only origin/fix/aud-001-game024-gate-hardening
if ($LASTEXITCODE -ne 0) { throw "Git update failed" }

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
$import = & $godot --headless --path . --editor --import --quit 2>&1 | Out-String
$code = $LASTEXITCODE
$import
if ($code -ne 0 -or $import -match '(?m)^\s*(SCRIPT ERROR:|ERROR:)') {
    throw "Godot import failed"
}

foreach ($test in @(
    "mobile_joystick_test.gd",
    "mobile_joystick_layout_test.gd",
    "touch_controls_test.gd",
    "touch_layout_test.gd",
    "player_controller_test.gd",
    "player_vehicle_contact_test.gd",
    "car_art_04a_side_contact_test.gd",
    "car_art_04e_airborne_guard_test.gd"
)) {
    $output = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
    $code = $LASTEXITCODE
    $output
    if ($code -ne 0 -or $output -match '(?m)^\s*(SCRIPT ERROR:|ERROR:)' -or
        $output -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
        throw "FAILED: $test"
    }
}
```

After focused tests pass, run `tools/car_art_04e_verification.ps1` (which also runs GAME-024), then build/debug APK only if all gates pass.

## Required Android acceptance matrix

| Scenario | Must be observed |
|---|---|
| Resting thumb | No movement, no jitter |
| Slow thumb tilt | Slow walk proportional to input strength |
| Full diagonal thumb | Normalized diagonal, no speed exploit |
| Thumb held + right finger camera swipe | Player walks and camera rotates independently |
| Thumb held + Jump | Jump works without cancelling movement |
| Thumb held + Run | Sprint works; releasing Run stops sprint |
| Use while camera moving | Interact triggers, no camera snap |
| Pause, unpause, background/resume | No stuck movement or phantom press |
| Notched phone / landscape edges | Every button fully visible, does not obscure important HUD |
| Device load | FPS/frame-time compared to old controller; no extra per-frame texture generation |

Do **not** mark UX done on headless GDScript PASS alone: measure actual device finger coordination, HUD interference and visual readability. Screenshots/video from Android remain needed. Do not claim hardware performance until measured.

## 2026-11-14 — Local failure: missing InputMap movement action

The user ran `tools/car_art_04e_verification.ps1` at commit `7287d64`. Godot import, CAR-ART-04A/04B/04D and vehicle visuals fixtures all printed PASS. Immediately afterward the run emitted `ERROR: The InputMap action "move_left" doesn't exist` and stopped before accepting the mobile controls. **This is a real source integration bug, not a verified successful mobile-controls gate.**

Root cause: `project.godot` does not declare the `move_*` input actions, and standalone test scenes do not necessarily execute the gameplay input setup. The new joystick's `release_stick()` called `Input.action_release()` unconditionally when `CivicTouchControls._layout()` hid it on desktop, triggering Godot's error. The joystick also assumed movement actions were already registered when pressing movement input.

Fix: `CivicMobileJoystick._ready()` registers missing movement actions only, preserving existing keyboard/gamepad event bindings and deadzones. `_apply_actions()` safely skips an absent name during teardown or early lifecycle calls. `CivicTouchControls._ready()` registers missing Jump/Run/Use/Pause action names without replacing existing mappings. `touch_controls_test.gd` now verifies all required actions exist when the touch UI becomes ready. Commits `fc94203`, `319dd2f`, `997d01b`.

**Verification pending:** rerun the strict `tools/car_art_04e_verification.ps1` at the new SHA. Do not assume Android touch acceptance from this source-only fix.

## Progress log

- **2026-11-14:** Added analog joystick, responsive joystick planning, real circular action controls, right-look button exclusion and tests. Source committed; user-run Godot verification pending.
- **2026-11-14:** Strengthened multi-finger ownership regression, app-focus-out release, and corrected TouchScreenButton texture origin to match action hitbox rectangles (Godot `shape_centered` centers the shape within the texture, not the whole node at the rect center). Visual-hitbox alignment now has a focused assertion. All changes remain **unverified in Godot/Android**.
