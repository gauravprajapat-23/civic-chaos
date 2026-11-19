extends SceneTree
## TRAFFIC-FIX-09: lit signals, actual one-direction stop permission,
## and player marshal requests all agree with the same authority.
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Furniture = preload("res://scripts/world/street_furniture.gd")
const Marshal = preload("res://scripts/civic/traffic_marshal_control.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var signals := Signals.new(12.0, 3.0, 2.0)
    signals.enable_single_approach_mode()
    var spawner := Spawner.new() as CivicTrafficSpawner
    stage.add_child(spawner)
    if not spawner.configure(Builder.make_city_graph(), 459, true):
        _fail("traffic setup failed")
        return
    var reservations := Reservations.new()
    spawner.configure_intersection(signals, reservations)
    var furniture := Furniture.new()
    stage.add_child(furniture)
    furniture.configure_signals(signals)
    furniture._process(0.0)
    if not _check_visible_lamps(furniture, "N"):
        _fail("initial north green visual does not match controller")
        return
    var empty_cars: Array[CivicVehicleAgent] = []
    if Marshal.request_axis("E", signals, reservations, spawner, empty_cars).get("reason") != "minimum_green":
        _fail("marshal violated minimum north green")
        return
    signals.advance_fixed(4.2)
    if Marshal.request_axis("S", signals, reservations, spawner, empty_cars).get("reason") != "not_next_approach":
        _fail("marshal skipped scheduled east approach")
        return
    var accepted: Dictionary = Marshal.request_axis("E", signals, reservations, spawner, empty_cars)
    if not bool(accepted.get("accepted", false)):
        _fail("safe east request refused: " + str(accepted))
        return
    if not _check_visible_lamps(furniture, "N"):
        _fail("request instantly changed visible north green")
        return
    signals.advance_fixed(0.9)
    furniture._process(0.0)
    if signals.phase_name() != "N_AMBER" or not _check_visible_lamps(furniture, ""):
        _fail("requested turn skipped physical amber signal")
        return
    signals.advance_fixed(3.0)
    furniture._process(0.0)
    if signals.phase_name() != "ALL_RED_N" or not _check_visible_lamps(furniture, ""):
        _fail("requested turn skipped physical all-red")
        return
    signals.advance_fixed(2.0)
    furniture._process(0.0)
    if signals.phase_name() != "E_GREEN" or not _check_visible_lamps(furniture, "E"):
        _fail("east green head did not light exclusively")
        return
    if Marshal.request_axis("E", signals, reservations, spawner, empty_cars).get("reason") != "already_green":
        _fail("marshal allowed same green twice")
        return
    # If a pedestrian holds a conflicting zone, the marshal must wait
    # rather than forcing the next phase through it.
    var permission: Dictionary = reservations.request(900, PackedStringArray(["pedestrian_crossing_ns"]), 0, 100)
    if not bool(permission.get("granted", false)) or not reservations.occupy(900, "pedestrian_crossing_ns"):
        _fail("walker reservation test invalid")
        return
    signals.advance_fixed(4.1)
    if Marshal.request_axis("S", signals, reservations, spawner, empty_cars).get("reason") != "pedestrian_in_crossing":
        _fail("marshal request ran through pedestrian occupancy")
        return
    reservations.release(900, "pedestrian_crossing_ns")
    reservations.cancel(900)
    stage.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_09_VISUAL_MARSHAL_PASS")
    quit(0)

func _check_visible_lamps(furniture: Node3D, allowed: String) -> bool:
    furniture._process(0.0)
    var all: Array[String] = ["N", "E", "S", "W"]
    for index in range(4):
        var head: Node3D = furniture.get_node_or_null("TrafficSignal_%d" % index)
        if head == null:
            return false
        var green: MeshInstance3D = head.get_node_or_null("Lamp_2") as MeshInstance3D
        if green == null:
            return false
        var finish: StandardMaterial3D = green.material_override as StandardMaterial3D
        if finish == null or finish.emission_enabled != (allowed == all[index]):
            return false
    return true

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
