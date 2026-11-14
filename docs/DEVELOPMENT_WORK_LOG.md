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
| QA-PLAY-01 | P0 | Complete a human first-time playthrough of tutorial, wrong way, parking, cleanup, finale and Free Roam | PLAYTHROUGH MATRIX READY — HUMAN/ANDROID EVIDENCE PENDING | Recorded steps, screenshots, blockers and end state |
| AI-03-VERIFY | P1 | Verify opt-in daily routine / assistance safely and in real scenes | SAFETY FIX + TEST COMMITTED — LOCAL VERIFICATION PENDING | Godot import, AI tests, crossing/traffic checkpoints, visual review |
| UX-02 | P1 | HUD / modal readability, touch sizing and safe-area audit | RESPONSIVE TEST PASSED — DEVICE REVIEW PENDING | Screenshot comparison at PC and mobile aspect ratios |
| STORY-CHOICE-01 | P1 | Make meaningful, safely recoverable player choices | 3 PARKING FOCUSED TESTS PASSED — FULL GATE PENDING | Distinct tested consequences, no duplicate rewards |
| PROG-01 | P1 | Reputation ranks and offline rotating civic goals | USER REPORTED FOCUSED TESTS PASS — LATEST FULL GATE UNCONFIRMED | Save/replay/anti-farming tests, clear return incentive |
| PROG-02 | P1 | Neighborhood support unlocks with physical Free Roam navigation benefits | CODE COMMITTED — GODOT TEST PENDING | Audited-receipt thresholds, visual beacon, stage transition, reload consistency |
| PROG-03 | P1 | Visible neighborhood improvement projects earned from real civic work | CODE COMMITTED — LOCAL TESTS / VISUAL QA PENDING | Tier gates, no extra scores, physically non-blocking objects, checkpoint reconstruction |
| PROG-04 | P1 | Usable community garden, kiosk and solar response information services | CODE COMMITTED — GODOT REGRESSION PENDING | E/USE gated at real location, audited unlock, no score mutation, valid save replay |
| GAME-QA-01 | P0 | Complete Playability and Visual Audit | AUDIT PLAN + HUD/GUIDE LAYOUT FIX COMMITTED — LOCAL TESTS PENDING | Actual screenshots, full manual journey, Android QA |
| ART-01 | P1 | Consistent buildings, NPC silhouettes, props, environment and movement polish | TODO | Visible screenshots and real playtest signoff |
| AUDIO-01 | P1 | Feedback SFX, ambiance, dialogue captions and mute/volume controls | TODO | Auditory/readability QA and muted accessibility |
| PERF-ANDROID-01 | P0 | Android touch parity, real-device frame/physics measurements and stability | TODO | Hardware profile, no invented FPS claims, complete campaign test |
| RELEASE-01 | P0 | Signed Android release export, package QA and final acceptance | BLOCKED | Completed P0/P1 checks, reproducible signed build |

## Work journal (append, never overwrite historical evidence)

### 2026-11-14 — CAR-ART-04B/C enclosed sedan glass and mirror redesign
- User asked to continue CAR-ART-04. Based on the actual `vehicle_visuals.gd`, the previous mirror was a solid dark block at ±0.855 m with no rear-facing glass or mount; front/side glass was oversized and sat outside the tapered cabin silhouette.
- `scripts/traffic/vehicle_visuals.gd` now positions roof and front/rear/side glass relative to the tapered cabin. Both mirror assemblies have short attached mounts, compact dark housings and separate pale blue-gray metallic mirror glass on the rear-facing surface. Existing `Mirror_L`/`Mirror_R` node names retained.
- Added `tests/car_art_04bc_visual_test.gd` checking symmetric mirrors, mounting offsets, housing dimensions, reflective material separation, cabin mesh, unchanged vehicle collision box and no additional physical colliders.
- Tracker `docs/qa/CAR_ART_04_TRACKER.md` advanced phases 04B/C to **CODE COMMITTED / TEST NOT YET RUN**. 04A jump/collision acceptance remains pending, 04D paint/materials and 04E physical Android audit remain open.
- Commits `485f392`, `cb0d7e4`, `4e7b8a0`; no GitHub Actions triggered. **Godot import, focused geometry tests, full GAME-024 gate, screenshots and Android measurements still pending.**



