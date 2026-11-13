# UI-01 — Responsive touch layout (staged, not activated)

**Status:** Safe-area geometry component and executable Godot tests committed. **Not used by `CivicTouchControls` yet**; activation is blocked on AUD-001 Godot 4.7.2 + AUD-002 campaign/save acceptance.

## Skills applied

The uploaded `game-ui-ux`, `godot-ui-control`, `input-systems` and `godot-gdscript-headless-testing` skills prioritize viewport/safe-area geometry, readable touch targets, consistent hitbox/caption positions, orientation changes and explicit nonzero test exits.

## Existing problem

`scripts/ui/touch_controls.gd` currently uses an unchanged fixed `72×64` target with percentage positions and one screen-width-based scaling factor for mobile safe-area coordinates. On compact or notched screens, those percentages do not guarantee independently reachable buttons or even that hitboxes remain inside the visible safe area. Its older `tests/touch_controls_test.gd` used bare `assert()` instead of explicit failure exits.

## Staged solution

- New `scripts/ui/touch_layout.gd`: pure, **unconnected** `CivicTouchLayout.plan(viewport_size, requested_safe)`, returning a `Dictionary` of eight `Rect2` input hitboxes plus uniform square button size.
- Computes a **directional cross** in the lower left (up/left/right/down), a 2×2 action cluster in the lower right (use/run/jump), and a distinct upper-right pause target.
- Usable `Rect2` is intersected with the viewport. Rectangles are anchored from its left/right/bottom edges rather than absolute 16:9 coordinates.
- Shared target size automatically scales between **44 and 72 viewport units**, subject to space, with 8-unit edge padding, 6-unit intra-cluster spacing and a 12-unit center gutter. Too-small viewports fail closed rather than silently placing buttons over each other.
- Every computed hitbox must fit entirely inside the safe rectangle. The result fails if any two hitboxes collide when expanded by 2 units; it never clips a valid result to force a fit.
- New `tests/touch_layout_test.gd`: seven phone/landscape/tablet/notch safe-area cases, fallback full viewport, duplicate-plan determinism, directional arrangement, all eight keys, minimum target size, nonoverlap and invalid viewport rejection.
- Existing `tests/touch_controls_test.gd` now uses descriptive `_fail()` + `quit(1)`, not bare `assert()`. **The actual live control code has not been edited.**
- Acceptance inventory: **101 Godot fixtures, 21 focused tests, 30 Python tests and four deterministic replays**. These are required runs, not successfully executed engine results.

## Activation checklist — after Godot acceptance

1. Recheck `CivicTouchLayout.plan` against actual Android viewport units and `DisplayServer.get_display_safe_area()`, using separate X/Y conversion if physical screen units differ from viewport/UI canvas units.
2. In `CivicTouchControls._layout()`, use the same `Rect2.position` for each `TouchScreenButton` and caption, and `Rect2.size` for both the hitbox and label; rerun on viewport/orientation changes.
3. Keep `TouchScreenButton` visibility touch-only. Ensure move, jump, sprint, interact, look drag and pause use independent touch pointers; never swallow keyboard/gamepad input or treat a button press as a camera-look gesture.
4. Verify HUD/mission guide and pause overlays do not obscure the touch areas. Avoid horizontal clipping and keep controls reachable after aspect ratio changes.
5. Capture real Android screenshots and hands-on input evidence for supported portrait/landscape/safe-inset devices; import the scene in Godot and run 101 regressions before turning on.
6. Keep the old implementation as a simple rollback fallback until target-device evidence passes. No GitHub Actions.

**Local evidence:** A separate Python geometry reproduction passed seven viewport/safe-area cases, but it does not execute GDScript or establish Android touch correctness. Godot 4.7.2 is unavailable in this authoring environment.

Related issue: [#51](https://github.com/gauravprajapat-23/civic-chaos/issues/51). Performance milestone [#52](https://github.com/gauravprajapat-23/civic-chaos/issues/52) remains gated and has no measured baseline yet.
