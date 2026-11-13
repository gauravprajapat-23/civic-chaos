extends SceneTree
## PERF-01 opt-in representative city profiler. Never used by the main menu.
## Run on real Android/desktop hardware for meaningful numbers.
##
## godot --path . --script res://tools/profile_city_baseline.gd -- \
##   --frames=1800 --warmup=120 --stride=5
##
## HEADLESS SMOKE IS NOT A GPU OR RELEASE-BUILD BENCHMARK.
const MainScene = preload("res://scenes/core/main.tscn")
const Capture = preload("res://scripts/core/performance_capture.gd")
const DEFAULT_FRAMES: int = 1800
const DEFAULT_WARMUP: int = 120
const DEFAULT_STRIDE: int = 5

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var options: Dictionary = _parse_args(OS.get_cmdline_user_args())
    if options.is_empty():
        _fail("invalid profile arguments")
        return
    var scene: Node3D = MainScene.instantiate() as Node3D
    if scene == null:
        _fail("main city scene could not instantiate")
        return
    root.add_child(scene)
    var junction: Node = scene.get_node_or_null("FourWayJunction")
    var pedestrians: Node = scene.get_node_or_null("DistrictPedestrians")
    if junction == null or pedestrians == null:
        _fail("live city junction or pedestrian manager missing")
        return
    var spawner: CivicTrafficSpawner = junction.get("traffic_spawner") as CivicTrafficSpawner
    if spawner == null:
        _fail("city traffic spawner missing")
        return

    pedestrians.set("profile_movement_enabled", true)
    pedestrians.call("reset_movement_profile")
    var capture: CivicPerformanceCapture = Capture.new() as CivicPerformanceCapture
    var headless: bool = DisplayServer.get_name() == "headless"
    capture.configure({
        "scenario": "civic_chaos_city_baseline",
        "source": "Godot 4.7.2 actual scene and engine monitors",
        "engine_version": Engine.get_version_info().get("string", "unknown"),
        "operating_system": OS.get_name(),
        "display_server": DisplayServer.get_name(),
        "runtime_mode": "headless_smoke_only" if headless else "windowed_cli_debug",
        "headless": headless,
        "seed": spawner.seed,
        "configured_pedestrians": pedestrians.get("pedestrian_count"),
        "configured_traffic_limit": spawner.maximum_active,
        "viewport": str(root.get_viewport().get_visible_rect().size),
        "warmup_frames": options["warmup"],
        "sampled_frames": options["frames"],
        "sample_stride": options["stride"],
        "notes": "No GPU timing; use Godot Visual Profiler and device release build to identify CPU/GPU bottleneck."
    })
    for index in range(int(options["warmup"])):
        await process_frame
    pedestrians.call("reset_movement_profile")
    var previous_us: int = Time.get_ticks_usec()
    for frame_index in range(int(options["frames"])):
        await process_frame
        var now_us: int = Time.get_ticks_usec()
        var interval_ms: float = float(now_us - previous_us) / 1000.0
        previous_us = now_us
        if frame_index % int(options["stride"]) != 0 or interval_ms <= 0.0:
            continue
        var traffic: Dictionary = spawner.metrics()
        var movement: Dictionary = pedestrians.call("movement_profile")
        var timing: Dictionary = traffic.get("timing", {})
        var observed: Dictionary = {
            "frame_interval_ms": interval_ms,
            "process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
            "physics_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
            "pedestrian_update_us": float(movement.get("average_us", 0.0)),
            "traffic_update_us": float(timing.get("average_us", 0.0)),
            "draw_calls": maxi(0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))),
            "static_memory_bytes": maxi(0, int(Performance.get_monitor(Performance.MEMORY_STATIC))),
            "cars": int(traffic.get("active", 0)),
            "walkers": int(movement.get("walkers", 0))
        }
        if not capture.add_observation(observed):
            _fail("performance observation rejected or sample limit exceeded")
            return
    if capture.count() == 0:
        _fail("no usable frame observations were recorded")
        return
    var report: Dictionary = capture.report()
    report["measurement_status"] = "headless_smoke_not_comparable" if headless else "device_measurement_requires_visual_profiler"
    report["actual_gameplay_optimization_applied"] = false
    report["traffic_totals"] = spawner.metrics()
    # A dev run must not modify an existing gameplay save; profile output
    # lives under user:// and is never used for checkpoint restore.
    var output: String = "user://civic-chaos-perf-baseline.json"
    var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
    if file == null:
        _fail("could not open user:// performance report")
        return
    file.store_string(JSON.stringify(report, "  ") + "\n")
    file.close()
    pedestrians.set("profile_movement_enabled", false)
    scene.queue_free()
    print("CIVIC_CHAOS_PERFORMANCE_PROFILE_REPORT " + ProjectSettings.globalize_path(output))
    print("CIVIC_CHAOS_PERFORMANCE_BASELINE_PASS")
    quit(0)

func _parse_args(args: PackedStringArray) -> Dictionary:
    var options: Dictionary = {
        "frames": DEFAULT_FRAMES, "warmup": DEFAULT_WARMUP,
        "stride": DEFAULT_STRIDE
    }
    for raw in args:
        var argument: String = str(raw)
        var parts: PackedStringArray = argument.split("=")
        if parts.size() != 2 or not ["--frames", "--warmup", "--stride"].has(parts[0]):
            return {}
        if not parts[1].is_valid_int():
            return {}
        var number: int = int(parts[1])
        options[parts[0].trim_prefix("--")] = number
    if options["frames"] < 30 or options["frames"] > 18000 or options["warmup"] < 0 or options["warmup"] > 3600:
        return {}
    if options["stride"] < 1 or options["stride"] > 60:
        return {}
    if int(ceil(float(options["frames"]) / float(options["stride"]))) > Capture.MAX_SAMPLES:
        return {}
    return options

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
