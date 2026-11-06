# Civic Chaos — Game Design Document (GDD)
Status: **Approved concept for planning, not implemented gameplay** · 2026-11-06
Engine: Godot 4.7.2 / GDScript · Platforms: Windows PC first, Android second · Architecture: offline-first, no backend required

## One-line pitch
**A chaotic, funny, choice-driven third-person civic-sense game where small public-space rule violations create believable city-wide consequences, and the player helps a fictional Indian-inspired neighborhood recover.**

## Identity and pillars
1. **Cause and effect, not lectures.** A wrong-way shortcut creates a roadblock; blocked zebra crossings change pedestrian paths; litter increases cleanup demand. Players learn by seeing outcomes.
2. **Good civic sense is gameplay.** Detect, investigate, choose a proportionate action, help a community and watch the environment respond.
3. **Funny but humane.** Exaggerated NPC reactions, playful commentary and emergent chaos; never celebrate serious injury, shame real demographic groups or reward harassment.
4. **Fair systemic city.** NPCs can disobey rules for recognizable motives (rushing, distraction, selfishness, ignorance, peer pressure), but all obey simulation safety and recovery constraints.
5. **Low-cost, highly replayable.** Seeded dynamic events, multiple reasonable solutions, offline progress, responsive PC/Android controls, stylized visuals rather than expensive photorealism.

## Player fantasy
You are a **Neighborhood Volunteer**, not a law-enforcement officer. You can observe, document, politely request cooperation, help guide people to safe alternatives, clean designated small messes, alert authorized city helpers and coordinate legitimate interventions. You cannot issue arbitrary fines, seize vehicles, assault NPCs, stop real moving traffic by standing in front of cars, or claim powers not granted by a mission. Any authorized marshal response is performed by an NPC helper.

The game opens in fictional **Nagripur**, a city where everybody wants convenience but everyone pays for chaos. A friendly, witty radio host gives the player their first neighborhood challenge. Individual pedestrians are not automatically villains; the system should show why the rules matter.

## Audience and play format
- Accessible to teenagers and adults; humor understandable without a civics textbook.
- Sessions: short replayable incidents and longer linked story missions.
- Camera: third-person walking/exploration. No player-controlled car driving required for v1.
- Controls: WASD/mouse + interaction on PC, virtual joystick/touch camera/action button on Android.
- Language: English UI first, Hindi localization target for v1.5; text keys must be localization-ready from first mission.
- Game modes: **Story** and **Free Roam** for v1; seeded Challenge mode later.
- No online account, purchases, multiplayer, or networking for first release.

## Core loop
1. **Explore:** see shops, roads, sidewalks, people, traffic, and environmental clues.
2. **Notice:** identify a violation based on real visual evidence (signs, road direction, stopped traffic, obstruction).
3. **Understand:** inspect safe from nearby, collect simple in-game evidence, check impact and available response.
4. **Choose:** request cooperation, report to an appropriate NPC service, undertake a permitted activity, or wait.
5. **Act:** complete a short play mechanic; never physically endanger the character to earn points.
6. **Observe results:** traffic releases, people reroute, NPCs respond, litter is removed, public sentiment changes.
7. **Earn and unlock:** complete objectives; reputation, trust, cooperation, efficiency, and safety change; district challenges progress.
8. **New chaos:** event director spawns related, different or harder incidents from deterministic seeded rules.

Core twist: **A violation can cascade into several coupled incidents.** If parked illegally, a delivery van blocks a lane; vehicles queue; frustrated drivers honk; pedestrians cross in unsafe gaps. Solving the first cause is often better than clicking all three symptoms.

## Three interlocking systems
### A. Civic rule simulation
Rules are data-defined with ID, context, triggers, violation severity, responsible service, safe response options, evidence requirements, timers and recovery behavior. The game should distinguish intentional/accidental violations without pretending every unknown NPC deserves punishment.

### B. Observable city consequences
Every incident must alter at least one measurable simulation quantity: queue length, walking route cost, blocked sidewalk, trash count, noise meter, service delay or public cooperation. Numbers come from the actual simulation (no fabricated HUD). The incident state transitions through **active → escalated → intervention → resolved** using the existing manager; additional story presentation is optional.

### C. Feedback and progression
Reuse existing `CivicCityMetrics` dimensions exactly:
- **Safety:** exposure to risky behavior and safe interventions.
- **Efficiency:** travel delay, obstruction and queue recovery.
- **Trust:** accuracy and proportionality of player reporting/helping.
- **Cooperation:** NPC willingness to yield, queue and use civic facilities.

