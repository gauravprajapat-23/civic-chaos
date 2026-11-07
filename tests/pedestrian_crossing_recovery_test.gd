extends SceneTree
## A stalled person may relinquish a pre-entry reservation, but not road
## occupancy while physically inside the crosswalk.
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var walkers = Walkers.new()
    walkers.pedestrian_count = 1
    stage.add_child(walkers)
    var reserved := Reservations.new()
    walkers.configure_traffic(null, null, reserved)
    await physics_frame
    walkers.set_physics_process(false)
    var body: Node3D = walkers._walkers[0]["root"]
    var length: float = walkers.district_extent * 1.65
    body.position = walkers._walk_position(0, -6.0)
    walkers._walker_progress[0] = length * 0.5 - 6.0
    if not walkers._reserve_crossing(0, 0):
        _fail("pre-entry reservation denied")
        return
    walkers._crossing[0] = true
    if reserved.occupant("pedestrian_crossing_ew") != 100000:
        _fail("reserved crossing not marked occupied")
        return
    walkers._blocked_frames[0] = 100
    if walkers._retire_stalled_crossing(0, 0):
        _fail("crossing released without waiting timeout")
        return
    reserved.advance_to(120)
    if not walkers._retire_stalled_crossing(0, 0):
        _fail("stalled pre-entry reservation did not release")
        return
    if reserved.occupant("pedestrian_crossing_ew") != -1 or walkers._crossing[0]:
        _fail("reservation remains held after safe pre-entry release")
        return

    # Entry now takes place: even a very old reservation must remain held
    # if the walker is physically within the road conflict zone.
    body.position = walkers._walk_position(0, 0.0)
    walkers._walker_progress[0] = length * 0.5
    if not walkers._reserve_crossing(0, 0):
        _fail("crossing could not be reserved for occupied-road case")
        return
    walkers._crossing[0] = true
    walkers._blocked_frames[0] = 100
    reserved.advance_to(300)
    if walkers._retire_stalled_crossing(0, 0):
        _fail("occupied road zone was unsafely released by timeout")
        return
    if reserved.occupant("pedestrian_crossing_ew") != 100000:
        _fail("crosswalk occupant lost safety ownership while inside road")
        return
    body.position = walkers._walk_position(0, 6.2)
    if walkers._walker_in_crossing_conflict(0, 0):
        _fail("safe pedestrian exit still judged inside crossing")
        return
    walkers._release_crossing(0, 0)
    walkers._crossing[0] = false
    if reserved.occupant("pedestrian_crossing_ew") != -1:
        _fail("completed crossing kept zone blocked")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_PEDESTRIAN_CROSSING_RECOVERY_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
