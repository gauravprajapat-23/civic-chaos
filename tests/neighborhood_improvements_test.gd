extends SceneTree
## PROG-03: visible, receipt-backed district improvements without new saves
## or collision geometry. Invalid completions cannot unlock city props.
const Improvements = preload("res://scripts/world/neighborhood_improvements.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var project := Improvements.new() as CivicNeighborhoodImprovements
    stage.add_child(project)
    if project.project_visible(0) or project.project_visible(1) or project.project_visible(2):
        _fail("new neighborhood already has restored projects")
        return
    var receipts: Dictionary = {}
    for total in range(26):
        if total > 0:
            receipts["free_roam:%d:resolved" % total] = true
        if not project.update_from_receipts(530, total, receipts):
            _fail("verified progression update was rejected at count %d" % total)
            return
        var first: bool = total >= 3
        var second: bool = total >= 10
        var third: bool = total >= 25
        if project.project_visible(0) != first or project.project_visible(1) != second or project.project_visible(2) != third:
            _fail("neighborhood milestone visibility incorrect at %d" % total)
            return
        if project.get_child_count() != 3:
            _fail("repeated progress updates duplicated neighborhood props")
            return
    var state: Dictionary = project.project_state()
    if state["unlocked"].size() != 3 or state["remaining"] != 0:
        _fail("final improvement catalog was not completed")
        return
    var count_before: int = project.get_child_count()
    if project.update_from_receipts(530, 26, receipts):
        _fail("forged extra completion accepted by improvement projects")
        return
    if project.get_child_count() != count_before or not project.project_visible(2):
        _fail("invalid progress mutated the last verified city improvements")
        return
    var replay: Variant = JSON.parse_string(JSON.stringify(receipts))
    var after_reload := Improvements.new() as CivicNeighborhoodImprovements
    stage.add_child(after_reload)
    if not after_reload.update_from_receipts(530, 25, replay):
        _fail("verified city improvements failed to reconstruct after JSON replay")
        return
    if after_reload.project_state() != state:
        _fail("checkpoint replay changed neighborhood project state")
        return
    for mesh_parent in after_reload.get_children():
        if mesh_parent is not Node3D:
            _fail("improvement object is not a visual-only node")
            return
        for piece in mesh_parent.get_children():
            if piece is MeshInstance3D:
                continue
            if piece is CivicNeighborhoodService:
                var station: CivicNeighborhoodService = piece as CivicNeighborhoodService
                if station.collision_layer != 16 or station.collision_mask != 0:
                    _fail("unlocked service station has unsafe physics layer")
                    return
                continue
            _fail("city project created an unexpected child node")
            return
    stage.queue_free()
    print("CIVIC_CHAOS_NEIGHBORHOOD_IMPROVEMENTS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
