# CC-017 Pedestrian Navigation and Protected Crossings

`CivicPedestrianNavigator` follows a sidewalk waypoint route. `configure(id, waypoints, cross_segment, manager)` marks one route segment as a protected crosswalk. `advance_fixed(tick, delta, pedestrian_green, vehicle_clear)` walks on sidewalks and waits before the crosswalk until the signal permits crossing and vehicle clearance is confirmed.

The pedestrian acquires the named `crosswalk` conflict-zone reservation before entering and holds occupancy until reaching the far sidewalk. Once crossing begins, a signal change does not strand the pedestrian in the road. `interrupt(reason)` releases access and enters blocked recovery. Invalid routes and nonfinite waypoints are rejected.

The current implementation is a navigation/controller component. Scene placement, sidewalk geometry, vehicle-to-crosswalk conflict-zone mapping and automatic signal/vehicle sensors still need integration. Crossing safety depends on the caller supplying a truthful `vehicle_clear` value; no physical collision avoidance is implied.

Test: `godot --headless --path . --script res://tests/pedestrian_navigation_test.gd`.
