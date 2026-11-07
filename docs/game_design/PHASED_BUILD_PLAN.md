# Civic Chaos — Phased Implementation Roadmap
Date: 2026-11-06 · Planning baseline: `fix/regression-nov05` at `79b2148` · No GitHub Actions

## Delivery rule
Build **one vertical slice** to playable quality before expanding city size, NPC count or features. All stages are sequential dependency gates, **not promised dates**. Each stage ends only with a local Godot 4.7.2 import, relevant executable regressions and actual PC gameplay evidence. Android export requires separate device testing.

## Progress legend
- **Exists (logic only)**: file/test exists but is not connected as player gameplay.
- **Implemented, unverified**: code was changed, but latest engine test result was not provided.
- **Planned**: not implemented.
- **Accepted**: executable tests + game walkthrough documented and reproducible.

| Gate | Goal | Required deliverable | Dependencies | Exit / evidence |
|---|---|---|---|---|
| G0 | Stabilize core game | Safe nonoverlapping spawns, no disappearing building shells, playable vehicle/crosswalk collisions | Existing physics/render code | All relevant regressions PASS on current head + visual playtest in city |
| G1 | Playable civic loop | Session controller integrating incidents, interactions, missions, metrics, HUD and persistence | G0 | Discover→inspect→report→intervention→verified outcome→reward using game controls |
| G2 | Flagship wrong-way mission | Live wrong-way car, real queue, traffic marshal NPC, objective prompts, recovery | G1 + safe lane/traffic corrections | Player can complete wrong-way mission in 3D without scripted test calls; retry/save pass |
| G3 | Second and third civic incidents | Illegal parking and littering systems with different decision mechanics | G2 | 3 connected missions; no fake rewards; cause/effect visible |
| G4 | City social simulation | Personality-driven compliance, public feedback, seeded incident cascades | G3 | Different seeded runs, consistent/replayable outcomes; bounded active events |
| G5 | Presentation and usability | Lived-in market district, animation, bilingual-ready UI, accessibility, mini-map if budget permits | G4 | Human walkthrough by a new player, clear directions, no missing art or overlapping UI |
| G6 | Performance and Android | Low-cost geometry, LOD, physics budgets, touch layouts, Android packaging | G5 | Real Windows and Android profiling, no persistent stalls, stable load/save |
| G7 | Release candidate | Negative-path QA, mission flow, metrics correctness, package/sign/release checklist | G6 | Zero open P0/P1; documented P2 exceptions; complete release smoke tests |

## G0 — Fix before new gameplay
The source audit found serious pending risks (not all reproduced): expanded-city stop lines map to old lane IDs; opposing cars share one centerline; car probes omit world geometry; car spawn checks other cars only; NPC crossing reservations can remain occupied; recovery may hop off route. The previous submitted Godot suite at `927fc8f` passed 45/46 with forced NPC overlap failing; candidate changes later pushed but not independently verified. The distant-building visibility patch `79b2148` also needs real Godot validation.

**Tasks:** rerun focused NPC, LOD and full local regressions (separate report file); fix the city stop-line mismatch; separate left-driving lanes; implement world obstacle/spawn clearance and proper pedestrian occupancy cleanup. Prefer small, verified commits. Do not weaken tests.

## G1 — Integrate systems into playable scene
1. Add a `CivicGameplaySession` scene coordinator in `scripts/civic/` and mount it in `scripts/core/main.gd`. Keep `CivicIncidentManager`, `CivicMissionManager`, `CivicInteractionService`, `CivicCityMetrics` as the authorities.
2. Introduce a typed/event-validated bus with stable IDs: `incident_observed`, `incident_reported`, `service_requested`, `intervention_started`, `world_recovered`. Avoid duplicate processing or reward farming.
3. Build one physical incident marker with in-world visual clues, interaction range check and accessible card showing evidence/action choices.
4. Hook real-world recovery measurements into mission objectives and score dimensions; never synthesize a recovery signal purely from a button click.
5. Add session save versioning for player + civic modules; use stable actor/incident IDs.
6. Bind live mission, incident count and reputation to existing `CivicStatusHUD`. Implement a minimal tutorial that is a mission.

