import pathlib
import tempfile
import unittest

from tools import preflight_godot_sources as preflight


class SourcePreflightTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        (self.root / "scripts").mkdir()
        (self.root / "scenes").mkdir()
        (self.root / "project.godot").write_text(
            '[application]\nrun/main_scene="res://scenes/menu.tscn"\n', encoding="utf-8"
        )
        (self.root / "scenes/menu.tscn").write_text(
            '[gd_scene format=3]\n[ext_resource type="Script" path="res://scripts/npc.gd" id="1"]\n',
            encoding="utf-8"
        )
        (self.root / "scripts/npc.gd").write_text(
            'class_name CivicTestActor\nextends Node\nconst A = preload("res://scenes/menu.tscn")\n',
            encoding="utf-8"
        )

    def test_literal_scene_and_script_references_pass(self):
        result = preflight.check_project(self.root)
        self.assertTrue(result["passed"], result["issues"])
        self.assertEqual(result["static_resources_checked"], 3)

    def test_missing_literal_script_is_reported(self):
        (self.root / "scenes/menu.tscn").write_text(
            '[ext_resource type="Script" path="res://scripts/ghost.gd" id="1"]', encoding="utf-8"
        )
        result = preflight.check_project(self.root)
        self.assertFalse(result["passed"])
        self.assertTrue(any(item["type"] == "missing_resource" for item in result["issues"]))

    def test_duplicate_global_class_is_rejected(self):
        (self.root / "scripts/other.gd").write_text('class_name CivicTestActor\nextends Node\n', encoding="utf-8")
        result = preflight.check_project(self.root)
        self.assertFalse(result["passed"])
        self.assertTrue(any(item["type"] == "duplicate_class_name" for item in result["issues"]))

    def test_dynamic_load_not_claimed_as_literal(self):
        (self.root / "scripts/npc.gd").write_text(
            'class_name CivicTestActor\nextends Node\nvar scene = load("res://" + path)\n',
            encoding="utf-8"
        )
        self.assertTrue(preflight.check_project(self.root)["passed"])

    def test_parent_reference_rejected(self):
        (self.root / "scripts/npc.gd").write_text(
            'class_name CivicTestActor\nconst A = preload("res://../outside.gd")\n',
            encoding="utf-8"
        )
        self.assertTrue(any(item["type"] == "invalid_resource_path"
                            for item in preflight.check_project(self.root)["issues"]))

    def test_missing_project_rejected(self):
        (self.root / "project.godot").unlink()
        self.assertTrue(any(item["type"] == "missing_project"
                            for item in preflight.check_project(self.root)["issues"]))


if __name__ == "__main__":
    unittest.main()
