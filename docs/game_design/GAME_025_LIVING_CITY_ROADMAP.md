# GAME-025 — Living City & Free Roam Expansion

## Scope and status

**GAME-025-01 — Safe daily routines and neighborhood activity reporting:** implemented in source on `fix/aud-001-game024-gate-hardening`; local Godot 4.7.2 acceptance pending. No CI jobs were launched.

The campaign's four missions still gate Free Roam. Existing repeatable litter, fallen-sign and misplaced-cone incidents, volunteer progression, neighborhood improvement receipts, checkpoints, and the civic score ledger remain the authority for physical activity and reward attribution. GAME-025 does not replay campaign rewards.

### GAME-025-01 behavior

- During the campaign, `DistrictPedestrians.daily_routines_enabled` remains false; existing safety/traffic behavior remains unchanged.
- Once the campaign finale is acknowledged, `Main._start_free_roam_events()` enables safe deterministic commute, market, break and return-home schedule behavior. This method runs for both new Free Roam and restored Free Roam states.
- Restoring a campaign checkpoint without Free Roam calls `_sync_living_city_npcs()` to keep those routines disabled.
- The mission guide reports current resident activities while Free Roam is active. The status summary is derived from actual pedestrian activity arrays; it is display-only and is not checkpointed.
- Existing pedestrian crossing reservations, collision checks, incident director rewards, score receipts, event deadlines and saves are untouched. Ambient assistance remains visual-only.

### Subsequent batches

- **GAME-025-02:** Free Roam dispatch board and repeatable activity feed — source implemented, Godot verification pending. F7 / CALLS opens a paused board; Show on City Map follows the real live event target. No available incident means an honest all-clear view and cooldown; no fictional mission entries.
- **GAME-025-03:** Four neighborhood discoveries and visual-only wayfinding signposts, map-selectable street-route destinations, and read-only exploration progress — source implemented; Godot and Android verification pending. Route overlays follow the existing street graph, not a new pedestrian navmesh.
- **GAME-025-04:** Persistent neighborhood discovery checkpoints and a receipt-gated Neighborhood Guide goal — source and tests committed; Godot/PC/Android acceptance pending. Recognition is display-only; existing verified Free Roam outcomes remain the sole source of score/badge progress.
- **GAME-025-05:** Optimize crowd behavior under road/crossing pressure, audit Android controls and performance, and run full campaign-to-Free Roam acceptance.

### Verify on Windows

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/game025_living_city_routines_test.gd
& $godot --path .
```

Require the marker `CIVIC_CHAOS_GAME025_LIVING_CITY_ROUTINES_PASS`, exit code 0, and no Godot `ERROR:` in test output. A source commit does not prove tests passed.

### Manual acceptance

1. From a new campaign run, verify movement and crossing safety remain unchanged.
2. Finish the finale, select Continue, and enter Free Roam.
3. Observe market/commute/break/return-home activity reporting in the guide. Routines should not pause residents inside crosswalk conflict zones.
4. Complete a repeatable event, verify one real score receipt and no campaign reward duplication.
5. Save, reload, and confirm repeated events and living-city routines resume safely.
6. Verify Android navigation, UI readability, crowd performance and no stuck traffic before release.


## GAME-025-02 — Municipal Dispatch Board acceptance

- New file `scripts/ui/free_roam_dispatch_board.gd` is a read-only, touch-friendly panel. F7 on desktop or CALLS on screen opens it after the finale is acknowledged. CLOSE/F7 returns to gameplay without advancing time while open.
- `CivicFreeRoamEvents.dispatch_state()` derives live event title, precise site label, actual priority/deadline, stage-specific source/destination target, and verified success/expired counts. It never starts or rewards incidents.
- When no event is live, the board displays ALL CLEAR and the scheduler's remaining cooldown; SHOW ON CITY MAP is disabled.
- When a call exists, SHOW ON CITY MAP closes the dispatch panel and opens the existing map showing the mission route. No separate fake pin/mission is added; the current `guidance_state()` remains the authoritative navigation target.
- Regression: `tests/game025_dispatch_board_test.gd`, marker `CIVIC_CHAOS_GAME025_DISPATCH_BOARD_PASS`.
- To accept: Godot import PASS; focused dispatch, existing map, live Free Roam, checkpoint and UI tests exit 0 without `ERROR:`; PC F7 modal and phone CALLS touch must work without joystick stuck state; verify save/load while a live incident and during a cooldown.
- Do not manually run GitHub Actions. No release claim before full PC and Android acceptance.


## GAME-025-03 — Neighborhood exploration acceptance

- `scripts/world/living_city_zones.gd` is a shared catalog with four destinations: Community Garden, Community Kiosk, Solar Corner, and South Market Walk. The first three align with previously-defined improvement positions; the fourth aligns with the audited southern Free Roam sidewalk site.
- `scripts/world/living_city_exploration.gd` creates low-cost, **non-colliding** directional signs in Free Roam only. A player walking within 5 horizontal metres discovers each once per running scene. This is discovery feedback **only**, with no incident, score, unlock or reward changes. Visits are session-local until a separate persistent-collection milestone is designed.
- The city map lists all four zone locations below the existing MISSION/landmark buttons, draws named markers, and routes toward selected places using existing road graph. Map guidance may include off-road access connectors; it does not change pedestrian crossing reservations or claim a newly navigable sidewalk mesh.
- The mission guide displays visited / total exploration progress during Free Roam. New zones never spawn during the original campaign, and no new StaticBody3D/collision layers are introduced.
- Focused test: `res://tests/game025_neighborhood_exploration_test.gd`, success marker `CIVIC_CHAOS_GAME025_NEIGHBORHOOD_EXPLORATION_PASS`. Also run both AUD3 map tests, GAME-025 Living City/Dispatch tests, and Free Roam event/checkpoint regressions.
- Verify PC/Android UI sizing of two map destination rows, character walking, 5 m visit triggers, live map route geometry, and no obstruction of traffic/crossings. Current source commits are not verified by local Godot execution.


## GAME-025-04 — Persistent discoveries and explorer recognition

- `CivicLivingCityExploration.checkpoint_state()` stores a deterministic list of visited zone IDs. Strict validation rejects unknown/duplicate IDs, unsupported schemas, and malformed records. `restore_checkpoint` emits no discovery event and is idempotent; repeat visits in the same or restored game are not counted twice.
- The existing checksum-protected player checkpoint now includes optional `exploration_checkpoint` only with completed campaign and Free Roam state. Load preflight rejects a bad/orphaned nested record before restoring the live world; older Free Roam saves lacking this field remain compatible and start with zero visits.
- A fresh landmark discovery schedules a best-effort save through the existing civic/traffic validity gate; F5 manual save remains available. An invalid world state can still refuse save, with no fabricated success acknowledgement.
- `CivicVolunteerProgression.exploration_goal` displays **Neighborhood Guide** recognition after all four landmarks plus at least three audited Free Roam receipts. It grants **no extra points, currency or civic scores**. Existing volunteer ranks/badges continue to be based on actual `free_roam:*:resolved` receipts.
- Focused test `res://tests/game025_exploration_progression_test.gd` checks real one-time discovery, JSON save round-trip, tampered zone IDs, duplicate IDs, orphaned record rejection, idempotent restore, and refusal to unlock a goal from false activity counters.
- Acceptance includes new test plus `game025_neighborhood_exploration_test.gd`, `game025_dispatch_board_test.gd`, `free_roam_director_checkpoint_test.gd` and full campaign/save regression. Require zero Godot errors and a visible PASS marker before release. Confirm F5/F9 and exit/relaunch persistence on PC and Android; no manual GitHub Actions.
