# Civic Chaos — Graphics and Performance Audit
Date: 2026-11-06 · Source inspection only. No FPS, GPU, draw-call or memory measurements were collected.

## Renderer and target
`project.godot:20–30` configures a 1280x720 viewport, canvas-items stretching and Godot GL Compatibility rendering for desktop/mobile. Android export capability is configured in the repository but no build or on-device test was executed.

## Source findings
1. **BUG-007/P2 — Vanishing buildings:** `graphics_lod.gd:42–55` hides high meshes beyond a distance threshold if no low-detail substitute exists. `main.gd:68–71` registers group meshes without substitutes. For HIGH quality, cutoff is 105 m (70 × 1.5), shorter than the expanded 120 m road reach and 144 m terrain half extent. Expect pop-out when distant; verify visually.
2. **BUG-008/P3 — Secondary road material:** `neighborhood.gd:145–146` matches `ends_with("Road")`, but secondary roads have names such as `SecondaryRoad_NS_1`; material fallback is likely.
3. **BUG-005/P2 — Overlapping floors:** `main.tscn:7–12,42–51` has old 100x100 ground; `neighborhood.gd:20–23` creates a larger terrain slab. Audit coplanar surfaces and duplicate physics work.
4. **PERF-RISK-001/P2 — Procedural node/material proliferation:** `neighborhood.gd:125–161` creates unique box meshes and materials; `_decorate_building` builds many per-window mesh nodes. `street_furniture.gd:29–56` similarly allocates a new mesh/material per part. This can increase draw calls and scene-tree overhead on Android. Quantify before optimizing.
5. **PERF-RISK-002/P2 — NPC update scaling:** `district_pedestrians.gd:146–162` scans other walkers per walker (quadratic); current count is small (8), but scaling to city-wide crowds needs spatial partitioning.
6. **VISUAL-001/P3 — Limited distant environment:** Existing lighting is one DirectionalLight3D with shadows disabled in `main.tscn:34–38`; emissive streetlights are materials, not actual area illumination. Treat visual quality as a subjective playtest, not a measured defect.
7. **VISUAL-002/P3 — Outdated UI:** `main.tscn:92–94` still displays 'DISTRICT PREVIEW'.

## Recommended graphics strategy
- Use reusable meshes/materials and MultiMeshInstance3D for repeated props after profiling.
- Keep essential building silhouettes visible with cheap far LOD; never cull the entire city skyline.
- Define one road material policy for both primary and secondary roads.
- Introduce modest baked/cheap lighting presets for GL Compatibility, with shadow and light budgets per platform.
- Benchmark viewport performance, physics frame time, draw calls, memory and startup times on integrated Intel GPU and a representative Android device.

## Performance verification matrix
| Metric | PC | Android |
|---|---|---|
| Average/1% low FPS | NOT MEASURED | NOT MEASURED |
| Frame time and physics time | NOT MEASURED | NOT MEASURED |
| Draw calls and visible instances | NOT MEASURED | NOT MEASURED |
| Memory usage / leaks | NOT MEASURED | NOT MEASURED |
| Long-running simulation | NOT RUN | NOT RUN |
| Export/build | NOT RUN | NOT RUN |

No invented benchmark figures. Profile before declaring a performance pass.
