#!/usr/bin/env python3
"""Read-only, fail-closed handoff gate before post-AUD-001 gameplay work.

Checks the exact current Git revision against local Godot and Python evidence.
Never runs GitHub Actions, modifies game code, or manufactures a passing report.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys

REPLAYS = ("determinism_test.gd", "wrong_way_mission_test.gd", "traffic_budget_test.gd")
STATE_PREFIX = "CIVIC_CHAOS_REPLAY_STATE "
MIN_GODOT = 99
MIN_FOCUSED = 19
MIN_PYTHON = 22


def validate(gate, regression, branch, commit):
    """Return all unmet acceptance conditions, never a guessed readiness."""
    issues = []
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        issues.append("current_git_commit_unavailable")
    if gate.get("status") != "passed":
        issues.append("verification_gate_not_passed")
    if gate.get("branch") != branch or gate.get("expected_branch") != branch:
        issues.append("verification_branch_mismatch")
    if gate.get("commit") != commit or regression.get("source_commit") != commit:
        issues.append("verification_commit_mismatch")
    if not re.match(r"^4\.7\.2(?:[.\-]|$)", str(gate.get("godot_version", ""))):
        issues.append("godot_version_not_4_7_2")
    for key in (
        "import_passed", "python_runner_checks_passed", "source_preflight_passed",
        "full_regression_passed", "source_unchanged",
    ):
        if gate.get(key) is not True:
            issues.append("gate_missing_" + key)
    if gate.get("python_runner_test_count", 0) < MIN_PYTHON:
        issues.append("python_checks_incomplete")
    focused = gate.get("focused_tests", [])
    if not isinstance(focused, list) or len(focused) < MIN_FOCUSED:
        issues.append("focused_inventory_incomplete")
    elif (len({t.get("name") for t in focused if isinstance(t, dict)}) != len(focused)
          or any(not isinstance(t, dict) or t.get("passed") is not True for t in focused)):
        issues.append("focused_test_missing_or_failed")
    tests = regression.get("tests", [])
    count = regression.get("expected_test_count")
    if (not isinstance(tests, list) or len(tests) < MIN_GODOT
            or count != len(tests) or gate.get("regression_tests_run") != len(tests)
            or gate.get("regression_expected_tests") != len(tests)):
        issues.append("full_regression_inventory_incomplete")
    elif (len({t.get("test") for t in tests if isinstance(t, dict)}) != len(tests)
          or any(not isinstance(t, dict) or t.get("passed") is not True for t in tests)):
        issues.append("regression_test_missing_or_failed")
    if regression.get("passed") is not True or regression.get("negative_path_passed") is not True:
        issues.append("regression_or_negative_path_failed")
    if regression.get("missing_tests") != [] or regression.get("import", {}).get("returncode") != 0:
        issues.append("regression_missing_fixtures_or_import_failed")
    by_name = {t.get("test"): t for t in tests if isinstance(t, dict)} if isinstance(tests, list) else {}
    for name in REPLAYS:
        entry = by_name.get(name, {})
        evidence = entry.get("replay_state", [])
        if (entry.get("replay_passed") is not True or not isinstance(evidence, list)
                or not evidence or any(not isinstance(x, str) or not x.startswith(STATE_PREFIX)
                                       for x in evidence)):
            issues.append("replay_evidence_missing_" + name)
    return issues


def current_git(root):
    """Read-only local revision and worktree check; never trusts report metadata."""
    try:
        branch = subprocess.run(["git", "branch", "--show-current"], cwd=root,
                                capture_output=True, text=True, timeout=10, check=True).stdout.strip()
        commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root,
                                capture_output=True, text=True, timeout=10, check=True).stdout.strip()
        changes = subprocess.run(
            ["git", "status", "--porcelain", "--untracked-files=all", "--", ".", ":(exclude)build"],
            cwd=root, capture_output=True, text=True, timeout=10, check=True,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return "", "", "git_status_unavailable"
    return branch, commit, changes


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument("--gate", default="build/game-024-verification.json")
    parser.add_argument("--regression", default="build/game-024-regression.json")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    branch, commit, changes = current_git(root)
    issues = []
    reports = []
    for name in (args.gate, args.regression):
        try:
            p = pathlib.Path(name)
            if not p.is_absolute():
                p = root / p
            data = json.loads(p.read_text(encoding="utf-8-sig"))
            if not isinstance(data, dict):
                raise ValueError("report must be a JSON object")
            reports.append(data)
        except (OSError, ValueError, UnicodeError) as exc:
            issues.append("missing_or_invalid_report:" + name + ":" + type(exc).__name__)
    if changes:
        issues.append("worktree_not_clean_or_git_unavailable")
    if not branch:
        issues.append("git_branch_unavailable")
    if len(reports) == 2:
        issues.extend(validate(reports[0], reports[1], branch, commit))
    result = {"ready": not issues, "branch": branch, "commit": commit, "issues": issues}
    print(json.dumps(result, indent=2))
    return 0 if not issues else 1


if __name__ == "__main__":
    sys.exit(main())
