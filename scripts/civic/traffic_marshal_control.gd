class_name CivicTrafficMarshalControl
extends RefCounted
## TRAFFIC-GAME-02 safety gate. Signal/controller remains authoritative.
## The operation never moves a vehicle, releases a crossing, or overrides
## intersection occupancy; a request merely advances an already-served
## green into its normal amber -> all-red -> opposite green sequence.
static func request_axis(axis: String, signals: CivicTrafficSignalController,
        reservations: CivicIntersectionReservations,
        spawner: CivicTrafficSpawner,
        mission_cars: Array[CivicVehicleAgent] = []) -> Dictionary:
    if signals == null or spawner == null or spawner.road_graph == null:
        return {"accepted": false, "reason": "controller_unavailable"}
    var valid_directions: Array[String] = ["NS", "EW"]
    if signals.single_approach_mode:
        valid_directions = ["N", "E", "S", "W"]
    if not valid_directions.has(axis):
        return {"accepted": false, "reason": "invalid_axis"}
    var approach: String = axis if signals.single_approach_mode else ("N" if axis == "NS" else "E")
    if signals.aspect_for_approach(approach) == "green":
        return {"accepted": false, "reason": "already_green"}
    # A real pedestrian reservation cannot be cancelled by any manual
    # operation. Check BOTH occupied zones before even queuing a change.
    if reservations != null and (reservations.occupant("pedestrian_crossing_ns") >= 0 or
            reservations.occupant("pedestrian_crossing_ew") >= 0):
        return {"accepted": false, "reason": "pedestrian_in_crossing"}
    for car in spawner.active_vehicles:
        if is_instance_valid(car) and CivicCentralIntersectionPriority.occupies(car, spawner.road_graph):
            return {"accepted": false, "reason": "vehicle_in_junction"}
    for car in mission_cars:
        if is_instance_valid(car) and CivicCentralIntersectionPriority.occupies(car, spawner.road_graph):
            return {"accepted": false, "reason": "mission_vehicle_in_junction"}
    return signals.request_next_green(axis)

static func message(result: Dictionary) -> String:
    if bool(result.get("accepted", false)):
        return "Request accepted. Current green will finish, then AMBER and ALL-RED before the next axis gets green."
    match str(result.get("reason", "")):
        "pedestrian_in_crossing":
            return "WAIT | Pedestrian is still in a protected crossing."
        "vehicle_in_junction", "mission_vehicle_in_junction":
            return "WAIT | A vehicle must clear the central junction first."
        "minimum_green":
            return "WAIT | Current green must serve at least four seconds."
        "already_green":
            return "That direction already has green. Let vehicles move."
        "already_changing", "clearance_in_progress":
            return "A safe signal transition is already underway."
        "not_next_approach":
            return "That approach is not next in rotation. N, E, S, W each get a turn."
        _:
            return "Request unavailable. Check the signal status and try again."
