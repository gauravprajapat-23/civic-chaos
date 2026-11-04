# Godot validation CI

Issue: [CC-002](https://github.com/gauravprajapat-23/civic-chaos/issues/2)

## Workflow

`.github/workflows/godot-validation.yml` runs on pushes to `main`, feature/fix branches, pull requests targeting `main`, and manual dispatch.

Uses **Godot 4.4.1** standard Linux binary installed by `chickensoft-games/setup-godot@v2`. This is a pinned baseline; change deliberately and retest when the project adopts a newer engine.

1. Headless editor import validates project resources and parses scripts.
2. The smoke suite loads and instantiates every registered scene.
3. The negative-path check invokes the same suite with `--force-fail` and requires a nonzero exit code.
4. The startup smoke runs the main scene for three frames and requires `CIVIC_CHAOS_MAIN_READY` in output.

## Local commands

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --quit-after 3
```

For Windows PowerShell, substitute the full path to your Godot console executable.

## Merge policy

Do not close CC-002 until a GitHub Actions run on this branch passes. A deliberately failing regression should also make the workflow fail, while the negative-path check itself should pass when it detects a nonzero exit.

## Current limitation

CI validates structure and boot, not actual gameplay. Gameplay-specific tests will be added in later issues. The branch builds on CC-001; merge CC-001 before CC-002, or merge a PR that includes both changes.
