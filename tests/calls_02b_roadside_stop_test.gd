extends SceneTree
## CALLS-02B: roadside parking must be a real road-graph location,
## not a teleport to the off-road incident prop.
const Responder = preload("res://scripts/civic/call_service_response.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var incident := Vector3(9.0, 0.12, -29.0)
    var candidates: Array[Vector3] = Responder.roadside_candidates(graph, incident)
    if candidates.is_empty():
        _fail("road graph supplied no legal roadside candidates")
        return
    for candidate in candidates:
        var distance: float = Vector2(candidate.x - incident.x,
            candidate.z - incident.z).length()
        if distance < 3.0 or distance > 18.0:
            _fail("roadside candidate outside bounded assistance range")
            return
    var stage := Node3D.new()
    root.add_child(stage)
    var van := Responder.new() as CivicCallServiceResponse
    stage.add_child(van)
    if not van.configure(graph, 50105, "fallen_public_sign", incident):
        _fail("no collision-clear response route from a public depot")
        return
    if van.stop_point.distance_to(incident) < 3.0 or (
            van.stop_point.distance_to(incident) > 18.0):
        _fail("responder routes to incident object instead of roadside")
        return
    if van.route[van.route.size() - 1].distance_to(van.stop_point) > 0.01:
        _fail("actual driving route does not end at roadside parking")
        return
    if van.arrived or van.response_status != "EN ROUTE":
        _fail("responder marked ON SCENE before reaching its stop")
        return
    var initial := van.position
    for i in range(10):
        await physics_frame
    if van.position.distance_to(initial) < 0.01:
        _fail("responder cannot travel toward its roadside stop")
        return
    if not van._step_is_clear(van.position, van.position + Vector3(0.1, 0, 0)):
        _fail("unoccupied approach falsely blocked")
        return
    van.retire()
    stage.queue_free()
    print("CIVIC_CHAOS_CALLS_02B_ROADSIDE_STOP_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
