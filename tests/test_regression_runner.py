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

    def test_source_commit_is_exact_sha(self):
        sha = "a" * 40
        good = run_regression.subprocess.CompletedProcess(
            args=["git"], returncode=0, stdout=sha + "\n", stderr=""
        )
        with patch.object(run_regression.subprocess, "run", return_value=good) as mocked:
            self.assertEqual(run_regression.source_commit(), sha)
        self.assertEqual(mocked.call_args.args[0], ["git", "rev-parse", "HEAD"])

        not_a_sha = run_regression.subprocess.CompletedProcess(
            args=["git"], returncode=0, stdout="main\n", stderr=""
        )
        with patch.object(run_regression.subprocess, "run", return_value=not_a_sha):
            self.assertEqual(run_regression.source_commit(), "")

    def test_missing_git_cannot_claim_a_verified_source_commit(self):
        for error in (FileNotFoundError("git"), run_regression.subprocess.TimeoutExpired(["git"], 10)):
            with patch.object(run_regression.subprocess, "run", side_effect=error):
                self.assertEqual(run_regression.source_commit(), "")
        failed = run_regression.subprocess.CompletedProcess(
            args=["git"], returncode=128, stdout="", stderr="not a work tree"
        )
        with patch.object(run_regression.subprocess, "run", return_value=failed):
            self.assertEqual(run_regression.source_commit(), "")

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

    def test_negative_path_rejects_timeout_and_generic_crashes(self):
        marker = "ERROR: CIVIC_CHAOS_INTENTIONAL_FAILURE"
        for code, timed_out in [(-1, True), (-1, False), (2, False), (0, False)]:
            result = {"returncode": code, "timed_out": timed_out, "output": marker}
            self.assertFalse(run_regression.negative_path_passed(result))
        self.assertFalse(run_regression.negative_path_passed(
            {"returncode": 1, "timed_out": False, "output": "unrelated failure"}
        ))
        self.assertTrue(run_regression.negative_path_passed(
            {"returncode": 1, "timed_out": False, "output": marker}
        ))

    def test_godot_log_decoder_is_utf8_with_replacement(self):
        result = run_regression.subprocess.CompletedProcess(
            args=["godot"], returncode=0, stdout="READY", stderr=""
        )
        with patch.object(run_regression.subprocess, "run", return_value=result) as call:
            output = run_regression.run("godot", ["--editor", "--quit"], 5)
        self.assertEqual(output["returncode"], 0)
        self.assertFalse(output["timed_out"])
        self.assertEqual(call.call_args.kwargs["encoding"], "utf-8")
        self.assertEqual(call.call_args.kwargs["errors"], "replace")

    def test_replay_state_extraction_ignores_unrelated_output(self):
        output = (
            "Godot Engine\n"
            "CIVIC_CHAOS_REPLAY_STATE clock=[1,2,3]\n"
            "CIVIC_CHAOS_DETERMINISM_PASS\n"
            "CIVIC_CHAOS_REPLAY_STATE rng=[0.25,0.75]\n"
        )
        self.assertEqual(
            run_regression.extract_replay_evidence(output),
            [
                "CIVIC_CHAOS_REPLAY_STATE clock=[1,2,3]",
                "CIVIC_CHAOS_REPLAY_STATE rng=[0.25,0.75]",
            ],
        )
        self.assertEqual(run_regression.extract_replay_evidence(
            "CIVIC_CHAOS_DETERMINISM_PASS\n"), [])

    def test_replay_state_must_match_even_with_identical_pass_markers(self):
        name = "determinism_test.gd"
        marker = run_regression.expected_pass_marker(name)
        first = {"returncode": 0, "output":
                 "CIVIC_CHAOS_REPLAY_STATE clock=[1,2]\n" + marker + "\n"}
        matching = {"returncode": 0, "output": first["output"]}
        divergent = {"returncode": 0, "output":
                     "CIVIC_CHAOS_REPLAY_STATE clock=[1,3]\n" + marker + "\n"}
        no_state = {"returncode": 0, "output": marker + "\n"}
        with_error = {"returncode": 0, "output":
                      first["output"] + "SCRIPT ERROR: failed\n"}
        self.assertTrue(run_regression.deterministic_replay_passed(name, first, matching))
        self.assertFalse(run_regression.deterministic_replay_passed(name, first, divergent))
        self.assertFalse(run_regression.deterministic_replay_passed(name, first, no_state))
        self.assertFalse(run_regression.deterministic_replay_passed(name, no_state, no_state))
        self.assertFalse(run_regression.deterministic_replay_passed(name, first, with_error))

    def test_command_timeout_is_failure(self):
        with patch.object(run_regression.subprocess, "run", side_effect=run_regression.subprocess.TimeoutExpired("godot", 1)):
            result = run_regression.run("godot", ["--script", "x"], 1)
        self.assertEqual(result["returncode"], -1)
        self.assertTrue(result["timed_out"])

    def test_missing_binary_is_failure(self):
        with patch.object(run_regression.subprocess, "run", side_effect=FileNotFoundError("godot")):
            result = run_regression.run("godot", ["--editor", "--quit"], 1)
        self.assertEqual(result["returncode"], -1)
        self.assertFalse(result["timed_out"])


if __name__ == "__main__":
    unittest.main()