**Acceptance test:** start from main menu, walk to a real incident, inspect it, request a permitted action, see a real in-world change, complete mission and reload without duplicate points. Include negative checks for wrong distance, false evidence, duplicate resolution, save corruption and pausing.

## G2 — Flagship mission
- Reuse `CivicWrongWayMission` objective definitions / incident transitions, but replace its purely synthetic queue with live vehicle observations.
- Create a safely scripted wrong-way NPC car event that cannot corrupt legal lane routing and never requires player to run into a moving road.
- Use a city marshal NPC or service dispatch interaction. Animate enforcement/cooperation; then reroute/offboard offender legally.
- Record real queue release sustained over N ticks; update metric deltas once only.
- Camera, arrows and dialogue emphasize consequences and choices.
- Playtest loss/retry, reporting before evidence, queue already resolved, marshal never arrives, car stuck.

## G3 — Additional violations
- **Illegal parking**: design signage, parking spot validity, obstruction volumes, owner dialogue, voluntary relocation, marshal fallback and pedestrian route repair.
- **Littering**: visible tracked litter object count, finite bin capacity, cleanup interaction, sanitation service, local cooperation reactions.
- Both incidents must affect city state, not just UI values.
- Add linked 3-mission campaign, district result screen and Free Roam unlock.

## G4 — Dynamic behavior
- Integrate existing `CivicEventDirector`, `CivicNPCPersonality`, social influence, traffic budget and city metrics.
- Data-drive incident frequency/severity from current state; prevent event spam around player spawn and protect critical road access.
- Use understandable NPC reactions; stop indefinite red-light crossing waits; bounded event concurrency.
- Deterministic seed replay and fairness tests: one seed produces repeatable incident progression.

## G5 — World and UX
- Market Chowk: branded fictional stalls, accessible sidewalks, directional street signs, parking bay, bins, crossing, municipal service point.
- Fix city geometry/traffic graph mismatch; do not duplicate support colliders.
- Polish NPC walk/yield animations and expressive reactions; no clipping into player.
- Audio: light urban ambience, safe clear cues for detection/report/recovery, volume controls, subtitles and visual alternatives.
- Use full visibility for essential building geometry; deploy genuine LOD proxies/batching when measured.

## G6 — Platforms / performance
- Establish budgets per active district and mobile tier; measure NPC query cost, traffic step cost, draw calls and shader load on real devices.
- Test pause/resume, save corruption, forced phone rotation, on-screen actions and low-memory restarts.
- Android: scalable touch joystick and camera, minimum tap targets, readable civic detail card; keep offline assets bundled.
- Test Windows and Android gameplay through mission 3; packaging and screenshots.

## G7 — Release / future expansion
- Finish 3-mission first-playable release; collect feedback, fix softlocks and mis-tuned rewards.
- Only then add School Street, Hospital Road, Residential Ward, Bus Terminal, queue-jumping, accessible-route obstruction, honking and emergency-response incidents.
- Optional post-v1 seeded Challenge mode and expanded event encyclopedia.

## Recommended engineering layout
```text
scripts/civic/gameplay_session.gd       (planned coordinator)
scripts/civic/incident_definitions.gd  (planned data/schema)
scripts/civic/incident_world_adapter.gd (planned physical-world bridge)
scripts/civic/mission_progress_bridge.gd (planned; avoid duplicate records)
scenes/civic/incident_marker.tscn      (planned)
scenes/civic/service_helper.tscn       (planned)
scenes/ui/incident_detail.tscn        (planned)
data/incidents/*.json                 (planned)
data/missions/*.json                  (planned)
tests/gameplay_*_test.gd              (planned)
```
Choose names per existing conventions; do not create parallel managers duplicating the current classes.

## Stop conditions / quality bars
- Never close a code issue from static inspection.
- No unsafe player actions or forced vehicle-body penetration to complete a mission.
- A scene must be playable without direct test-script calls.
- Live city traffic and city map must agree; signals must recognize lane approach.
- No fabricated HUD metrics, duplicate rewards, or permanent state locks.
- No GitHub Actions. Local validation commands belong in the backlog and code PR notes.

Next implementation to start: **G0-GAME-001 / gameplay baseline** and then **G1-GAME-006 / session integration**, not a giant batch of unrelated features.
