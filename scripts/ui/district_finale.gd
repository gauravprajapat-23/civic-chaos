class_name CivicDistrictFinale
extends CanvasLayer
## GAME-022: accessible, scrollable district results and Free Roam controls.
## Display-only: never changes civic mission progress or city scores.
signal continue_selected
signal replay_selected
signal review_selected

var backdrop: ColorRect
var summary_label: Label
var ranking_label: Label
var mission_label: Label
var reward_label: Label
var dimension_labels: Dictionary = {}
var dimension_bars: Dictionary = {}
var continue_button: Button
var review_button: Button
var replay_button: Button
var replay_confirmation: ConfirmationDialog
var _unlocked: bool = false
var _current_report: Dictionary = {}

func _ready() -> void:
    layer = 30
    process_mode = Node.PROCESS_MODE_ALWAYS
    review_button = Button.new()
    review_button.name = "ReviewDistrictResults"
    review_button.text = "DISTRICT RESULTS  |  F2"
    review_button.position = Vector2(14, 344)
    review_button.custom_minimum_size = Vector2(218, 48)
    review_button.visible = false
    review_button.pressed.connect(func() -> void: review_selected.emit())
    add_child(review_button)

    backdrop = ColorRect.new()
    backdrop.name = "FinaleBackdrop"
    backdrop.color = Color(0.025, 0.038, 0.065, 0.91)
    backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(backdrop)
    backdrop.visible = false

    var center := CenterContainer.new()
    center.name = "FinaleCenter"
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    backdrop.add_child(center)
    var panel := PanelContainer.new()
    panel.name = "DistrictScorecard"
    panel.custom_minimum_size = Vector2(500, 440)
    center.add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.name = "ScoreScroll"
    scroll.custom_minimum_size = Vector2(480, 470)
    panel.add_child(scroll)
    var stack := VBoxContainer.new()
    stack.name = "ScoreContents"
    stack.add_theme_constant_override("separation", 12)
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(stack)

    _text_line(stack, "CIVIC CHAOS", 28)
    _text_line(stack, "MARKET CHOWK  |  THE CITY THANKS YOU", 17)
    ranking_label = _text_line(stack, "District standing", 22)
    summary_label = _text_line(stack, "Story missions complete", 17)
    _text_line(stack, "DISTRICT REPORT  •  VERIFIED CITY SCORES", 15)

    for dimension in CivicDistrictCampaign.DIMENSIONS:
        var name: String = str(dimension).capitalize()
        var line := _text_line(stack, name, 15)
        dimension_labels[dimension] = line
        var bar := ProgressBar.new()
        bar.name = name + "Progress"
        bar.min_value = 0.0
        bar.max_value = 1000.0
        bar.show_percentage = false
        bar.custom_minimum_size = Vector2(290, 15)
        stack.add_child(bar)
        dimension_bars[dimension] = bar

    mission_label = _text_line(stack, "CAMPAIGN RECORD", 15)
    reward_label = _text_line(stack, "Mission points", 16)
    _text_line(stack, "The roads are open, the footpath is clear, and the market is clean. The district is yours to explore.", 14)
    continue_button = Button.new()
    continue_button.name = "EnterFreeRoam"
    continue_button.text = "CONTINUE IN FREE ROAM"
    continue_button.custom_minimum_size = Vector2(320, 52)
    continue_button.pressed.connect(func() -> void: continue_selected.emit())
    stack.add_child(continue_button)
    replay_button = Button.new()
    replay_button.name = "ReplayStory"
    replay_button.text = "REPLAY STORY (RESTART LEVEL)"
    replay_button.tooltip_text = "Starts from the tutorial. Your disk checkpoint is not erased until you save again."
    replay_button.custom_minimum_size = Vector2(320, 45)
    replay_button.pressed.connect(_confirm_replay)
    stack.add_child(replay_button)

    replay_confirmation = ConfirmationDialog.new()
    replay_confirmation.title = "Replay the Civic Chaos story?"
    replay_confirmation.dialog_text = "Restart at the first tutorial? Unsaved progress will be lost. The last saved checkpoint stays on disk until you save over it."
    replay_confirmation.confirmed.connect(func() -> void: replay_selected.emit())
    add_child(replay_confirmation)
    get_viewport().size_changed.connect(_layout)
    _layout()

func _text_line(parent: VBoxContainer, label_text: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = label_text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(label)
    return label

func _layout() -> void:
    if backdrop == null:
        return
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    var panel := backdrop.get_node("FinaleCenter/DistrictScorecard") as PanelContainer
    var scroll := panel.get_node("ScoreScroll") as ScrollContainer
    panel.custom_minimum_size = Vector2(maxf(220.0, minf(550.0, viewport.x - 32.0)), 0.0)
    scroll.custom_minimum_size = Vector2(maxf(185.0, minf(515.0, viewport.x - 62.0)),
        maxf(150.0, minf(600.0, viewport.y - 48.0)))

func set_unlocked(value: bool) -> void:
    _unlocked = value
    if review_button != null:
        review_button.visible = _unlocked and not is_open()
    if not value and is_open():
        dismiss()

func present(report: Dictionary) -> bool:
    if not _unlocked or report.is_empty() or not bool(report.get("unlocked", false)) or backdrop == null:
        return false
    if not (report.get("scores") is Dictionary) or not (report.get("missions") is Array):
        return false
    var scores: Dictionary = report["scores"]
    for dimension in CivicDistrictCampaign.DIMENSIONS:
        if not (scores.get(dimension) is int or scores.get(dimension) is float):
            return false
    _current_report = report.duplicate(true)
    ranking_label.text = "%s   |   Reputation %d / 1000" % [
        str(report.get("rating", "District complete")), int(report.get("reputation", 0))]
    summary_label.text = "%d story incidents resolved  •  %d including the tutorial" % [
        int(report.get("story_count", 0)), int(report.get("mission_count", 0))]
    for dimension in CivicDistrictCampaign.DIMENSIONS:
        var score: int = int(scores[dimension])
        (dimension_labels[dimension] as Label).text = "%s  |  %d / 1000" % [
            str(dimension).capitalize(), score]
        (dimension_bars[dimension] as ProgressBar).value = score
    var rows: Array[String] = []
    for mission in report["missions"]:
        if mission is Dictionary:
            rows.append("✓ %s  •  +%d mission pts" % [
                str(mission.get("title", "Mission")), int(mission.get("reward", 0))])
    mission_label.text = "COMPLETED CAMPAIGN\n" + "\n".join(rows)
    reward_label.text = "Total earned mission points: %d" % int(report.get("reward_total", 0))
    backdrop.visible = true
    review_button.visible = false
    continue_button.grab_focus()
    return true

func dismiss() -> void:
    if backdrop != null:
        backdrop.visible = false
    if review_button != null:
        review_button.visible = _unlocked

func is_open() -> bool:
    return backdrop != null and backdrop.visible

func current_report() -> Dictionary:
    return _current_report.duplicate(true)

func _confirm_replay() -> void:
    replay_confirmation.popup_centered()
