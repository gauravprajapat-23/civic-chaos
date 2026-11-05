extends SceneTree

const Incidents = preload("res://scripts/civic/incident_manager.gd")
const Parking = preload("res://scripts/civic/parking_capacity.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var manager := Incidents.new()
    var parking := Parking.new()
    assert(parking.configure(manager))
    assert(parking.register_lane(1, 4))
    assert(parking.register_lane(2, 4))
    assert(parking.park_illegally(1, 77, 0.75, 0))
    assert(not parking.park_illegally(1, 78, 0.5, 0))
    for tick in range(1, 6):
        assert(parking.advance_to(tick, {1: 3, 2: 3}))
    assert(parking.lane_metrics(1)["queue"] == 10)
    assert(parking.lane_metrics(2)["queue"] == 0)
    assert(parking.remove_obstruction(1, 6))
    for tick in range(7, 12):
        assert(parking.advance_to(tick, {1: 0, 2: 0}))
    assert(parking.lane_metrics(1)["queue"] == 0)
    assert(parking.resolve(1, 12))
    assert(not parking.advance_to(12, {}))
    print("CIVIC_CHAOS_PARKING_PASS")
    quit(0)
