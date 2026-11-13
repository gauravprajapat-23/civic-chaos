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
| UX-01 | P1 | Responsive start menu and accessible How to Play guide | CODE COMMITTED — TEST PENDING | Godot import; menu navigation focused test; keyboard/touch review |
| QA-PLAY-01 | P0 | Complete a human first-time playthrough of tutorial, wrong way, parking, cleanup, finale and Free Roam | TODO | Recorded steps, screenshots, blockers and end state |
| AI-03-VERIFY | P1 | Verify opt-in daily routine / assistance safely and in real scenes | TODO | Godot import, AI tests, crossing/traffic checkpoints, visual review |
| UX-02 | P1 | HUD / modal readability, touch sizing and safe-area audit | CODE COMMITTED — TEST PENDING | Screenshot comparison at PC and mobile aspect ratios |
| STORY-CHOICE-01 | P1 | Make meaningful, safely recoverable player choices | TODO | Distinct tested consequences, no duplicate rewards |
| PROG-01 | P1 | Reputation ranks, daily requests and neighborhood unlocks with no pay-to-win civic authority | TODO | Save/replay/anti-farming tests, clear return incentive |
| ART-01 | P1 | Consistent buildings, NPC silhouettes, props, environment and movement polish | TODO | Visible screenshots and real playtest signoff |
| AUDIO-01 | P1 | Feedback SFX, ambiance, dialogue captions and mute/volume controls | TODO | Auditory/readability QA and muted accessibility |
| PERF-ANDROID-01 | P0 | Android touch parity, real-device frame/physics measurements and stability | TODO | Hardware profile, no invented FPS claims, complete campaign test |
| RELEASE-01 | P0 | Signed Android release export, package QA and final acceptance | BLOCKED | Completed P0/P1 checks, reproducible signed build |

## Work journal (append, never overwrite historical evidence)

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
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_game024.ps1 -ExpectedBranch "fix/aud-001-game024-gate-hardening" -Timeout 120
```

**Note:** Release acceptance also requires a real GUI/manual playthrough and Android device verification. Headless tests do not substitute for those.
