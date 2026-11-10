# AUD-002 — Complete Civic Chaos Game Audit

**Audit date:** 2026-11-10  
**Repository:** `gauravprajapat-23/civic-chaos`  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Source revision reviewed:** `a65a0f4ec2dd3a7771fda7bb4c9af2af8fef13a0`  
**Godot target:** 4.7.2, GL Compatibility, PC + Android, offline-first  
**Decision: NO-GO for public release.** This is a **repository/source audit**, not successful engine, Android, gameplay or performance verification. The source revision changes as this report is committed; local test evidence must always match the **latest** commit, not the SHA above.

## 1. Audit scope, methodology and evidence

Inspected the current GitHub branch's complete recursive tree: **400 tracked tree entries**, **69 GDScript files under `scripts/`**, **102 mandatory `tests/*_test.gd` fixtures**, Godot scene inventory, `project.godot`, `export_presets.cfg`, entry flow, major systems, prior full-game audit, issue register, audit-based implementation roadmap and all new AUD-001/AI-01/UI-01/PERF-01 components.

Source paths examined directly include the main menu/scene and `main.gd`; campaign, missions and Free Roam; save repository, lifecycle, checkpoint guard and selection queue; player placement; street generation, junction graph and traffic spawner; signal and reservation policy; pedestrian physics, NPC utility and staged hysteresis; HUD, mission guide, touch controls, finale and staged safe-area planner; graphics LOD; opt-in profiler; Android export preset; and the Python/PowerShell regression gates.

Also **inspected each of the 102 GDScript fixture sources** for direct bare assertions and explicit SceneTree exits. This is a static reliability review. GitHub's `build/regression-report.json` contains **36 historical PASS entries** but lacks the current 102-fixture inventory and matching current source-SHA evidence; it cannot establish acceptance for this branch.

**No GitHub Actions were manually dispatched.** Godot 4.7.2/PowerShell are absent in the authoring environment and direct GitHub clone is unavailable; **Godot import, full regression execution, manual campaign playthrough, Android export and FPS measurements were not performed**. A clean source branch and the presence of tests are not pass results.

Evidence vocabulary below: **Confirmed source** means the specific source behavior/topology mismatch exists; **Risk** means runtime effect needs reproduction; **Staged** means authored but not connected to live gameplay; **Unverified** means no exact-SHA Godot/device logs are available.

## 2. Game feature coverage

| Area | Current source state | Acceptance status |
| --- | --- | --- |
| Entry/menu | Main menu loads `scenes/core/main.tscn`; gameplay scene creates the HUD, guidance, world actors and touch layer | Source exists; startup/import unverified |
| Campaign | Tutorial footpath → wrong-way rescue → illegal parking → market cleanup → earned scorecard | Mission chain in `scripts/core/main.gd`; full real-player journey unverified |
| Ending/Free Roam | Finale acknowledgement, replay story, periodic litter/sign/cone incidents with physical targets and idempotent civic metrics | Implemented in source; repeated event playthrough/save integrity unverified |
| Saves | Versioned checksum document, backup recovery, cross-manager preflight, physics-tick player/world restore and rollback | Extensive fixtures present; physical F5/F9 and corruption recovery unverified |
| Traffic | Expanded 5×5 directed city graph, vehicles, signals, central stop lines, car-following and queues | **Map geometry / right-of-way discrepancies remain** |
| Pedestrians | Collision shapes, separation and crossing reservation/yield rules | Core exists; complex crowd/deadlock contacts need engine observation |
| NPC intelligence | Personality/blackboard/raw utility evaluator exist; deterministic hysteresis policy authored separately | **New policy staged; not wired to moving district pedestrians** |
| Visual world | Procedural colored roads/buildings, furniture, low-cost lighting and mesh LOD | Previous disappearing-shell/material issues addressed in current source; visual-device QA missing |
| Interface | Text HUD, guide, incident cards, results screen, eight touch buttons | Fixed-size panels and overlapping mobile touch regions remain |
| Android | arm64 debug export preset, offline/no Internet permission, GL Compatibility | Android install/playtest not done; release/signing/version targets unverified |
| Performance | Per-traffic timing, new default-off pedestrian probe and opt-in city sampler | No representative real-device FPS/GPU baseline or before/after optimization |
| QA/CI | 102 discovered Godot fixtures, 22 focused tests, 30 Python QA target, 4 state replays and independent SHA-bound gate | Inventory present; **full gate NOT RUN at this SHA** |

## 3. Prioritized findings

