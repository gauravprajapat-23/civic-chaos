# GAME-024 local acceptance gate. No GitHub Actions are invoked.
[CmdletBinding()]
param(
    [string]$Godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Python = "python",
    [int]$Timeout = 120,
    [string]$ExpectedBranch = "feat/game-024-dynamic-free-roam",
    [int]$MinimumTestCount = 104
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$gatePath = Join-Path $root "build\game-024-verification.json"
$logs = Join-Path $root "build\game-024-verification-logs"
New-Item -ItemType Directory -Path $logs -Force | Out-Null

$gate = [ordered]@{
    milestone = "GAME-024"
    status = "blocked"
    verified_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    expected_branch = $ExpectedBranch
    branch = ""
    commit = ""
    godot_version = ""
    import_passed = $false
    python_runner_checks_passed = $false
    python_runner_test_count = 0
    source_preflight_passed = $false
    source_files_checked = 0
    static_resources_checked = 0
    focused_tests = @()
    full_regression_passed = $false
    full_regression_timed_out = $false
    full_regression_exit_code = -1
    regression_tests_run = 0
    regression_expected_tests = 0
    regression_source_commit = ""
    source_unchanged = $false
    readiness_evidence_passed = $false
    regression_report = "build/game-024-regression.json"
    reason = ""
}

function Write-Gate {
    $gate | ConvertTo-Json -Depth 12 | Set-Content -Path $gatePath -Encoding UTF8
    Write-Host ("Verification report: " + $gatePath)
    Write-Host ("GAME-024 gate: " + $gate.status)
}

function Get-SourceChanges {
    # build/ contains generated reports and Godot export artifacts.
    # Everything else (including newly added but untracked test scripts)
    # is source until committed. A clean SHA must cover *all* test code.
    $changes = (& git status --porcelain --untracked-files=all -- . ":(exclude)build" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Git source status check failed"
    }
    return $changes
}

function Run-Local {
    param(
        [string[]]$Arguments,
        [string]$LogName,
        [string]$Executable = $Godot,
        [int]$ProcessTimeoutSeconds = $Timeout
    )
    # Redirect streams to files so verbose or hung fixtures cannot deadlock.
    $stdoutPath = Join-Path $logs ($LogName + ".stdout")
    $stderrPath = Join-Path $logs ($LogName + ".stderr")
    $exitCode = -1
    $timedOut = $false
    $output = ""
    try {
        $quotedArguments = @($Arguments | ForEach-Object {
            if ($_ -match '\s') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
        })
        $process = Start-Process -FilePath $Executable -ArgumentList $quotedArguments -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        if (-not $process.WaitForExit($ProcessTimeoutSeconds * 1000)) {
            $timedOut = $true
            # On Windows, terminate the complete Python -> Godot process
            # tree, not only the Python parent, before collecting logs.
            try {
                $killer = Start-Process -FilePath "taskkill.exe" -ArgumentList @(
                    "/PID", [string]$process.Id, "/T", "/F"
                ) -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $logs ($LogName + ".kill.stdout")) -RedirectStandardError (Join-Path $logs ($LogName + ".kill.stderr"))
                $killer.WaitForExit(10000) | Out-Null
            } catch {
                # A process can disappear between timeout and taskkill.
            }
            if (-not $process.HasExited) {
                try { $process.Kill() } catch { }
            }
            $process.WaitForExit(10000) | Out-Null
        } else {
            $exitCode = $process.ExitCode
        }
    } catch {
        $output = ($_ | Out-String)
    }
    if (Test-Path -LiteralPath $stdoutPath) {
        $output += Get-Content -LiteralPath $stdoutPath -Raw
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $output += Get-Content -LiteralPath $stderrPath -Raw
    }
    if ($timedOut) {
        $output += [Environment]::NewLine + "GAME-024 TEST TIMEOUT after $ProcessTimeoutSeconds seconds"
    }
    $output | Set-Content -Path (Join-Path $logs $LogName) -Encoding UTF8
    $hasEngineError = $output -match '(?m)^\s*(SCRIPT ERROR:|ERROR:)'
    return @{
        exit_code = $exitCode
        timed_out = $timedOut
        engine_error = [bool]$hasEngineError
        output = $output
        passed = ($exitCode -eq 0 -and -not $hasEngineError -and -not $timedOut)
    }
}

