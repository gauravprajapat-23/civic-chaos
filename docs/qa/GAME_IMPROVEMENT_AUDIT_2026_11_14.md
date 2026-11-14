# Civic Chaos — Whole-Game Improvement Audit (2026-11-14)

**Branch audited:** `fix/aud-001-game024-gate-hardening`  
**Reference:** source as retrieved 2026-11-14, through the MOB-CTRL-01 InputMap fix (`c634faa`).  
**Status:** CODE REVIEW / INITIAL TRIAGE — **not** a complete execution or player-experience audit.  
**Working agreement:** do not create a new branch, manually trigger GitHub Actions or merge PR #49. Use `[skip ci]` for subsequent commits.

## Product yardstick

The approved `docs/game_design/CIVIC_CHAOS_GAME_DESIGN.md` describes a funny-but-humane, cause/effect-driven **Neighborhood Volunteer** game. The short loop must be **explore → notice → understand → choose → act → observe results → earn/unlock → new chaos**. For v1, the most important experience is three discoverable linked incidents (wrong-way driving, illegal parking, market cleanup), safe choices, persistent mission state and Free Roam after the finale. Android virtual joystick/touch camera/actions must coexist. A simulated queue or score must never be presented as fabricated state.

The source contains implementations for these systems, but code presence is not evidence of understandable player experience, pleasant input, or a stable release.

## Audit scope and evidence quality

Directly inspected: GDD and implementation backlog; `scripts/core/main.gd`, `menu.gd`, `simulation_director.gd`, player controller, live touch controls/joystick/layout, touch-focused tests, vehicle/traffic spawner, civic mission/event managers, mission guide, status HUD, `project.godot`, strict GAME-024 and CAR-ART-04E scripts, latest development log, mobile and car QA trackers.

**Evidence statuses below are deliberately distinct:**
- **CONFIRMED SOURCE GAP:** reproducible through a direct code path or missing integration in inspected source. Needs Godot test to establish runtime impact.
- **RISK / HYPOTHESIS:** credible from source, not reproduced in an engine or device.
- **UNVERIFIED ACCEPTANCE:** code exists or historical tests passed, but no valid recent evidence on the current revision.

The user recently reported import and seven focused vehicle tests passing at `7287d64`, then the gate stopped at missing `InputMap` action `move_left`. Fix `c634faa` was committed **after** that output. No later GAME-024 full run or Android-device result is supplied in this audit.

## Prioritized implementation backlog

| Rank | ID | Priority | Area | Finding and evidence | Required work / proof |
|---:|---|---|---|---|---|
| 1 | AUD3-CTRL-01 | **P0** | Mobile Pause | **CONFIRMED SOURCE GAP.** `touch_controls.gd` publishes `pause_game` via `TouchScreenButton`, but `scripts/core/main.gd` listens for it in `_unhandled_key_input()` (key events), not an input path for touch action presses. | Route touch Pause to the existing `_toggle_pause()` via one safe action path; avoid double toggle from keyboard; test pause/resume on touch with gameplay state preserved |
| 2 | AUD3-CTRL-02 | **P0** | Modal multitouch state | **RISK.** `main.gd` sets `touch_layer.visible = false` for incident card/finale, while `mobile_joystick.gd` owns `Input.action_press()` and only releases on finger-up/focus loss/tree exit; hiding a CanvasLayer may leave a movement press active. | Explicitly release stick, Jump/Run and look-pointer state when opening cards, pausing, changing scenes or losing application focus; test interrupted touch gesture |
| 3 | AUD3-CTRL-03 | **P1** | Resize recovery | **CONFIRMED SOURCE GAP.** `touch_controls.gd::_layout()` sets each button `visible=false` on an invalid viewport but does not set it back to true when `joystick_plan()` becomes valid. | Restore action visibility on recovery and test invalid→valid resize plus input release; never show touch elements on desktop |
| 4 | AUD3-CTRL-04 | **P1** | Input behavior | **RISK.** `CivicMobileJoystick` emits `Input.action_press` for four directions and `main.gd` dynamically registers keyboard input; right-side camera look is tracked separately in `CivicPlayerController`. Multipoint source assertions are not proof of device gestures. | Real Android simultaneous move/look/jump/run/use, pause, app-background, camera sensitivity and cutout checks; record portrait/landscape results |
| 5 | AUD3-QA-01 | **P0** | Release baseline | **UNVERIFIED ACCEPTANCE.** Latest full GAME-024 result in work log is 109/109 at old commit `dd8645c` (2026-11-13). Subsequent code changes invalidate that acceptance. The most recent user gate stopped before full regression. | Re-run `tools/car_art_04e_verification.ps1` on current clean SHA (focused tests → GAME-024 full → independent evidence); preserve exact `build/game-024-verification.json` |
| 6 | AUD3-QA-02 | **P0** | First-time player journey | **UNVERIFIED ACCEPTANCE.** `main.gd` mounts gameplay session, wrong-way, parking, cleanup, finale and Free Roam paths; work log still has no human tutorial→finale→Free Roam acceptance video/checklist. | Complete fresh-install 20–30 min player run without developer commands; check discoverability, readability, action choices, failure recovery and persistent unlocks |
| 7 | AUD3-TRAFFIC-01 | **P1** | Traffic liveliness | **KNOWN LIMITATION.** `CAR_SAFE_05_FLOW_PERFORMANCE.md` explicitly says spawn backpressure reduces new arrivals but does **not** diagnose existing permanent gridlock or safely reroute a stuck vehicle. | Reproduce stalled intersection with queues and crossing; add deterministic stall diagnosis, conservative recovery, stop-line and pedestrian invariants; no teleport-through |
| 8 | AUD3-HUD-01 | **P1** | UX / feedback | **RISK.** HUD renders seven dense text lines; mission guide also occupies the top area; GDD asks for `Observe | Verify | Respond | Confirm recovery` and explicit change feedback. Real layout and clarity aren't established by headless geometry tests. | Screenshots 320×568, 740×360, 1280×720, 19.5:9 Android; reduce redundant labels, isolate critical objective, preserve four live city metrics |
| 9 | AUD3-STORY-01 | **P1** | Consequence and agency | **DESIGN ACCEPTANCE GAP.** Civic `MissionManager` includes idempotent claims, seeded `EventDirector` contains event cooldown and history, but neither proves choices have felt/visible consequences or that replay changes strategy. | Human scenario matrix: two safe solutions to same incident, distinct outcomes/metrics, no duplicate rewards after load/retry |
| 10 | AUD3-PERF-01 | **P0** | Device performance | **UNVERIFIED ACCEPTANCE.** Mobile GL Compatibility is configured; CAR-SAFE-05 tracks runtime metrics but has no measured device frame-time, heat or sustained crowd/traffic findings. | Android real-device 10-min busy intersection benchmark with 10/20-car cases, after checkpoint, warm device, FPS/hitches/memory and quality settings |
| 11 | AUD3-ART-01 | **P2** | Presentation | **KNOWN PLANNED WORK.** The development log lists ART-01 and AUDIO-01 TODO; recent sedan improvements remain unreviewed in 3D device screenshots. | Consistent building/NPC/vehicle silhouettes, signage and landmark clarity; distinct notification SFX, captions and mute controls, without performance regressions |
| 12 | AUD3-RELEASE-01 | **P0 gate** | Android shipping | **BLOCKED.** `export_presets.cfg` provides Android Debug, not proof of reproducible signed Play release, store compliance or installed-device smoke test. | Debug APK first after local gates, full touch smoke; then separately configure and validate signed release, permissions/package, crash/restore and distribution checklist |