### AUD2-001 — P0 / RELEASE BLOCK: no accepted current-source regression or device evidence
**Evidence:** `tools/verify_game024.ps1`, `tools/check_game024_gate.py`, `tools/run_regression.py`; tracked `build/regression-report.json` has 36 older passes and no source commit bound to the current branch. Latest source requires **102 mandatory Godot fixtures, 22 focused fixtures, 30 Python checks and four nonempty matching deterministic state replays**.

**Impact:** We cannot claim startup, 3D collisions, save integrity, mission completion, Android build or release viability. Every recent staged feature expanded the code under review without obtaining actual Godot evidence.

**Acceptance:** On a clean, pinned Windows Godot 4.7.2 checkout, run the strict local gate; require matching source SHA, explicit per-fixture marker + clean exit, zero engine errors, successful negative-path, four matching state traces, all focused/full fixtures. Then manual full campaign and Android acceptance. **Do this before more live gameplay integrations.**

### AUD2-002 — P1 / CONFIRMED SOURCE: traffic lanes extend beyond rendered roads
**Evidence:** `scripts/world/junction_builder.gd:46–90` creates a 5×5 lane grid at X/Z = `[-120,-46,0,46,120]`. `scripts/world/neighborhood.gd:24–27,75–84` draws axis roads at 0 and secondary roads at ±46; **there is no corresponding rendered road strip along the X/Z = ±120 perimeter**, even though it has driveable graph edges. The terrain extends to ±144.

**Impact:** City vehicles can be routed over grass/non-road visuals; this undermines legibility and makes lane/path safety difficult to interpret. It also means generated world topology has two independent definitions.

**Acceptance:** One source of truth for renderable road centerlines and driveable lanes. Every graph lane segment lies within a road surface width with clear shoulder margins; physical traffic scene shows no cars travelling off painted roads. Add full-city graph-to-rendered-road alignment regression and screenshots.

### AUD2-003 — P1 / RISK: city intersections beyond the center lack modeled right-of-way
**Evidence:** `scripts/traffic/traffic_spawner.gd:117–154` deliberately skips signal enforcement when an expanded-city lane doesn't end near the center, with comment that outer intersections have no central-junction signal. `junction_builder.gd` constructs multiple intersections while the scene supplies one central signal controller.

**Impact:** Vehicle turn conflicts outside Market Chowk can be resolved only by physical obstacle sensing rather than an explicit reservation/signal policy. Multi-car jams, turn clipping and car/pedestrian overlap are plausible.

**Acceptance:** Add conflict-zone policy per active city intersection or bounded yield priority, test two cars arriving from perpendicular approaches and pedestrians crossing at off-center junctions. Verify no overlapping reservations and no unbounded waiting.

### AUD2-004 — P1 / RISK: complex actor physics and checkpoint rollback lack device proof
**Evidence:** `scripts/player/player_controller.gd:117–196`, `scripts/npc/district_pedestrians.gd:189–671`, `scripts/traffic/vehicle_agent.gd:90–235`, `scripts/core/main.gd:395–555`. Restores perform collision checks, stage actors, and roll back when player placement fails. Swept movement, spawn clearance and reservation recovery are nontrivial.

**Impact:** Pushing/stacking, sudden pedestrian sidesteps, blocked saved positions, ghost obstacles and partial restore remain possible under crowded/jittery frame conditions.

**Acceptance:** Headless physical-space fixtures at actual physics ticks, then PC/Android manual scenarios for overlapping NPCs, moving car contact, boundary/fall recovery, mission actor collision, F5/F9 while incident world is active, backup recovery, and failure rollback.

### AUD2-005 — P1 / CONFIRMED SOURCE: mobile HUD, guide and finale have fixed-size layout conflicts
**Evidence:** `scripts/ui/touch_controls.gd:6–9,35–50` uses eight 72×64 buttons at fixed normalized positions and only one width-based screen/safe-area scale. `scripts/ui/civic_mission_guide.gd:17–54` anchors a 356-px top-right guide even on 320/360-px portrait screens; two 140-px buttons compete for its width. `scripts/ui/district_finale.gd:23–56` creates a results panel with 500-px minimum width and 480-px scroll content. `scripts/ui/civic_status_hud.gd:14–20` reserves a 348-px HUD width. The top-right touch Pause button shares the guide's top-right screen region.

**Impact:** On narrow screens controls and labels can clip, overlap or become difficult to hit, and the paused scorecard can exceed the viewport. The previously staged `CivicTouchLayout` is **not integrated with live controls**.

**Acceptance:** Responsive safe-area layouts for all UI layers, minimum 44-unit independently reachable targets, orientation/resizing tests, HUD/guide/pause nonoverlap, screenshots at 320/360/720px portrait, 740/1280/1920px landscape, and real Android multitouch playtest.

