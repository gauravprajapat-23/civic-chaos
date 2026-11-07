# Civic Chaos — Actionable First-Playable Backlog
Planning IDs `GAME-001`–`GAME-028` (these are **not** GitHub issue numbers). Status: **PLANNED** unless otherwise marked. Main roadmap: [PHASED_BUILD_PLAN.md](PHASED_BUILD_PLAN.md).

## Workflow
One task/branch at a time → reproduce or define failing scenario → implement → run local Godot import + focused tests → full regression when systems touch physics → manual gameplay check → commit → update result. **No GitHub Actions.**

## Gate G0 — Reliability before features
| ID | Priority | Task / implementation | Evidence of acceptance |
|---|---|---|---|
| GAME-001 | P0 | Revalidate latest `pedestrian_spawn_separation_test.gd`, `graphics_lod_test.gd`, `building_distance_lod_test.gd`, then full suite; use separate report file to preserve user work | Exact latest commit, Godot 4.7.2 output, all relevant PASS |
| GAME-002 | P0 | Repair expanded-city signal mapping PHYS-010; red/green stop lines derived from world lane direction | City signal test with real lane IDs >=100; car advances on green |
| GAME-003 | P0 | Separate opposing lanes and legal turn connectors PHYS-011 | Two-way traffic plays without head-on body overlap; intersection graph validated |
| GAME-004 | P0 | Safe vehicle-vs-world collision and spawn occupancy PHYS-012/013 | Cars cannot clip into walls, people, props, parked vehicles |
| GAME-005 | P1 | NPC crossing ownership and route-safe recovery PHYS-014/015/017 | 30 NPC test, no overlap, no visible teleport, no held-crossing softlock |

## Gate G1 — Actual civic gameplay
| ID | Priority | Task / implementation | Evidence of acceptance |
|---|---|---|---|
| GAME-006 | P0 | Add `CivicGameplaySession` that owns existing civic service instances and event routing | Session active in main 3D scene; deterministic tick and unique IDs |
| GAME-007 | P0 | Bridge world incident spawn/observe/resolve to manager lifecycle and objective progress | Real object triggers one incident; no duplicates; transitions legal |
| GAME-008 | P0 | Build `IncidentMarker` with proximity, focus prompt, evidence and action confirmation | E/touch opens correct card; wrong distance rejected |
| GAME-009 | P1 | Connect live `CivicStatusHUD` mission, incidents and four civic metrics | HUD accurately follows simulation; no placeholder while session active |
| GAME-010 | P0 | Wire mission/incident/metrics/unlocks/seed save and versioned migration | Save/load/restart consistent; no duplicated rewards |
| GAME-011 | P1 | Tutorial walk-and-inspect with hints + accessible action choices | New player completes first interaction without developer intervention |

## Gate G2 — Wrong-Way Disaster: playable flagship
| ID | Priority | Task / implementation | Evidence of acceptance |
|---|---|---|---|
| GAME-012 | P0 | Link wrong-way scenario to real staged offender vehicle and congestion observation | Offender and queue visible; route legality intact |
| GAME-013 | P0 | Safe authorized marshal response and offender reroute | NPC service clears actual obstruction without player vehicle force |
| GAME-014 | P0 | Real recovery and idempotent mission reward | No completion before measurable sustained queue recovery |
| GAME-015 | P1 | Mission dialogue, objective waypoints, failure/retry | 3D end-to-end walkthrough and repeatable fail/retry success |

## Gate G3 — Additional missions
| ID | Priority | Task / implementation | Evidence of acceptance |
|---|---|---|---|
| GAME-016 | P1 | Illegal parking and pedestrian obstruction | Parking volume checked; safe relocation repairs walkway |
| GAME-017 | P1 | Littering, bins and sanitation assistance | Litter count drops in world; NPC cooperation reaction visible |
| GAME-018 | P1 | Three-mission story order, end-of-district scorecard, free roam | Campaign can finish once, replay and save |

