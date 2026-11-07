# Civic Chaos — Consolidated Remaining-Work Audit
Date: 2026-11-07
Scope: `main`, `fix/regression-nov05`, `feat/game-024-dynamic-free-roam`, and `feat/game-025-daily-routines-draft`
Latest draft branch inspected: `36b5bc012170858f283d86a16a0d3f97bf71f04a`

**Evidence class: GitHub source/document/test-inventory inspection only.** No Godot executable, live game playthrough, Android device or current branch test output was available to this audit. **Do not claim runtime acceptance, merge/release readiness or actual measured performance from file existence. No GitHub Actions were run.**

## 1. Decision

**NO-GO for release; yes to a bounded first playable prototype after verification.** Substantial game logic exists, but the working branches, acceptance evidence and design documents are out of sync. Stabilize the existing four-stage campaign and GAME-024 before enabling GAME-025, increasing NPC counts, creating new districts or packaging Android builds.

The following statuses distinguish (a) source committed, (b) integrated into the main 3D scene, (c) engine-tested on current commit, and (d) human-playable/device-accepted. These statuses are not interchangeable.

## 2. Repository evidence snapshot

| Evidence | Finding |
|---|---|
| Default `main` | `d0326def4e1777e2eac281324793ad7d0d988ecc`; older than current campaign changes |
| Regression branch | `fix/regression-nov05` at `0b436169be89a76da034b12b625d8acd1e123739` |
| GAME-024 branch | `feat/game-024-dynamic-free-roam` at `bd4c0ae2e2dc7880f3171061f0c8d4b7487a6a7f` |
| GAME-025 draft | `feat/game-025-daily-routines-draft` at `36b5bc012170858f283d86a16a0d3f97bf71f04a` |
| Tests | 90 `*_test.gd` scripts on GAME-024; 96 on GAME-025; all 96 are referenced by the local runner's explicit list or the manual-only workflow manifest |
| Committed report | `build/regression-report.json` describes **36 passing tests from an older state**; it is **not a GAME-024 or GAME-025 acceptance report** |
| Pull request | Open draft #48 for regression fixes explicitly lists unresolved Godot 4.7.2 import/scene/NPC preload issues, hangs and traffic throughput |
| Issue hygiene | Original CC-001–CC-042 task tickets are largely still open although much supporting code exists; each must be reconciled with actual acceptance evidence, not bulk-closed |
| Platform | Project config targets Godot **4.7**, GL Compatibility; Android docs/workflow still refer to **4.4.1** |
| Release evidence | No verified current-commit Windows/Android campaign walkthrough, full-suite report, device FPS/memory profile, or release package |

Historical results cannot be silently relabeled as new tests. Local `build/` reports may exist on the developer's machine but were not supplied here.

## 3. Code/design comparison

| Area | Source state | Current missing acceptance or design work |
|---|---|---|
| Player/camera/neighborhood | Third-person player, procedural buildings, furniture, traffic and crossing systems integrated in main scene | Playthrough, mesh visibility, city-graph/visual alignment, collision stress |
| Civic campaign | Footpath tutorial → wrong-way queue/tow → illegal parking → market cleanup → finale/Free Roam source paths exist | Verify complete human playthrough, retries, stranded cars/NPCs, mission softlocks, safe reloads and nonduplicated rewards |
| Civic metrics/HUD | Safety/Efficiency/Trust/Cooperation and incident card/mission guidance source connected | Verify scores follow physically observed consequences and remain consistent through F5/F9 |
| Free Roam GAME-023/024 | Seeded one-at-a-time scheduler, eight dynamic locations, three collect/restore challenges, priority timer and witness speech | GAME-024 acceptance gate, collision-safe placement at every site, PC/Android interaction, replay/legacy checkpoint tests |
| NPC daily routines GAME-025-A | Four-role agenda, waypoint map, intent, real-walker opt-in preview, city-clock bridge and v2 preview checkpoint written | Not enabled by `scripts/core/main.gd`; real locations are abstract progress points, not shop/home anchors; gate + transition/migration/crowd tests pending |
| Personality & social influence | Standalone NPC personality, utility, influence scripts and tests exist | Not shown wired into `district_pedestrians.gd` live movement/choices; no emergent personality-driven incidents |
| Civic causality | Physical queue/witness/obstruction tests and constrained event budget | No demonstrated linked cascade where an independently simulated NPC violation causes queue/crosswalk consequences and repairing the root clears symptoms |
| Meaningful choices | Wrong-way report, owner request, cleanup/bin service interactions are implemented | Wrong-way and parking each have one main resolution; GDD calls for at least two safe choices for one incident with visibly different outcomes |
| Context conversations | Witness speech/gesture with reaction timers | No opt-in nearby E/USE role/time/reputation dialogue tree or conversation priority over incident card |
| Crowds | Existing bounded walkers and collision avoidance; 8 by default | No tested market crowds, routine gathering, population presets, budget/LOD profiling or crowd softlock recovery |
| Visible consequences | Moved props, queue measurements, civic score receipts and finale | Sustainable local neighborhood state, altered NPC cooperation, cleaner streets/traffic and distinct repair/failure visuals remain incomplete |
| Presentation | Procedural meshes, HUD and touch controls | Visual identity, original audio/captions, localization-ready UI, control/sensitivity settings, device layout verification, accessible prompts |
| Android | Export preset, touch logic, GL Compatibility | Confirm 4.7.2-compatible templates, debug APK import/install/run, multitouch/safe area, frame-time and memory measurements |

