extends SceneTree
## TRAFFIC-FIX-06: only admit new pedestrians when sufficient red time
## remains, without ever cancelling a crossing that is already occupied.
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var signal_controller := Signals.new(12.0, 3.0, 2.0)
    if absf(signal_controller.seconds_until_green("E") - 17.0) > 0.001:
        _fail("initial east/west red-window duration incorrect")
        return
    if signal_controller.seconds_until_green("N") != 0.0:
        _fail("north/south green must have zero delay")
        return
    var walker := Walkers.new()
    walker.pedestrian_count = 0
    var scene := Node3D.new()
    root.add_child(scene)
    scene.add_child(walker)
    walker.configure_traffic(signal_controller, null, null)
    if not walker._can_cross(0):
        _fail("pedestrian cannot enter during safe NS green window")
        return
    if walker._can_cross(2):
        _fail("pedestrian entering perpendicular crossing on NS green")
        return
    signal_controller.advance_fixed(5.0)
    if walker._can_cross(0):
        _fail("pedestrian was admitted with only 12 seconds before EW green")
        return
    signal_controller.advance_fixed(7.0)
    if walker._can_cross(0):
        _fail("late amber approach allowed pedestrian crossing")
        return
    signal_controller.advance_fixed(5.0)
    if signal_controller.aspect_for_approach("E") != "green" or walker._can_cross(0):
        _fail("new crossing was authorized during EW vehicle green")
        return
    if not walker._can_cross(2):
        _fail("new north/south-conflicting crossing denied during long EW green")
        return
    signal_controller.advance_fixed(5.0)
    if walker._can_cross(2):
        _fail("NS crossing admitted too late during EW green")
        return
    signal_controller.advance_fixed(12.0)
    if signal_controller.aspect_for_approach("N") != "green" or not walker._can_cross(0):
        _fail("new NS vehicle cycle did not reopen safe pedestrian entry")
        return
    scene.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_06_PEDESTRIAN_ENTRY_WINDOW_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
