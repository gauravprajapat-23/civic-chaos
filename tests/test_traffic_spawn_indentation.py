"""Regression guard for tab-indented traffic spawn safety blocks.

Godot can emit SCRIPT ERROR during editor import while exiting with code 0.
Prevent the exact mixed-indentation regression before running Godot.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPAWNER = ROOT / "scripts" / "traffic" / "traffic_spawner.gd"


class TrafficSpawnerIndentationTests(unittest.TestCase):
    def test_try_spawn_body_uses_tabs_without_space_indented_statements(self):
        content = SPAWNER.read_text(encoding="utf-8")
        start = content.index("func try_spawn() -> bool:")
        end = content.index("\nfunc metrics()", start)
        block = content[start:end]
        self.assertIn("vehicle.physics_obstacle_checks_enabled = true", block)
        self.assertIn("if _spawn_occupied(vehicle):", block)
        for line_number, line in enumerate(block.splitlines(), 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            prefix = line[:len(line) - len(line.lstrip(" \t"))]
            if prefix:
                self.assertTrue(
                    prefix.startswith("\t") and " " not in prefix,
                    f"try_spawn line {line_number} uses mixed or space indentation: {line!r}",
                )

    def test_spawn_safety_is_before_active_vehicle_append(self):
        content = SPAWNER.read_text(encoding="utf-8")
        start = content.index("func try_spawn() -> bool:")
        end = content.index("\nfunc metrics()", start)
        block = content[start:end]
        self.assertLess(
            block.index("vehicle.physics_obstacle_checks_enabled = true"),
            block.index("if _spawn_occupied(vehicle):"),
        )
        self.assertLess(
            block.index("if _spawn_occupied(vehicle):"),
            block.index("active_vehicles.append(vehicle)"),
        )


if __name__ == "__main__":
    unittest.main()
