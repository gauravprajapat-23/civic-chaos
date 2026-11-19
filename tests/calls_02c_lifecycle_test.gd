extends SceneTree
## GAME-001: run with godot --headless --path . --script res://tests/calls_02c_lifecycle_test.gd
const Response = preload("res://scripts/civic/call_service_response.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _assert(value: bool, message: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL: " + message)

func _deny(_start: Vector3, _finish: Vector3) -> bool:
    return false

func _run() -> void:
    var response = Response.new()
    root.add_child(response)
    _assert(not response.active, "new responder inactive")
    _assert(response.lifecycle_state()["call_id"] == -1, "no call before dispatch")
    _assert(response.lifecycle_state()["terminal_status"] == "", "no terminal status before dispatch")
    _assert(Response.service_for("civic_litter") == "SANITATION", "existing service mapping")
    _assert(Response.service_for("unknown") == "", "unknown service rejected")
    _assert(not response.configure(null, 1, "civic_litter", Vector3.ZERO), "invalid graph rejected")
    response.set_traffic_step_permission(Callable(self, "_deny"))
    _assert(response.traffic_step_permission.is_valid(), "Traffic permission gate registered")
    var finished: Array = []
    response.lifecycle_finished.connect(func(id: int, status: String) -> void:
        finished.append({"id": id, "status": status}))
    response.retire()
    _assert(finished.is_empty(), "inactive retire does not emit completion")
    _assert(not response.active, "inactive retire remains inactive")
    response.active = true
    response.call_id = 42
    response._set_status("SERVICE UNAVAILABLE")
    response.retire()
    _assert(finished.size() == 1, "active retire emits exactly once")
    _assert(finished[0]["id"] == 42, "terminal event retains call id")
    _assert(finished[0]["status"] == "SERVICE UNAVAILABLE", "terminal reason retained")
    _assert(response.lifecycle_state()["terminal_status"] == "SERVICE UNAVAILABLE", "snapshot retains terminal reason")
    response.retire()
    _assert(finished.size() == 1, "retire is idempotent")
    print("GAME-001 lifecycle: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)
