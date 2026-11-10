import unittest
from tools.check_game024_gate import MIN_GODOT, MIN_FOCUSED, REPLAYS, STATE_PREFIX, validate


class GateReadinessTests(unittest.TestCase):
    def setUp(self):
        self.branch = "fix/aud-001-game024-gate-hardening"
        self.sha = "a" * 40
        self.gate = {
            "status": "passed", "branch": self.branch, "expected_branch": self.branch,
            "commit": self.sha, "godot_version": "4.7.2.stable.official",
            "import_passed": True, "python_runner_checks_passed": True,
            "source_preflight_passed": True, "full_regression_passed": True,
            "source_unchanged": True, "python_runner_test_count": 22,
            "focused_tests": [{"name": f"focused_{i}", "passed": True} for i in range(MIN_FOCUSED)],
            "regression_tests_run": MIN_GODOT, "regression_expected_tests": MIN_GODOT,
        }
        self.regression = {
            "passed": True, "negative_path_passed": True, "source_commit": self.sha,
            "import": {"returncode": 0}, "expected_test_count": MIN_GODOT,
            "missing_tests": [], "tests": [
                {"test": f"fixture_{i}_test.gd", "passed": True} for i in range(MIN_GODOT - len(REPLAYS))
            ] + [{"test": name, "passed": True, "replay_passed": True,
                  "replay_state": [STATE_PREFIX + "state=1"]} for name in REPLAYS],
        }

    def check(self):
        return validate(self.gate, self.regression, self.branch, self.sha)

    def test_exact_revision_with_real_state_evidence_can_pass(self):
        self.assertEqual(self.check(), [])

    def test_stale_or_wrong_branch_evidence_is_rejected(self):
        self.gate["commit"] = "b" * 40
        self.assertIn("verification_commit_mismatch", self.check())
        self.gate["commit"] = self.sha
        self.gate["branch"] = "main"
        self.assertIn("verification_branch_mismatch", self.check())

    def test_unverified_or_invalid_godot_is_rejected(self):
        self.gate["status"] = "blocked"
        self.gate["godot_version"] = "4.6.0.stable"
        issues = self.check()
        self.assertIn("verification_gate_not_passed", issues)
        self.assertIn("godot_version_not_4_7_2", issues)

    def test_partial_focused_suite_is_rejected(self):
        self.gate["focused_tests"].pop()
        self.assertIn("focused_inventory_incomplete", self.check())

    def test_full_suite_and_negative_path_are_required(self):
        self.regression["tests"].pop()
        self.regression["negative_path_passed"] = False
        issues = self.check()
        self.assertIn("full_regression_inventory_incomplete", issues)
        self.assertIn("regression_or_negative_path_failed", issues)

    def test_missing_or_forged_state_replay_is_rejected(self):
        for t in self.regression["tests"]:
            if t.get("test") == REPLAYS[0]:
                t["replay_state"] = []
        self.assertIn("replay_evidence_missing_" + REPLAYS[0], self.check())

    def test_duplicate_fixture_names_are_rejected(self):
        self.regression["tests"][0]["test"] = self.regression["tests"][1]["test"]
        self.assertIn("regression_test_missing_or_failed", self.check())

    def test_missing_python_checks_is_rejected(self):
        self.gate["python_runner_test_count"] = 21
        self.assertIn("python_checks_incomplete", self.check())


if __name__ == "__main__":
    unittest.main()
