# CC-008 Modular Roads and Test Junction

`CivicRoadSegment` renders a reusable road mesh between two endpoints, with configurable width. The `@tool` script updates the mesh in the editor.

`CivicJunctionBuilder.make_test_graph()` creates four incoming and four outgoing directed lanes. Every incoming lane can turn into three outbound arms (no U-turns). All endpoints meet at the origin, so graph geometry validates without connector gaps.

`CivicJunctionBuilder.make_road_visuals(parent)` instantiates four 20m road arms from the reusable segment scene. `four_way_junction.tscn` combines graph and visuals.

The prototype represents lane centerlines along the road axes. Lane offsets, road markings, curb meshes, collision surfaces and traffic priority are later work. Do not interpret the visual roads as physically complete intersections.

Run:
```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/junction_test.gd
```
