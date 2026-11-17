extends SceneTree
## VEHICLE-RIDE-01: existing Android touch UI changes its text, not
## its positions, targets or ownership. Walking labels restore on exit.
const Touch = preload("res://scripts/ui/touch_controls.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var controls := Touch.new() as CivicTouchControls
    root.add_child(controls)
    await process_frame
    var original: Dictionary = controls._rects.duplicate(true)
    if controls.labels["jump"].text != "JUMP" or controls.labels["interact"].text != "USE":
        _fail("walking buttons changed from existing controls")
        return
    controls.set_riding(true)
    if controls.labels["jump"].text != "BRAKE" or controls.labels["sprint"].text != "BOOST" or (
            controls.labels["interact"].text != "EXIT"):
        _fail("riding actions not readable on Android")
        return
    if original != controls._rects or controls.buttons.size() != 4:
        _fail("bike controls added a second joystick or moved hitboxes")
        return
    controls.set_riding(false)
    if controls.labels["jump"].text != "JUMP" or controls.labels["sprint"].text != "RUN" or (
            controls.labels["interact"].text != "USE"):
        _fail("touch action captions not restored after dismount")
        return
    controls.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_01_MOBILE_ACTIONS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
