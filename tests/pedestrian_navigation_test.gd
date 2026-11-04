extends SceneTree

const Navigator = preload("res://scripts/npc/pedestrian_navigator.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var manager := Reservations.new()
    var path := PackedVector3Array([Vector3.ZERO, Vector3(2, 0, 0), Vector3(4, 0, 0)])
    var pedestrian := Navigator.new()
    root.add_child(pedestrian)
    assert(pedestrian.configure(1, path, 1, manager))
    for tick in range(1, 50):
        manager.advance_to(tick)
        pedestrian.advance_fixed(tick, 0.05, false, true)
    assert(pedestrian.state_name() == "waiting")
    pedestrian.advance_fixed(50, 0.05, true, false)
    assert(pedestrian.state_name() == "waiting")
    var vehicle_slot := manager.request(2, PackedStringArray(["crosswalk"]), 50, 100)
    assert(vehicle_slot["granted"])
    assert(manager.occupy(2, "crosswalk"))
    pedestrian.advance_fixed(50, 0.05, true, true)
    assert(pedestrian.state_name() == "waiting")
    assert(manager.release(2, "crosswalk"))
    manager.cancel(2)
    pedestrian.advance_fixed(51, 0.05, true, true)
    assert(pedestrian.state_name() == "crossing")
    assert(manager.occupant("crosswalk") == 1)
    for tick in range(52, 100):
        manager.advance_to(tick)
        pedestrian.advance_fixed(tick, 0.05, false, false)
    assert(pedestrian.state_name() == "complete")
    assert(manager.occupant("crosswalk") == -1)
    var invalid := Navigator.new()
    root.add_child(invalid)
    assert(not invalid.configure(3, PackedVector3Array([Vector3.ZERO]), 0, manager))
    assert(invalid.state_name() == "blocked")
    print("CIVIC_CHAOS_PEDESTRIAN_PASS")
    quit(0)
