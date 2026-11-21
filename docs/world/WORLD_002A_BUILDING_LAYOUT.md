# WORLD-002A — Real Building Footprints and Neighborhood Identity

**Scope:** First safe physical-world milestone toward a distinctive open-world city, based on merged `main`. The MAP-002A–D UI is still pending in separate draft PR #91; this branch intentionally does not depend on it or modify its files.

## Why this milestone
The game currently has an authoritative 5×5 road graph with 40 undirected roads, 80 stable lane IDs and a west-side organic S-bend. Earlier world work proved those physical roads align with traffic, collision, saving, map drawing and missions. Replacing the entire street graph in one PR would risk breaking traffic and save compatibility.

WORLD-002A safely changes **actual static building placement** and visual architecture within existing road blocks, not just the overhead map. This is a first pass, not yet a GTA-scale geography replacement.

## Implementation
- `scripts/world/world_002_building_layout.gd`: deterministic plot plan for the existing 15 outer building lots; varying X/Z offsets, separate footprint widths and depths, height profiles and market/residential/civic/mixed styles. Every physical building footprint keeps at least a 7m road-axis buffer, checked by the same static plan used for construction. The existing CommunityPark stays at plot (row 1, column 2).
- `scripts/world/neighborhood.gd`: outer `StaticBody3D` blocks now use the above varied 3D center and size. **Collider shape equals visible shell**. Existing node names `OuterBuilding_ROW_COLUMN`, gameplay plot IDs, roads, road widths, building count and parking/park interactions remain.
- `scripts/world/world_002_facade_identity.gd`: non-physical architectural accents (market awnings, residential balconies, civic canopies, parapets and facade bands). All additional pieces are `MeshInstance3D` with no colliders; does not obstruct traffic.
- No editing `scripts/core/main.gd`, `city_network_definition.gd`, `junction_builder.gd`, `city_road_layout.gd`, `organic_road_geometry.gd`, HUD, traffic, missions or save schema. The project retains 40 existing road edges and stable lane IDs.

## Native verification — Godot 4.7.2 on Windows

Run a detached review checkout so you do not alter a working local main or unfinished map PR worktree.

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$review = "C:\Users\gauravp\Projects\civic-chaos-world-002a-review"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
if (-not (Test-Path $review)) {
    git worktree prune
    git worktree add --detach $review origin/feature/world-002-organic-neighborhoods
} else {
    $status = @(git -C $review status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0 -or $status.Count -gt 0) { throw "Review tracked changes" }
    git -C $review switch --detach origin/feature/world-002-organic-neighborhoods
}
if ($LASTEXITCODE -ne 0) { throw "Worktree setup failed" }
Push-Location $review
try {
    $import = & $godot --headless --path . --editor --import --quit 2>&1 | Out-String
    $code = $LASTEXITCODE
    $import | Out-Host
    if ($code -ne 0 -or $import -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)') {
        throw "Import failed"
    }
    foreach ($test in @(
        "world_002a_block_layout_test.gd",
        "world_001e_map_parity_test.gd",
        "world_001f_save_contract_test.gd",
        "road_footpath_01_crossing_test.gd",
        "aud3_city_map_test.gd"
    )) {
        $output = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
        $code = $LASTEXITCODE
        $output | Out-Host
        if ($code -ne 0 -or $output -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)' -or
            $output -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
            throw "FAILED: $test"
        }
        Write-Host "PASS $test" -ForegroundColor Green
    }
    Write-Host "5/5 WORLD TESTS PASSED" -ForegroundColor Green
} finally { Pop-Location }
```

## Manual rendered and collision gates
1. View the district street-level and from above: 15 outer buildings are no longer identical boxes at exact old grid centers; market, residential, civic and mixed facades are visibly distinct.
2. Walk and ride every perimeter and collector street. No building, parapet, awning or balcony should block a lane, sidewalk or crosswalk. Pay special attention to organic west street and bike reverse.
3. Check 3D collisions are consistent with the building exterior rather than letting the player enter/clip through walls.
4. Verify the existing Community Park, Old Bus Stop, parking court, shop names, incident locations, mission labels and navigation destinations remain recognizable and accessible.
5. On Android test FPS/draw calls and camera clipping. Consider LOD/culling adjustments if new façade geometry is expensive.
6. When MAP-002A–D PR #91 merges, rerun integration and inspect map/3D POI parity before merging WORLD-002A.

**Status:** committed implementation and focused test, **Godot not run by the agent**; no Actions, merge, or main modification. Draft PR until independent acceptance.

## Next WORLD-002 milestones
- **WORLD-002B:** varied street-edge public spaces and coherent district themes, with safe pedestrian and vehicle clearances.
- **WORLD-002C:** new genuinely curved/split connectors only after changing a single authoritative road-data source, building matching real asphalt/sidewalks, validating lane IDs/save compatibility and traffic junction priority.
- **WORLD-002D:** cross-map parity, scenario driving, Android profiling and rendered release verification.