### AUD2-006 — P2 / CONFIRMED QA DEBT: 18 legacy fixtures still contain bare `assert()`
**Evidence:** All 102 Godot test files were scanned for direct `assert(...)` lines. **18** still use them, including `incident_lifecycle_test.gd`, `mission_framework_test.gd`, `neighborhood_test.gd`, `deadlock_recovery_test.gd`, `vehicle_behavior_test.gd` and `wrong_way_scenario_test.gd`. Several have a final `quit(0)` but **no explicit failure `quit(1)`**. `traffic_stop_line_test.gd` is NOT a missing-exit case: it correctly routes both outcomes through `_finish(exit_code)`.

**Impact:** Assertions behave differently depending on Godot build/assert settings; a failing assertion can abort before explicit quit or may be disabled in optimized builds. The strict runner catches script errors when printed, but this doesn't replace reliable explicit exits.

**Acceptance:** Migrate all 18 fixtures to descriptive `_fail()` + `quit(1)` paths, preserve their fixture-specific PASS markers and run the full regression. Add a lint rule or Python unit test preventing new bare assertions in headless fixtures. Do not automatically transform assertions whose expressions have side effects.

### AUD2-007 — P2 / CONFIRMED ARCHITECTURAL RISK: three different logical time units
**Evidence:** `CivicGameplaySession._physics_process()` increments `tick` once per physics callback (`scripts/civic/gameplay_session.gd:156–163`); `SimulationDirector` uses a 20 Hz logical `SimulationClock`; `CivicFreeRoamEvents._physics_process()` advances its own `tick` once per accumulated second (`scripts/civic/free_roam_events.gd:70–78`).

**Impact:** This is not automatically a bug: values are initialized and translated in some callers. However managers compare/restore timestamps from these different domains; future missions or live AI routines can mistakenly treat raw ticks as the same unit.

**Acceptance:** Document each clock domain and mapping, prohibit raw cross-domain comparisons, and test scenario durations, event deadlines and post-restore chronology over varying physics FPS and pauses.

### AUD2-008 — P2 / STAGED: advanced NPC utility does not yet drive visible NPC movement
**Evidence:** `scripts/npc/npc_utility_engine.gd` and `npc_decision_stability.gd` are pure logic/policy; `scripts/npc/district_pedestrians.gd` handles fixed sidewalk loops and crossing decisions without importing the new stability policy. GAME-025 daily routines remain separate/disabled.

**Impact:** Real moving pedestrians do not yet demonstrate varied sustained personalities, social decisions, contextual errands or day/night routine behavior.

**Acceptance:** Only after AUD-001 and campaign acceptance: integrate per-NPC blackboard/utility with fixed ticks, instant safety overrides, action holds, deterministic replay and opt-in rollback flag; prove no changes to civic score/rewards.

### AUD2-009 — P2 / UNMEASURED: crowd and procedural rendering scalability
**Evidence:** `district_pedestrians.gd` scans other walkers inside per-walker updates; `traffic_spawner.gd:92–115` senses leaders across the active fleet. `neighborhood.gd:126–163,206–249` and `street_furniture.gd:29–56` create many individually allocated meshes/materials. `performance_capture.gd` and `profile_city_baseline.gd` exist as opt-in tools; no accepted reports.

**Impact:** O(N²)-like neighbor work and draw-call growth are credible scale risks. **No measured FPS, p95, GPU, memory or throughput baseline has been produced**, so no bottleneck or improvement can be certified.

**Acceptance:** Pin scene, device, resolution, build mode, NPC/car counts and seed; record real windowed + Android median and p95 frame intervals, CPU physics/scripts, Godot Visual Profiler GPU and draw calls; optimize only the measured hotspot and rerun physics/regressions.

### AUD2-010 — P2 / RELEASE: Android path is a debug-export baseline, not an accepted release
**Evidence:** `export_presets.cfg` defines one `Android Debug` arm64-v8a preset with package version 0.1.0; no release preset. `docs/ANDROID_EXPORT.md` still references Godot 4.4.1 CI while project/stabilization targets Godot 4.7.2. `project.godot` uses GL Compatibility.

**Impact:** No verified Android install, touch focus, pause/resume, background recovery, heat/battery, package size, signing or release artifact. Debug-only success would not establish release readiness.

**Acceptance:** Update documentation and export templates to 4.7.2, verify SDK/JDK and debug install via adb, record Android device logs/screenshots, then add release signing/export smoke checks without committing secrets.

