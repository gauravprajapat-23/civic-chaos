# GAME-024 — Dynamic Event Locations, NPC Reactions and Varied Free Roam

**Branch:** `feat/game-024-dynamic-free-roam` (based on the latest `fix/regression-nov05` GAME-023 work)  
**Status:** Source and executable Godot regression scripts committed; Godot 4.7.2 execution not yet verified.

## What changes in the playable city

Free Roam still unlocks only after the district finale is acknowledged. It remains entirely offline and uses the same physical **E / USE** inspect → collect → deposit workflow, mission guidance, score HUD, audit ledger and F5/F9 checkpoint. No story mission or campaign reward is reset.

- **Eight named incident locations** around the north, south, east and west neighborhood edges. Evidence and its receiving prop appear together; the mission guide and incident card use the actual selected location.
- **Physical spawn clearance** probes both locations against city colliders, vehicles, pedestrians and other interactable props and avoids materializing an incident within 4 m of the player. If no suitable site is available, the scheduler returns its single event budget and retries after cooldown instead of spawning inside a street obstacle.
- **No immediate location repeat:** a deterministic per-instance selection visits candidate sites in a reproducible order and excludes the most recent site. It does not consume the event scheduler's RNG.
- **Three civic challenge types:** recycle litter, restore a fallen public sign, or return a stray safety cone to its storage rack. The cone has distinct geometry, typed actions and safety/cooperation scores.
- **Priority variants:** each third scheduled incident has a 90-second deadline instead of 180. Resolving one earns one extra Trust point through the *same idempotent* outcome receipt. Expired priority activities close in the civic audit trail without player points; they do not leak event budget.
- **Witness NPCs:** nearby pedestrians briefly show contextual, event-specific speech and a raised-arm gesture when an issue is spotted, inspected, carried or addressed. A distant event can trigger a nearby witness when one later walks close enough. Speech expires and never modifies score, traffic collision, crossing permission or pedestrian path state.
- **HUD:** shows the active incident type, district slot, and priority status. The guide displays the current physical target and remaining deadline.

## Source layout

| File | Role |
|---|---|
| `scripts/civic/free_roam_challenges.gd` | Safe slot catalog, typed challenge metadata, deterministic selection, priority deadlines, witness dialogue |
| `scripts/civic/free_roam_events.gd` | Collision-aware event staging, progression, score receipts, position-specific guide, schema v2 checkpoint |
| `scripts/civic/cleanup_target.gd` | Safety cone and storage rack objects |
| `scripts/npc/district_pedestrians.gd` | In-world pedestrian speech and gesture, without changing movement |
| `scripts/core/main.gd` | Connects live event signals to the existing pedestrian system |
| `scripts/ui/civic_incident_card.gd` | Whitelists typed cone actions |
| `scripts/ui/civic_status_hud.gd` | Displays current challenge category, location and urgency |
| `tests/free_roam_dynamic_locations_test.gd` | Safe placement selection, rotated incidents, priority expiry and tamper rejection |
| `tests/free_roam_npc_reactions_test.gd` | Witness dialogue, gesture binding and expiration |

## Persistence and invariants

The Free Roam checkpoint is now **schema v2**, adding `last_location_id` and three fields to any live event: `site_id`, `tier`, and `deadline_tick`. Neither the active incident ID, director budget nor the civic score-receipt scheme changed.

The validation step requires a cataloged location, an exact match to the last chosen live site, the expected deterministic priority tier, and the authoritative deadline derived from the event director's scheduled end. Unknown sites, fabricated deadlines, invented incident IDs, extra budget and duplicate reward receipts are rejected before restore.

Legacy GAME-023 **schema v1** checkpoints are accepted with the original literal positions for litter/sign activities; after restore, a new v2 checkpoint can include a `legacy_litter` or `legacy_sign` location until that old event finishes. New incidents use the rotating eight-site catalog. Only one event is active at a time.

**No GitHub Actions or release workflows are launched.** These test files were registered in the existing local strict regression runner and must be run on the Windows machine with Godot installed.

## Windows local test commands

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git switch feat/game-024-dynamic-free-roam
git pull --ff-only origin feat/game-024-dynamic-free-roam

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

$tests = @(
  "free_roam_dynamic_locations_test.gd",
  "free_roam_npc_reactions_test.gd",
  "free_roam_live_events_test.gd",
  "free_roam_event_restart_test.gd",
  "free_roam_expiry_test.gd",
  "free_roam_card_test.gd",
  "district_finale_checkpoint_test.gd"
)
foreach ($test in $tests) {
    & $godot --headless --path . --script "res://tests/$test"
    if ($LASTEXITCODE -ne 0) { throw "FAILED: $test" }
}

python tools/run_regression.py --godot $godot --timeout 120 --report build/game-024-regression.json
if ($LASTEXITCODE -ne 0) { throw "Regression suite failed; review build/game-024-regression.json" }
```

Manual acceptance: walk to an event in each district sector, inspect/collect/deposit with **E**, confirm the actual visible NPC witness dialogue (when a walker is nearby), confirm priority expiry and respawn cooldown, and F5/F9 across an active carry. Test on Android touch controls before the next release.

## Remaining gates

- [x] Source integration for rotating, collision-probed sites, cone challenge and priority variants
- [x] NPC witness reactions connected to actual city walkers
- [x] Checkpoint v2 validation and legacy v1 migration
- [x] New regressions and local runner registration
- [ ] Godot 4.7.2 import and tests executed locally
- [ ] Manual 3D collision/visibility and PC/Android interaction check
- [ ] Release-level performance and full regression suite verified
