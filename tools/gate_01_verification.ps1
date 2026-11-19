# GATE-01: local regression stabilization. Never invokes GitHub Actions.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\gate_01_verification.ps1
[CmdletBinding()]
param(
    [string]$Godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe",
    [string]$ExpectedBranch = "fix/aud-001-game024-gate-hardening",
    [int]$TimeoutSeconds = 120,
    [switch]$BuildApk
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $root "build\gate-01"
$reportPath = Join-Path $evidence "report.json"

# Important: a test is only passing if the process exits zero, its log
# contains an explicit PASS marker, and there are no engine errors.
$groups = [ordered]@{
    calls = @(
        "calls_01_live_feed_test.gd",
        "calls_01_accept_gps_test.gd",
        "calls_02_service_ui_test.gd",
        "calls_02_response_vehicle_test.gd",
        "calls_02b_roadside_stop_test.gd",
        "calls_02b_gridlock_recovery_test.gd"
    )
    motorcycle = @(
        "vehicle_ride_01_bike_test.gd",
        "vehicle_ride_05a_mount_and_car_clearance_test.gd",
        "vehicle_ride_05a_swept_turn_clearance_test.gd",
        "vehicle_ride_05a_safe_dismount_test.gd",
        "vehicle_ride_05b_rider_grip_binding_test.gd",
        "vehicle_ride_05c_geometry_test.gd",
        "vehicle_ride_05c_front_design_test.gd",
        "vehicle_ride_05d_character_reverse_test.gd",
        "vehicle_ride_05d_reverse_travel_test.gd",
        "vehicle_ride_05d_crash_reverse_test.gd",
        "vehicle_ride_05d_pedestrian_crash_reverse_test.gd",
        "vehicle_ride_05d_unnamed_ground_remount_test.gd",
        "vehicle_ride_05d_remount_cycle_test.gd"
    )
    city = @(
        "road_footpath_01_crossing_test.gd",
        "aud3_city_map_test.gd",
        "traffic_fix_09_single_approach_rules_test.gd",
        "traffic_fix_08_central_spillback_test.gd"
    )
    mobile = @(
        "touch_controls_test.gd",
        "touch_layout_test.gd",
        "mobile_joystick_test.gd",
        "mobile_joystick_layout_test.gd",
        "aud3_mobile_input_lifecycle_test.gd",
        "aud3_responsive_touch_recovery_test.gd"
    )
}
if ($TimeoutSeconds -lt 15) { throw "TimeoutSeconds must be at least 15." }
New-Item -ItemType Directory -Force $evidence | Out-Null
$report = [ordered]@{
    gate = "GATE-01"
    status = "failed"
    branch = ""
    commit = ""
    started_at_utc = [DateTime]::UtcNow.ToString("o")
    completed_at_utc = $null
    tests = @()
    passed = 0
    failed = 0
    android_apk = "not_requested"
    error = ""
}
function Save-Report {
    $report.completed_at_utc = [DateTime]::UtcNow.ToString("o")
    $report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $reportPath -Encoding UTF8
}
function Invoke-GateProcess {
    param([string]$Name, [string[]]$Arguments, [string]$Marker = "")
    $out = Join-Path $evidence "$Name.stdout.log"
    $err = Join-Path $evidence "$Name.stderr.log"
    # Separate streams to avoid PowerShell 5.1 interpreting Godot stderr
    # diagnostic lines as terminating NativeCommandError records.
    $process = Start-Process -FilePath $Godot -ArgumentList $Arguments `
        -WorkingDirectory $root -Wait:$false -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill() } catch { }
        $process.WaitForExit()
    }
    $output = (Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue) +
        "`n" + (Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue)
    $engineError = $output -match '(?m)^\s*(SCRIPT ERROR:|ERROR:|FATAL ERROR:)'
    $markerFound = (-not $Marker) -or ($output -match '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$')
    $ok = -not $timedOut -and $process.ExitCode -eq 0 -and
        -not $engineError -and $markerFound
    $entry = [ordered]@{
        name = $Name
        passed = $ok
        exit_code = $process.ExitCode
        timeout = $timedOut
        engine_error = $engineError
        marker_found = $markerFound
        stdout = "build/gate-01/$Name.stdout.log"
        stderr = "build/gate-01/$Name.stderr.log"
    }
    $report.tests += $entry
    if ($ok) { $report.passed++ } else { $report.failed++ }
    Save-Report
    if (-not $ok) {
        Write-Host $output
        throw "FAILED $Name (timeout=$timedOut, exit=$($process.ExitCode), marker=$markerFound). Logs in build/gate-01."
    }
    Write-Host "PASS $Name" -ForegroundColor Green
}
Push-Location $root
try {
    if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot executable not found: $Godot" }
    $branch = (& git branch --show-current | Out-String).Trim()
    $sha = (& git rev-parse HEAD | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne $ExpectedBranch -or
            $sha -notmatch '^[0-9a-f]{40}$') {
        throw "Wrong branch/commit: $branch $sha"
    }
    $report.branch = $branch
    $report.commit = $sha
    # Ignore generated reports/APK files; fail if source is modified.
    $changes = (& git status --porcelain --untracked-files=all -- . ":(exclude)build" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $changes) {
        throw "Local source tree is not clean: $changes"
    }
    foreach ($group in $groups.Keys) {
        foreach ($name in $groups[$group]) {
            if (-not (Test-Path -LiteralPath (Join-Path $root "tests\$name"))) {
                throw "Missing required $group test: tests/$name"
            }
        }
    }
    Invoke-GateProcess "import" @("--headless", "--path", ".", "--editor", "--import", "--quit")
    foreach ($group in $groups.Keys) {
        Write-Host "Running $group verification..." -ForegroundColor Cyan
        foreach ($name in $groups[$group]) {
            $stem = [System.IO.Path]::GetFileNameWithoutExtension($name)
            Invoke-GateProcess $stem @("--headless", "--path", ".", "--script", "res://tests/$name") "CIVIC_CHAOS_"

        }
    }
    if ($BuildApk) {
        $apkDir = Join-Path $root "build\android"
        New-Item -ItemType Directory -Force $apkDir | Out-Null
        $relative = "build/android/CivicChaos-GATE-01-debug.apk"
        Invoke-GateProcess "android-export" @("--headless", "--path", ".", "--export-debug", '"Android Debug"', $relative)
        $apk = Join-Path $root $relative
        if (-not (Test-Path $apk) -or (Get-Item $apk).Length -lt 1024) {
            throw "Android export did not create a usable APK"
        }
        $report.android_apk = $relative
    }
    $report.status = "passed"
    Save-Report
    Write-Host "GATE-01 PASS at commit $sha. Report: $reportPath" -ForegroundColor Green
    if (-not $BuildApk) {
        Write-Host "APK not built; Android device acceptance is still pending." -ForegroundColor Yellow
    } else {
        Write-Host "Debug APK built. On-device visual QA still pending." -ForegroundColor Yellow
    }
} catch {
    $report.status = "failed"
    $report.error = $_.Exception.Message
    Save-Report
    throw
} finally {
    Pop-Location
}