### 2026-11-14 — CAR-ART-04A airborne player-car contact started
- User screenshot showed player visually embedded in roof/cabin; the current `CivicPlayerController` uses world-only collision mask 1 and independent horizontal vehicle layer-4 sweeps. Source review confirmed previous contact code swept only at the **present** player capsule height and skipped collision evaluation when horizontal input was zero; a descending player could consequently enter the car from above.
- Updated `scripts/player/player_controller.gd`: conservative horizontal-motion collision fraction at current **and predicted vertical** height, and minimal tested perimeter escape for a falling player overlapping a vehicle. The recovery checks world/car/pedestrian clearance before repositioning and preserves the no-vehicle-roof-as-floor policy. No traffic logic, collision layers or save schema changed.
- Added `tests/car_art_04a_jump_clearance_test.gd` (center and side descent) and `tests/car_art_04a_side_contact_test.gd` (airborne forward contact and subsequent release).
- Created full work register `docs/qa/CAR_ART_04_TRACKER.md` for phases 04A collision, 04B cabin, 04C mirrors, 04D paint/glass, 04E Android/gameplay acceptance. All work is tracked as **committed vs verified**, with P0 acceptance gates and PC/device evidence requirements.
- Commits `8c33548`, `2be2bfd`, `a50fe8b`, `1a1b890`, `dd17c7e`.
- **LOCAL GODOT VERIFICATION PENDING.** Run new focused tests, prior `player_vehicle_contact_test.gd`, traffic/crossing/checkpoint tests and exact-SHA GAME-024 gate. Manual jump/sideways collision screenshot or video and Android playtest remain necessary before marking 04A passed. No GitHub Actions triggered.



### 2026-11-14 — CAR-SAFE-05 initial flow-recovery and Android measurement batch
- Inspected `CivicTrafficSpawner.advance_fixed()`, existing per-tick safety observations, `CivicTrafficBudget.metrics()`, checkpoint state and outer intersection tests. Existing spawner continued creating new cars even when most active cars were stationary.
- Implemented deterministic **queue-pressure spawn backoff**: at least 3 active vehicles and at least 75% below 0.2 m/s suppresses new spawns; automatically clears once moving traffic reduces congestion. No rerouting, teleporting, signal override, collision bypass, RNG draws or false rejections. Both per-tick and direct `try_spawn()` use the same admission policy.
- Added live diagnostic metrics `congested`, `spawn_backpressure_ticks` and `queue_pressure()` while preserving the existing save schema and accurate measured workload telemetry. Counter resets on traffic generation configure and checkpoint commit.
- Added focused `tests/car_safe_05_backpressure_test.gd` for 3/4 queued vs 2/4 moving, suppression without changing RNG/rejections, automatic release and snapshot isolation.
- Added `docs/qa/CAR_SAFE_05_FLOW_PERFORMANCE.md` with strict Godot local verification and physical Android measurement checklist. **No Android FPS/device figures claimed.** Persistent stalled traffic root-cause resolution and safe reroutes remain open follow-up work.
- Commits `9004139`, `659505f`, `811e773`. **Code committed, Godot local regression and hardware observations pending.** Do not run GitHub Actions.



### 2026-11-14 — CAR-SAFE-04 live traffic checkpoint/character protection
- User reports the preceding focused traffic/character tests passed; the latest full GAME-024 acceptance for subsequently modified code is **not yet verified**.
- Reviewed `CivicTrafficSpawner.prepare_restore()`, `CivicVehicleAgent.people_clear_at()`, vehicle/player/pedestrian collision layers and outer-junction physical traffic tests. Found a concrete restore-path gap: normal spawning rejects actors in the **45-cm protective buffer**, but checkpoint staging checked only `footprint_blocked_at` (smaller hard collision).
- `prepare_restore()` now applies both padded `people_clear_at` and hard `footprint_blocked_at` checks before staging vehicles. A failed restore still frees staged cars and restores old collision layers; no checkpoint fields or movement rules were changed.
- Added `tests/car_safe_04_checkpoint_test.gd`: valid save payload at a real graph position; reject player and pedestrian each placed outside the hard box but inside the padded corridor; confirm no state change/prepared generation after rejection; clear actors, stage/abort, then stage/commit successfully.
- Reuses one per-vehicle `BoxShape3D` for repeated human collision probes instead of allocating a new shape at each route-sampling step, and extends `tests/car_character_clearance_test.gd` with shape-identity assertions.
- Commits `0d3846a`, `74f8d53`, `2b6395a`, `90e48b8`.
- **Local Godot validation pending:** import, `car_safe_04_checkpoint_test.gd`, `car_character_clearance_test.gd`, `vehicle_actor_safety_test.gd`, `vehicle_pedestrian_recovery_test.gd`, `outer_intersection_movement_test.gd`, `traffic_checkpoint_invariants_test.gd`, `checkpoint_load_queue_test.gd`, then full GAME-024 verification. Manual moving-player busy-junction and Android performance observations remain pending.



