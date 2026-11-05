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