## Gate G4 — Emergent chaos
| ID | Priority | Task / implementation | Evidence of acceptance |
|---|---|---|---|
| GAME-019 | P1 | Wire `CivicEventDirector` to real incidents, budget/cooldown | Seeded replay, nonconflicting spawn positions, no event spam |
| GAME-020 | P1 | NPC personality/social influence affects safe civic choices | Different traits cause distinct, deterministic reactions |
| GAME-021 | P1 | Causal-chain propagation and priority | One illegal park can trigger queue + crosswalk issue; fixing root resolves symptoms |
| GAME-022 | P1 | City feedback and fairness balance | Trust responds to false vs valid reporting; safety never rewards risk |

## Gates G5–G7 — Polish and release
| ID | Priority | Task / implementation | Evidence of acceptance |
|---|---|---|---|
| GAME-023 | P1 | Market district signage/storefronts/visual accessibility and LOD | Buildings remain visible; routes clear; budget measured |
| GAME-024 | P1 | Movement animations, NPC reactions and camera polish | No clip/foot sliding at game speed; readable silhouettes |
| GAME-025 | P1 | Bilingual-ready UI, tooltips, audio cues, touch parity | English complete; Hindi strings prepared; touch-accessible |
| GAME-026 | P0 | PC + Android stability and profiling | Actual device logs, load/save/restart, mission flow and FPS measurement |
| GAME-027 | P0 | Integrated gameplay, negative-path and seed replay suite | All P0/P1 tests PASS; no reward duplication or softlock |
| GAME-028 | P0 | Release packaging, checklist and acceptance playtest | Installer/APK verified; 3 missions finish; known issues documented |

## What already exists in code (reuse, don't rebuild)
- **Foundations:** third-person player, camera, street district, roads, traffic/vehicle scripts, basic NPCs, touches and HUD.
- **Logic-only systems (not full 3D gameplay):** `CivicMissionManager`, `CivicIncidentManager`, `CivicInteractionService`, `CivicCityMetrics`, `CivicEventDirector`, `CivicWrongWayMission`.
- **Regression suite:** broad headless tests, but the live integrated game has not passed a mission walkthrough and the latest physics/render patch awaits local validation.
- **Existing audit dependencies:** `docs/physics/NEXT_PHYSICS_AUDIT.md` and `docs/rendering/BUILDING_DISTANCE_LOD_FIX.md`.

## Immediate first two work batches
**Batch A — Stabilize and connect:** GAME-001, then GAME-002–005 in individual focused changes. Do not add more NPCs, cars or a larger map during this batch.

**Batch B — Make it a real game:** GAME-006–011, followed by GAME-012–015. Deliver one fully playable Wrong-Way Disaster mission before writing more campaign content.