### 2026-11-14 — CAR-SAFE-03 unblock Godot parser and guard traffic spawn indentation
- User's exact Godot 4.7.2 console output revealed a **syntax blocker** at `scripts/traffic/traffic_spawner.gd:233`: `Used space character for indentation instead of tab as used before in the file`. Godot editor import displayed script errors despite allowing the terminal session to continue; four earlier focused tests still passed, but `traffic_checkpoint_invariants_test.gd` could not load `CivicTrafficSpawner`. Later tests were **not executed**.
- Corrected only the two misindented comments and `vehicle.physics_obstacle_checks_enabled = true` inside `try_spawn()`, preserving the intended character-avoidance physics and tick behavior. Commit `c14487e`.
- Added Python guard `tests/test_traffic_spawn_indentation.py` to require tab indentation in `try_spawn()` and verify actor clearance is enabled before the spawn occupancy check, and checked before appending the car. Commit `0f56f0b`.
- **Status: FIX COMMITTED, GODOT IMPORT AND TRAFFIC REGRESSION RE-RUN PENDING.** Note that Godot may print `SCRIPT ERROR` while returning exit code 0: inspect output explicitly as well as `$LASTEXITCODE`. Re-run safety, actor overlap/recovery, checkpoint, junction tests, then the full GAME-024 gate. Do not export an APK based on the broken import.



### 2026-11-14 — CAR-SAFE-02 protected vehicle/person clearance and sedan polish
- Source review: CivicVehicleAgent already used full oriented footprint sweeps with sub-metre samples, physical layer 4 car body, player collision layer 2, pedestrian collision layer 8, and player side-motion cast. Preserve deterministic route physics and existing save/checkpoint schema.
- Added a **separate padded human clearance query** (45 cm on car sides/front/rear) at each prospective vehicle footprint step plus an immediate safety query before acceleration. People within the corridor hold traffic in place, instead of allowing visual/physical overlap. The car's actual collision shape remains unchanged; surface/road/prop queries are still done by the existing authoritative footprint.
- Spawner now refuses a traffic entry within the same padded player/pedestrian corridor. No new randomness or backend; traffic timing/determinism requires local regression verification.
- Added `tests/car_character_clearance_test.gd` with player and pedestrian sensing bodies to validate stop-before-contact and resume-after-clear in a real Godot physics world.
- Car visuals expanded with three front grille slats, a front badge and paired side marker/reflector details; extended `tests/vehicle_visuals_test.gd` to check these objects.
- Commits `4b76259`, `75d557f`, `f534440`, `b53ef81`, `28b9ec0`.
- **CODE COMMITTED; LOCAL GODOT VERIFICATION PENDING.** Import and test `car_character_clearance_test.gd`, `vehicle_visuals_test.gd`, `vehicle_scene_contract_test.gd`, `vehicle_feedback_optional_test.gd`, `player_vehicle_contact_test.gd`, `traffic_checkpoint_invariants_test.gd`, `outer_intersection_priority_test.gd`, `outer_intersection_movement_test.gd`, then full GAME-024 gate at exact commit. A complete PC/Android crossing playthrough and FPS capture still required; cannot assert collisions never occur without physical-device verification.



