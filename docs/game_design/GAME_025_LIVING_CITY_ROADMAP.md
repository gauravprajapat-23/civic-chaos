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
- **GAME-025-03:** Visit-worthy places and distinct neighborhood activity zones with verified navigable pedestrian paths.
- **GAME-025-04:** Persistent volunteer goals earned only through verified event receipts; no timer-based score farming.
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