Show trends and clear reasons for changes, not just a green/red score. Mission reward points unlock cosmetic badges, community-request missions, volunteer tools and neighborhood improvements; they cannot purchase public authority or unfair shortcuts. Use existing idempotent scoring/reward logic.

## Civic-sense incidents by release
| Behavior | Visible trigger | Player decision / interaction | Simulated result | Release |
|---|---|---|---|---|
| Wrong-way driving | Vehicle blocks an opposing lane, queues accumulate | Inspect, document, request traffic marshal; safely wait for intervention | Lane obstruction removed, queue drains, trust/safety changes | v1 mission 1 |
| Illegal parking | Vehicle blocks a crosswalk/sidewalk/bus passage | Verify sign and blocked path; request owner or authorized service | Footpath clears or route recovers; cooperative NPC response | v1 mission 2 |
| Littering / overflowing bin | Litter piles near market, people avoid or complain | Use bin, help cleanup designated area or request sanitation worker | Visual litter reduction, cleanliness and cooperation feedback | v1 mission 3 |
| Queue jumping | NPC cuts line at stall or public service | Politely request order or call organizer | Queue smooths or escalates to volunteer coordination | v1.5 |
| Unsafe pedestrian crossing | People step into traffic instead of zebra crossing | Place clear safe instructions, wait for valid signal; guide along safe route | Pedestrian routes adapt and risk declines | v1.5 |
| Excessive honking / noise | Congestion creates a honking cascade | Clear root obstruction, share calm reminder / de-escalate | Noise falls after actual traffic improves | v1.5 |
| Blocking emergency access | Traffic queue delays a scripted response vehicle | Coordinate with authorized marshal, clear legal right of way | High-stakes but nonviolent consequence feedback | post-v1 showcase |

**No forced injury/death as a scoring mechanism.** High-stakes emergency consequences can be conveyed through time, delay and distress without graphic harm.

## Three linked playable missions (v1 narrative arc)
### Mission 01: **Wrong Way, Wrong Day**
- Player is introduced to Market Chowk and its direction signs.
- One wrong-way vehicle obstructs a lane; nearby drivers queue and react.
- Player observes a real obstruction, inspects it from a safe area, submits a report.
- Traffic marshal NPC arrives or acts from a defined service point; offender exits safely onto a legal route.
- Win condition: real queue clears and stays clear for several ticks, mission objectives all recorded, reward granted once.
- Failure/retry: false report or early intervention produces guidance; game must remain recoverable.
- Existing `CivicWrongWayMission` is a **scripted logic proof only**. Do not mistake synthetic queues for playable scene behavior.

### Mission 02: **Footpath for People**
- A shop visitor parks across a zebra crossing and pedestrians route onto the road.
- Player verifies obstruction, finds or alerts the owner and guides them toward legal parking through a dialogue/selection choice.
- Vehicle relocates to a validated parking slot. Crosswalk routing becomes clear; cooperation score updates based on response.
- Choice: escalation can resolve a stubborn offender but excessive reporting harms trust; unsafe physical vehicle movement is not player-controlled.

### Mission 03: **Market Clean-Up Chain**
- Bins overflow as more people arrive after traffic improves.
- Player places litter into bins or requests municipal sanitation support; public bin capacity and litter piles must update visually.
- Cooperative NPCs start using bins more often after seeing examples.
- Finale: district scorecard compares baseline vs end state; free roam remains available and events continue.

All three missions must have discoverable triggers, visual actors, physical locations, HUD objectives, appropriate feedback, save/load and replayable recovery. No scripted "Press E to magically fix city" shortcuts.

## How one playable incident should feel
**Spot** a blocked crosswalk → **examine** direction/parking signs and nearby pedestrian behavior → **choose** asking the owner (quick, might fail) or calling the marshal (slower, reliable) → **watch** vehicle leave, walkers reclaim path, and lane queue drop → **see** "Efficiency +, Cooperation +" with a short explanation → **earn** the next neighborhood request.

An incident only awards improvement when the linked world state genuinely improves. Empty reports never complete missions.

