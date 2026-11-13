extends SceneTree
## UX-01: menu exposes gameplay instructions without changing Start/Quit routing.
const Menu = preload("res://scenes/core/menu.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var instance: Control = Menu.instantiate() as Control
    if instance == null:
        _fail("main menu did not instantiate")
        return
    root.add_child(instance)
    var start: Button = instance.get_node_or_null("CenterContainer/VBoxContainer/StartButton") as Button
    var quit_button: Button = instance.get_node_or_null("CenterContainer/VBoxContainer/QuitButton") as Button
    var guide_button: Button = instance.get_node_or_null("CenterContainer/VBoxContainer/HowToPlayButton") as Button
    var guide: ColorRect = instance.get_node_or_null("GuideBackdrop") as ColorRect
    if start == null or quit_button == null or guide_button == null or guide == null:
        _fail("menu navigation or accessibility controls are missing")
        return
    if start.disabled or quit_button.disabled or guide_button.disabled or guide.visible:
        _fail("menu started with disabled actions or an open guide")
        return
    guide_button.pressed.emit()
    if not guide.visible:
        _fail("How to Play button failed to open the overlay")
        return
    var instructions: Label = instance.get_node_or_null(
        "GuideBackdrop/GuideCenter/GuidePanel/VBoxContainer/GuideScroll/Instructions") as Label
    if instructions == null:
        _fail("instructions were not available to keyboard and touch users")
        return
    for required in ["WASD", "F5", "F9", "TOUCH CONTROLS", "WRONG", "Free Roam"]:
        if not instructions.text.to_lower().contains(required.to_lower()):
            _fail("gameplay guide omitted " + required)
            return
    var close: Button = instance.get_node_or_null(
        "GuideBackdrop/GuideCenter/GuidePanel/VBoxContainer/CloseGuideButton") as Button
    if close == null or close.custom_minimum_size.y < 48.0:
        _fail("touch accessible guide dismissal missing")
        return
    close.pressed.emit()
    if guide.visible:
        _fail("guide did not dismiss")
        return
    instance.queue_free()
    print("CIVIC_CHAOS_MENU_UX_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
