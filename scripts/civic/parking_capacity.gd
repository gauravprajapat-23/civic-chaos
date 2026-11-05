class_name CivicParkingCapacity
extends RefCounted
## Deterministic lane-capacity and queue model for illegal parking.

var incidents: CivicIncidentManager
var lanes: Dictionary = {}
var tick_index: int = -1

func configure(manager: CivicIncidentManager) -> bool:
    if manager == null:
        return false
    incidents = manager
    return true

func register_lane(lane_id: int, capacity_per_tick: int) -> bool:
    if lane_id < 0 or capacity_per_tick <= 0 or lanes.has(lane_id):
        return false
    lanes[lane_id] = {"base_capacity": capacity_per_tick, "blocked_fraction": 0.0, "queue": 0, "served": 0, "arrived": 0, "incident_id": -1}
    return true

func park_illegally(lane_id: int, offender_id: int, fraction: float, tick: int) -> bool:
    if not lanes.has(lane_id) or offender_id < 0 or not is_finite(fraction) or fraction <= 0.0 or fraction > 1.0 or tick < tick_index:
        return false
    var lane: Dictionary = lanes[lane_id]
    if lane["blocked_fraction"] > 0.0:
        return false
    var result := incidents.create_incident("illegal_parking", offender_id, tick, str(lane_id))
    if not result["ok"]:
        return false
    lane["blocked_fraction"] = fraction
    lane["incident_id"] = int(result["id"])
    lanes[lane_id] = lane
    tick_index = tick
    return true

func remove_obstruction(lane_id: int, tick: int) -> bool:
    if not lanes.has(lane_id) or tick < tick_index:
        return false
    var lane: Dictionary = lanes[lane_id]
    if lane["blocked_fraction"] <= 0.0:
        return false
    if not incidents.transition(int(lane["incident_id"]), "intervention", tick, "vehicle_removed"):
        return false
    lane["blocked_fraction"] = 0.0
    lanes[lane_id] = lane
    tick_index = tick
    return true

func advance_to(tick: int, demand: Dictionary) -> bool:
    if tick <= tick_index:
        return false
    for key in demand.keys():
        if not lanes.has(key) or not (demand[key] is int) or int(demand[key]) < 0:
            return false
    for id in lanes.keys():
        var lane: Dictionary = lanes[id]
        var incoming: int = int(demand.get(id, 0))
        var available: int = int(floor(float(lane["base_capacity"]) * (1.0 - float(lane["blocked_fraction"]))))
        var waiting: int = int(lane["queue"]) + incoming
        var served: int = mini(waiting, available)
        lane["queue"] = waiting - served
        lane["arrived"] = int(lane["arrived"]) + incoming
        lane["served"] = int(lane["served"]) + served
        lanes[id] = lane
    tick_index = tick
    return true

func resolve(lane_id: int, tick: int) -> bool:
    if not lanes.has(lane_id) or tick < tick_index:
        return false
    var lane: Dictionary = lanes[lane_id]
    if lane["blocked_fraction"] > 0.0 or lane["queue"] > 0 or int(lane["incident_id"]) < 0:
        return false
    return incidents.transition(int(lane["incident_id"]), "resolved", tick, "lane_capacity_restored")

func lane_metrics(lane_id: int) -> Dictionary:
    if not lanes.has(lane_id):
        return {}
    return (lanes[lane_id] as Dictionary).duplicate(true)
