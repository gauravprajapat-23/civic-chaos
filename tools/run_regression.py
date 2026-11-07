#!/usr/bin/env python3
"""Strict Godot regression runner: validates exit status, PASS markers, replay and failures."""
import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/godot-validation.yml"
REPLAY = ("determinism_test.gd", "wrong_way_mission_test.gd", "traffic_budget_test.gd")
# Legacy fixture names are preserved; aliases are accepted ONLY for their
# specific test, never as proof that a different test completed.
PASS_MARKER_OVERRIDES = {
    "ai_lod_scheduler_test.gd": "CIVIC_CHAOS_AI_LOD_PASS",
    "car_following_test.gd": "CIVIC_CHAOS_FOLLOWING_PASS",
    "civic_hud_test.gd": "CIVIC_CHAOS_HUD_PASS",
    "deadlock_detector_test.gd": "CIVIC_CHAOS_DEADLOCK_PASS",
    "incident_lifecycle_test.gd": "CIVIC_CHAOS_INCIDENT_PASS",
    "intersection_reservations_test.gd": "CIVIC_CHAOS_RESERVATIONS_PASS",
    "lane_routing_test.gd": "CIVIC_CHAOS_ROUTING_PASS",
    "mission_framework_test.gd": "CIVIC_CHAOS_MISSIONS_PASS",
    "parking_capacity_test.gd": "CIVIC_CHAOS_PARKING_PASS",
    "pedestrian_navigation_test.gd": "CIVIC_CHAOS_PEDESTRIAN_PASS",
    "player_civic_interactions_test.gd": "CIVIC_CHAOS_PLAYER_INTERACTIONS_PASS",
    "player_controller_test.gd": "CIVIC_CHAOS_PLAYER_PASS",
    "signal_phases_test.gd": "CIVIC_CHAOS_SIGNAL_PASS",
    "surface_player_test.gd": "CIVIC_CHAOS_SURFACE_AND_PLAYER_PASS",
    "traffic_spawner_test.gd": "CIVIC_CHAOS_SPAWNER_PASS",
    "vehicle_agent_test.gd": "CIVIC_CHAOS_VEHICLE_PASS",
    "wrong_way_scenario_test.gd": "CIVIC_CHAOS_WRONG_WAY_PASS",
}


def expected_pass_marker(name):
    return PASS_MARKER_OVERRIDES.get(
        name, "CIVIC_CHAOS_" + name.removesuffix("_test.gd").upper() + "_PASS"
    )


def extract_pass_markers(output):
    return re.findall(r"CIVIC_CHAOS_[A-Z0-9_]+_PASS", output)


def test_passed(name, result):
    return (result["returncode"] == 0 and
            expected_pass_marker(name) in extract_pass_markers(result["output"]) and
            not has_engine_error(result["output"]))


def missing_test_files(tests, root=ROOT):
    return [name for name in tests if not (root / "tests" / name).is_file()]


def has_engine_error(output):
    """Godot errors fail a test even if it printed PASS or exited with zero."""
    return any(
        line.lstrip().startswith(("SCRIPT ERROR:", "ERROR:"))
        for line in output.splitlines()
    )


