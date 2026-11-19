extends SceneTree
## ROAD-FIX-01: all grid crossing openings remain physically and visually
## clear while every between-junction sidewalk retains walkable support.
const Layout = preload("res://scripts/world/city_road_layout.gd")
const NeighborhoodScene = preload("res://scenes/world/neighborhood.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var intervals: Array[Vector2] = Layout.sidewalk_intervals()
    if intervals.size() != 4:
        _fail("expected four sidewalk runs between five cross-street axes")
        return
    var clearance: float = Layout.ROAD_WIDTH_M * 0.5 + 1.5
    for interval in intervals:
        if interval.y <= interval.x:
            _fail("zero or inverted sidewalk interval")
            return
        for axis in Layout.coordinates():
            if interval.x < axis + clearance - 0.001 and interval.y > axis - clearance + 0.001:
                _fail("sidewalk geometry intrudes into a road opening at " + str(axis))
                return

    var district: Node3D = NeighborhoodScene.instantiate() as Node3D
    root.add_child(district)
    await physics_frame
    var expected: int = 0
    for side in [-1, 1]:
        for i in range(intervals.size()):
            var interval: Vector2 = intervals[i]
            var middle: float = (interval.x + interval.y) * 0.5
            var run: float = interval.y - interval.x
            for direction in ["X", "Z"]:
                var name: String = "Sidewalk%s%d_%d" % [direction, side, i]
                var slab := district.get_node_or_null(name) as StaticBody3D
                if slab == null or slab.collision_layer != 1:
                    _fail("no walkable solid slab at " + name)
                    return
                var shape := slab.get_node_or_null("CollisionShape3D") as CollisionShape3D
                var mesh := slab.get_node_or_null("MeshInstance3D") as MeshInstance3D
                if shape == null or not (shape.shape is BoxShape3D) or mesh == null or not (mesh.mesh is BoxMesh):
                    _fail("incomplete sidewalk geometry at " + name)
                    return
                var box: Vector3 = (shape.shape as BoxShape3D).size
                var paint: Vector3 = (mesh.mesh as BoxMesh).size
                if box.distance_to(paint) > 0.0001:
                    _fail("visual sidewalk and floor collider do not align at " + name)
                    return
                if direction == "X":
                    if absf(slab.position.z - middle) > 0.001 or absf(box.z - run) > 0.001:
                        _fail("north/south sidewalk run differs from shared intervals")
                        return
                else:
                    if absf(slab.position.x - middle) > 0.001 or absf(box.x - run) > 0.001:
                        _fail("east/west sidewalk run differs from shared intervals")
                        return
                var curb: MeshInstance3D
                if direction == "X":
                    curb = district.get_node_or_null("CurbNorthSouth_%d_%d" % [side, i]) as MeshInstance3D
                else:
                    curb = district.get_node_or_null("CurbEastWest_%d_%d" % [side, i]) as MeshInstance3D
                if curb == null or not (curb.mesh is BoxMesh):
                    _fail("segmented curb is absent at " + name)
                    return
                if direction == "X" and absf((curb.mesh as BoxMesh).size.z - run) > 0.001:
                    _fail("north/south curb crosses a road opening")
                    return
                if direction == "Z" and absf((curb.mesh as BoxMesh).size.x - run) > 0.001:
                    _fail("east/west curb crosses a road opening")
                    return
                expected += 1
    if expected != 16:
        _fail("incorrect number of solid sidewalk pieces")
        return
    for name in ["SidewalkX1", "SidewalkX-1", "SidewalkZ1", "SidewalkZ-1",
            "CurbNorthSouth_1", "CurbEastWest_-1"]:
        if district.get_node_or_null(name) != null:
            _fail("legacy full-length crossing geometry remains: " + name)
            return

    # Actual physics ray tests: pedestrian support exists between crossings,
    # but not at the crossing gaps where only road / terrain may be contacted.
    var world := district.get_world_3d().direct_space_state
    for point in [Vector3(5.0, 0, -24.0), Vector3(-5.0, 0, 24.0),
            Vector3(24.0, 0, 5.0), Vector3(-24.0, 0, -5.0)]:
        var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0,
            point + Vector3.DOWN * 1.5)
        query.collision_mask = 1
        var hit: Dictionary = world.intersect_ray(query)
        if hit.is_empty() or not str((hit["collider"] as Node).name).begins_with("Sidewalk"):
            _fail("walkable sidewalk has no grounded physics support at " + str(point))
            return
    for axis in Layout.coordinates():
        for offset in [-1.0, 1.0]:
            for candidate in [Vector3(5.0, 0, axis + offset),
                    Vector3(axis + offset, 0, -5.0)]:
                var query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 2.0,
                    candidate + Vector3.DOWN * 1.5)
                query.collision_mask = 1
                var hit: Dictionary = world.intersect_ray(query)
                if not hit.is_empty() and str((hit["collider"] as Node).name).begins_with("Sidewalk"):
                    _fail("raised sidewalk blocks real road opening at " + str(candidate))
                    return
    district.queue_free()
    print("CIVIC_CHAOS_ROAD_FIX_01_SEGMENTED_SIDEWALKS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
