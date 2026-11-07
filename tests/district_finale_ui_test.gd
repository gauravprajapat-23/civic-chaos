extends SceneTree
## GAME-022: explicit Continue, Review, and confirmed Replay UI actions.
const Finale = preload("res://scripts/ui/district_finale.gd")
const Campaign = preload("res://scripts/civic/district_campaign.gd")
const Fixture = preload("res://tests/support/campaign_fixture.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var data: Dictionary = Fixture.completed()
    if data.is_empty():
        _fail("campaign fixture missing")
        return
    var score: Dictionary = Campaign.scorecard(data["civic"], data["wrong_way"],
        data["parking"], data["cleanup"])
    var finale := Finale.new() as CivicDistrictFinale
    root.add_child(finale)
    await process_frame
    if finale.present(score):
        _fail("results could be opened before Free Roam was earned")
        return
    finale.set_unlocked(true)
    if not finale.present(score) or not finale.is_open():
        _fail("completed campaign results did not open")
        return
    if finale.continue_button.text != "CONTINUE IN FREE ROAM":
        _fail("finale has no explicit free roam action")
        return
    if finale.ranking_label.text.find("543") < 0 or finale.reward_label.text.find("315") < 0:
        _fail("visible scorecard does not display actual district totals")
        return
    for dimension in Campaign.DIMENSIONS:
        if int((finale.dimension_bars[dimension] as ProgressBar).value) != score["scores"][dimension]:
            _fail("scorecard bar displayed a fabricated city metric")
            return
    var continued: int = 0
    var replayed: int = 0
    var reviewed: int = 0
    finale.continue_selected.connect(func() -> void: continued += 1)
    finale.replay_selected.connect(func() -> void: replayed += 1)
    finale.review_selected.connect(func() -> void: reviewed += 1)
    finale.continue_button.pressed.emit()
    if continued != 1 or replayed != 0:
        _fail("continue action triggered wrong handler")
        return
    finale.dismiss()
    if finale.is_open() or not finale.review_button.visible:
        _fail("Free Roam review button did not become available")
        return
    finale.review_button.pressed.emit()
    if reviewed != 1:
        _fail("district review action was not exposed after ending")
        return
    if not finale.present(score):
        _fail("completed scorecard could not be reopened")
        return
    finale.replay_confirmation.confirmed.emit()
    if replayed != 1 or continued != 1:
        _fail("confirmed replay triggered reward/continue handler")
        return
    finale.dismiss()
    finale.set_unlocked(false)
    if finale.review_button.visible or finale.present(score):
        _fail("Free Roam UI remained exposed after revoking unlock")
        return
    finale.queue_free()
    print("CIVIC_CHAOS_DISTRICT_FINALE_UI_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