def run(godot, args, timeout):
    started = time.monotonic()
    try:
        process = subprocess.run([godot, "--headless", "--path", str(ROOT), *args],
                                 cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        return {"returncode": process.returncode, "output": process.stdout + process.stderr,
                "elapsed_seconds": round(time.monotonic() - started, 3)}
    except subprocess.TimeoutExpired as error:
        captured = error.stdout or b""
        if isinstance(captured, bytes):
            captured = captured.decode("utf-8", errors="replace")
        stderr = error.stderr or b""
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        return {"returncode": -1, "output": str(error) + "\\n" + captured + "\\n" + stderr,
                "elapsed_seconds": round(time.monotonic() - started, 3)}
    except OSError as error:
        return {"returncode": -1, "output": str(error),
                "elapsed_seconds": round(time.monotonic() - started, 3)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--report", default="build/regression-report.json")
    parser.add_argument("--timeout", type=int, default=30)
    args = parser.parse_args()
    workflow = WORKFLOW.read_text(encoding="utf-8")
    tests = list(dict.fromkeys(re.findall(r"res://tests/([\w-]+_test\.gd)", workflow)))
    tests.extend(("traffic_stop_line_test.gd", "traffic_braking_test.gd", "world_collision_test.gd", "pedestrian_collision_test.gd", "vehicle_obstacle_test.gd", "city_traffic_test.gd", "surface_player_test.gd", "player_pedestrian_contact_test.gd", "player_vehicle_contact_test.gd", "player_safe_restore_test.gd", "pedestrian_crowd_avoidance_test.gd", "pedestrian_spawn_separation_test.gd", "building_distance_lod_test.gd", "city_signal_stop_line_test.gd", "vehicle_world_obstacle_test.gd", "vehicle_spawn_occupancy_test.gd", "gameplay_session_test.gd", "two_way_lane_separation_test.gd", "pedestrian_crossing_recovery_test.gd", "gameplay_persistence_test.gd", "gameplay_incident_card_test.gd", "wrong_way_live_mission_test.gd", "wrong_way_report_post_test.gd", "authorized_tow_route_test.gd", "authorized_tow_obstacle_test.gd", "wrong_way_checkpoint_test.gd", "mission_guide_test.gd", "mission_guidance_flow_test.gd", "illegal_parking_live_test.gd", "illegal_parking_obstacle_test.gd", "parking_owner_card_test.gd", "parking_checkpoint_test.gd", "multi_incident_checkpoint_test.gd", "save_resilience_test.gd", "checkpoint_transaction_test.gd", "save_generation_consistency_test.gd", "world_traffic_checkpoint_test.gd", "world_junction_checkpoint_test.gd", "world_pedestrian_checkpoint_test.gd", "world_transaction_rollback_test.gd", "traffic_transaction_stress_test.gd", "market_cleanup_live_test.gd", "market_cleanup_checkpoint_test.gd", "market_cleanup_card_test.gd", "district_campaign_unlock_test.gd", "district_finale_ui_test.gd", "district_finale_checkpoint_test.gd", "free_roam_director_checkpoint_test.gd", "free_roam_live_events_test.gd", "free_roam_event_restart_test.gd", "free_roam_card_test.gd", "free_roam_expiry_test.gd", "free_roam_dynamic_locations_test.gd", "free_roam_npc_reactions_test.gd", "free_roam_legacy_migration_test.gd", "npc_utility_test.gd"))
    tests = list(dict.fromkeys(tests))
    # Never silently turn missing regression files into a green run.
    missing = missing_test_files(tests)
    report = {"schema_version": 1, "godot": args.godot, "tests": [],
              "expected_test_count": len(tests), "missing_tests": missing,
              "passed": False}
    destination = ROOT / args.report
    if not tests or missing:
        print("FAIL regression inventory: %s missing test(s): %s" %
              (len(missing), ", ".join(missing)), file=sys.stderr)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        return 1
    import_result = run(args.godot, ["--editor", "--import", "--quit"], args.timeout)
    report["import"] = {k: v for k, v in import_result.items() if k != "output"}
    report["import"]["output_tail"] = import_result["output"][-4000:]
    failed = import_result["returncode"] != 0 or has_engine_error(import_result["output"])
    if failed:
        print("FAIL Godot import (exit code %s)" % import_result["returncode"], file=sys.stderr)
        print(import_result["output"][-4000:], file=sys.stderr)
    if not failed:
        for name in tests:
            command = ["--script", "res://tests/" + name]
            first = run(args.godot, command, args.timeout)
            marker = expected_pass_marker(name)
            markers = extract_pass_markers(first["output"])
            engine_error = has_engine_error(first["output"])
            ok = test_passed(name, first)
            entry = {"test": name, "passed": ok, "exit_code": first["returncode"],
                     "engine_error_detected": engine_error,
                     "expected_marker": marker, "markers": markers,
                     "duration_seconds": first["elapsed_seconds"]}
            if name in REPLAY and ok:
                second = run(args.godot, command, args.timeout)
                second_markers = extract_pass_markers(second["output"])
                entry["replay_passed"] = (test_passed(name, second) and
                                          second_markers == markers)
                ok = ok and entry["replay_passed"]
                entry["passed"] = ok
            report["tests"].append(entry)
            print(("PASS" if ok else "FAIL") + " " + name, flush=True)
            if not ok:
                print(first["output"][-3000:], file=sys.stderr)
                failed = True
        negative = run(args.godot, ["--script", "res://tests/smoke_test.gd", "--", "--force-fail"], args.timeout)
        report["negative_path_passed"] = (negative["returncode"] != 0 and
                                           "CIVIC_CHAOS_INTENTIONAL_FAILURE" in negative["output"])
        failed = failed or not report["negative_path_passed"]
    report["passed"] = not failed
    # The inventory count must not shrink during the run. A subset is not a
    # completed local suite even if every remaining test prints PASS.
    if len(report["tests"]) != report["expected_test_count"]:
        failed = True
        report["passed"] = False
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Report:", destination)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
