class_name CivicLaneData
extends Resource
## Directed lane centerline and outgoing legal connections.
## All geometry uses global world coordinates in metres.

@export var lane_id: int = -1
@export var centerline: PackedVector3Array = PackedVector3Array()
@export var next_lane_ids: PackedInt32Array = PackedInt32Array()
@export_range(0.1, 60.0, 0.1) var speed_limit_mps: float = 13.89
@export_range(0.5, 10.0, 0.1) var width_m: float = 3.2
@export_flags("Car", "Bus", "Bike", "Emergency") var allowed_vehicle_mask: int = 15
@export var parking_allowed: bool = false
@export var is_wrong_way_connector: bool = false

func length_m() -> float:
    var distance: float = 0.0
    for index in range(1, centerline.size()):
        distance += centerline[index - 1].distance_to(centerline[index])
    return distance

func is_vehicle_allowed(vehicle_mask: int) -> bool:
    return (allowed_vehicle_mask & vehicle_mask) != 0

func geometry_errors() -> PackedStringArray:
    var errors := PackedStringArray()
    if lane_id < 0:
        errors.append("lane ID must be nonnegative")
    if centerline.size() < 2:
        errors.append("centerline requires at least two points")
    else:
        for point in centerline:
            if not is_finite(point.x) or not is_finite(point.y) or not is_finite(point.z):
                errors.append("centerline contains nonfinite coordinates")
                break
        for index in range(1, centerline.size()):
            if centerline[index - 1].distance_squared_to(centerline[index]) < 0.000001:
                errors.append("centerline has duplicate consecutive points")
                break
        if length_m() <= 0.001:
            errors.append("centerline has zero length")
    if not is_finite(speed_limit_mps) or speed_limit_mps <= 0.0:
        errors.append("speed limit must be finite and positive")
    if not is_finite(width_m) or width_m <= 0.0:
        errors.append("lane width must be finite and positive")
    if allowed_vehicle_mask <= 0:
        errors.append("vehicle mask must allow at least one class")
    return errors
