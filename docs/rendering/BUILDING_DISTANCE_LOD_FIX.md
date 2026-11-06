# Civic Chaos — Distant Building Visibility

**Symptom:** Buildings seem incomplete or disappear when the camera gets farther away, even though windows, doors and roof trims can still be visible.

**Cause (source-confirmed):** `scripts/core/main.gd` registers the city's building base meshes in the `lod_meshes` group via `graphics_lod.register_mesh(mesh)` without a secondary mesh. The LOD controller previously applied a far visibility cutoff regardless of whether a replacement mesh existed.

### Behavior after the fix

| Mesh registration | Near | Beyond detail switch | Very far |
|---|---|---|---|
| High only (current building shells) | High visible | High visible | High visible |
| High + valid low proxy | High visible | Low proxy visible | Low proxy visible |

The 3D engine's camera/frustum can still naturally clip anything outside camera view. LOD does not artificially hide essential city geometry. The far-distance setting is retained for configuration compatibility; it no longer causes culling of meshes without proxies.

### Testing
- `tests/graphics_lod_test.gd` checks replacement and no-proxy behavior in LOW/BALANCED/HIGH.
- `tests/building_distance_lod_test.gd` instantiates the actual procedural Neighborhood and verifies building shell, roof, and front-window visibility over near/distant camera positions and LOW/HIGH modes.
- Run the focused tests and full local `tools/run_regression.py` suite on Godot 4.7.2, then inspect the same view as the screenshot.

**Not addressed:** Real distant GPU performance optimization (merged façade geometry / baked walls / impostor materials), which should be a separate issue. This fix prioritizes correctness rather than making essential buildings disappear.
