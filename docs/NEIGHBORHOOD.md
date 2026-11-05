# CC-030 Reusable Neighborhood

`scenes/world/neighborhood.tscn` is a procedural district with four road approaches, sidewalks, four buildings with static collision, marked crossings and a civic information point. Attach it to a world scene and configure `district_extent`, `road_width`, `sidewalk_width` and `building_height` in the Inspector. `rebuild()` regenerates its children.

This is a geometric blockout rather than final art. Road navigation graph and pedestrian navmesh integration, detailed building access, collision clearance verification and manual traversal remain outstanding.

Run: `godot --headless --path . --script res://tests/neighborhood_test.gd`.
