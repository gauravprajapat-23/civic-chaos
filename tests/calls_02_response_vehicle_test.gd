extends SceneTree
## CALLS-02: visible service vehicle travels continuously along real
## road-graph waypoints, never teleporting to the caller or through walls.
const Response = preload("res://scripts/civic/call_service_response.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var responder := Response.new() as CivicCallServiceResponse
    stage.add_child(responder)
    var result := responder.configure(Builder.make_city_graph(), 50042,
        "fallen_public_sign", Vector3(9, 0, -29))
    if not result or not responder.active or responder.arrived or (
            responder.route.size() < 2):
        _fail("municipal vehicle could not start legal response route")
        return
    if responder.get_node_or_null("MunicipalServiceVehicle") == null or (
            responder.find_child("MunicipalServiceVan", true, false) == null):
        _fail("service dispatch did not create physical vehicle")
        return
    if responder.configure(Builder.make_city_graph(), 50042,
            "fallen_public_sign", Vector3(9, 0, -29)):
        _fail("duplicate responder request created a second route")
        return
    var initial: Vector3 = responder.position
    for i in range(12):
        await physics_frame
    if responder.position.distance_to(initial) < 0.01:
        _fail("response vehicle did not advance physically on free road")
        return
    if responder.position.distance_to(initial) > 2.0:
        _fail("response vehicle teleported instead of driving")
        return

    # Inject a physical wall directly across the immediate next step.
    var block := StaticBody3D.new()
    block.collision_layer = 1
    block.position = responder.position
    var obstacle := CollisionShape3D.new()
    var cube := BoxShape3D.new()
    cube.size = Vector3(4.0, 2.0, 4.0)
    obstacle.shape = cube
    obstacle.position.y = 0.7
    block.add_child(obstacle)
    stage.add_child(block)
    await physics_frame
    var stopped: Vector3 = responder.position
    for i in range(12):
        await physics_frame
    if responder.position.distance_to(stopped) > 0.02:
        _fail("municipal vehicle passed through a blocking wall")
        return
    block.queue_free()
    for i in range(4):
        await physics_frame
    if responder.position.distance_to(stopped) < 0.01:
        _fail("municipal vehicle did not resume after obstruction cleared")
        return
    if responder.process_mode != Node.PROCESS_MODE_PAUSABLE:
        _fail("service vehicle would travel while dispatch UI is paused")
        return
    responder.retire()
    await process_frame
    if is_instance_valid(responder):
        _fail("responder remained after retirement")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_CALLS_02_RESPONSE_VEHICLE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