### Important design-document drift

1. `docs/game_design/CIVIC_CHAOS_GAME_DESIGN.md` still describes the civic gameplay coordinator as *not implemented*, although the later campaign implementation mounts it in `main.gd`.
2. `docs/game_design/IMPLEMENTATION_BACKLOG.md` uses legacy **GAME-023–025** for graphics/UI, but the newer campaign continues **GAME-023 Free Roam, GAME-024 dynamic incidents, GAME-025 Living City**. Preserve both IDs only with an explicit namespace/epoch, otherwise future coding tasks will hit the wrong scope.
3. `README.md` introduces only the first **two** Free Roam activities. GAME-024 adds a **third**, the storage-cone challenge.
4. `docs/game_design/GAME_025_A_DAILY_ROUTINES_DRAFT.md` begins with an older claim that no code is instantiated in `district_pedestrians.gd`; its later sections document the new opt-in integration. Update the executive status and avoid contradictory acceptance claims.
5. `docs/ANDROID_EXPORT.md` and workflow manifests reference Godot **4.4.1** while `project.godot` declares 4.7 and the current local target is 4.7.2.
6. Older audit findings for NPC/LOD/roads must be reproduced on the **latest branch**; a patched source line does not prove the report's runtime bug is closed.
7. `docs/game_design/GAME_CONTINUATION_PROGRESS.md` says the workflow can run on push, while the inspected `.github/workflows/godot-validation.yml` uses **manual `workflow_dispatch` only**. Keep actual workflow policies aligned with the user's no-Actions instruction.

## 4. Prioritized actionable backlog

### P0 — Gate blockers (do these first)

**AUD-001: Resolve real Godot regression failures and establish the GAME-024 gate.**  
Source: draft PR #48; `tools/verify_game024.ps1`, `tools/run_regression.py`, Free Roam and scene tests.  
Reproduce import/parser failures, NPC personality preload, traffic vehicle test hangs and throughput, then run GAME-024's focused tests and all **90** registered tests. Capture Godot 4.7.2, exact SHA, exit codes, stderr, pass markers and negative-path result. **Exit:** 0 Godot errors, no failed/hung tests, `build/game-024-verification.json` status passed on tested commit, and manual safe interaction check.

**AUD-002: Verify actual end-to-end story and checkpoint integrity.**  
Source: `scripts/core/main.gd`, `scripts/civic/*mission.gd`, `scripts/core/save_repository.gd`, `scripts/world/junction_scene.gd`.  
Start the menu, complete footpath → wrong-way → parking → cleanup → finale → Free Roam; test wrong distance, false report, replay, restart, mid-car tow, mid-litter carry, damaged primary save/backup recovery, F5/F9 during traffic crossing, no replayed reward. **Exit:** no softlocks, ghost objects, missing guides or inconsistent score/incident receipt; actual PC walkthrough recorded.

**AUD-003: Stabilize branch integration and audit ticket states.**  
Source: `main`, PR #48, GAME-024, GAME-025 draft, GitHub CC issues.  
Only after AUD-001/AUD-002 pass, decide safe merge order (regression → 024 → 025). Compare exact commit SHAs and avoid silently landing test-only 025 previews. Reconcile CC issues individually against tests; document deferred issues. **Exit:** one clearly labeled accepted baseline; no duplicate/historical GAME identifiers interpreted as shipped code.

### P1 — Make the city feel alive after the gate

**AUD-004: Complete GAME-025-A live routines and migration.**  
Enable existing scheduler/clock bridge in `main.gd` only behind successful accepted test results. Anchor destinations to actual world points (storefront, home, depot), keep pedestrians moving on current safe paths, and add idle animation at clear stops. Support v1→v2 save migration and bounded missed-destination recovery. **Exit:** realistic live routine, no crossing freeze/collision, loaded saves preserve actual agenda/world tick, deterministic replay.

**AUD-005: Contextual NPC conversations (GAME-025-B).**  
Implement role + time + current incident + reputation dialogue with E/USE only near NPC, prioritizing mission interactables. Add dialogue variation and captions, never award Trust for speaking. **Exit:** interruptible nearby conversations, no card/action conflicts, tests for interaction range and dismissal.

**AUD-006: Causal incidents + distinct safe solutions.**  
Give at least one story/free-roam incident two *meaningful* safe actions (e.g., request owner versus authorized service when cooperation fails) with different time, cooperation, and observable outcomes. Tie emergent incidents to actual personality/utility/traffic state rather than only a timed picker. **Exit:** root obstruction creates observable secondary congestion, clearing root reduces symptoms; no fabricated scores or unsafe rewards.

