# GAME-QA-01 — Complete Playability and Visual Audit

**Status:** In progress. Godot automation is not a substitute for a human playthrough or Android-device checks.
**Accepted engineering baseline:** Commit `88e2b108066b43378a0b8385e84af37720269060`, GAME-024 113/113 regressions, 24/24 focused checks, independent evidence true (user-provided output, 2026-11-13).
**Scope:** Desktop keyboard/mouse, portrait and landscape preview, Android touch; full story and Free Roam.

## Reproduce

From the repository root on Windows:

```powershell
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Import failed" }
foreach ($test in @(
  "game_qa_mission_guide_test.gd",
  "ui_responsive_civic_test.gd", "menu_ux_test.gd", "touch_layout_test.gd",
  "neighborhood_unlocks_test.gd", "neighborhood_service_test.gd",
  "free_roam_event_restart_test.gd", "district_finale_checkpoint_test.gd"
)) {
  & $godot --headless --path . --script "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { throw "FAILED: $test" }
}
& $godot --path .
```

Commit newly generated Godot `.gd.uid` files before rerunning `tools/verify_game024.ps1`. Keep the full acceptance gate fail-closed. Do not manually trigger GitHub Actions.

## Human end-to-end run — record PASS / FAIL / BLOCKED and screenshots

| Stage | Player action | Expected result | Evidence |
|---|---|---|---|
| Start menu | Start story; open/close How to Play; keyboard focus | Both actions work, controls and choice guidance understandable | Menu and guide screenshots |
| Tutorial | Find orange crate, inspect, report, wait for clearance | Genuine obstacle goes away, one audited reward and mission advances | World, card and HUD screenshot |
| Wrong-way | Go to west junction, safely report the vehicle, observe recovery | Traffic remains safe, no collision/exploit, mission advances exactly once | Before/after scene |
| Illegal parking | Inspect vehicle, test direct-owner route; fresh run for municipal alternative | Both recover sidewalk physically; distinct outcomes; no duplicate score | Choice card, before/after |
| Market clean-up | Complete required physical litter/sign actions | Clear objective markers; no carrying/interaction ghost props | Carry and destination |
| Finale | Open district result, review scorecard, choose continue | Four real missions audited, Free Roam starts; F2 can review result | Finale scorecard |
| Free Roam | Resolve 3 different incidents; expire one; save/load mid-carry | Counts and city metrics remain consistent; event/props restore safely | Incident, save-reload |
| Volunteer progression | Earn 3, 10, 25 verified activities | Rank and goal remain truthful; 3 support tiers appear | Badge and HUD |
| Neighborhood projects | Approach unlocked planter/kiosk/solar point and press E / USE | Each returns accurate information; locked/distant/non-player uses denied | Service point & message |
| Controls and lifecycle | Pause/resume, F5/F9, restart, menu; test after finale | No stuck modal/camera, reentrant saves or duplicate rewards | Before/after save |
| Traffic/pedestrians | Walk around junctions and crossings while events are active | No blocked crossing, floating pedestrian, traffic deadlock | Video or screenshots |

## Visual viewport matrix

| Viewport | Inspect |
|---|---|
| 320 × 568 | Portrait objective guide/HUD separation, readable action button |
| 360 × 740 | Portrait labels, modal close button and touch reach |
| 740 × 360 | Landscape guide on right, HUD on left; no horizontal UI overflow |
| 1280 × 720 | Standard desktop overview and focus order |
| 1920 × 1080 | Large-screen legibility and visual density |

For **Android hardware**, additionally record device model, OS, renderer, orientation, cold-start success, touch hit accuracy, pause/resume after app backgrounding, save/relaunch, and measured frame timings. Do not claim FPS or stability without capture.

## Findings and release blockers

**Source inspection findings:** (1) Mission guide previously used fixed desktop offsets; (2) portrait guide and civic HUD shared horizontal space; (3) How to Play text did not mention municipal parking choice or new community support. The GAME-QA-01 batch makes guide geometry responsive, separates portrait HUD position, and updates the instructions. Automated tests assert geometry but do not prove rendered text fits at every DPI.

**Still unverified:** true human first-time walkthrough, Android screenshot review, physical-device input parity, audio quality, NPC/building artwork quality, signed release export, perf metrics.

For each observed bug log: revision SHA, OS/device, exact scene, steps to reproduce, expected and actual result, screenshot/video reference, severity P0/P1/P2, and whether the fix was retested. No acceptance without evidence.