### 2026-11-13 — ART-CAR-02 visual detail and physical car/actor avoidance
- User requested more recognizable cars, and improved interaction when the player or NPC pedestrians come into contact with moving cars.
- **Physical change:** `scripts/traffic/traffic_spawner.gd` now enables the existing physics obstacle sweep for *all* spawned physical vehicles, not only expanded-city cars. Each vehicle samples its forthcoming footprint and brakes when layer-2 player, layer-8 pedestrian, other vehicle or protruding street obstacle would be hit; the fixed route, collision box, save schema, speed law and RNG remain unchanged. Pure abstract traffic-agent tests continue to function without a collider. This avoids introducing dynamic rigid-body impulses or damage while stopping actor penetration.
- **Pedestrian spawn hardening:** `_spawn_is_clear` avoids currently known live traffic positions when a spawner is connected. This intentionally avoids unsafe `direct_space_state` queries in `_ready()`; physics-frame pedestrian path probes remain unchanged. Changes `ba82bf0`, `588da95`.
- **Visual:** additional window center pillars, door seams, running boards, wheel-arch trim, bumper intake, chrome waistline, fog lamps and central brake strip. Rear light emission responds to real vehicle stop state; no new colliders or traffic RNG draws. `4d06a00`, `9f7525f`.
- **Regression:** `tests/vehicle_actor_safety_test.gd` stages a physically collidable player then a pedestrian in a real lane, requires a moving car to brake before contact and resume after clearance. `tests/vehicle_visuals_test.gd` now verifies styling features and brake-light state. `bca329e`, `37183f7`.
- Additional work: tapered custom `ArrayMesh` cabin roof replaces the old rectangular mesh (`b97d94f`), preserving original `Cabin` node name. NPC overlap recovery now detects physically embedded pedestrians against the oriented vehicle footprint and searches a local collision-checked landing position rather than leaving them inside the vehicle (`ba9a5ae`).
- New `tests/vehicle_pedestrian_recovery_test.gd` validates that local recovery, and `tests/vehicle_visuals_test.gd` checks the tapered cabin (`1e6e204`, `a34a9a2`, `6ab2413`). This improves recovery of already-overlapping actors; does not claim full rigid-body vehicle impact physics.
- **Status: CODE COMMITTED, LOCAL GODOT VERIFICATION PENDING.** Run import, `vehicle_actor_safety_test.gd`, `vehicle_visuals_test.gd`, `player_vehicle_contact_test.gd`, `vehicle_scene_contract_test.gd`, `traffic_checkpoint_invariants_test.gd`, `world_pedestrian_checkpoint_test.gd`, and full GAME-024 gate. Confirm real Android controls and moving-car safety before release. No GitHub Actions manually triggered.



### 2026-11-13 — ART-CAR-01 sedan visual replacement, no traffic changes
- User requested the existing Civic Chaos vehicle look recognizably like a car instead of a toy-like box.
- Inspected the actual traffic scene `scenes/traffic/vehicle_agent.tscn`, root `CivicVehicleAgent`, existing four named wheels and authoritative `CollisionBody/CollisionShape3D` (BoxShape3D 1.6×1.2×3.0). Kept the scene contract and unchanged collision, node paths, route physics and save model.
- New `scripts/traffic/vehicle_visuals.gd` builds a sedan silhouette using lightweight BoxMesh/CylinderMesh children: reshaped low chassis, cabin, sloped glass, side windows, hood/trunk/roof, bumper, grille, headlights/taillights with emission, mirrors, handles and hubcaps. No added colliders or GPU-heavy external assets.
- Scene now instantiates `DetailVisuals` and route configuration sets cosmetic paint from the existing first lane ID; **no new random draws**, preserving deterministic traffic spawning and replay.
- Added `tests/vehicle_visuals_test.gd` checking scene detail parts, unchanged box collider, car movement, repeatable paint and distinct lane colors. Existing `vehicle_scene_contract_test.gd`, `vehicle_feedback_optional_test.gd`, vehicle movement/checkpoint tests still required.
- Commits `3a29478`, `4195f1c`, `d700189`, `2c13038`. **Implementation committed, local Godot import/tests and actual screenshot/Android APK acceptance pending.**



### 2026-11-13 — GAME-QA-01 screenshot: How to Play content wraps one letter per line
- User-provided screenshot shows the How to Play modal frame at healthy width but instruction text squeezed into a narrow sliver, forcing single-character lines. Classified **P1 UI readability blocker**.
- Root cause: the wrapping `Label` nested directly under `ScrollContainer` lacked a useful minimum content width; scrolling container vertical expansion did not guarantee text-layout width.
- Fix in `scripts/core/menu.gd`: explicitly size the instruction label to the responsive panel width minus safe content margins/scrollbar, expand horizontally, keep vertical scroll, disable horizontal scrolling. Existing start/navigation logic is untouched.
- Extended `tests/menu_ux_test.gd` with checks for actual text width and no horizontal overflow. Commits `33007ae`, `02242be`.
- **LOCAL GODOT TEST AND VISUAL RECHECK PENDING.** Reopen How to Play at 1037×676 (reported image), 320×568 and 740×360; text must display words/paragraphs, not one letter per line. Later committed edits invalidate the previously accepted `88e2b10` full gate baseline.



