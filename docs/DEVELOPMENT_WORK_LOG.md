# Civic Chaos — Remaining Work & Verification Log

**Updated:** 2026-11-13
**Branch:** `fix/aud-001-game024-gate-hardening`
**Release status:** Playable prototype; not production-ready.
**Working agreement:** Use the existing branch, keep PR #49 draft until explicitly approved, never manually trigger GitHub Actions. Commits use `[skip ci]`.

## Verified baseline (user-provided local evidence)

| Gate | Source / evidence | Status |
|---|---|---|
| GAME-024 (Godot 4.7.2) | `build/game-024-verification.json` on the user's Windows machine; gate output reported `passed` twice | **PASSED on 2026-11-13** |
| Focused gameplay regressions | NPC decision stability, pedestrian checkpoint, crossing recovery, player contact, traffic checkpoint | **5/5 PASSED** |
| Full GAME-024 regression inventory | Previously 106 fixtures; accepted as part of the successful gate | **PASSED at gate revision** |
| AI-03 daily routines | Committed at `2b77caa`; no subsequent local Godot output supplied | **UNVERIFIED** |
| Manual tutorial → finale playthrough | Not supplied | **PENDING** |
| Android physical-device test / signed release | Not supplied | **PENDING** |

The GAME-024 result applies only to the exact local commit tested. Later commits are **not automatically accepted**.

## Remaining-work register

| ID | Priority | Task | State | Acceptance evidence |
|---|---|---|---|---|
| UX-01 | P1 | Responsive start menu and accessible How to Play guide | FOCUSED GODOT TEST PASSED — VISUAL REVIEW PENDING | Godot import; menu navigation focused test; keyboard/touch review |
| QA-PLAY-01 | P0 | Complete a human first-time playthrough of tutorial, wrong way, parking, cleanup, finale and Free Roam | TODO | Recorded steps, screenshots, blockers and end state |
| AI-03-VERIFY | P1 | Verify opt-in daily routine / assistance safely and in real scenes | SAFETY FIX + TEST COMMITTED — LOCAL VERIFICATION PENDING | Godot import, AI tests, crossing/traffic checkpoints, visual review |
| UX-02 | P1 | HUD / modal readability, touch sizing and safe-area audit | RESPONSIVE TEST PASSED — DEVICE REVIEW PENDING | Screenshot comparison at PC and mobile aspect ratios |
| STORY-CHOICE-01 | P1 | Make meaningful, safely recoverable player choices | 3 PARKING FOCUSED TESTS PASSED — FULL GATE PENDING | Distinct tested consequences, no duplicate rewards |
| PROG-01 | P1 | Reputation ranks, daily requests and neighborhood unlocks with no pay-to-win civic authority | TODO | Save/replay/anti-farming tests, clear return incentive |
| ART-01 | P1 | Consistent buildings, NPC silhouettes, props, environment and movement polish | TODO | Visible screenshots and real playtest signoff |
| AUDIO-01 | P1 | Feedback SFX, ambiance, dialogue captions and mute/volume controls | TODO | Auditory/readability QA and muted accessibility |
| PERF-ANDROID-01 | P0 | Android touch parity, real-device frame/physics measurements and stability | TODO | Hardware profile, no invented FPS claims, complete campaign test |
| RELEASE-01 | P0 | Signed Android release export, package QA and final acceptance | BLOCKED | Completed P0/P1 checks, reproducible signed build |

## Work journal (append, never overwrite historical evidence)

### 2026-11-13 — Focused UX and choice tests passed; full acceptance blocked
- User ran Godot 4.7.2 import successfully at commit `77ae2a6`, then **7/7 focused scripts passed**: `menu_ux_test.gd`, `ui_responsive_civic_test.gd`, `parking_owner_card_test.gd`, `parking_response_choice_test.gd`, `illegal_parking_live_test.gd`, `parking_checkpoint_test.gd`, `multi_incident_checkpoint_test.gd`.
- GAME-024 full acceptance reported **blocked** twice without an inline reason. No focused test PASS lines appeared in the gate output; its exact preflight/runner failure remains **unknown** until reading `build/game-024-verification.json`.
- Updated the acceptance script at `179be3d` to print `BLOCKED REASON` and, for source-cleanliness failures, the changed file list. The gate still fails closed and preserves its existing acceptance criteria.
- **Do not mark the full regression or current release acceptance passed.** Next: inspect the JSON `reason`, `git status --short` and relevant log, remedy the actual failure, rerun at the exact latest commit.

