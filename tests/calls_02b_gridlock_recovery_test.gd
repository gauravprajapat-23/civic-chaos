extends SceneTree
## CALLS-02B: no ghosting through congestion; after prolonged standstill
## the responder withdraws so it cannot cause permanent road gridlock.
const Responder = preload("res://scripts/civic/call_service_response.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := _traffic_fixture(stage, graph)
    if spawner == null:
        _fail("live Traffic authority failed to initialize")
        return
    var van := Responder.new() as CivicCallServiceResponse
    stage.add_child(van)
    if not van.configure(graph, 50106,
            "misplaced_safety_cone", Vector3(9, 0.12, -29)):
        _fail("test responder could not be dispatched")
        return
    if not van.configure_traffic(spawner):
        _fail("responder failed to bind authoritative Traffic rules")
        return
    var statuses: Array[String] = []
    van.status_changed.connect(func(value: String) -> void: statuses.append(value))
    var blocker := StaticBody3D.new()
    blocker.name = "StoppedRoadUser"
    blocker.collision_layer = 4
    blocker.position = van.position
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(4.0, 2.0, 4.0)
    collider.shape = shape
    collider.position.y = 0.7
    blocker.add_child(collider)
    stage.add_child(blocker)
    await physics_frame
    var held: Vector3 = van.position
    for i in range(170):
        await physics_frame
    if held.distance_to(van.position) > 0.02 or not statuses.has("WAITING FOR CLEAR ROAD"):
        _fail("service vehicle crossed collision or failed to report delay")
        return
    blocker.queue_free()
    await physics_frame
    for i in range(10):
        await physics_frame
    if not statuses.has("EN ROUTE") or (
            van.position.distance_to(held) < 0.01):
        _fail("van failed to resume after traffic moved")
        return
    var blocked_again := StaticBody3D.new()
    blocked_again.collision_layer = 4
    blocked_again.position = van.position
    var again := CollisionShape3D.new()
    again.position.y = 0.7
    again.shape = shape
    blocked_again.add_child(again)
    stage.add_child(blocked_again)
    await physics_frame
    # One long blocked tick must terminate instead of teleporting;
    # game clock normally accrues this in many short physics steps.
    van._physics_process(Responder.ABORT_BLOCKED_S + 0.1)
    if not statuses.has("SERVICE UNAVAILABLE") or van.active:
        _fail("indefinitely blocked van was not withdrawn")
        return
    await process_frame
    if is_instance_valid(van):
        _fail("withdrawn service left a traffic-blocking collision body")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_CALLS_02B_GRIDLOCK_RECOVERY_PASS")
    quit(0)

## Legacy CALLS movement fixtures now use the same fail-closed Traffic
## authority required by GAME-002. No disabling permission checks.
func _traffic_fixture(stage: Node3D, graph: CivicRoadGraph) -> CivicTrafficSpawner:
    var spawner := Spawner.new() as CivicTrafficSpawner
    stage.add_child(spawner)
    if not spawner.configure(graph, 777, true):
        spawner.queue_free()
        return null
    var signals := Signals.new(12.0, 3.0, 2.0)
    signals.enable_single_approach_mode()
    spawner.configure_intersection(signals, Reservations.new())
    return spawner

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