### 2026-11-13 — GAME-024 fully accepted; GAME-QA-01 gameplay/visual audit started
- User supplied **complete GAME-024 acceptance at exactly `88e2b108066b43378a0b8385e84af37720269060`**: status `passed`, 113/113 full regression tests, 24 focused tests, independent evidence `True`, Godot import/negative-path gate passed. This is an accepted **engineering baseline**, not a claim of manual game quality or acceptance of newer commits.
- Source audit found fixed-size mission guide offsets and potential overlap with civic HUD on narrow portrait displays. Replaced fixed guide bounds with deterministic viewport-relative `CivicMissionGuide.panel_bounds`, moved portrait HUD below the upper guide, and added `tests/game_qa_mission_guide_test.gd` covering 5 screen sizes, overlap and recovery actions.
- How to Play now explains direct/municipal illegal-parking choice and the usable neighborhood projects, eliminating outdated onboarding.
- Added `docs/qa/GAME_QA_01_PLAYABILITY_VISUAL_AUDIT.md` with a real player path from menu through tutorial, wrong-way, parking choices, cleanup, finale, Free Roam, support services and save/restore plus PC/mobile viewport & Android evidence matrix.
- Commits `53a2f54`, `230e2b8`, `df65fd4`, `7155577`, `bb64fd0`, `c7dd3ae`, `499bc80` (vertical scroll), `988445c` (scroll regression).
- **Status: Code committed; NO local Godot result yet for these edits.** Manual walkthrough, screenshots, Android tactile performance and art/audio evaluation are open. Rerun focused QA and full acceptance at exact new commit; no GitHub Actions manually triggered.


### 2026-11-13 — Exact 113/113 suite accepted by runner; Git probe failed in independent validator
- User supplied exact report at commit `ac46337ef44bcab57ab1eb356e3cae88ac2e8749`: **113/113 regression cases**, `full_regression_passed=True`, `source_unchanged=True`; the independent checker returned `branch=""`, `commit=""` and Git evidence issues. This is a genuine **blocked** gate, not a Godot test failure.
- Root cause at the process level remains **unconfirmed**. `tools/check_game024_gate.py` previously swallowed exceptions/failed exit codes from **any one** of its three Git subprocess calls and replaced both otherwise-valid branch and commit with blanks. The strict runner had independently obtained a real commit.
- Updated Git evidence probe to check branch, commit and status **separately**, keep any successful data, and include specific Git exit codes/stderr or exception types in the checker `issues` list. Existing strict commit equality, tree cleanliness, replay/negative tests and inventory checks remain enforced. Commit `4c7c215`.
- Next: update local checkout, run `python tools/check_game024_gate.py` against the existing reports for a precise diagnostic. Since those reports were generated at an older SHA, `verification_commit_mismatch` is expected **until the full gate is rerun on the new commit**; use the Git-specific issues to locate an environment/configuration problem first. Never treat a stale report as pass.

### 2026-11-13 — Independent postgate evidence validation blocked
- User ran `tools/verify_game024.ps1` and all **24/24 focused GAME-024 tests passed**. The script then set provisional `passed`, indicating its full regression and other acceptance conditions had passed; the **final independent evidence checker blocked** and downgraded the result.
- Exact unmet condition(s) are **not known**: the original script only printed a generic "Independent evidence validation failed" line. The source of truth is `build/game-024-verification-logs/postgate-evidence.log` or `postgate-evidence.log.stdout` on the user's Windows machine.
- Updated `tools/verify_game024.ps1` to include the checker's specific `issues` list in the gate report and console message, retaining fail-closed behavior. Commits `399a24a`, `3495b54`; no validation flags or acceptance thresholds were weakened.
- **No new full GAME-024 PASS is claimed.** Next inspect the already-written checker log, repair the specific evidence mismatch, and rerun acceptance on the resulting exact Git commit.

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