### 2026-11-13 — UX-01 menu test failure + STORY-CHOICE-01 parking choices
- User's local Godot import passed on the earlier `b175734` revision; `menu_ux_test.gd` failed because the guide's dynamically constructed VBoxContainer lacked the exact `VBoxContainer` name required by the test. The test stopped the loop; other UX fixture results were not supplied.
- **Fix:** set the runtime guide container name to `VBoxContainer` (`c158713`). Still needs a new Godot test run on latest SHA.
- **New gameplay choice:** the illegal-parking detail card offers both a direct owner request and optional municipal assistance after the same physical evidence inspection. The direct owner request remains faster; municipal response requires a fixed 80-tick dispatch delay before the SAME authorized owner safely relocates the vehicle. The scored outcome differs (direct cooperation is higher) but both paths require verified car movement and pedestrian route reopening. Neither response grants permission to move a car directly or bypass physics.
- **Persistence:** optional `response_kind` field preserves the choice without changing the v1 checkpoint version; absent field is treated as legacy direct-owner route. Invalid actions and duplicates are refused; no extra mission reward.
- Commits: `81c4779` incident-card optional second action; `9d41f41` parking branch and persistence; `16d21f9` card option tests; `b1f97fc` parking choice regression.
- **Status:** CODE COMMITTED; this branch's Godot import, UX re-test and new parking-choice fixtures remain **UNVERIFIED**. Existing full GAME-024 acceptance predates these edits.
- Next: rerun menu, card, parking choice, parking checkpoint, physical parking live tests; then full local GAME-024 gate; only afterward perform a GUI playthrough of both choices and record screenshots/elapsed recovery time.

### 2026-11-13 — AI-03 routine safety hardening
- Reviewed the opt-in daily routine implementation against pedestrian recovery and physics-safety contracts.
- Corrected a false stall: voluntary sidewalk breaks now reset rather than increment `_blocked_frames`; true blocked movement still increments it.
- Civic-help proximity no longer automatically implies physical safety. Help is declined near overlapping players, active cars or solid world obstructions, and it never alters missions, rewards or crossing reservations.
- Strengthened `tests/npc_decision_stability_test.gd` to check planned rests do not create false obstruction counters and overlapping players block assistance.
- Source commits: `6923bbf` (runtime), `555b21d` (focused test). **Local Godot import and focused/full regression evidence pending at this revision.**
- Next: user runs `npc_decision_stability_test.gd`, pedestrian checkpoints/recovery and full GAME-024 gate; then visualize the opt-in routines in actual gameplay before enabling by default.

### 2026-11-13 — UX-02 responsive civic UI
- Source audit: the live `CivicStatusHUD` used fixed pixel offsets and the incident card had no bounded scroll container, risking clipping at narrow screen sizes.
- Implemented: viewport-bounded HUD geometry in `scripts/ui/civic_status_hud.gd`; bounded incident-card geometry with vertical-only evidence scrolling in `scripts/ui/civic_incident_card.gd`.
- Added `tests/ui_responsive_civic_test.gd` covering 320px portrait, landscape and desktop bounds, action sizes, evidence gating, authoritative score display and dismissal.
- Source commits: `08bd078` (HUD), `5a793db` and `1bf94a3` (card), `371eb70` and `205ccf1` (test).
- Status: **CODE COMMITTED; Godot import, local tests and visual phone review NOT YET RUN**. Do not mark UX-02 accepted.
- Next: perform live UI screenshots and a manual campaign playthrough on Windows and Android before closing visual issues.

### 2026-11-13 — UX-01 started
- Source audit: `scenes/core/menu.tscn` had a bare Start/Quit menu without instructions or structured visual hierarchy.
- Implementation: styled deep-blue/yellow start menu, first-time-player How to Play modal with PC/touch controls, campaign and Free Roam instructions, Esc/Back dismissal and size-aware layout. Start/Quit lifecycle preserved.
- Source commits: `f10958f` (menu); `ca56ebe` (new `tests/menu_ux_test.gd`). Full GAME-024 runner automatically discovers the new fixture.
- Verification status: **source and test committed; engine import, focused test and full gate NOT YET RUN on this SHA**. The earlier accepted GAME-024 SHA predates this change. Do not mark acceptance based on commits alone.
- Next: run menu-focused test and local import, then GAME-024 gate at the updated revision.

## Verification command (Windows)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git merge --ff-only origin/fix/aud-001-game024-gate-hardening
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/menu_ux_test.gd
& $godot --headless --path . --script res://tests/ui_responsive_civic_test.gd
& $godot --headless --path . --script res://tests/gameplay_incident_card_test.gd
& $godot --headless --path . --script res://tests/civic_hud_test.gd
& $godot --headless --path . --script res://tests/npc_decision_stability_test.gd
& $godot --headless --path . --script res://tests/world_pedestrian_checkpoint_test.gd
& $godot --headless --path . --script res://tests/pedestrian_crossing_recovery_test.gd
& $godot --headless --path . --script res://tests/parking_owner_card_test.gd
& $godot --headless --path . --script res://tests/parking_response_choice_test.gd
& $godot --headless --path . --script res://tests/parking_checkpoint_test.gd
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_game024.ps1 -ExpectedBranch "fix/aud-001-game024-gate-hardening" -Timeout 120
```

**Note:** Release acceptance also requires a real GUI/manual playthrough and Android device verification. Headless tests do not substitute for those.
