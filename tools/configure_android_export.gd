@tool
extends EditorScript
## Configure Android SDK location in Godot editor settings for CI export.

func _run() -> void:
    var sdk_path := OS.get_environment("ANDROID_HOME")
    if sdk_path.is_empty() or not DirAccess.dir_exists_absolute(sdk_path):
        push_error("ANDROID_HOME must point to an installed Android SDK")
        return
    var settings := EditorInterface.get_editor_settings()
    settings.set_setting("export/android/android_sdk_path", sdk_path)
    print("CIVIC_CHAOS_ANDROID_SDK_CONFIGURED")
