"""CAR-ART-04E: generated Godot test UIDs must not block the clean-SHA gate.

Only tests/*.gd.uid is ignored; real test scripts, engine scripts and
other resource UIDs remain visible to git status and verification.
"""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def ignored(path: str) -> bool:
    result = subprocess.run(
        ["git", "check-ignore", "-q", "--no-index", "--", path],
        cwd=ROOT, capture_output=True, check=False, timeout=10,
    )
    if result.returncode not in (0, 1):
        raise AssertionError(f"git check-ignore failed: {result.stderr!r}")
    return result.returncode == 0


class GodotUidCleanGateTests(unittest.TestCase):
    def test_generated_car_test_sidecars_are_ignored(self):
        for name in (
            "car_art_04a_jump_clearance_test.gd.uid",
            "car_art_04a_side_contact_test.gd.uid",
            "car_art_04bc_visual_test.gd.uid",
            "car_art_04d_materials_test.gd.uid",
            "car_safe_04_checkpoint_test.gd.uid",
            "car_safe_05_backpressure_test.gd.uid",
            "future_test.gd.uid",
        ):
            with self.subTest(name=name):
                self.assertTrue(ignored(f"tests/{name}"))

    def test_source_edits_and_other_resource_uids_still_block_gate(self):
        for path in (
            "tests/car_art_04a_side_contact_test.gd",
            "tests/new_collision_test.gd",
            "scripts/player/player_controller.gd",
            "scripts/player/player_controller.gd.uid",
            "scenes/traffic/vehicle_agent.tscn",
            "docs/qa/CAR_ART_04_TRACKER.md",
        ):
            with self.subTest(path=path):
                self.assertFalse(ignored(path))


if __name__ == "__main__":
    unittest.main()
