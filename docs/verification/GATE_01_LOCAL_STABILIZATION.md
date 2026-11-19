# GATE-01 — Civic Chaos Local Stabilization Gate

Scope: Civic Chaos Godot 4.7.2 on Windows. Branch: `fix/aud-001-game024-gate-hardening`.
This gate makes no GitHub API or GitHub Actions calls. It does not modify the
saved-game format, production missions or score logic.

## Run

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/aud-001-game024-gate-hardening
git fetch origin fix/aud-001-game024-gate-hardening
git merge --ff-only FETCH_HEAD
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\gate_01_verification.ps1
```

For a debug Android export after regressions:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\gate_01_verification.ps1 -BuildApk
```

Read `build/gate-01/report.json`. A failure stops immediately, recording the
first failing test, engine exit code, timeout and stdout/stderr paths.
Every test must print its own `CIVIC_CHAOS_*_PASS` line. The local
report is not release certification.

## Test coverage

- CALLS-01/02/02B: live incident IDs, acceptance, GPS target, municipal
  service gating, response movement, roadside selection and blockage recovery
- Motorcycle: mount, reverse, collision recovery, animation, clearance and remount
- Road/traffic: footpath transitions, city map, signal priority, spillback
- Android controls: touch ownership, joystick lifecycle and screen changes

## Required on-device acceptance (not automated by this gate)

1. Test walking across a footpath edge in all cardinal directions and against
   a building wall; the wall must stay solid.
2. Mount bike, reverse from clear road, contact a parked vehicle or wall at
   low speed, reverse away, dismount and remount. Repeat with joystick.
3. Confirm mounted character uses original face, hair and clothing; hand and
   foot attachments remain aligned while turning.
4. Unlock Free Roam, accept a real CALLS incident, open its city-map route,
   request service and observe a responder driving without passing through
   moving traffic or pedestrians.
5. At a red signal or pedestrian crossing, verify responder does not gain
   illegal access. If it cannot advance, record waiting/failure status.
6. Resolve/expire an incident, reload a checkpoint, rotate the phone and
   reopen CALLS / MAP / pause. Check stale touch inputs and retired responders.
7. Observe 10+ minutes of city traffic and crowd behavior. Capture device
   frame time, crashes, unusually blocked junctions and any stuck service van.

## Release decision

- **PASS (source gate):** report status passed and commit matches local HEAD.
- **BLOCKED:** any test or import fails, output contains Godot SCRIPT ERROR /
  ERROR, test does not print PASS, command times out, or source is dirty.
- **ANDROID PENDING:** debug export exists but physical-device checks above
  have not been completed.
- **RELEASE CANDIDATE:** only after the local gate, on-device checks and
  existing GAME-024 acceptance workflow all pass against the same commit.

The CALLS-02 van still uses custom graph following rather than the normal
traffic spawner's complete intersection reservation/signal behavior. This is a
known CALLS-02C engineering blocker, even if GATE-01 source tests pass.
