> **Updated game direction (2026-11-06):** For the playable civic-sense experience and the current implementation priorities, use [Game Design Document](docs/game_design/CIVIC_CHAOS_GAME_DESIGN.md), [Phased Build Plan](docs/game_design/PHASED_BUILD_PLAN.md), and [First-Playable Backlog](docs/game_design/IMPLEMENTATION_BACKLOG.md). The milestone table below records the older foundation plan; it is not evidence that those milestones are fully playable.

# Civic Chaos — Development Roadmap

Godot 4.x · GDScript · PC + Android · Offline first

## Goal
Build a third-person open-world civic-sense game whose NPCs cause believable traffic problems through rule violations, and where players restore safe movement and improve city conditions.

## Milestones
| Milestone | Weeks | Deliverable |
|---|---|---|
| M0 Foundation | 1–2 | Runnable Godot project, CI, deterministic simulation, player, lifecycle |
| M1 Road & Vehicle AI | 3–7 | Directed lane graph, routing, vehicle motion, signals, safe intersections |
| M2 Intelligent NPC AI | 8–10 | Personality, utility decision engine, pedestrians, AI LOD |
| M3 Civic Incidents | 11–13 | Wrong-side driving, illegal parking, deadlock detection and recovery |
| M4 Missions | 14–16 | Civic incident interactions, trust, first fully playable mission |
| M5 Presentation | 17–19 | Neighborhood environment, HUD, animation, debug telemetry |
| M6 Android | 20–22 | Touch controls, renderer/LOD, profiling, build validation |
| M7 Release | 23–24 | Regression suites, balancing, release packaging and acceptance |

Planning IDs CC-001 to CC-041 identify tasks, not GitHub issue numbers. GitHub issue bodies include milestone, priority, acceptance and tests. Milestone labels are expressed in issue text until native GitHub milestones/labels are configured.

## Priorities
- P0: Critical foundation, correctness, safety or release blocker
- P1: Required for demo quality
- P2: Polish that may be deferred

## Invariants
1. Legal routing must never traverse wrong-way connectors.
2. Conflicting intersection reservations must never overlap.
3. Timed-out reservations cannot release physically occupied conflict zones.
4. Unsafe NPC actions cannot bypass safety constraints.
5. Traffic congestion must be distinguishable from simulation deadlock.
6. No mission should reward unsafe traffic interventions.
7. Every issue closes only after executable tests and verification evidence.

## Recommended order
M0 → Lane graph → A* → Vehicle motion → Signals → Reservations → NPC brain → Civic incidents → Deadlock recovery → Wrong Way Disaster mission → Android and release tests.

## GitHub issue workflow
Ready → In progress → Testing → Review → Done.

Use branches feat/cc-NNN-name or fix/cc-NNN-name, and include the planning ID in commits and PRs. Avoid closing issues based only on code changes without test evidence.

## Scope boundary
The first release is a vertical slice with one flagship mission. Five further missions need their own content backlog before claiming a six-mission demo.

## Exit targets
- Reproducible seeded traffic simulation
- 20 vehicles at a test junction as an initial prototype target
- A cause-and-effect wrong-side violation
- Safe recovery from resolvable jams
- PC + Android build and profiling evidence
