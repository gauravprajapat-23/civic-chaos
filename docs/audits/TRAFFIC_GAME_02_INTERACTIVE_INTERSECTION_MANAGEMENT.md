# TRAFFIC-GAME-02 — Interactive Intersection Management

**Date:** 2026-11-16  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source, UI and regression committed. Godot 4.7.2 import, runtime replay and Android verification pending.

## Design goal

Player-facing, safe civic-sense traffic control from the roadside **Traffic Marshal** station. This extends ROAD-GAME-01. A new compact panel presents:
- **Request N/S next green**
- **Request E/W next green**
- **Meter new arrivals for 20 seconds** (the prior verified-jam action)
- **Close**

The panel uses real Godot buttons for PC and touch with keyboard focus, Escape to close, and visible explanations of rejection. The player must be within 3.5 m of the interaction post and aim/use it. Opening the panel pauses *player movement and look* but **not** the live traffic simulation: amber, red, all-red and moving pedestrians continue as normal. The panel does not edit the traffic-controller scene directly; all direction actions pass through `CivicTrafficMarshalControl.request_axis`.

## Safety / game balance

1. **Only opposite axis may be requested**, e.g. request E/W when N/S is green. The controller does not allow an arbitrary N-only or W-only green because its six-phase checkpointed model has paired opposing vehicle approaches.
2. **Minimum real green:** the current green serves **at least four seconds** before any player acceleration is accepted. Normal 12 s green is otherwise preserved.
3. **No instant changes:** accepted request queues a shortened remaining-green window of at most 0.8 seconds, then the unchanged **3-second amber → 2-second all-red → other-axis green** sequence. The preceding green phase never becomes red immediately.
4. **Pedestrians:** request is rejected whenever either central crossing has an actual reservation occupant. No reservation is released or bypassed.
5. **Vehicles:** request is rejected whenever a live background car or a scripted mission car occupies the protected central junction. Neither cars nor pedestrians are teleported/despawned by the action.
6. **Controller remains authority:** when lights become green, normal spawner central arbitration, collision sweeps, pedestrian checks and mission service safety remain unchanged. No player action creates a conflicting N/S and E/W green.
7. **Automatic cycle fallback:** when no player action is taken, the default signal sequence continues. Player requests do not create a permanent manual mode. Controller `snapshot` / `can_restore` / `restore` and its schema version remain unchanged.
8. **Reputation:** mere button pressing never earns points. The existing ROAD-GAME-01 **verified marshal recovery** awards Safety +10, Efficiency +15, Cooperation +10 only after real background route completion, global stopped queue reduction and fewer physically blocked center cars; the event receipt prevents repeat rewards after save/load. The temporary spawn meter is unchanged and never sends cars through an unsafe signal.
9. **Respect mission progression:** Wrong Way and Illegal Parking still require physical clearing, respectful reporting and authorized relocation. The panel does not auto-complete those incidents.

## Files

- `scripts/traffic/traffic_signal_controller.gd` — `request_next_green(axis)` with minimum green and amber/all-red sequence.
- `scripts/civic/traffic_marshal_control.gd` — crossing, vehicle and mission-world occupancy refusal gate and clear UI messages.
- `scripts/ui/traffic_marshal_panel.gd` — button-based traffic officer panel (screen-local UI).
- `scripts/core/main.gd` — opens the panel on ROAD-GAME-01 sign interaction, routes requests through civic safety policy, reuses existing metering action, closes via button/Escape and restores player controls.
- `tests/traffic_game_02_manual_signal_test.gd` — minimum green, conflicting pedestrian, real central car, mission car, amber/all-red and checkpoint signal-restore invariants.

## Local verification (PowerShell)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
$branch = "fix/aud-001-game024-gate-hardening"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Git fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Git update failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$exitCode = $LASTEXITCODE
$log | Out-Host
if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Godot import failed"
}

$tests = @(
    "traffic_game_02_manual_signal_test.gd",
    "road_game_01_traffic_marshal_test.gd",
    "traffic_fix_06_axis_crossing_release_test.gd",
    "traffic_fix_06_pedestrian_entry_window_test.gd",
    "signal_phases_test.gd",
    "city_signal_stop_line_test.gd",
    "junction_fix_03b_central_release_test.gd",
    "wrong_way_tow_service_priority_test.gd",
    "world_junction_checkpoint_test.gd",
    "traffic_spawner_test.gd"
)
foreach ($test in $tests) {
    $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $exitCode = $LASTEXITCODE
    $log | Out-Host
    if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
        -not ($log | Select-String '_PASS')) { throw "FAILED: $test" }
}
Write-Host "TRAFFIC-GAME-02 focused gate passed" -ForegroundColor Green

New-Item -ItemType Directory -Force "build" | Out-Null
$apk = "build/civic-chaos-traffic-game-02-debug.apk"
& $godot --headless --path . --export-debug "Android Debug" $apk
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $apk)) { throw "Debug APK failed" }
```

## Gameplay acceptance

- [ ] Approach the northwest roadside Traffic Marshal post. E / touch USE opens a compact modal and restores movement when closed.
- [ ] Current green axis and intended next axis are readable; it must not hide the full scene behind oversized HUD content.
- [ ] Attempt switch at 0 seconds: refused (minimum green). After 4 seconds with no vehicles or crossing occupied: accepted.
- [ ] Verify amber remains visible for 3 seconds and **all red** lasts 2 seconds before requested axis receives green. Never both perpendicular axes green.
- [ ] Place walker in either central crosswalk, or car in conflict zone: manual switch refused until it physically clears.
- [ ] Auto-signal operation when the player ignores the panel is unchanged.
- [ ] On 8/12/20 live cars in PC and Android, no extra collisions, teleports or unexpected traffic starvation.
- [ ] Verified marshal reputation requires actual traffic clearing; red-light timing alone grants nothing.
- [ ] Save/load normal traffic phase and civic reward history; opening the panel does not add checkpoint fields or persist a manual override.
- [ ] Android Debug APK built and tested on device.

**Not verified locally in Godot during GitHub coding.** The issue remains OPEN until the user's import, tests and actual live gameplay report PASS. Never manually trigger GitHub Actions for this milestone.
