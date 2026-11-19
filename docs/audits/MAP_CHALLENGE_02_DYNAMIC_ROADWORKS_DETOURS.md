# MAP-CHALLENGE-02 — Dynamic Roadworks, Legal Detours & Marshal Reopening

**Date:** 2026-11-17  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source + focused regression committed; Godot/Android runtime verification pending. No GitHub Actions manually triggered.

## Gameplay goal

Make the mostly predictable city feel alive with **temporary roadwork interruptions, alternate legal paths, visually narrow worksite shoulders and civic action**. This follows MAP-CHALLENGE-01's permanent S-bends. Do not put a random solid barrier under a vehicle or create another five-minute junction deadlock.

## Implementation

- `scripts/world/roadworks_detour.gd` is a deterministic roadworks director, activated on the already-running 20Hz city clock by `scripts/core/main.gd`, first eligible at tick 1200 (60 seconds). Four predefined *outer* one-way candidates are considered in rotated order. Each closure lasts at most 1200 ticks/60 seconds and the next event is separated by 3600 ticks/180 seconds after reopening.
- A road may be closed **only if** no ordinary or mission vehicle has that directed lane anywhere in its **remaining route**. The director also checks the existing `CivicLaneRouter` for a legal multi-lane alternative around the same start/end pair, excluding the candidate and already closed incident roads. When no safe option is available, the event is postponed rather than blocking the existing convoy.
- The existing `CivicTrafficSpawner.set_incident_route_closure` authority disallows new background-car routes over the worksite lane. It does not rewrite, teleport, de-collide or despawn a car already in the world. Other legitimate incident closures remain independent because each owner has its own key.
- The actual worksite has two high-visibility ROADWORKS / DETOUR signs and five orange cones along the **outside of the shoulder**. These have no collision bodies and never block the 8m paved carriageway. A visually narrowed shoulder hints at trouble without creating phantom physical barriers.
- The existing Traffic Marshal post now offers **Verify Roadworks Detour / Reopen**. The button requires two completed real background traffic journeys **while that closure is active** before signing off. It invokes `CivicCityMetrics.apply_outcome` with a one-time, idempotent `map_challenge_02:roadworks_verified` event (safety +5, efficiency +10, cooperation +5) if the underlying civic session is live. This measures actual completed journeys—not merely elapsed seconds or stationary vehicles. A completion may have used another path; the current metric is *overall traffic throughput during the diversion*, not proof that the particular car drove the full detour.
- If the player does not act, the 60s roadworks work period expires and the lane reopens automatically. Manual completion also reopens the lane. A scene rebuild resets the per-spawner route closure; checkpoint rewind causes the transient worksite to retire and reschedule rather than applying a stale closure against restored vehicles. The closure is not written into the traffic save schema.
- No changes to central/outer light phases, pedestrian crossing reservations, Wrong Way mission lanes, physical car-following, or existing traffic admission limits.

## Implemented files

- `scripts/world/roadworks_detour.gd` — deterministic director, detour proof, worksite art, countdown and verified finish
- `scripts/core/main.gd` — lifecycle, simulation tick adapter, marshal action and event reward
- `scripts/ui/traffic_marshal_panel.gd` — mobile/desktop action
- `tests/map_challenge_02_roadworks_detour_test.gd` — route/closure and worksite safety regression

## Local Windows gate

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Merge failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$exitCode = $LASTEXITCODE
$log | Out-Host
if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Godot import failed"
}
$tests = @(
    "map_challenge_02_roadworks_detour_test.gd",
    "map_challenge_01_bends_and_turns_test.gd",
    "traffic_fix_08_incident_detour_test.gd",
    "traffic_perf_11e_city_admission_test.gd",
    "traffic_fix_13_post_completion_traffic_test.gd",
    "traffic_fix_12_marshal_removal_test.gd",
    "traffic_spawner_test.gd",
    "world_junction_checkpoint_test.gd",
    "neighborhood_test.gd"
)
foreach ($test in $tests) {
    Write-Host "Running $test" -ForegroundColor Cyan
    $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
    $exitCode = $LASTEXITCODE
    $log | Out-Host
    if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
        -not ($log | Select-String '_PASS')) {
        throw "FAILED: $test"
    }
}
Write-Host "MAP-CHALLENGE-02 REGRESSION PASSED!" -ForegroundColor Green
New-Item -ItemType Directory -Force build | Out-Null
$apk = "build/civic-chaos-map-challenge-02-debug.apk"
& $godot --headless --path . --export-debug "Android Debug" $apk
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $apk)) {
    throw "Android export failed"
}
Get-Item $apk | Select-Object FullName, Length
```

## Live acceptance checklist

- [ ] At around 60s of safe, unoccupied gameplay, one outer street activates an orange-cone ROADWORKS / DETOUR warning. If all candidates are occupied or unrouteable, the event waits instead.
- [ ] Existing cars—including Wrong Way mission followers—remain physically present on their original legal routes. No vehicle suddenly stops because a solid cone spawned inside its body.
- [ ] New background traffic avoids the closed directed lane; legal alternatives remain available, with no U-turn or graph shortcut.
- [ ] The other direction on the same street remains legally open (one directed lane closed).
- [ ] Traffic Marshal button refuses reopening before two completed journeys and permits it afterward, then the event closes only once. Reputation is idempotent.
- [ ] Unassisted roadworks automatically reopen after 60 seconds, and a later event may appear after cooldown. F5/F9 rolls back without a stale road closure.
- [ ] Wrong Way and Illegal Parking missions remain completable and do not mis-award reputation.
- [ ] Five-minute playtest: no stuck same-position front-of-line block, completed routes increase, incoming car limit remains bounded and FPS on Android Compatibility remains acceptable.

**This is source-complete only.** No engine tests or Android installation were executed through the GitHub connector. Correct any local failures before considering the feature release-ready.
