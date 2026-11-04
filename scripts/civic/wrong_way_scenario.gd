class_name CivicWrongWayScenario
extends RefCounted

var graph: CivicRoadGraph
var slots: CivicIntersectionReservations
var incidents: CivicIncidentManager
var connector_id: int = -1
var incident_id: int = -1
var blocked: bool = false
var queue_count: int = 0
var peak_queue: int = 0
var recovery_tick: int = -1
var last_tick: int = -1

func configure(g: CivicRoadGraph, r: CivicIntersectionReservations, i: CivicIncidentManager, source: int, illegal: int) -> bool:
    if g == null or r == null or i == null or g.get_lane(source) == null or g.has_lane(illegal):
        return false
    var lane := CivicLaneData.new()
    lane.lane_id = illegal
    lane.is_wrong_way_connector = true
    var points: PackedVector3Array = g.get_lane(source).centerline
    lane.centerline = PackedVector3Array([points[points.size() - 1], points[0]])
    if not g.add_lane(lane):
        return false
    graph = g
    slots = r
    incidents = i
    connector_id = illegal
    return true

func enter_violation(offender: int, tick: int) -> bool:
    if graph == null or offender < 0 or blocked or tick < last_tick:
        return false
    var result := incidents.create_incident("wrong_way_driving", offender, tick, str(connector_id))
    if not result["ok"]:
        return false
    incident_id = int(result["id"])
    blocked = true
    last_tick = tick
    queue_count = 0
    peak_queue = 0
    return true

func advance_to(tick: int, demand: int = 1) -> bool:
    if tick <= last_tick or demand < 0:
        return false
    last_tick = tick
    if blocked:
        queue_count += demand
        peak_queue = maxi(peak_queue, queue_count)
    else:
        queue_count = maxi(0, queue_count - maxi(demand, 1))
    return true

func intervene(tick: int) -> bool:
    if not blocked or tick < last_tick:
        return false
    if not incidents.transition(incident_id, "intervention", tick, "marshal_redirect"):
        return false
    blocked = false
    recovery_tick = tick
    last_tick = tick
    return true

func resolve(tick: int) -> bool:
    if blocked or queue_count > 0 or incident_id < 0 or tick < last_tick:
        return false
    if not incidents.transition(incident_id, "resolved", tick, "flow_restored"):
        return false
    last_tick = tick
    return true

func metrics() -> Dictionary:
    return {"blocked": blocked, "queue": queue_count, "peak_queue": peak_queue, "incident_id": incident_id, "recovery_tick": recovery_tick}
