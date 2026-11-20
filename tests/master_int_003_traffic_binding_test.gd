extends SceneTree
## MASTER-INT-003: Main must use the same configured traffic authority.
## The actual dispatch call site is also asserted as a source regression.
const Master = preload("res://scripts/core/main.gd")
const Response = preload("res://scripts/civic/call_service_response.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var source: String = FileAccess.get_file_as_string("res://scripts/core/main.gd")
    if source.is_empty() or not source.contains(
            "_bind_dispatch_traffic(service, graph, spawner, signals, reservations)"):
        _fail("live dispatch does not invoke Master Traffic binding")
        return
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var spawner: CivicTrafficSpawner = Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 777, false):
        _fail("Traffic fixture failed to configure")
        return
    var responder: CivicCallServiceResponse = Response.new() as CivicCallServiceResponse
    root.add_child(responder)
    if Master._bind_dispatch_traffic(responder, graph, spawner, null, null):
        _fail("missing signals/reservations accepted")
        return
    if responder.lifecycle_state()["traffic_gate_available"]:
        _fail("missing authority installed permission")
        return
    var signals: CivicTrafficSignalController = Signals.new(12.0, 3.0, 2.0)
    signals.enable_single_approach_mode()
    var reservations: CivicIntersectionReservations = Reservations.new()
    if Master._bind_dispatch_traffic(responder, graph, spawner, signals, reservations):
        _fail("unbound junction authority accepted")
        return
    spawner.configure_intersection(signals, reservations)
    var second: CivicTrafficSpawner = Spawner.new() as CivicTrafficSpawner
    root.add_child(second)
    if not second.configure(Builder.make_test_graph(), 778, false):
        _fail("second Traffic fixture failed")
        return
    second.configure_intersection(signals, reservations)
    if Master._bind_dispatch_traffic(responder, graph, second, signals, reservations):
        _fail("mismatched road graph accepted")
        return
    if not Master._bind_dispatch_traffic(responder, graph, spawner, signals, reservations):
        _fail("real Traffic authority rejected")
        return
    var state: Dictionary = responder.lifecycle_state()
    if not state["traffic_gate_available"] or not state["traffic_gate_configured"]:
        _fail("successful binding did not install fail-closed adapter")
        return
    # A configured adapter cannot move without an authoritative lane route.
    if responder.traffic_step_permission.call(Vector3.ZERO, Vector3(0, 0, -0.5)):
        _fail("empty route permission was not denied")
        return
    spawner.queue_free()
    second.queue_free()
    responder.queue_free()
    print("CIVIC_CHAOS_MASTER_INT_003_TRAFFIC_BINDING_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error("MASTER-INT-003: " + message)
    quit(1)
