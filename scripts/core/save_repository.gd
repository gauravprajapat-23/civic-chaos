class_name CivicSaveRepository
extends RefCounted
## Versioned, atomic JSON save files. No executable deserialization.

const SAVE_VERSION: int = 1
const DEFAULT_PATH: String = "user://civic_chaos_save.json"

static func write_save(payload: Dictionary, path: String = DEFAULT_PATH) -> bool:
    var document := payload.duplicate(true)
    document["version"] = SAVE_VERSION
    if not _valid_document(document):
        push_warning("Refusing invalid save payload")
        return false
    var temporary := path + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        push_warning("Could not open temporary save: %s" % FileAccess.get_open_error())
        return false
    file.store_string(JSON.stringify(document, "\t"))
    file.flush()
    file.close()
    var absolute_temp := ProjectSettings.globalize_path(temporary)
    var absolute_path := ProjectSettings.globalize_path(path)
    var error := DirAccess.rename_absolute(absolute_temp, absolute_path)
    if error != OK:
        DirAccess.remove_absolute(absolute_temp)
        push_warning("Save replacement failed: %s" % error)
        return false
    return true

static func read_save(path: String = DEFAULT_PATH) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var raw := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(raw)
    if not parsed is Dictionary:
        return {}
    var document: Dictionary = parsed
    if not _valid_document(document):
        return {}
    return document

static func _valid_document(document: Dictionary) -> bool:
    if document.get("version", -1) != SAVE_VERSION:
        return false
    if not document.has("player") or not document["player"] is Dictionary:
        return false
    var player: Dictionary = document["player"]
    for field in ["x", "y", "z", "yaw"]:
        if not player.has(field) or not (player[field] is float or player[field] is int):
            return false
        if not is_finite(float(player[field])):
            return false
    return true
