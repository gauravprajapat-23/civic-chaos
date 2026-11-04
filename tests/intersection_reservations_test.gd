extends SceneTree

const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var manager := Reservations.new()
    if not manager.request(1, PackedStringArray(["center"]), 1, 10)["granted"]:
        _fail("initial reservation rejected")
        return
    if manager.request(2, PackedStringArray(["center"]), 5, 12)["reason"] != "conflict":
        _fail("overlapping conflict allowed")
        return
    if not manager.request(3, PackedStringArray(["east"]), 5, 12)["granted"]:
        _fail("nonconflicting reservation rejected")
        return
    if not manager.advance_to(5) or not manager.occupy(1, "center"):
        _fail("reserved vehicle cannot occupy")
        return
    if manager.occupy(2, "center"):
        _fail("unauthorized occupancy allowed")
        return
    if manager.request(2, PackedStringArray(["center"]), 12, 15)["reason"] != "occupied":
        _fail("occupied zone unprotected")
        return
    manager.advance_to(11)
    if manager.active_reservation_count() != 1 or manager.occupant("center") != 1:
        _fail("expiration erased occupancy or wrong reservations")
        return
    if manager.request(2, PackedStringArray(["center"]), 12, 15)["reason"] != "occupied":
        _fail("expired occupancy not protected")
        return
    if not manager.release(1, "center"):
        _fail("owner release failed")
        return
    if not manager.request(2, PackedStringArray(["center"]), 12, 15)["granted"]:
        _fail("released zone still blocked")
        return
    if manager.advance_to(10):
        _fail("clock went backwards")
        return
    if manager.request(4, PackedStringArray(), 12, 15)["reason"] != "invalid_request":
        _fail("empty zones accepted")
        return
    manager.reset()
    if manager.current_tick != 0 or manager.active_reservation_count() != 0:
        _fail("reset failed")
        return
    print("CIVIC_CHAOS_RESERVATIONS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
