extends SceneTree
## CALLS-02B: no ghosting through congestion; after prolonged standstill
## the responder withdraws so it cannot cause permanent road gridlock.
const Responder = preload("res://scripts/civic/call_service_response.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var van := Responder.new() as CivicCallServiceResponse
    stage.add_child(van)
    if not van.configure(Builder.make_city_graph(), 50106,
            "misplaced_safety_cone", Vector3(9, 0.12, -29)):
        _fail("test responder could not be dispatched")
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

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
