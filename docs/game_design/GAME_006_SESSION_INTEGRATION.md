# GAME-006 — Civic Gameplay Session: first playable scene integration
Date: 2026-11-06 · **IMPLEMENTED, GODOT NOT RUN**.

## New vertical-slice bootstrap
- `scripts/civic/gameplay_session.gd`: scene coordinator reuses `CivicIncidentManager`, `CivicMissionManager`, `CivicCityMetrics` and `CivicInteractionService`.
- `scripts/civic/incident_marker.gd`: physical orange obstruction on north footpath, not decorative only; pressing E on the marker calls the coordinator.
- `scripts/core/main.gd`: mounts coordinator into the real 3D district and connects live mission/incident/reputation data to `CivicStatusHUD`.
- `tests/gameplay_session_test.gd`: verifies out-of-range rejection, inspect then report, no double-report, service response, actual removal of world obstruction, mission completion and idempotent scores/rewards.
- Existing traffic HUD remains supplied by the spawner. No fabricated queue/reputation values are sent.

## How to play the first incident
Spawn near north footpath. Walk toward the **orange FOOTPATH BLOCKED crate near (5, -14)**, look at it and press **E** to inspect; press **E** again to send the report. After the authorized service delay, the obstruction disappears, the mission completes, and efficiency/cooperation scores increase once.

This is a **starter tutorial mission** to connect the gameplay loop. It is **not** a finished wrong-way driving mission, there is no marshal arrival animation, and persistence of civic session state has **not** been added yet. More meaningful player choices, dynamic world consequences and mission polish remain GAME-007 onward. Current crate affects actual path geometry/physics; a claimed complete city-wide traffic recovery would be inaccurate.

## Pending validation
- [ ] Godot 4.7.2 import passes
- [ ] `tests/gameplay_session_test.gd` passes
- [ ] Existing core, NPC, traffic and HUD tests pass after wiring
- [ ] Human player can locate crate, inspect, report, and see it disappear
- [ ] Touch interaction parity, save/reload, pause/resume and service timeout verified
- [ ] Fully simulated Wrong-Way Disaster mission added as GAME-012 onward

No GitHub Actions run; do not mark GAME-006 accepted yet.
