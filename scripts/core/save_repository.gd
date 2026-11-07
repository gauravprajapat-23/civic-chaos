class_name CivicSaveRepository
extends RefCounted
## GAME-018: verified, recoverable local save generations; no executable JSON.
## Existing flat version-1 documents remain readable, but new writes are v2.

const SAVE_VERSION: int = 2
const LEGACY_VERSION: int = 1
const DEFAULT_PATH: String = "user://civic_chaos_save.json"

## A save is only promoted after the temporary generation is parsed and
## verified. The last valid primary is copied through a separately verified
## backup staging file before replacement.
static func write_save(payload: Dictionary, path: String = DEFAULT_PATH) -> bool:
    if payload.has("version") or payload.has("checksum") or not _valid_player(payload):
        return false
    var document: Dictionary = payload.duplicate(true)
    document["version"] = SAVE_VERSION
    document["checksum"] = _checksum(document)
    if not _valid_document(document):
        return false
    var temporary: String = path + ".tmp"
    var backup_stage: String = path + ".bak.tmp"
    var backup: String = path + ".bak"
    var temp_path: String = ProjectSettings.globalize_path(temporary)
    var primary_path: String = ProjectSettings.globalize_path(path)
    var backup_stage_path: String = ProjectSettings.globalize_path(backup_stage)
    var backup_path: String = ProjectSettings.globalize_path(backup)
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(document, "\t"))
    file.flush()
    file.close()
    if _read_one(temporary).is_empty():
        DirAccess.remove_absolute(temp_path)
        return false
    if FileAccess.file_exists(path) and not _read_one(path).is_empty():
        # Do not overwrite a valid backup with a corrupted main document.
        if DirAccess.copy_absolute(primary_path, backup_stage_path) != OK:
            DirAccess.remove_absolute(temp_path)
            return false
        if _read_one(backup_stage).is_empty():
            DirAccess.remove_absolute(backup_stage_path)
            DirAccess.remove_absolute(temp_path)
            return false
        if DirAccess.rename_absolute(backup_stage_path, backup_path) != OK:
            DirAccess.remove_absolute(backup_stage_path)
            DirAccess.remove_absolute(temp_path)
            return false
    if DirAccess.rename_absolute(temp_path, primary_path) != OK:
        DirAccess.remove_absolute(temp_path)
        return false
    return true

## Never use .tmp as a recovery source: it may represent an interrupted,
## uncommitted write. Primary always wins; backup is last known good.
static func read_save(path: String = DEFAULT_PATH) -> Dictionary:
    return read_save_detail(path).get("data", {})

static func read_save_detail(path: String = DEFAULT_PATH) -> Dictionary:
    var primary: Dictionary = _read_one(path)
    if not primary.is_empty():
        return {"ok": true, "source": "primary", "data": primary}
    var backup: Dictionary = _read_one(path + ".bak")
    if not backup.is_empty():
        return {"ok": true, "source": "backup", "data": backup}
    return {"ok": false, "source": "none", "data": {}}

static func _read_one(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var raw: String = file.get_as_text()
    file.close()
    var parser := JSON.new()
    if parser.parse(raw) != OK or not (parser.data is Dictionary):
        return {}
    var document: Dictionary = parser.data
    if not _valid_document(document):
        return {}
    return document

static func _checksum(document: Dictionary) -> String:
    var unsigned: Dictionary = document.duplicate(true)
    unsigned.erase("checksum")
    return JSON.stringify(unsigned, "", true).sha256_text()

static func _valid_player(document: Dictionary) -> bool:
    if not (document.get("player") is Dictionary):
        return false
    var player: Dictionary = document["player"]
    for field in ["x", "y", "z", "yaw"]:
        if not (player.get(field) is int or player.get(field) is float):
            return false
        if not is_finite(float(player[field])):
            return false
    return true

static func _valid_document(document: Dictionary) -> bool:
    if not _valid_player(document):
        return false
    var version: Variant = document.get("version")
    if not (version is int or version is float):
        return false
    if not is_finite(float(version)) or float(version) != floorf(float(version)):
        return false
    if int(version) == LEGACY_VERSION:
        # Legacy saves had no checksum. Never downgrade v2 integrity by
        # treating an incorrectly signed v2 document as a legacy save.
        return not document.has("checksum")
    if int(version) != SAVE_VERSION:
        return false
    var claimed: Variant = document.get("checksum")
    if not (claimed is String) or str(claimed).length() != 64:
        return false
    return str(claimed) == _checksum(document)
