class_name SeededRandom
extends RefCounted
## Independent deterministic RNG streams, derived from a global seed and stable agent ID.
## Never use String.hash() for persistent replay seed derivation.

var _root_seed: int
var _streams: Dictionary = {}

func _init(root_seed: int = 1) -> void:
    _root_seed = root_seed

func for_agent(agent_id: int) -> RandomNumberGenerator:
    if not _streams.has(agent_id):
        var generator := RandomNumberGenerator.new()
        generator.seed = _derive_seed(agent_id)
        _streams[agent_id] = generator
    return _streams[agent_id] as RandomNumberGenerator

func next_float(agent_id: int) -> float:
    return for_agent(agent_id).randf()

func next_int(agent_id: int, minimum: int, maximum: int) -> int:
    assert(minimum <= maximum)
    return for_agent(agent_id).randi_range(minimum, maximum)

func reset() -> void:
    _streams.clear()

func _derive_seed(agent_id: int) -> int:
    # Stable integer mixing using Godot's 64-bit integer arithmetic.
    # Constants are within signed 64-bit range.
    var value: int = _root_seed ^ (agent_id * 6364136223846793005)
    value = value ^ (value >> 33)
    value *= 1442695040888963407
    value = value ^ (value >> 29)
    return value
