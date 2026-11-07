#!/usr/bin/env python3
"""AUD-001: local source-reference checks before opening the Godot editor.

Catches missing *literal* resource references and duplicate GDScript global
class names; this does not parse or execute GDScript and cannot replace Godot.
"""
import argparse
import json
from pathlib import Path, PurePosixPath
import re

SCANNED_SUFFIXES = frozenset((".gd", ".tscn", ".tres", ".godot", ".gdshader"))
EXCLUDED_DIRS = frozenset((".godot", ".git", "build", "__pycache__"))
CLASS_NAME = re.compile(r"(?m)^\s*class_name\s+([A-Za-z_][A-Za-z_0-9]*)\b")
LITERAL_LOAD = re.compile(
    r"\b(?:preload|load|ResourceLoader\.load|ResourceLoader\.exists)\s*\(\s*"
    r"[\"'](res://[^\"']+)[\"']\s*\)"
)
RESOURCE_PATH = re.compile(r"\bpath\s*=\s*[\"'](res://[^\"']+)[\"']")
MAIN_SCENE = re.compile(r"\brun/main_scene\s*=\s*[\"'](res://[^\"']+)[\"']")


def source_files(root):
    root = Path(root)
    return sorted(path for path in root.rglob("*")
                  if path.is_file() and path.suffix in SCANNED_SUFFIXES
                  and not any(segment in EXCLUDED_DIRS for segment in path.relative_to(root).parts))


def literal_resources(path, content):
    # Full-line comments are documentation, not imports. Their examples
    # must not make an otherwise healthy project fail its preflight.
    script = "\n".join(line for line in content.splitlines()
                       if not line.lstrip().startswith("#")) if path.suffix == ".gd" else content
    found = set(LITERAL_LOAD.findall(script))
    if path.suffix in (".tscn", ".tres", ".godot"):
        found.update(RESOURCE_PATH.findall(content))
        found.update(MAIN_SCENE.findall(content))
    return sorted(found)


def check_project(root):
    root = Path(root)
    issues = []
    if not (root / "project.godot").is_file():
        issues.append({"type": "missing_project", "file": "project.godot"})
    owners = {}
    references = 0
    files = source_files(root)
    for path in files:
        relative = path.relative_to(root).as_posix()
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeError as error:
            issues.append({"type": "source_decode_error", "file": relative, "detail": str(error)})
            continue
        if path.suffix == ".gd":
            for name in CLASS_NAME.findall(content):
                owners.setdefault(name, []).append(relative)
        for reference in literal_resources(path, content):
            references += 1
            raw = reference.removeprefix("res://")
            parts = PurePosixPath(raw).parts
            if not raw or raw.startswith("/") or ".." in parts or "\\" in raw:
                issues.append({"type": "invalid_resource_path", "file": relative, "resource": reference})
                continue
            destination = root.joinpath(*parts)
            if not destination.is_file():
                issues.append({"type": "missing_resource", "file": relative, "resource": reference})
    for name, locations in sorted(owners.items()):
        if len(locations) > 1:
            issues.append({"type": "duplicate_class_name", "class_name": name, "files": locations})
    return {"passed": not issues, "source_files_checked": len(files),
            "static_resources_checked": references,
            "global_classes_checked": len(owners), "issues": issues}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path, default=Path("build/game-024-source-preflight.json"))
    args = parser.parse_args(argv)
    report = check_project(args.root)
    destination = args.report if args.report.is_absolute() else args.root / args.report
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS" if report["passed"] else "FAIL", "Godot source preflight:", destination)
    for issue in report["issues"][:20]:
        print(issue)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
