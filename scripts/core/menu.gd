extends Control
## UX-01: compact, responsive first-time player menu. Guide is informational;
## Start/Quit still use the existing scene lifecycle.

var guide_backdrop: ColorRect
var guide_panel: PanelContainer
var guide_button: Button
var close_guide_button: Button
var start_button: Button

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _style_menu()
    _build_guide()
    get_viewport().size_changed.connect(_layout_guide)
    print("CIVIC_CHAOS_MENU_READY")

func _style_menu() -> void:
    var background := ColorRect.new()
    background.name = "CityBackdrop"
    background.color = Color(0.045, 0.075, 0.11)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    move_child(background, 0)

    var content := get_node("CenterContainer/VBoxContainer") as VBoxContainer
    content.add_theme_constant_override("separation", 16)
    content.custom_minimum_size.x =  minf(480.0, maxf(250.0, get_viewport_rect().size.x - 40.0))
    var title := content.get_node("Title") as Label
    title.text = "CIVIC CHAOS"
    title.add_theme_font_size_override("font_size", 43)
    title.add_theme_color_override("font_color", Color(0.99, 0.8, 0.35))
    var subtitle := content.get_node("Subtitle") as Label
    subtitle.text = "Nagripur needs a little less chaos."
    subtitle.add_theme_font_size_override("font_size", 17)
    subtitle.add_theme_color_override("font_color", Color(0.83, 0.91, 0.95))
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    start_button = content.get_node("StartButton") as Button
    start_button.text = "START STORY"
    guide_button = Button.new()
    guide_button.name = "HowToPlayButton"
    guide_button.text = "HOW TO PLAY"
    guide_button.pressed.connect(show_guide)
    content.add_child(guide_button)
    content.move_child(guide_button, content.get_child_count() - 2)
    var quit_button := content.get_node("QuitButton") as Button
    quit_button.text = "QUIT"
    for button in [start_button, guide_button, quit_button]:
        button.custom_minimum_size.y = 54.0
        button.focus_mode = Control.FOCUS_ALL
        button.add_theme_font_size_override("font_size", 18)
        var normal := StyleBoxFlat.new()
        normal.bg_color = Color(0.13, 0.22, 0.3)
        normal.corner_radius_top_left = 10
        normal.corner_radius_top_right = 10
        normal.corner_radius_bottom_left = 10
        normal.corner_radius_bottom_right = 10
        normal.content_margin_left = 16
        normal.content_margin_right = 16
        button.add_theme_stylebox_override("normal", normal)
        var focused := normal.duplicate() as StyleBoxFlat
        focused.bg_color = Color(0.24, 0.39, 0.47)
        button.add_theme_stylebox_override("hover", focused)
        button.add_theme_stylebox_override("focus", focused)
    start_button.grab_focus()

func _build_guide() -> void:
    guide_backdrop = ColorRect.new()
    guide_backdrop.name = "GuideBackdrop"
    guide_backdrop.color = Color(0.0, 0.0, 0.0, 0.87)
    guide_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(guide_backdrop)
    guide_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    center.name = "GuideCenter"
    guide_backdrop.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    guide_panel = PanelContainer.new()
    guide_panel.name = "GuidePanel"
    center.add_child(guide_panel)
    var surface := StyleBoxFlat.new()
    surface.bg_color = Color(0.075, 0.12, 0.17)
    surface.border_color = Color(0.7, 0.55, 0.27)
    surface.set_border_width_all(2)
    surface.set_corner_radius_all(12)
    surface.set_content_margin_all(18)
    guide_panel.add_theme_stylebox_override("panel", surface)
    var layout := VBoxContainer.new()
    layout.name = "VBoxContainer"
    layout.add_theme_constant_override("separation", 12)
    guide_panel.add_child(layout)
    var title := Label.new()
    title.text = "HOW TO PLAY"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 25)
    title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.36))
    layout.add_child(title)
    var scroll := ScrollContainer.new()
    scroll.name = "GuideScroll"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    layout.add_child(scroll)
    var instructions := Label.new()
    instructions.name = "Instructions"
    instructions.text = (
        "YOU ARE A NEIGHBORHOOD VOLUNTEER\\n"
        + "Explore Nagripur, inspect civic problems, choose safe actions and watch the city recover.\\n\\n"
        + "PC CONTROLS\\n"
        + "WASD: Move   Mouse: Look   Shift: Run   Space: Jump\\n"
        + "E: Interact   F1: Pause   F5: Save   F9: Load\\n"
        + "F2: District results (after unlock)   F10: Restart   F12: Menu\\n\\n"
        + "TOUCH CONTROLS\\n"
        + "Directional buttons move; drag the right side to look. Use RUN, JUMP, USE and PAUSE.\\n\\n"
        + "STORY OBJECTIVES\\n"
        + "1. Inspect the footpath tutorial.\\n"
        + "2. Report wrong-way traffic and wait for safe towing.\\n"
        + "3. Inspect illegal parking; request the owner or municipal help.\\n"
        + "4. Clean the market and finish the district.\\n\\n"
        + "AFTER THE FINALE\\n"
        + "Continue in Free Roam. Collect litter, return fallen signs and store misplaced cones.\\n"
        + "Earn volunteer badges and neighborhood support by resolving real incidents.\\n"
        + "At 3, 10 and 25 completions, the market gains usable community projects.\\n"
        + "Approach a service point and press E / USE for local guidance.\\n"
        + "Follow the objective guide and interact close to marked objects."
    ).replace("\\n", "\n")
    instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    instructions.add_theme_font_size_override("font_size", 16)
    instructions.add_theme_color_override("font_color", Color(0.92, 0.95, 0.97))
    scroll.add_child(instructions)
    close_guide_button = Button.new()
    close_guide_button.name = "CloseGuideButton"
    close_guide_button.text = "BACK TO MENU"
    close_guide_button.custom_minimum_size.y = 52
    close_guide_button.pressed.connect(hide_guide)
    layout.add_child(close_guide_button)
    guide_backdrop.visible = false
    _layout_guide()

func _layout_guide() -> void:
    if guide_panel == null:
        return
    var area: Vector2 = get_viewport_rect().size
    guide_panel.custom_minimum_size = Vector2(
        minf(590.0, maxf(210.0, area.x - 24.0)),
        minf(570.0, maxf(160.0, area.y - 24.0))
    )

func show_guide() -> void:
    guide_backdrop.visible = true
    close_guide_button.grab_focus()

func hide_guide() -> void:
    guide_backdrop.visible = false
    guide_button.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
    if guide_backdrop != null and guide_backdrop.visible and event.pressed and not event.echo:
        if event.is_action_pressed("ui_cancel"):
            hide_guide()
            get_viewport().set_input_as_handled()

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _on_quit_pressed() -> void:
    get_tree().quit()