## NPC design
- Roles: commuter, shopkeeper, driver, pedestrian, traffic marshal, sanitation helper, market organizer.
- Small traits: patience, urgency, rule awareness, cooperation, risk aversion. Behavior choice is deterministic per NPC + seed and conditioned by city state.
- Reactions: stop, wait, politely refuse, cooperate, learn, become frustrated, assist others.
- Soft NPC–NPC and NPC–player spacing (not hard physics contact); cars remain solid to vehicles and use detection for pedestrians.
- Spawn only into walkable free space; no NPC appearing inside another actor, wall, street sign, or car.
- Do not create AI systems that impose significant CPU cost on distant NPCs. Use bounded active zones / LOD.

## World layout and visual direction
### v1 one playable district: Market Chowk
One central junction, two connected street approaches, zebra crossings, sidewalks, a market row, bus stop, municipal help desk, one legal parking lot, bins and believable signage. Distinct visual landmarks make it easy to see the difference between a rule and its violation.

The current procedural district is a **prototype asset**. Upgrade it in place; do not create a second competing city/world architecture. Roads, lanes, signs, NPC navigation and collision must share **one** source of world coordinates.

### Future expansions
- **School Street:** school drop-off, pedestrian priority, parking.
- **Hospital Road:** emergency access and congestion response.
- **Residential Ward:** noise, waste collection, accessible sidewalk.
- **Bus Terminal:** queues, public-transport discipline.

Each expansion unlocks only after the earlier district is stable and produces a complete civic gameplay loop.

### Art / presentation
Stylized low-poly but more lived-in: consistent building façades, varied storefronts, balconies, lane paint, traffic signs, trees, street vendors, road textures, subtle day/night lighting and expressive NPC animation. City identity should derive from recognizable situations rather than stereotypes. Avoid vanishing building shells at distance; use actual LOD proxies and batching for performance.

### UI
- Mini-map compass and discoverable mission marker (optional in v1 if affordable).
- Objective tracker: `Observe | Verify | Respond | Confirm recovery`.
- Incident detail card: what happened, evidence, safe options, current consequence.
- City score strip: Safety / Efficiency / Trust / Cooperation.
- Before/after summary at mission end; concise tooltips for why an action helped or hurt.
- Captions, adjustable sensitivity, motion options, readable colors, touch-safe layouts.

## Design boundaries
- Safety-first responses only; no rewards for confrontation, property damage or blocking emergency vehicles.
- If a violation is unobserved, the HUD may hint at clues but must not invent facts.
- Player may make imperfect choices; game responds with fair feedback and a recovery path.
- Consequences use simulation state, not pre-canned numbers claimed as live.
- Offline save includes player, missions, incidents, metrics, unlocks, event seed and world modifications with versioned schema and safe restore.
- Mission/reputation rewards remain idempotent; duplicate interaction cannot farm rewards.
- Autosave only on stable checkpoints; no corruption/soft-lock after loading.

## Definition of the first playable v1 vertical slice
- One coherent playable district and **three connected missions** above.
- Three truly simulated incident types, not just abstract state-machine tests.
- At least two meaningful safe actions for one incident, with visibly different social/travel outcomes.
- Player can discover, inspect, act, finish and retry without developer commands.
- Save/load restores mission/world progress safely.
- Player and NPCs do not spawn overlapped; cars respect other actors/roads; buildings stay visible.
- Stable Windows gameplay and a documented Android smoke build; no promises of a specific FPS until measured.
- Manual human playtest demonstrates the loop end to end and finds it understandable without instruction from a developer.

## Excluded from v1
Multiplayer, server accounts, ad monetization, huge maps, full car driving, police combat, elaborate economy, unlimited procedural building interiors, crowd simulation at AAA scale and autonomous LLM NPC conversations.

## Repository grounding (observed at planning time)
Existing code: `scripts/civic/mission_manager.gd`, `incident_manager.gd`, `city_metrics.gd`, `event_director.gd`, `wrong_way_mission.gd`; `scripts/player/civic_interaction_service.gd`; `scripts/core/simulation_director.gd`; `scripts/ui/civic_status_hud.gd`; procedural Neighborhood, traffic spawner, player scene and NPCs.

**Gap:** Most civic systems are currently independent simulation/service logic. The live `scripts/core/main.gd` mounts player, NPC, furniture and HUD, but does not yet orchestrate a complete playable mission, evidence UI, authorized NPC intervention, metric event stream or persistent multi-system session. The current HUD shows placeholders for absent mission/incident/reputation state. Bridge those existing services rather than rebuilding them.

See `docs/game_design/PHASED_BUILD_PLAN.md` and `docs/game_design/IMPLEMENTATION_BACKLOG.md`.
