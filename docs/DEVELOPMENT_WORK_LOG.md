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
| Full GAME-024 regression inventory | 109 fixtures on exact user-tested commit `dd8645c` | **109/109 PASSED on 2026-11-13** |
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
| PROG-01 | P1 | Reputation ranks and offline rotating civic goals | USER REPORTED FOCUSED TESTS PASS — LATEST FULL GATE UNCONFIRMED | Save/replay/anti-farming tests, clear return incentive |
| PROG-02 | P1 | Neighborhood support unlocks with physical Free Roam navigation benefits | CODE COMMITTED — GODOT TEST PENDING | Audited-receipt thresholds, visual beacon, stage transition, reload consistency |
| PROG-03 | P1 | Visible neighborhood improvement projects earned from real civic work | CODE COMMITTED — LOCAL TESTS / VISUAL QA PENDING | Tier gates, no extra scores, physically non-blocking objects, checkpoint reconstruction |
| PROG-04 | P1 | Usable community garden, kiosk and solar response information services | CODE COMMITTED — GODOT REGRESSION PENDING | E/USE gated at real location, audited unlock, no score mutation, valid save replay |
| ART-01 | P1 | Consistent buildings, NPC silhouettes, props, environment and movement polish | TODO | Visible screenshots and real playtest signoff |
| AUDIO-01 | P1 | Feedback SFX, ambiance, dialogue captions and mute/volume controls | TODO | Auditory/readability QA and muted accessibility |
| PERF-ANDROID-01 | P0 | Android touch parity, real-device frame/physics measurements and stability | TODO | Hardware profile, no invented FPS claims, complete campaign test |
| RELEASE-01 | P0 | Signed Android release export, package QA and final acceptance | BLOCKED | Completed P0/P1 checks, reproducible signed build |

## Work journal (append, never overwrite historical evidence)

### 2026-11-13 — PROG-04 remote-access fixture correction
- User reported Godot 4.7.2 headless import **PASSED**, then `neighborhood_unlocks_test.gd` failed with `remote garden use incorrectly provided civic information`; the test loop halted before later cases. The output alone does not show a proximity bypass.
- Review identified the fixture left its player at the last real Free Roam delivery, which can be within 3m of the garden service. Its purported "remote" attempt did not set or assert a remote position.
- Corrected `tests/neighborhood_unlocks_test.gd`: explicitly position the player **10 metres** from the service and assert distance >3m, verify remote denial, then place the genuine player within 1.3m. Added a nearby spoofed actor check before verifying authorized service feedback. The production rule still rejects distant actors and non-player objects; no permission or safety rule was relaxed.
- Commit `34d5004`. **TEST RE-RUN PENDING**. If still failing, inspect the next exact error before changing gameplay rules.

### 2026-11-13 — PROG-02 restore failure hardening / PROG-04 service interactions
- User ran Godot 4.7.2 import and `neighborhood_improvements_test.gd` successfully on PROG-03 source revision `65a9862`, but `neighborhood_unlocks_test.gd` stopped at "existing checkpoint could not restore unlocked support"; later tests in that loop were NOT executed. No new full gate acceptance can be inferred.
- **Restore fix (`ef68a67`):** a rigorously validated checkpoint identical to the already-staged Free Roam state now uses a safe idempotent restore (resyncing navigation/improvements) rather than attempting to restage the exact same live evidence collider. Different checkpoints still take the existing preflight and physical restoration path; save format unchanged. Added an explicit checkpoint-valid assertion before the test's same-state load to distinguish any remaining validation error.
- **PROG-04:** Added `CivicNeighborhoodService` E/USE targets under earned improvements only, using the existing player raycast interaction layer (16), a small stationary hitbox and no physics movement authority.
  - Garden at 3 verified completions: inspect own validated volunteer progression.
  - Community kiosk at 10: inspect current local civic event and destination neighborhood.
  - Solar response point at 25: inspect the incident's real priority tier and remaining time.
- Only proximity-checked real player interactions are answered, after revalidation of earned state; no score, mission, reward, timeout, teleport, checkpoint format or world traffic mutations. Locked services disable their interaction layer.
- Updated `tests/neighborhood_improvements_test.gd` for the deliberate service hitbox, `tests/neighborhood_unlocks_test.gd` for verified third-completion use, spoofed/locked access, no score/reward mutation and checkpoint idempotence; added `tests/neighborhood_service_test.gd` for service lock/unlock behavior.
- **CODE COMMITTED; NO LOCAL GODOT RESULTS YET for this revision.** Priority: Godot import + `neighborhood_unlocks_test.gd` + `neighborhood_improvements_test.gd` + `neighborhood_service_test.gd`, then Free Roam save/restart tests and full gate. Commit generated `.gd.uid` files first.

### 2026-11-13 — PROG-03 district improvement projects
- Created `scripts/world/neighborhood_improvements.gd` with three visible, **non-colliding**, simple 3D city upgrades unlocked by audited Free Roam resolutions: restored market planters (3), a community information kiosk (10), and solar-style street lighting (25). These are deliberately cosmetic props in the current Market Chowk rather than invented new accessible districts.
- Integrated `CivicNeighborhoodImprovements` under active Free Roam; objects are placed only after source receipt validation and recomputed after each real incident resolution and checkpoint restoration. Existing traffic/collision/mission/reward and checkpoint formats remain untouched.
- Added HUD progress readout for improvements and next project. New `tests/neighborhood_improvements_test.gd` checks tier boundaries, receipt fraud rejection, no duplicate props and JSON replay. Extended `tests/neighborhood_unlocks_test.gd` to verify the first improvement appears after **three real physical incident resolutions** and returns after checkpoint restore.
- Commits: `31b9ebf` model, `ce11e13` integration, `5b300bf` unit regression, `c9b0729` HUD, `c6a9d26` physical integration regression.
- **Status: CODE COMMITTED; unverified at this revision.** Run local Godot import and targeted tests, check newly generated `.gd.uid` files, and rerun the full gate on the exact revision. Visual/manual playtest and Android QA remain mandatory. No GitHub Actions manually triggered.

