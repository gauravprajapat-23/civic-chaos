# CC-038 Regression and deterministic replay

Run `python tools/run_regression.py --godot godot` after installing Godot 4.4.1. The runner discovers the existing GDScript test commands from the validation workflow, runs a fresh editor import, checks each test for zero exit status and a CIVIC_CHAOS_*_PASS marker, repeats the deterministic clock, wrong-way mission and traffic budget tests, and injects the expected smoke-test failure. It writes JSON evidence to `build/regression-report.json`.

CI uploads the report even if the gate fails. The separate Android workflow handles APK export; this suite does **not** prove Android installation or launch. Tests that print PASS despite failing assertions can still give false positives; consider replacing assert-only checks with explicit nonzero failure handling. No clean Godot CI run has been verified.
