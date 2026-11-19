extends SceneTree
## TRAFFIC-FIX-12: trace the real front vehicle, not each jammed car.
## Read-only; no actor removed, signal changed, or civic reward granted.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    var graph := Builder.make_city_graph()
    if not spawner.configure(graph, 18, true):
        _fail("city setup failed")
        return
    var lane_id: int = graph.sorted_lane_ids()[0]
    var front := _vehicle(lane_id, 25.0, "Front")
    var middle := _vehicle(lane_id, 20.0, "Middle")
    var rear := _vehicle(lane_id, 15.0, "Rear")
    spawner.register_road_user(front)
    spawner.register_road_user(middle)
    spawner.register_road_user(rear)
    root.add_child(front)
    root.add_child(middle)
    root.add_child(rear)
    var result: Dictionary = spawner.head_of_line(rear)
    if not bool(result.get("valid", false)) or result.get("head") != "Front":
        _fail("queued follower was not traced to true front-most car: " + str(result))
        return
    if result.get("chain", []).size() != 3:
        _fail("chain did not include all actual waiting cars")
        return
    if not front.active or not middle.active or not rear.active or not (
            is_equal_approx(rear.lane_distance_m, 15.0)):
        _fail("read-only inspection modified real traffic")
        return
    front.active = false
    var resumed: Dictionary = spawner.head_of_line(rear)
    if resumed.get("head") != "Middle":
        _fail("completed front car remained a phantom head blocker")
        return
    spawner.unregister_road_user(front)
    spawner.unregister_road_user(middle)
    spawner.unregister_road_user(rear)
    front.queue_free()
    middle.queue_free()
    rear.queue_free()
    spawner.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_12_HEAD_OF_LINE_PASS")
    quit(0)

func _vehicle(id: int, progress: float, label: String) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.name = label
    car.active = true
    car.route = PackedInt32Array([id])
    car.current_route_index = 0
    car.lane_distance_m = progress
    car.speed_mps = 0.0
    return car

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
