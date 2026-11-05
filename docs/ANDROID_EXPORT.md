# Android debug build (CC-037)

Engine and export templates: Godot 4.4.1 (CI). Target ABI: arm64-v8a. Package: org.civicchaos.game. Export preset: Android Debug. The CI workflow builds and uploads an APK artifact, but it cannot verify installation or launch on physical hardware.

On Windows, install matching Godot Android export templates, JDK and Android SDK in Godot Editor Settings. Then run:

    godot --headless --path . --editor --import --quit
    godot --headless --path . --export-debug "Android Debug" build/android/civic-chaos-debug.apk
    adb install -r build/android/civic-chaos-debug.apk
    adb shell monkey -p org.civicchaos.game 1

Create build/android before exporting. Use debug signing only; do not commit keystores or passwords. Confirm real device startup, touch controls and pause/resume. No Android build has yet been verified.
