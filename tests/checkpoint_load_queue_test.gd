extends SceneTree
## AUD-001: an F9 input selects one verified generation, not a later F5.
## Loading is consumed once on a physics tick; duplicate requests must not
## overwrite the first selection or create a second restore transaction.
const Queue = preload("res://scripts/core/checkpoint_load_queue.gd")
const Repo = preload("res://scripts/core/save_repository.gd")
const Main = preload("res://scripts/core/main.gd")
const PATH: String = "user://aud001_checkpoint_load_queue.json"

func _initialize() -> void:
    call_deferred("_run")

func _payload(x: float) -> Dictionary:
    return {"player": {"x": x, "y": 0.1, "z": 0.0, "yaw": 0.0},
        "campaign_checkpoint": {"test_generation": int(x)}}

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        var path: String = PATH + suffix
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
    _clean()
    var queue: CivicCheckpointLoadQueue = Queue.new() as CivicCheckpointLoadQueue
    if queue.has_pending() or not queue.consume().is_empty():
        _fail("empty queue claimed a pending restore")
        return
    if not Repo.write_save(_payload(1.0), PATH):
        _fail("could not write initial checkpoint generation")
        return
    var chosen_a: Dictionary = Repo.read_save_detail(PATH)
    if not queue.request(chosen_a) or not queue.has_pending():
        _fail("F9 could not queue the selected verified generation")
        return
    # The queued document is a deep copy; mutating an external dictionary
    # or committing a new file must not replace the selected snapshot.
    chosen_a["data"]["player"]["x"] = -111.0
    chosen_a["data"]["campaign_checkpoint"]["test_generation"] = -111
    if not Repo.write_save(_payload(2.0), PATH):
        _fail("could not write newer checkpoint generation")
        return
    if queue.request(Repo.read_save_detail(PATH)):
        _fail("second F9 overwrote an already queued checkpoint")
        return
    var chosen: Dictionary = queue.consume()
    if queue.has_pending() or float(chosen.get("data", {}).get("player", {}).get("x", -1)) != 1.0:
        _fail("dequeued F9 loaded a newer generation or leaked pending state")
        return
    if int(chosen["data"]["campaign_checkpoint"].get("test_generation", -1)) != 1:
        _fail("queue did not deep-copy nested campaign data")
        return
    if not queue.consume().is_empty():
        _fail("consumed request could be applied twice")
        return
    if not queue.request(Repo.read_save_detail(PATH)):
        _fail("queue failed to accept new request after first was consumed")
        return
    chosen = queue.consume()
    if float(chosen.get("data", {}).get("player", {}).get("x", -1)) != 2.0:
        _fail("next F9 did not select the newly committed generation")
        return
    if not queue.request({"ok": false, "source": "none", "data": {}}):
        _fail("missing-save document could not be queued for safe failure")
        return
    queue.clear()
    if queue.has_pending() or not queue.consume().is_empty():
        _fail("clearing pending load left stale checkpoint data")
        return

    # An explicit empty F9 selection must remain empty, even when F5
    # creates a new checkpoint before the next physics tick. Only a truly
    # omitted selection (null) is allowed to read the latest file.
    _clean()
    if not queue.request({}):
        _fail("could not queue explicit unavailable document")
        return
    if not Repo.write_save(_payload(3.0), PATH):
        _fail("could not create newer save after missing F9 snapshot")
        return
    if not Main.checkpoint_selected_document(queue.consume()).is_empty():
        _fail("empty selected F9 document silently loaded later F5 save")
        return
    # The test checkpoint uses a deliberately isolated user:// path.
    # The no-argument legacy API always reads SaveRepository.DEFAULT_PATH,
    # not this fixture's private file. Verify the correct default behavior
    # without overwriting a real player's default game save.
    var direct: Dictionary = Main.checkpoint_selected_document()
    if direct != Repo.read_save_detail():
        _fail("legacy direct load did not select the default save")
        return
    var explicitly_selected: Dictionary = Main.checkpoint_selected_document(Repo.read_save_detail(PATH))
    if float(explicitly_selected.get("data", {}).get("player", {}).get("x", -1.0)) != 3.0:
        _fail("explicit checkpoint selection did not preserve the test generation")
        return
    _clean()
    print("CIVIC_CHAOS_CHECKPOINT_LOAD_QUEUE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    _clean()
    quit(1)
