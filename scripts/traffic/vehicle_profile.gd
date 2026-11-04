class_name CivicVehicleProfile
extends Resource
## Tunable movement limits; metres, seconds, metres/second.

@export_range(0.1, 40.0, 0.1) var maximum_speed_mps: float = 8.0
@export_range(0.1, 20.0, 0.1) var acceleration_mps2: float = 3.0
@export_range(0.1, 30.0, 0.1) var braking_mps2: float = 6.0
@export_range(0.1, 20.0, 0.1) var turn_rate_radians: float = 2.5
@export_flags("Car", "Bus", "Bike", "Emergency") var vehicle_mask: int = 1

func is_valid() -> bool:
    return is_finite(maximum_speed_mps) and maximum_speed_mps > 0.0 and is_finite(acceleration_mps2) and acceleration_mps2 > 0.0 and is_finite(braking_mps2) and braking_mps2 > 0.0 and is_finite(turn_rate_radians) and turn_rate_radians > 0.0 and vehicle_mask > 0
