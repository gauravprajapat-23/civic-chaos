# WORLD-002C2 — Connected Neighborhood Loop & New T-Junction

## Scope and implementation

WORLD-002C2 adds **one connected northeastern neighborhood loop** consisting of two actual, low-speed 6m-wide roads, one new intermediate node and the existing north perimeter junctions. This is an incremental drivable-network expansion, not yet a citywide organic road redesign.

| From | Via | To | Lane IDs | Speed |
| --- | --- | --- | --- | --- |
| Existing (46, -120), node `3:0` | New (83, -106), `world002:ne-loop` | Existing (120, -120), node `4:0` | 1000–1003 | 4 m/s |

The existing northeast corner at (120,-120) becomes a **three-arm T-junction** while node `3:0` becomes a cross junction. Both remain **unsignalized**; existing traffic controller does not automatically guarantee conflict-free turning at the new approaches. Native NPC conflict and driving acceptance is mandatory before merge.

### Source-of-truth contracts

- `CivicWorld002NeighborhoodConnector.road_definitions()` supplies both canonical road descriptions with explicit 13-point centerlines and unique node/road IDs, preserving all existing road entries in their existing order.
- `CivicCityNetworkDefinition.nodes()` now returns **26 nodes** (25 unchanged + 1 new); `roads()` returns **42 edges** (40 unchanged + 2 appended). New lane IDs 1000–1003 cannot collide with saved legacy IDs 100–179; network schema remains 1 and old checkpoint records with historic lane IDs should still load.
- `CivicJunctionBuilder.make_city_graph()` uses the **same** centerline source, with separate Indian left-hand lane offsets and existing graph connection contracts. Both ends join real current intersections; no fake road leading into a building.
- `CivicNeighborhood._world002_connected_roads()` generates two visible asphalt ribbons and two collision meshes, again using those exact centerlines. They join the existing north-perimeter carriageway. Scene names `World002ConnectedRoad_1000` and `World002ConnectedRoad_1002` identify the new physical pieces.
- Preflight tests compare the full new 6m-wide physical road ribbon plus 1m buffer with **all WORLD-002A building collision footprints and WORLD-002B public-square footprints**, verifying at sampled positions. Static placement clearance is also verified independently in code. All previously created buildings, plazas, west organic road and east curves remain.
- `scripts/traffic/traffic_spawner.gd` retains 1000–1003 as navigable lane continuations but excludes new side-road lanes from the initial city spawn-entry set, avoiding NPC creation at a busy unsignalized junction. This change requires Traffic-owner approval before merge.
- The map loops that draw `CityNetwork.roads()` automatically receive the new streets, including MAP-002A–D PR #91 when integrated.

### Checkpoint migration

The schema-1 traffic snapshot stores per-vehicle lane IDs, lane progress and route steps, not a fixed lane count. By **appending** lane IDs 1000–1003, saved routes with IDs 100–179 stay meaningful; the test gate checks existing stored route IDs and new additive lane IDs, without renumbering. Any schema-1 snapshots containing *new* routes will require the updated application version. This is additive compatibility, not a promise that an older binary can load newly created routes.

## Regression changes

- New `tests/world_002c2_connected_streets_test.gd` checks 26/42 node/edge inventory, invariant 80 legacy IDs, four new IDs, node forms, physical support, lane connectivity and junction topology.
- Previous focused tests WORLD-001E map parity, WORLD-001F save, WORLD-002A/B/C were updated to verify the **new expected 42/84 inventory** *while continuing to test all 80 unchanged legacy lane IDs*. Historic save route 102 remains the same.
- The historical 40-edge count is no longer the invariant; `Network.roads()` deliberately expands. Other tests elsewhere in the repository may still assume exactly 40/80 and need a repository-wide regression gate.

## Windows Godot 4.7.2 verification — required

This agent cannot execute Windows Godot. Tests are **committed but not claimed PASS**. Use a clean detached worktree (created when missing) to preserve local branches:

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "feature/world-002-organic-neighborhoods"
$review = "C:\Users\gauravp\Projects\civic-chaos-world-002a-review"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
if (-not (Test-Path $review)) {
    git worktree prune
    git worktree add --detach $review "origin/$branch"
} else {
    $local = @(git -C $review status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0 -or $local.Count -gt 0) { throw "Review tracked changes first" }
    git -C $review switch --detach "origin/$branch"
}
if ($LASTEXITCODE -ne 0) { throw "Review worktree checkout failed" }
Push-Location $review
try {
    $log = & $godot --headless --path . --editor --import --quit 2>&1 | Out-String
    $code = $LASTEXITCODE
    $log | Out-Host
    if ($code -ne 0 -or $log -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)') { throw "Godot import failed" }
    $tests = @(
        "world_002c2_connected_streets_test.gd",
        "world_002c_organic_roads_test.gd",
        "world_002b_public_spaces_test.gd",
        "world_002a_block_layout_test.gd",
        "world_001e_map_parity_test.gd",
        "world_001f_save_contract_test.gd",
        "road_footpath_01_crossing_test.gd",
        "aud3_city_map_test.gd"
    )
    foreach ($test in $tests) {
        $out = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
        $code = $LASTEXITCODE
        $out | Out-Host
        if ($code -ne 0 -or $out -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)' -or
            $out -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
            throw "FAILED: $test"
        }
        Write-Host "PASS: $test" -ForegroundColor Green
    }
    Write-Host "WORLD-002A/B/C/C2: 8/8 FOCUSED REGRESSIONS PASSED" -ForegroundColor Green
} finally { Pop-Location }
```

## Rendered and behavior gate — not covered by headless tests

1. Drive the whole new loop in both directions and turn at both old intersections; check collision continuity, bike reversing, approach speeds and smooth turning.
2. Observe NPCs negotiating the new unsignalized four-arm `3:0` and T `4:0` while other traffic passes: **no side-swipe, wrong-way, overlapping green or blocked approach**. If priority or reservation logic does not handle them safely, block merge and implement the correct permission contract before proceeding.
3. Check the parallel existing north road remains unobstructed, and new road surface does not overlay buildings, plaza furniture or sidewalks.
4. Save and restore vehicles on both legacy lanes and new lanes 1000–1003; ensure invalid/old binary routes fail safely.
5. Confirm the map and minimap show the two new connector edges using the actual canonical polylines; with PR #91 later merge, rerun the combined integration gate.
6. Profile Android draw calls, nav responsiveness and 20+ traffic agents. Existing release acceptance tests may assume 40 roads; audit and adapt the assertions rather than disabling protections.

**PR #92 remains DRAFT, unmerged. No GitHub Actions manually triggered. Do not change `scripts/core/main.gd`.**