### Detailed source observations

**Input & UI**
1. `scripts/core/main.gd` uses `_unhandled_key_input` for Pause, while the touch layer's four circle buttons are `TouchScreenButton` action sources. An Android tap should be tested explicitly, not inferred from the existence of a pause action name.
2. `scripts/ui/mobile_joystick.gd::_apply_actions()` writes global action strengths. When a scene covers the controls without a touch-up event, there is no explicit ownership-aware cancellation in `scripts/core/main.gd::_show_incident_card` or `_present_campaign_finale`.
3. `scripts/ui/touch_controls.gd::_layout()` hides buttons on invalid plan and sets their positions on valid plan, but lacks `button.visible = true` in that path. This is an actionable, isolated bug.
4. `scripts/core/main.gd::_enter_tree()` binds keyboard actions before adding touch layer; recent `InputMap` repair in joystick addresses standalone test startup, but the complete game gate must still be run.

**Campaign and economy:** `CivicMissionManager.claim_reward()` prevents repeat claims, which is a useful foundation. Judge gameplay against **actual observable queue/sidewalk/trash changes**, not simply the presence of manager classes.

**Simulation:** `CivicTrafficSpawner.congestion_backpressure()` uses active>=3 and >=75% stopped cars (speed < 0.2 m/s) to defer new arrivals. That is a useful cap, not a guarantee that existing jams resolve. Verify signal fairness, parking obstruction, pedestrian priority and checkpoint rollback when adjusting it.

**Art/performance:** The low-poly scene and opaque materials help budget but do not establish 30/60 FPS on Android. Avoid adding postprocessing or per-car dynamic lights before measuring.

## Recommended coding and verification sequence

1. **AUD3-FIX-01 (first change):** Fix touch Pause and modal movement/finger lifecycle as one P0 integration batch. Add a fixture that injects touch/action events, tests pause/resume exactly once and confirms all action strengths reset after a modal opens.
2. **AUD3-FIX-02:** Fix invalid→valid touch layout restoration and test it across display resize/orientation; make look-touch and action exclusion reflect the actual visible state.
3. **AUD3-GATE-01:** Run focused mobile controls + vehicle/traffic/campaign regressions and the full exact-revision GAME-024 gate; do not skip failures or suppress `ERROR:`.
4. **AUD3-PLAY-01:** Fresh Story → three incidents → finale → Free Roam walkthrough, manual Android gestures and screenshots; capture source SHA and reproducible steps for each bug.
5. **AUD3-TRAFFIC-02:** Only if gameplay exhibits sustained blockage, implement deterministic recovery without bypassing lights or crossing collision.
6. **AUD3-POLISH-01:** Refine HUD clarity, mission feedback, landmarks, sound accessibility and player choices based on actual observed friction.
7. **AUD3-RELEASE-01:** On physical Android, profile sustained FPS and package/debug/signed readiness separately.

### Exit criteria for the audit follow-up
- P0 mobile Pause works on Android and keyboard without duplicate toggles.
- No movement remains pressed when a touch is cancelled, app backgrounds or an incident/finale modal opens.
- UI returns after small/invalid screen dimensions recover; no off-screen controls or accidental camera-look from buttons.
- Full GAME-024 gate passes at **the audited follow-up commit**.
- Manual Story → Free Roam completed from fresh install, checkpoint replay is consistent, no unrecoverable traffic gridlock.
- Android screenshots, FPS and thermal notes are attached to QA evidence.
- Release remains **blocked** until these checks have real evidence.

## Audit history
- 2026-11-14: Initial source-based improvement audit completed. No gameplay changes or GitHub Actions in this audit; future fixes are tracked here and in `docs/DEVELOPMENT_WORK_LOG.md`.
