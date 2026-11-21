extends SceneTree
## WORLD-002D physical acceptance: sampled asphalt contact must actually
## be the physical road, not terrain, a building, plaza or invisible wall.
const World = preload("res://scripts/world/neighborhood.gd")
const Network = preload("res://scripts/world/city_network_definition.gd")
var failures: int = 0

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-002D SURFACE: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world: CivicNeighborhood = World.new() as CivicNeighborhood
    root.add_child(world)
    await physics_frame
    await physics_frame
    var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
    for road in Network.roads():
        if not bool(road.get("world_002_connector", false)) and (
                not bool(road.get("world_002_curve", false))):
            continue
        var name: String = ""
        if bool(road.get("world_002_connector", false)):
            name = "World002ConnectedRoad_%d" % int(road["lane_forward"])
        else:
            name = "World002EastRoad_North" if (
                (road["start"] as Vector3).z < 0.0) else "World002EastRoad_South"
        var target: StaticBody3D = world.get_node_or_null(name) as StaticBody3D
        _check(target != null, "expected physical road body missing: " + name)
        if target == null:
            continue
        var points: PackedVector3Array = road["centerline"]
        _check(points.size() >= 5, "real asphalt lacks sampled centerline")
        for fraction in [0.25, 0.5, 0.75]:
            var index: int = mini(points.size() - 2,
                maxi(1, int(roundf(float(points.size() - 1) * fraction))))
            var sample: Vector3 = points[index]
            var query := PhysicsRayQueryParameters3D.create(
                sample + Vector3(0, 2.0, 0), sample + Vector3(0, -1.0, 0))
            query.collision_mask = 0xFFFFFFFF
            var hit: Dictionary = space.intersect_ray(query)
            _check(not hit.is_empty(), "sampled carriageway has no physical support: " + name)
            if hit.is_empty():
                continue
            _check(hit.get("collider") == target,
                "sampled road hits another collider instead of real asphalt: " + name)
            var normal: Vector3 = hit.get("normal", Vector3.ZERO)
            _check(normal.y > 0.90, "road collision not drivable/upward: " + name)
    world.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_002D_ROAD_SURFACE_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_002D_ROAD_SURFACE_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