### 2026-11-13 — PROG-02 neighborhood support unlocks
- User reported the PROG-01 rotating-goal focused test batch passed. No exact-revision full gate JSON was provided for that batch; the **last explicit full acceptance** remains `dd8645c` with 109/109 tests.
- Implemented three earnable neighborhood support tiers, derived from real unique Free Roam completion receipts at **3 / 10 / 25** activities:
  - **North Market Watch (3):** visible blue source beacon above the current civic incident (helps locate evidence).
  - **East Community Logistics (10):** beacon moves to the physical return destination after pickup.
  - **South Priority Response (25):** stronger visual beacon for urgent priority incidents.
- Navigation aid uses a non-colliding `MeshInstance3D`, respects the event stage, and is rebuilt after checkpoint loading. No movement teleports, score multipliers, event deadline changes, extra rewards, source data fields, or checkpoint-schema modifications.
- Added `tests/neighborhood_unlocks_test.gd`, exercising **three real resolved incidents** to unlock a visual aid, verifying beacon position, score/save integrity and checkpoint rehydration. Extended `tests/volunteer_progression_test.gd` for all threshold boundaries.
- Commits: `54977be` progression, `a0bddb5` world beacon, `2666b50` guidance, `01a7958` thresholds test, `d16cbc2` / `21d1741` live test.
- **Status:** CODE COMMITTED; not yet imported or run on the user's local Godot 4.7.2. Commit generated `.gd.uid` files before running full acceptance. Manual visual and Android-device confirmation remain required.
- Next: run `neighborhood_unlocks_test.gd`, `volunteer_progression_test.gd`, `free_roam_live_events_test.gd`, `free_roam_event_restart_test.gd`, `free_roam_legacy_migration_test.gd` and `world_pedestrian_checkpoint_test.gd` before full gate.

### 2026-11-13 — PROG-01 verified foundation and offline rotating civic goals
- User's Godot 4.7.2 local import passed, followed by **5/5 focused tests**: `volunteer_progression_test.gd`, `free_roam_live_events_test.gd`, `free_roam_event_restart_test.gd`, `free_roam_director_checkpoint_test.gd`, and `civic_hud_test.gd` on commit `fe232ef`. This is **not** a new full-GAME-024 acceptance.
- Added cumulative **four-activity civic goal cycles** (Neighborhood Patrol, Public Space Care, Market Stewardship) that change on verified Free Roam completions. They do **not** depend on phone clock/calendar, penalize absences, create synthetic mission rewards, or alter checkpoint schema.
- The HUD now shows the current cycle title and verified progress. The existing volunteer-progression fixture adds cycle-boundary, forged count, JSON replay and HUD checks.
- Implementation commits: `af8443e` progression model, `ce29b44` HUD, `5123226` tests.
- **Code committed, current-revision Godot verification pending**. Daily-calendar goals and neighborhood unlocks are not implemented. New Godot `.gd.uid` files should be committed before full gate.
- Next: run import, volunteer progression and Free Roam checkpoint tests, then exact-revision full acceptance, followed by real device UI inspection.

### 2026-11-13 — GAME-024 passed / PROG-01 ranks and badge foundation
- User's **exact commit `dd8645c`** passed the local Godot 4.7.2 GAME-024 gate with **109/109 full regression fixtures**, all 24 focused tests, source/import, negative-path and independent readiness evidence. The four generated Godot UID files were committed. This is the last **verified baseline**, not an acceptance claim for later commits.
- PROG-01 first batch: added read-only `CivicVolunteerProgression` thresholds (New Volunteer / Neighborhood Helper / Trusted Volunteer / Community Champion) and cumulative Free Roam milestone badges at 3/10/25/50 verified completions. Progress is derived strictly from `CivicCityMetrics.processed_events` and cross-checked with resolved count; no grant API, extra mission reward, changed save format, calendar-clock dependence or penalty for missed days.
- Integrated rank and next goal into the Free Roam HUD through `CivicFreeRoamEvents.hud_state()`; added `tests/volunteer_progression_test.gd` checking replay, forged-counter denial, thresholds and UI display.
- Commits: `99de7cd` model, `1757f1e` Free Roam readout, `50c48cd` HUD, `542a034` focused test.
- Status: **CODE COMMITTED; Godot import and test on the NEW revision pending**. Rank and milestone display are the first part of PROG-01; daily challenge rotation and playable neighborhood unlocks are still planned.
- Next: commit any new Godot-generated `.gd.uid` files, run the focused volunteer progression and existing Free Roam test group, and rerun the full gate.

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
& $godot --headless --path . --script res://tests/volunteer_progression_test.gd
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_game024.ps1 -ExpectedBranch "fix/aud-001-game024-gate-hardening" -Timeout 120
```

**Note:** Release acceptance also requires a real GUI/manual playthrough and Android device verification. Headless tests do not substitute for those.
