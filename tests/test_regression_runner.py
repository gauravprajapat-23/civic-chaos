import pathlib
import tempfile
import unittest
from unittest.mock import patch

from tools import run_regression


class RegressionRunnerTests(unittest.TestCase):
    def test_workflow_discovers_tests(self):
        workflow = run_regression.WORKFLOW.read_text(encoding="utf-8")
        import re
        names = set(re.findall(r"res://tests/([\w-]+_test\.gd)", workflow))
        self.assertIn("determinism_test.gd", names)
        self.assertIn("traffic_budget_test.gd", names)
        self.assertGreaterEqual(len(names), 30)

    def test_marker_must_belong_to_executed_test(self):
        wrong_marker = {"returncode": 0, "output": "CIVIC_CHAOS_FREE_ROAM_CARD_PASS\n"}
        self.assertFalse(run_regression.test_passed("free_roam_live_events_test.gd", wrong_marker))
        self.assertTrue(run_regression.test_passed("free_roam_card_test.gd", wrong_marker))

    def test_legacy_alias_is_specific_to_its_fixture(self):
        legacy = {"returncode": 0, "output": "CIVIC_CHAOS_AI_LOD_PASS\n"}
        self.assertTrue(run_regression.test_passed("ai_lod_scheduler_test.gd", legacy))
        self.assertFalse(run_regression.test_passed("vehicle_agent_test.gd", legacy))

    def test_script_errors_or_nonzero_exit_never_pass(self):
        failed = {"returncode": 1, "output": "CIVIC_CHAOS_FREE_ROAM_CARD_PASS\n"}
        self.assertFalse(run_regression.test_passed("free_roam_card_test.gd", failed))
        failed = {"returncode": 0, "output": "CIVIC_CHAOS_FREE_ROAM_CARD_PASS\nSCRIPT ERROR: parse error"}
        self.assertFalse(run_regression.test_passed("free_roam_card_test.gd", failed))

    def test_missing_registered_file_is_fatal(self):
        with tempfile.TemporaryDirectory() as folder:
            root = pathlib.Path(folder)
            (root / "tests").mkdir()
            (root / "tests" / "exists_test.gd").write_text("extends SceneTree\n", encoding="utf-8")
            self.assertEqual(
                run_regression.missing_test_files(["exists_test.gd", "missing_test.gd"], root),
                ["missing_test.gd"]
            )

    def test_discover_runs_new_fixtures_without_losing_required_ones(self):
        with tempfile.TemporaryDirectory() as folder:
            root = pathlib.Path(folder)
            (root / "tests").mkdir()
            (root / "tests" / "new_collision_test.gd").write_text("extends SceneTree\n", encoding="utf-8")
            inventory = run_regression.discover_test_files(
                ["required_test.gd", "required_test.gd"], root
            )
            self.assertEqual(inventory, ["required_test.gd", "new_collision_test.gd"])
            self.assertEqual(
                run_regression.missing_test_files(inventory, root), ["required_test.gd"]
            )

    def test_godot_error_lines_fail_even_after_expected_marker(self):
        marker = run_regression.expected_pass_marker("free_roam_card_test.gd")
        for message in ("ERROR: Invalid shape", "  SCRIPT ERROR: Parse failed"):
            result = {"returncode": 0, "output": marker + "\n" + message + "\n"}
            self.assertFalse(run_regression.test_passed("free_roam_card_test.gd", result))

    def test_command_timeout_is_failure(self):
        with patch.object(run_regression.subprocess, "run", side_effect=run_regression.subprocess.TimeoutExpired("godot", 1)):
            result = run_regression.run("godot", ["--script", "x"], 1)
        self.assertEqual(result["returncode"], -1)

    def test_missing_binary_is_failure(self):
        with patch.object(run_regression.subprocess, "run", side_effect=FileNotFoundError("godot")):
            result = run_regression.run("godot", ["--editor", "--quit"], 1)
        self.assertEqual(result["returncode"], -1)


if __name__ == "__main__":
    unittest.main()