### AUD2-011 — P2 / GAME DESIGN: limited post-campaign reasons to return
**Evidence:** `README.md`, `main.gd:679–770` and `free_roam_events.gd` show campaign completion, scorecard and repeatable cleanup/sign/cone events with small civic-score outcomes. A persistent district-upgrade/city-rebuilding economy, ranked civic progression or expanding activity roster is not implemented in the current source.

**Impact:** Core completion can feel final; optional Free Roam incidents alone may not provide a strong long-term progression loop.

**Acceptance:** Plan (not silently implement) neighborhood trust tiers, unlockable projects, escalating district challenges and meaningful nonpunitive rewards, with save integrity, balanced scoring and offline achievements.

### AUD2-012 — P3 / POLISH: old preview copy and outdated issue narratives
**Evidence:** `scenes/core/main.tscn` still labels the HUD `CIVIC CHAOS | DISTRICT PREVIEW`. The older `docs/audits/FULL_GAME_AUDIT.md` describes P0 street-furniture type mismatch, vanishing LOD, secondary-road color and duplicate central ground as if current; current `street_furniture.gd` has StaticBody3D roots, `graphics_lod.gd` keeps essential meshes visible, `neighborhood.gd:147` colors secondary roads correctly, and `main.tscn` no longer includes an active extra ground collider (only unused ground subresources).

**Impact:** Misleading QA notes and an unfinished-feeling user interface obscure which problems actually remain.

**Acceptance:** Revise the canonical issue register with the current branch evidence; remove dead scene subresources and stale game text after release-critical fixes, without misrepresenting unrun Godot tests.

## 4. Ranked action plan / release gates

| Order | Task | Owner milestone | Objective exit |
| --- | --- | --- | --- |
| 0 | **Freeze source SHA and run actual Godot 4.7.2 local gate** | AUD-001 / PR #49 | 30 Python checks, import, 22 focused, 102 full, 4 state replays, intentional negative path; `ready: true` for exact SHA |
| 1 | Resolve first real import/physics/test failure from the logs | AUD-001 regression stabilization | No open engine parser/runtime errors; evidence linked |
| 2 | Fix graph-to-visible-road coverage and outer-intersection policy | AUD2-002/003 | Every driven lane visibly supported; deterministic priority tests |
| 3 | Validate full real-player campaign, rewards, F5/F9 and Free Roam | AUD-002 campaign playthrough | No duplicate rewards, lost progress, ghost props or unsafe restores |
| 4 | Responsive Android HUD, guide, touch and finale | UI-01 / issue #51 | On-device screen-size and multitouch acceptance; no cropped/overlapping UI |
| 5 | Activate NPC utility only behind a tested feature toggle | AI-01 / issue #50 | Stable 120+ ticks, instant safety overrides, fixed-seed replay, no civic regression |
| 6 | Profile real PC+Android city; optimize measured bottleneck | PERF-01 / issue #52 | Captured median/p95 before and after; no collision or mission regressions |
| 7 | Expand Free Roam rewards and long-term replay incentives | design milestone, separate scope | Signed-off retention plan, balanced earn/spend, compatible saves |
| 8 | Complete Android release checklist | release gate | Verified export, manual device gameplay, stable frame time, crash logs, signed package |

## 5. Recommended verification commands (Windows only)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git switch fix/aud-001-game024-gate-hardening
git pull --ff-only origin fix/aud-001-game024-gate-hardening

powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_game024.ps1 `
  -ExpectedBranch "fix/aud-001-game024-gate-hardening" -Timeout 120

python .\tools\check_game024_gate.py
Get-Content .\build\game-024-verification.json
Get-Content .\build\game-024-regression.json
```

Collect `build/game-024-verification-logs/`, `build/regression-logs/` and actual Android console logs for the first failure. Do not pass an old report or run GitHub Actions to bypass this local gate. **Even a passing headless gate needs a manual full campaign, responsive UI and physical-device test before release.**

## 6. Audit conclusion

Civic Chaos has a substantive offline vertical-slice architecture and implemented campaign source, but **code coverage ≠ verified game quality**. The immediate blocker is unexecuted exact-revision Godot/Android acceptance; high-confidence new source defects include disconnected perimeter road geometry and too-large fixed mobile panels. Several older graphics/prop defects are already source-fixed and should not be relisted as current unaddressed failures. Gameplay code for staged AI/UI/performance work must remain isolated until the verification barrier is met.

**Final verdict: PROTOTYPE / NOT RELEASE READY. No GitHub Actions run. No merged PR. No invented FPS or engine pass claims.**