**AUD-007: Visible civic feedback and durable neighborhood state (GAME-025-D).**  
From the authoritative event/metric ledger show cleaner areas, functioning signage, safe pedestrian flow, changed local citizen responses and before/after consequences. Persist only validated presentation state and do not duplicate civic score receipts. **Exit:** visible, save-stable outcomes for success and expiry; expiry never grants points.

**AUD-008: Crowds with a strict NPC/physics budget (GAME-025-C).**  
Add quiet/normal/busy presets only after no-overlap and crossing tests. Profile the O(N²) avoidance checks, use bounded staging, never spawn into other bodies, remove crossing reservations safely. **Exit:** stable crowded market and busy crossings at measured frame-time budgets.

**AUD-009: Traffic/world geometry quality.**  
Verify offset lanes vs visible curbs, turn connectors, secondary intersection signals, car/world obstacle sweeps, pedestrian crossings, safe spawn, building silhouettes. Keep map and graph derived from compatible geometry. **Exit:** live driving and walking never clip through buildings/cars or deadlock permanently; visual PC checks recorded.

### P2 — Experience, performance, Android, release

**AUD-010: Art, UX, audio and localization.**  
Replace developer-style status labels and limited menu; add legible street landmarks, route arrows, captions, sound cues and options for volume/look sensitivity; introduce localization keys for English and Hindi. No substantial binary audio/image assets or translation files appear in the inspected Git tree; these require creation/integration. **Exit:** a first-time player can finish without verbal coaching; touch UI and captions readable.

**AUD-011: Android 4.7.2 build and real device profiling.**  
Align export documentation/templates, manually export/install an offline arm64 debug APK, test simultaneous multitouch, safe areas, background/restart, save recovery, FPS/1% lows, frame time, RAM, draw calls and NPC limits. **Exit:** documented actual hardware results, no startup crashes or input loss. Do not run Actions.

**AUD-012: Retention and replay progression within GDD bounds.**  
After stability, add voluntary neighborhood badges, cosmetic volunteer tools, rotating citizen requests and tangible district improvements—**not** authority purchases, combat, forced danger, monetization or a backend. **Exit:** several distinct repeatable sessions, with non-farmable progress and a reason to revisit.

**AUD-013: Release acceptance.**  
Complete full local regression, deterministic seed replay, corrupted-save suite, human walkthrough and Android packaging with a single frozen commit. **Exit:** zero unresolved P0/P1, explicit P2 deferrals, playable Windows build and verified Android APK.

## 5. Recommended next coding sequence

`AUD-001 engine regression/024 gate → AUD-002 human campaign + save integrity → AUD-003 baseline/branch reconciliation → AUD-004 complete 025-A routines → AUD-005 conversations → AUD-006 causal choices → AUD-007 consequences → AUD-008 crowd load → AUD-009 road checks → AUD-010 presentation → AUD-011 Android → AUD-012 replay progression → AUD-013 release`.

This order intentionally does **not** start with another large feature system. The existing project has more authored modules than verified player-facing behavior.

## 6. Commands for the next actionable gate (Windows PowerShell)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git switch feat/game-024-dynamic-free-roam
git pull --ff-only origin feat/game-024-dynamic-free-roam
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_game024.ps1
if ($LASTEXITCODE -ne 0) { throw "GAME-024 local acceptance failed" }

git switch feat/game-025-daily-routines-draft
git pull --ff-only origin feat/game-025-daily-routines-draft
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
python tools/run_regression.py --godot $godot --timeout 120 --report build/game-025-audit-regression.json
if ($LASTEXITCODE -ne 0) { throw "GAME-025 full regression failed" }
```

For GAME-024, confirm that the report lists the expected branch SHA, exact Godot version, import and focused/full regression status. Follow both runs with a *real* PC campaign walkthrough. No automation/action workflows should be triggered.

## 7. Source links

- [Live GDD](../game_design/CIVIC_CHAOS_GAME_DESIGN.md)
- [Older phased roadmap](../game_design/PHASED_BUILD_PLAN.md)
- [Older GAME-ID backlog](../game_design/IMPLEMENTATION_BACKLOG.md)
- [GAME-024 design](../game_design/GAME_024_DYNAMIC_FREE_ROAM.md)
- [GAME-025 feature plan](../game_design/GAME_025_LIVING_CITY_PLAN.md)
- [GAME-025 staged implementation](../game_design/GAME_025_A_DAILY_ROUTINES_DRAFT.md)
- [Earlier source audit](FULL_GAME_AUDIT.md)
- [Physics issue register](ISSUE_REGISTER.md)
- [Local acceptance script](../../tools/verify_game024.ps1)
- [Strict full regression runner](../../tools/run_regression.py)
- [PR #48](https://github.com/gauravprajapat-23/civic-chaos/pull/48)

No game source, runtime acceptance statuses, CI workflows or GitHub issue states are changed by this audit.