Push-Location $root
try {
    # Immediately replace any previously passing gate report with a pending
    # status. A crash during a fresh run cannot leave stale success visible.
    Write-Gate
    $gate.branch = (& git branch --show-current | Out-String).Trim()
    $gate.commit = (& git rev-parse HEAD | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $gate.commit -notmatch '^[0-9a-f]{40}$') {
        $gate.reason = "Cannot resolve a Git commit for the local project."
        Write-Gate
        exit 1
    }
    if ($MinimumTestCount -lt 104 -or $Timeout -lt 1) {
        $gate.reason = "Unsafe acceptance configuration: require at least 104 tests and a positive timeout."
        Write-Gate
        exit 1
    }
    $sourceChanges = Get-SourceChanges
    if (-not [string]::IsNullOrWhiteSpace($sourceChanges)) {
        $gate.reason = "Uncommitted tracked or untracked source changes: commit or stash before acceptance."
        Write-Gate
        exit 1
    }
    if ($gate.branch -ne $gate.expected_branch) {
        $gate.reason = "Switch to the GAME-024 branch before verification."
        Write-Gate
        exit 1
    }
    if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
        $gate.reason = "Godot executable not found: " + $Godot
        Write-Gate
        exit 1
    }
    # Windows PowerShell 5.1 Start-Process -PassThru can return a process
    # object without a usable ExitCode even when the executable exits 0.
    # Version probing is fast and does not need the timed subprocess wrapper.
    # Use direct native invocation and its authoritative LASTEXITCODE instead;
    # still reject any failed launch, engine error, or wrong Godot version.
    $versionOutput = ""
    $versionExitCode = -1
    try {
        $versionOutput = (& $Godot --version 2>&1 | Out-String)
        $versionExitCode = $LASTEXITCODE
    } catch {
        $versionOutput = ($_ | Out-String)
    }
    $versionOutput | Set-Content -Path (Join-Path $logs "godot-version.log") -Encoding UTF8
    $gate.godot_version = ($versionOutput.Trim() -split "\r?\n")[0]
    if ($versionExitCode -ne 0 -or $versionOutput -match '(?m)^\s*(SCRIPT ERROR:|ERROR:)') {
        $gate.reason = ("Godot version probe failed: exit_code={0}; output={1}; " +
            "inspect build/game-024-verification-logs/godot-version.log") -f `
            $versionExitCode, $gate.godot_version
        Write-Gate
        exit 1
    }
    if ($gate.godot_version -notmatch '^4\.7\.2([\.-]|$)') {
        $gate.reason = "GAME-024 requires Godot 4.7.2; found " + $gate.godot_version
        Write-Gate
        exit 1
    }

    # Validate the QA harness itself before trusting its Godot pass/fail.
    # unittest writes progress to stderr even on success; redirected streams
    # keep PowerShell 5.1 ErrorActionPreference from treating that as a throw.
    $pythonCheck = Run-Local -Executable $Python -Arguments @(
        "-m", "unittest", "discover", "-s", "tests", "-p",
        "test_*.py", "-v"
    ) -LogName "python-runner-tests.log"
    $ranPattern = [regex]::Match($pythonCheck.output, '(?m)^Ran\s+(\d+)\s+tests?\s+in\s+')
    if ($ranPattern.Success) {
        $gate.python_runner_test_count = [int]$ranPattern.Groups[1].Value
    }
    $gate.python_runner_checks_passed = $pythonCheck.passed -and $gate.python_runner_test_count -ge 30
    if (-not $gate.python_runner_checks_passed) {
        $gate.reason = "Python regression and resource-preflight unit tests failed; inspect python-runner-tests.log"
        Write-Gate
        exit 1
    }

    # Static preflight catches missing literal scene/preload paths and
    # duplicate global class names before Godot's expensive import.
    $sourceCheck = Run-Local -Executable $Python -Arguments @(
        "tools/preflight_godot_sources.py", "--report", "build/game-024-source-preflight.json"
    ) -LogName "source-preflight.log"
    $sourceReportPath = Join-Path $root "build\game-024-source-preflight.json"
    if ($sourceCheck.passed -and (Test-Path -LiteralPath $sourceReportPath)) {
        $sourceReport = Get-Content -LiteralPath $sourceReportPath -Raw | ConvertFrom-Json
        $gate.source_files_checked = [int]$sourceReport.source_files_checked
        $gate.static_resources_checked = [int]$sourceReport.static_resources_checked
        $gate.source_preflight_passed = (
            [bool]$sourceReport.passed -and
            @($sourceReport.issues).Count -eq 0 -and
            $gate.source_files_checked -gt 0 -and
            $gate.static_resources_checked -gt 0
        )
    }
    if (-not $gate.source_preflight_passed) {
        $gate.reason = "Source-reference preflight failed; inspect build/game-024-source-preflight.json and source-preflight.log"
        Write-Gate
        exit 1
    }

    $import = Run-Local -Arguments @("--headless", "--path", $root, "--editor", "--import", "--quit") -LogName "godot-import.log"
    $gate.import_passed = $import.passed
    if (-not $import.passed) {
        $gate.reason = "Godot import failed. Review build/game-024-verification-logs/godot-import.log"
        Write-Gate
        exit 1
    }

    $tests = @(
        "free_roam_director_checkpoint_test.gd",
        "free_roam_dynamic_locations_test.gd",
        "free_roam_npc_reactions_test.gd",
        "vehicle_scene_contract_test.gd",
        "vehicle_feedback_optional_test.gd",
        "traffic_checkpoint_invariants_test.gd",
        "traffic_reconfigure_atomicity_test.gd",
        "checkpoint_record_shapes_test.gd",
        "checkpoint_load_queue_test.gd",
        "checkpoint_orphaned_records_test.gd",
        "player_checkpoint_atomicity_test.gd",
        "npc_personality_contract_test.gd",
        "npc_utility_test.gd",
        "npc_decision_stability_test.gd",
        "touch_layout_test.gd",
        "performance_capture_test.gd",
        "city_road_alignment_test.gd",
        "outer_intersection_priority_test.gd",
        "free_roam_legacy_migration_test.gd",
        "free_roam_card_test.gd",
        "free_roam_live_events_test.gd",
        "free_roam_event_restart_test.gd",
        "free_roam_expiry_test.gd",
        "district_finale_checkpoint_test.gd"
    )
    foreach ($name in $tests) {
        $result = Run-Local -Arguments @("--headless", "--path", $root, "--script", ("res://tests/" + $name)) -LogName ($name + ".log")
        $marker = "CIVIC_CHAOS_" + $name.Replace("_test.gd", "").ToUpperInvariant() + "_PASS"
        $markerPresent = $result.output.Contains($marker)
        $pass = $result.passed -and $markerPresent
        $gate.focused_tests += [ordered]@{
            name = $name
            passed = $pass
            exit_code = $result.exit_code
            engine_error = $result.engine_error
            timed_out = $result.timed_out
            pass_marker = $markerPresent
        }
        Write-Host ("{0} {1}" -f $(if ($pass) { "PASS" } else { "FAIL" }), $name)
        if (-not $pass) {
            $gate.reason = "Focused test failed: " + $name + ". See build/game-024-verification-logs/"
            Write-Gate
            exit 1
        }
    }

    # The strict Python suite owns replay and negative-path verification.
    # Never pipe native stderr through PowerShell 5.1 with
    # ErrorActionPreference=Stop: one failing fixture can throw before its
    # diagnostic stdout/stderr and JSON report are processed.
    # Each Godot fixture has its own timeout; this is a separate bounded
    # deadline for the *whole* runner, including import and replay.
    $suiteTimeout = [int][Math]::Min(14400, [Math]::Max(300,
        ([double]($MinimumTestCount + 6) * [double]($Timeout + 5))))
    $fullResult = Run-Local -Executable $Python -Arguments @(
        "tools/run_regression.py", "--godot", $Godot, "--timeout",
        [string]$Timeout, "--report", "build/game-024-regression.json"
    ) -LogName "full-regression.log" -ProcessTimeoutSeconds $suiteTimeout
    $gate.full_regression_timed_out = $fullResult.timed_out
    $gate.full_regression_exit_code = $fullResult.exit_code
    $fullPath = Join-Path $root "build\game-024-regression.json"
    if ($fullResult.passed -and (Test-Path -LiteralPath $fullPath)) {
        $regression = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json
        $gate.regression_tests_run = @($regression.tests).Count
        $gate.regression_expected_tests = [int]$regression.expected_test_count
        $gate.regression_source_commit = [string]$regression.source_commit
        $allTestsPassed = @($regression.tests | Where-Object { -not $_.passed }).Count -eq 0
        $gate.full_regression_passed = (
            [bool]$regression.passed -and
            ($gate.regression_source_commit -eq $gate.commit) -and
            [bool]$regression.negative_path_passed -and
            ($regression.import.returncode -eq 0) -and
            (@($regression.missing_tests).Count -eq 0) -and
            $allTestsPassed -and
            ($gate.regression_tests_run -ge $MinimumTestCount) -and
            ($gate.regression_tests_run -eq $gate.regression_expected_tests)
        )
    }
    if (-not $gate.full_regression_passed) {
        $gate.reason = "Full local regression failed (exit $($gate.full_regression_exit_code), timeout $($gate.full_regression_timed_out), report SHA $($gate.regression_source_commit)). Inspect build/game-024-regression.json and build/game-024-verification-logs/full-regression.log"
        Write-Gate
        exit 1
    }
    $currentCommit = (& git rev-parse HEAD | Out-String).Trim()
    $sourceChanges = Get-SourceChanges
    $gate.source_unchanged = ($currentCommit -eq $gate.commit -and
        [string]::IsNullOrWhiteSpace($sourceChanges))
    if (-not $gate.source_unchanged) {
        $gate.reason = "Source commit or tracked files changed during verification."
        Write-Gate
        exit 1
    }
    # Mark provisional success for the independent, read-only readiness
    # checker, which rejects stale SHA, missing state replays, or incomplete
    # focused/full results. A failed checker immediately restores BLOCKED.
    $gate.status = "passed"
    $gate.reason = "Exact source revision passed import, focused tests, full suite and negative-path checks."
    Write-Gate
    $readiness = Run-Local -Executable $Python -Arguments @(
        "tools/check_game024_gate.py"
    ) -LogName "postgate-evidence.log"
    if (-not $readiness.passed) {
        $gate.status = "blocked"
        $gate.reason = "Independent evidence validation failed. Inspect build/game-024-verification-logs/postgate-evidence.log"
        Write-Gate
        exit 1
    }
    $gate.readiness_evidence_passed = $true
    Write-Gate
    exit 0
} catch {
    $gate.status = "blocked"
    $gate.reason = $_.Exception.Message
    Write-Gate
    exit 1
} finally {
    Pop-Location
}
