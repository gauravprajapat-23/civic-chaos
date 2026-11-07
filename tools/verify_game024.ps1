# GAME-024 local acceptance gate. No GitHub Actions are invoked.
[CmdletBinding()]
param(
    [string]$Godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Python = "python",
    [int]$Timeout = 120
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
    expected_branch = "feat/game-024-dynamic-free-roam"
    branch = ""
    commit = ""
    godot_version = ""
    import_passed = $false
    focused_tests = @()
    full_regression_passed = $false
    regression_report = "build/game-024-regression.json"
    reason = ""
}

function Write-Gate {
    $gate | ConvertTo-Json -Depth 12 | Set-Content -Path $gatePath -Encoding UTF8
    Write-Host ("Verification report: " + $gatePath)
    Write-Host ("GAME-024 gate: " + $gate.status)
}

function Run-Local {
    param([string[]]$Arguments, [string]$LogName)
    $exitCode = -1
    $output = ""
    try {
        $output = (& $Godot @Arguments 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    } catch {
        $output = ($_ | Out-String)
    }
    $output | Set-Content -Path (Join-Path $logs $LogName) -Encoding UTF8
    $hasEngineError = $output -match '(?m)^\s*(SCRIPT ERROR:|ERROR:)'
    return @{
        exit_code = $exitCode
        engine_error = [bool]$hasEngineError
        output = $output
        passed = ($exitCode -eq 0 -and -not $hasEngineError)
    }
}

Push-Location $root
try {
    $gate.branch = (& git branch --show-current | Out-String).Trim()
    $gate.commit = (& git rev-parse HEAD | Out-String).Trim()
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
    $versionResult = Run-Local -Arguments @("--version") -LogName "godot-version.log"
    $gate.godot_version = ($versionResult.output.Trim() -split "\r?\n")[0]
    if (-not $versionResult.passed -or $gate.godot_version -notmatch '^4\.7\.2([\.-]|$)') {
        $gate.reason = "GAME-024 requires Godot 4.7.2; found " + $gate.godot_version
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
    $pythonOutput = (& $Python "tools/run_regression.py" "--godot" $Godot "--timeout" "$Timeout" "--report" "build/game-024-regression.json" 2>&1 | Out-String)
    $pythonExit = $LASTEXITCODE
    $pythonOutput | Set-Content -Path (Join-Path $logs "full-regression.log") -Encoding UTF8
    $fullPath = Join-Path $root "build\game-024-regression.json"
    if ($pythonExit -eq 0 -and (Test-Path -LiteralPath $fullPath)) {
        $regression = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json
        $gate.full_regression_passed = [bool]$regression.passed
    }
    if (-not $gate.full_regression_passed) {
        $gate.reason = "Full local regression failed. Inspect build/game-024-regression.json and full-regression.log"
        Write-Gate
        exit 1
    }
    $gate.status = "passed"
    $gate.reason = "Godot import, focused tests, strict full regression and negative-path gate passed."
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
