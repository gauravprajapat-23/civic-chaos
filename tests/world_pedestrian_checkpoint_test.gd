extends SceneTree
## GAME-019: keep a real sidewalk walker linked to their occupied
## pedestrian-crossing reservation through a JSON checkpoint.
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var pedestrians := Walkers.new()
    pedestrians.pedestrian_count = 1
    pedestrians.name = "DistrictPedestrians"
    stage.add_child(pedestrians)
    pedestrians.set_physics_process(false)
    if pedestrians._walkers.size() != 1:
        _fail("one physical pedestrian was not staged")
        return
    var reserved := Reservations.new()
    if not reserved.request(100000, PackedStringArray(["pedestrian_crossing_ew"]), 1, 500)["granted"]:
        _fail("crossing reservation unavailable")
        return
    if not reserved.advance_to(10) or not reserved.occupy(100000, "pedestrian_crossing_ew"):
        _fail("pedestrian could not occupy the reserved crossing")
        return
    pedestrians._crossing[0] = true
    pedestrians._crossing_start_tick[0] = 10
    var recorded: Variant = JSON.parse_string(JSON.stringify(pedestrians.checkpoint_state()))
    var reserved_record: Variant = JSON.parse_string(JSON.stringify(reserved.snapshot()))
    if not pedestrians.checkpoint_valid(recorded, reserved_record):
        _fail("legitimate occupied pedestrian checkpoint refused")
        return
    var tampered: Dictionary = (reserved_record as Dictionary).duplicate(true)
    tampered["occupied"]["pedestrian_crossing_ew"] = 100001
    if pedestrians.checkpoint_valid(recorded, tampered):
        _fail("pedestrian permission accepted for the wrong crossing owner")
        return
    tampered = (recorded as Dictionary).duplicate(true)
    tampered["walkers"][0]["position"][0] = 9999.0
    if pedestrians.checkpoint_valid(tampered, reserved_record):
        _fail("teleported walker position accepted")
        return
    var original_location: Vector3 = pedestrians._walkers[0]["root"].position
    pedestrians._walkers[0]["root"].position += Vector3(5.0, 0, 0)
    if not pedestrians.restore_checkpoint(recorded, reserved_record):
        _fail("real pedestrian could not restore from verified occupied snapshot")
        return
    if pedestrians._walkers[0]["root"].position.distance_to(original_location) > 0.001:
        _fail("pedestrian did not return to checkpoint location")
        return
    if not pedestrians._crossing[0] or pedestrians._crossing_start_tick[0] != 10:
        _fail("checkpoint lost reserved crossing phase")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_WORLD_PEDESTRIAN_CHECKPOINT_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
