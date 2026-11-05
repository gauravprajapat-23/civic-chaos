extends SceneTree

const Controller = preload("res://scripts/traffic/traffic_signal_controller.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var signal_controller := Controller.new(4.0, 2.0, 1.0)
    if signal_controller.aspect_for_approach("N") != "green" or signal_controller.aspect_for_approach("E") != "red":
        _fail("initial green invalid")
        return
    signal_controller.advance_fixed(4.0)
    if signal_controller.phase_name() != "NS_AMBER" or signal_controller.aspect_for_approach("S") != "amber":
        _fail("amber phase invalid")
        return
    signal_controller.advance_fixed(2.0)
    if signal_controller.phase_name() != "ALL_RED_NS" or signal_controller.aspect_for_approach("N") != "red":
        _fail("clearance phase invalid")
        return
    signal_controller.advance_fixed(1.0)
    if signal_controller.phase_name() != "EW_GREEN" or signal_controller.aspect_for_approach("W") != "green":
        _fail("east-west green invalid")
        return
    for tick in range(1000):
        signal_controller.advance_fixed(0.05)
        if signal_controller.has_conflicting_green():
            _fail("conflicting green detected")
            return
    signal_controller.reset()
    signal_controller.advance_fixed(14.0)
    if signal_controller.phase_name() != "NS_GREEN":
        _fail("cycle wrap incorrect")
        return
    var invalid := Controller.new(0.0, 2.0, 1.0)
    if invalid.is_valid():
        _fail("invalid timing accepted")
        return
    print("CIVIC_CHAOS_SIGNAL_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