## Local PowerShell validation (after pulling target branch)
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/pedestrian_spawn_separation_test.gd
& $godot --headless --path . --script res://tests/building_distance_lod_test.gd
python tools/run_regression.py --godot $godot --timeout 60 --report build/game-design-baseline.json
Write-Host "Exit code: $LASTEXITCODE"
```

Tests are not run by this planning commit. Keep every incomplete task PLANNED even if supporting classes already exist.

## Progress checkpoint — 2026-11-06 continuation
For detailed files and exact unverified acceptance commands see [GAME_CONTINUATION_PROGRESS.md](GAME_CONTINUATION_PROGRESS.md).

- [x] Source code added for GAME-003: left-side opposing lane offsets and no immediate U-turns; **not** final intersection design.
- [x] Source code added for GAME-005: conservative pre-entry crossing reservation cleanup; inner-road deadlocks remain.
- [x] Source code added for GAME-009: show actual four civic metrics on HUD.
- [x] Source code added for GAME-010: versioned civic-state save/load with strict validation and JSON whole-number normalization.
- [ ] Godot 4.7.2 import + new physics/civic regressions on latest head.
- [ ] Gameplay visual check of roads, NPCs, distant buildings and live civic mission.
- [ ] GAME-008/011 incident card, choices and tutorial.
- [ ] GAME-012/015 real wrong-way mission.
- [ ] Remaining gates G3–G7.

**None of the above source additions are marked accepted without engine and playtest evidence.**

## GAME-008 / GAME-011 progress — 2026-11-06

- [x] Code added: in-world E/USE tutorial label, evidence modal with touch-sized Inspect/Report/Close controls, focus management and Escape dismissal.
- [x] Code added: marker now opens the UI rather than auto-reporting; explicit actions recheck the actual actor, distance, incident stage and duplicates.
- [x] Test added: `tests/gameplay_incident_card_test.gd` covers far-range denial, evidence unlock, remote-click denial, duplicate reporting and actual cleanup; registered in `tools/run_regression.py`.
- [ ] Godot 4.7.2 import + focused test + full regression passing **on latest branch head**.
- [ ] PC walkthrough (aim/E, button clicks, pause, F9) and Android device tap test.
- [ ] Branching "ask owner" vs municipal report, live municipal helper animation and wrong-way scenario remain future work.

**Implemented but NOT accepted until runtime and actual gameplay verification.** See [GAME_008_011_INCIDENT_CARD.md](GAME_008_011_INCIDENT_CARD.md).


## GAME-012 live scenario — first implementation (2026-11-06)
- [x] Source: red wrong-way offender on an actual city road, dynamically moving follower cars, real queue telemetry, sidewalk report point, visual marshal response, and measured physical release.
- [x] Source: stage follows GAME-006 footpath completion; reuses incident service, mission objectives, city metrics and existing card.
- [x] Test authored: `tests/wrong_way_live_mission_test.gd`, registered in local regression runner. **NOT RUN**.
- [ ] Full local Godot 4.7.2 import and regression passes; PC scene walkthrough and screenshot verification.
- [ ] GAME-013 authorized towing/traffic-safe reroute, GAME-014 save/resume, GAME-015 dialogues and retry flows.

See [GAME_012_WRONG_WAY_LIVE.md](GAME_012_WRONG_WAY_LIVE.md). This is implemented source code, **not verified/accepted gameplay**.


## GAME-013 progress — Authorised physical tow convoy (2026-11-06)
- [x] Source: municipal tow service vehicle and tow link move red wrong-way offender *along the graph-legal lane*, instead of deleting it at marshal arrival.
- [x] Source: in-road swept collision checks, signal occupancy, no unauthorized towing, retry after occupied staging, and mission completion gated on full convoy exit **plus measured queue release**.
- [x] Tests authored: `authorized_tow_route_test.gd`, `authorized_tow_obstacle_test.gd`, strengthened `wrong_way_live_mission_test.gd` (non-teleport, actual tow, legal exit). Registered in strict runner.
- [ ] Godot engine focused test and full strict runner verification; city scene visual assessment; mobile-device test.
- [ ] GAME-014 persistence for the ongoing tow / mission; GAME-015 UX and retries.

Full detail: [GAME_013_AUTHORIZED_TOW.md](GAME_013_AUTHORIZED_TOW.md). **Code added, NOT yet accepted as verified gameplay.**


## GAME-014 — active wrong-way checkpoints (2026-11-06)
- [x] Code: `CivicWrongWayLiveMission` JSON-safe versioned snapshots and pure cross-manager preflight; stable follower-index data, lane and tow progress.
- [x] Code: F5/F9 scene wiring, new-scene physical car rebuild, post-tutorial shared clock, backward-compatible player-only saves.
- [x] Regression source: `wrong_way_checkpoint_test.gd` registered, including on-disk JSON recreation after mid-tow checkpoint and duplicate rewards checks.
- [ ] Godot 4.7.2 focused and full strict tests; visible PC/Android mission restore; GAME-013 tow verification still outstanding.

Full details: [GAME_014_CHECKPOINTS.md](GAME_014_CHECKPOINTS.md). **Not yet engine-verified.**


## GAME-015 — Guided missions, dialogue and recoverable stalls (2026-11-06)

- [x] Source: real waypoint direction/distance and readable objective progression for the tutorial and wrong-way mission.
- [x] Source: Neighborhood Radio and marshal dialogue, visual speech label, pause-safe guide.
- [x] Source: after a prolonged genuinely stalled service, show *opt-in* Reload Checkpoint and confirmation-gated Restart Level; never auto-award or reset traffic.
- [x] Regression source: `mission_guide_test.gd` and `mission_guidance_flow_test.gd` registered in strict runner.
- [ ] Fresh Godot runtime test and 3D playthrough, including GAME-013 towing and GAME-014 checkpoint regression.
- [ ] Localization/audio/animation polish and mobile UI acceptance.

Details: [GAME_015_MISSION_GUIDE.md](GAME_015_MISSION_GUIDE.md). **Code committed, runtime unverified.**


## GAME-016 — Illegal parking with a real pedestrian blockage (2026-11-07)

- [x] Source: orange solid car blocking a 2 m north sidewalk, real pedestrian swept movement, observed physical stopping and reopening.
- [x] Source: visible cooperative owner, E/USE action `request_owner`, revalidation of distance/evidence/once-only report, authorized physical relocation to a marked bay.
- [x] Source: no score/reward until the actual witness moves beyond the former obstruction and the path is open; one-time civic outcomes.
- [x] Scene: follows completed wrong-way mission; new guide and existing incident card/HUD reused.
- [x] Tests authored: `illegal_parking_live_test.gd`, `illegal_parking_obstacle_test.gd`, `parking_owner_card_test.gd`.
- [ ] Engine import, focused tests, full strict regressions and visual playtest.
- [ ] GAME-017 parking mission persistence (GAME-014 format currently refuses incomplete parking saves).
- [ ] Background pedestrian path-network integration, owner alternatives and better vehicle/owner animations.

See [GAME_016_ILLEGAL_PARKING.md](GAME_016_ILLEGAL_PARKING.md). **Code added; not Godot-verified.**


## GAME-017 — Campaign checkpoint persistence (2026-11-07)

- [x] Source: parking car/owner/witness physical snapshot, bounded route progress and cross-manager validation.
- [x] Source: F5/F9 restores active parking alongside previous completed wrong-way state, with compatibility and anti-duplication checks.
- [x] Tests authored and registered: `parking_checkpoint_test.gd`, `multi_incident_checkpoint_test.gd`.
- [ ] Godot 4.7.2 import, focused and full regression suite, GAME-014 retest and manual PC/Android playthrough.
- [ ] GAME-018 full transaction recovery and extended save migration.

See [GAME_017_CAMPAIGN_CHECKPOINTS.md](GAME_017_CAMPAIGN_CHECKPOINTS.md). Code is **not yet engine-verified**.


## GAME-018 — Verified save generations and guarded restore (2026-11-07)

- [x] Source: canonical SHA-256 checksummed v2 saves; verified temporary generation, last-known-good `.bak`, primary/backup read selection and legacy v1 compatibility.
- [x] Source: single-document F9 player+civic restore; transaction guard freezes involved civic/mission physics and releases previous schedules on commit/failure.
- [x] Tests authored and registered: `save_resilience_test.gd`, `checkpoint_transaction_test.gd`, `save_generation_consistency_test.gd`; legacy lifecycle and save-test isolation updated.
- [ ] Godot 4.7.2 focus/full tests, GAME-014/017 retests, PC/Android manual acceptance.
- [ ] Full-world atomic checkpointing and background traffic/signal snapshot, future schema migrations.

See [GAME_018_SAVE_INTEGRITY.md](GAME_018_SAVE_INTEGRITY.md). **Source committed, runtime unverified.**


## GAME-019 — Background world checkpoint (2026-11-07)
- [x] Source: F5/F9 saves real city traffic lights, fixed clock, seeded vehicle routes/positions, pedestrian crossings and reservation ownership.
- [x] Source: guarded physical restage and shared world tick preflight in existing checkpoint transaction.
- [x] Regression source: `world_traffic_checkpoint_test.gd`, `world_junction_checkpoint_test.gd`, `world_pedestrian_checkpoint_test.gd`.
- [ ] Godot import/focused/full strict regression, PC/Android collision playtests and stronger city-wide rollback.
See [GAME_019_WORLD_CHECKPOINTS.md](GAME_019_WORLD_CHECKPOINTS.md). Source only; runtime unverified.


## GAME-020 — Dense-traffic transaction recovery (2026-11-07)

- [x] Source: stage background cars without deleting original nodes, then commit only after physical pedestrian landing checks; abort restores original colliders and counters without recreating cars.
- [x] Source: reject concurrent staged loads, prevent traffic ticks during staging and guard player restore eligibility before changing civic/world state.
- [x] Regression source: `world_transaction_rollback_test.gd`, `traffic_transaction_stress_test.gd`; expanded single-generation player restore test.
- [ ] Godot 4.7.2 import and focused/full GAME-014–020 regressions, dense-traffic/Android manual verification.
- [ ] Broader crash-atomic scene replacement and background world-object rollback.

See [GAME_020_TRANSACTION_RECOVERY.md](GAME_020_TRANSACTION_RECOVERY.md). **Code committed, Godot runtime unverified.**


## GAME-021 — Market Clean-Up Chain (continuation milestone, 2026-11-07)

- [x] Source: after real parking recovery, three collectible litter objects and a physical two-slot market bin are staged on the north walkway.
- [x] Source: existing incident card supports inspected collection, one-item carry, measured bin deposits, genuine full-bin service request, visible helper walk and bin emptying, single verified outcome/reward.
- [x] Source: F5/F9 `cleanup_checkpoint` validates bin volume, item states, sanitation progress and civic objectives against the authoritative civic snapshot.
- [x] Tests written: `market_cleanup_live_test.gd`, `market_cleanup_checkpoint_test.gd`, `market_cleanup_card_test.gd` and historical tutorial/parking clock test extensions.
- [ ] Local Godot 4.7.2 import, focused/full regressions, PC/Android physical walkthrough and cleanup checkpoint recovery.
- [x] GAME-022 source: final three-story results, district scorecard and Free Roam unlock (local Godot verification pending).
- [ ] Separately pending: original backlog's event-cascade GAME-021 (ID collision — not implemented).

See [GAME_021_MARKET_CLEANUP.md](GAME_021_MARKET_CLEANUP.md). **Runtime verification pending; CI/manual workflow dispatch intentionally deferred.**


## GAME-022 — District Finale, Civic Scorecard and Free Roam (2026-11-07)

- [x] Source: first story campaign ends after physically verified cleanup; four authentic tutorial/mission completions unlock Free Roam exactly once.
- [x] Source: story ending and scrollable scorecard display read-only city metrics, district reputation/rating, completed missions and earned reward totals.
- [x] Source: Continue in Free Roam resumes simulation, F2/on-screen button reopens results, Replay Story requests confirmation and restarts without deleting disk save immediately.
- [x] Source: F5/F9 `campaign_checkpoint` persists the unlocked/acknowledged state; checks completed manager/incident history, rejects fabricated rewards and supports older completed GAME-021 checkpoints.
- [x] Tests written: `district_campaign_unlock_test.gd`, `district_finale_ui_test.gd`, `district_finale_checkpoint_test.gd`; all registered in strict local regression runner.
- [ ] Godot 4.7.2 import, new and accumulated checkpoint regressions, PC/Android finale playback and device accessibility.
- [ ] Later improvements: decorative ending art/audio and optional dynamic Free Roam incident generation.

See [GAME_022_DISTRICT_FINALE.md](GAME_022_DISTRICT_FINALE.md). **Source committed, runtime unverified. GitHub Actions remain manual-only.**
