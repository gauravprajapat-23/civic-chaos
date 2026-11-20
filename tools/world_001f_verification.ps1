# WORLD-001F: exact-commit local Windows acceptance, no GitHub Actions.
# Run from a fresh review worktree:
# powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\world_001f_verification.ps1
[CmdletBinding()]
param(
  [string]$Godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe",
  [string]$ExpectedCommit = "",
  [int]$TimeoutSeconds = 120,
  [switch]$BuildApk
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$reportDir = Join-Path $root "build\world-001f"
$reportPath = Join-Path $reportDir "report.json"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

# The test list is deliberately explicit, to prevent a green exit from a
# partial "all tests" glob which silently skips a new milestone.
$groups = [ordered]@{
  network = @(
    "world_001a_network_compatibility_test.gd",
    "world_001b_organic_pilot_test.gd",
    "world_001c_priority_junction_test.gd",
    "world_001c_responder_yield_test.gd",
    "world_001d_neighborhood_identity_test.gd",
    "world_001e_map_parity_test.gd",
    "world_001f_save_contract_test.gd"
  )
  traffic = @(
    "outer_intersection_priority_test.gd",
    "traffic_trf_002_permission_test.gd",
    "city_signal_stop_line_test.gd",
    "traffic_fix_09_single_approach_rules_test.gd",
    "traffic_fix_08_central_spillback_test.gd",
    "traffic_trf_003_telemetry_test.gd",
    "world_junction_checkpoint_test.gd"
  )
  ui = @(
    "aud3_city_map_test.gd",
    "ui_003_safe_geometry_test.gd",
    "ui_003_modal_reflow_test.gd",
    "master_hud_004_safe_area_test.gd",
    "touch_controls_test.gd",
    "touch_layout_test.gd"
  )
  gameplay = @(
    "calls_game_002_lane_route_test.gd",
    "road_footpath_01_crossing_test.gd",
    "vehicle_ride_07_impact_contact_stress_test.gd",
    "vehicle_ride_07_sustained_grip_stability_test.gd"
  )
}
$report = [ordered]@{
  gate = "WORLD-001F"
  status = "failed"
  commit = ""
  branch = ""
  godot = $Godot
  started_at_utc = [DateTime]::UtcNow.ToString("o")
  completed_at_utc = ""
  tests = @()
  passed = 0
  failed = 0
  android_export = "not_requested"
  android_device_acceptance = "pending_manual_device"
  rendered_driving_acceptance = "pending_manual_playtest"
  error = ""
}
function Save-Report {
  $report.completed_at_utc = [DateTime]::UtcNow.ToString("o")
  $report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $reportPath -Encoding UTF8
}
function Invoke-WorldProcess {
  param([string]$Name, [string[]]$Arguments, [bool]$RequirePass = $false)
  $start = New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName = $Godot
  $start.WorkingDirectory = $root
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $start.Arguments = (($Arguments | ForEach-Object {
    '"' + $_.Replace('"', '\"') + '"'
  }) -join " ")
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $start
  $timedOut = $false
  $exitCode = $null
  $stdout = ""
  $stderr = ""
  try {
    if (-not $process.Start()) { throw "Cannot start $Name" }
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { try { $process.Kill() } catch {} }
    $process.WaitForExit()
    $stdout = $outTask.GetAwaiter().GetResult()
    $stderr = $errTask.GetAwaiter().GetResult()
    $exitCode = [int]$process.ExitCode
  } finally {
    $process.Dispose()
  }
  $stdout | Set-Content -LiteralPath (Join-Path $reportDir "$Name.stdout.log") -Encoding UTF8
  $stderr | Set-Content -LiteralPath (Join-Path $reportDir "$Name.stderr.log") -Encoding UTF8
  $merged = $stdout + "`n" + $stderr
  $marker = (-not $RequirePass) -or ($merged -match '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$')
  $engineError = $merged -match '(?m)^\s*(SCRIPT ERROR:|ERROR:|FATAL ERROR:)'
  $ok = -not $timedOut -and $exitCode -eq 0 -and $marker -and -not $engineError
  $report.tests += [ordered]@{
    test = $Name
    passed = $ok
    exit_code = $exitCode
    timed_out = $timedOut
    engine_error = $engineError
    marker_found = $marker
    stdout = "build/world-001f/$Name.stdout.log"
    stderr = "build/world-001f/$Name.stderr.log"
  }
  if ($ok) { $report.passed++ } else { $report.failed++ }
  Save-Report
  if (-not $ok) {
    Write-Host $merged
    throw "WORLD-001F failed: $Name (exit=$exitCode, timeout=$timedOut, marker=$marker)"
  }
  Write-Host "PASS $Name" -ForegroundColor Green
}
Push-Location $root
try {
  if ($TimeoutSeconds -lt 15) { throw "TimeoutSeconds must be at least 15" }
  if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot not found: $Godot" }
  $head = (& git rev-parse HEAD | Out-String).Trim()
  $branch = (& git branch --show-current | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-f]{40}$') {
    throw "Not a valid Git checkout"
  }
  if ($ExpectedCommit -and $head -ne $ExpectedCommit) {
    throw "Commit mismatch: expected $ExpectedCommit but found $head"
  }
  # Accept either detached HEAD or this named integration branch; no
  # accidental verification of main or an unrelated feature branch.
  if ($branch -ne "" -and $branch -ne "feature/world-001-organic-city") {
    throw "Wrong branch: $branch. Use a detached feature review worktree."
  }
  $report.commit = $head
  $report.branch = $branch
  $changes = (& git status --porcelain --untracked-files=all -- . ":(exclude)build" | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $changes) {
    throw "Source worktree is dirty: $changes"
  }
  foreach ($group in $groups.Keys) {
    foreach ($test in $groups[$group]) {
      if (-not (Test-Path -LiteralPath (Join-Path $root "tests\$test"))) {
        throw "Required $group test missing: $test"
      }
    }
  }
  Invoke-WorldProcess "import" @("--headless", "--path", ".", "--editor", "--import", "--quit")
  # Godot may create non-test *.gd.uid sidecars during import; don't
  # falsely report a clean accepted revision if that happens.
  $afterImport = (& git status --porcelain --untracked-files=all -- . ":(exclude)build" | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $afterImport) {
    throw "Import changed source files: $afterImport"
  }
  foreach ($group in $groups.Keys) {
    Write-Host "WORLD-001F $group..." -ForegroundColor Cyan
    foreach ($test in $groups[$group]) {
      $stem = [System.IO.Path]::GetFileNameWithoutExtension($test)
      Invoke-WorldProcess $stem @("--headless", "--path", ".", "--script", "res://tests/$test") $true
    }
  }
  if ($BuildApk) {
    $apkDir = Join-Path $root "build\android"
    New-Item -ItemType Directory -Force -Path $apkDir | Out-Null
    $relative = "build/android/CivicChaos-WORLD-001F-debug.apk"
    Invoke-WorldProcess "android-export" @("--headless", "--path", ".", "--export-debug", "Android Debug", $relative)
    $apk = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $apk) -or (Get-Item -LiteralPath $apk).Length -lt 1024) {
      throw "Android debug export produced no usable APK"
    }
    $report.android_export = $relative
  }
  $report.status = "passed"
  Save-Report
  Write-Host "WORLD-001F LOCAL REGRESSION PASS at $head" -ForegroundColor Green
  Write-Host "Report: $reportPath" -ForegroundColor Cyan
  Write-Warning "Rendered driving and Android on-device acceptance still require human checks."
} catch {
  $report.status = "failed"
  $report.error = $_.Exception.Message
  Save-Report
  throw
} finally {
  Pop-Location
}
