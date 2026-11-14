# CAR-ART-04E: fail-closed local vehicle QA and optional Android debug export.
# This script does not trigger GitHub Actions or modify tracked source.
[CmdletBinding()]
param(
    [string]$Godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe",
    [string]$ExpectedBranch = "fix/aud-001-game024-gate-hardening",
    [switch]$BuildApk
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $root "build\car-art-04e"
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$tests = @(
    "car_art_04a_jump_clearance_test.gd",
    "car_art_04a_side_contact_test.gd",
    "car_art_04e_airborne_guard_test.gd",
    "car_art_04bc_visual_test.gd",
    "car_art_04d_materials_test.gd",
    "player_vehicle_contact_test.gd",
    "vehicle_visuals_test.gd",
    "touch_controls_test.gd",
    "touch_layout_test.gd",
    "mobile_joystick_test.gd",
    "mobile_joystick_layout_test.gd",
    "aud3_mobile_input_lifecycle_test.gd",
    "vehicle_scene_contract_test.gd",
    "vehicle_actor_safety_test.gd",
    "vehicle_pedestrian_recovery_test.gd",
    "car_character_clearance_test.gd",
    "car_safe_04_checkpoint_test.gd",
    "outer_intersection_movement_test.gd",
    "traffic_checkpoint_invariants_test.gd"
)
Push-Location $root
try {
    if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot executable not found: $Godot" }
    $branch = (& git branch --show-current | Out-String).Trim()
    $sha = (& git rev-parse HEAD | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne $ExpectedBranch -or $sha -notmatch '^[0-9a-f]{40}$') {
        throw "Incorrect Git revision/branch: $branch $sha"
    }
    $changes = (& git status --porcelain --untracked-files=all -- . ":(exclude)build" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $changes) { throw "Commit all source changes before CAR-ART-04E gate: $changes" }

    function Invoke-GodotCheck([string]$label, [string[]]$argList, [string]$passMarker = "") {
        $output = & $Godot @argList 2>&1 | Out-String
        $exit = $LASTEXITCODE
        $output | Set-Content -Path (Join-Path $evidence "$label.log") -Encoding UTF8
        if ($exit -ne 0 -or $output -match '(?m)^\s*(SCRIPT ERROR:|ERROR:)' -or
            ($passMarker -and $output -notmatch [regex]::Escape($passMarker))) {
            Write-Host $output
            throw "FAILED $label (exit=$exit). Log: build/car-art-04e/$label.log"
        }
        Write-Host "PASS $label" -ForegroundColor Green
    }

    Invoke-GodotCheck "import" @("--headless", "--path", ".", "--editor", "--import", "--quit")
    foreach ($test in $tests) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($test)
        # The standard marker is required, to avoid treating a silent quit as a pass.
        # Older fixtures use different markers; require an explicit PASS suffix.
        $output = & $Godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
        $exit = $LASTEXITCODE
        $output | Set-Content -Path (Join-Path $evidence "$stem.log") -Encoding UTF8
        if ($exit -ne 0 -or $output -match '(?m)^\s*(SCRIPT ERROR:|ERROR:)' -or
            $output -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
            Write-Host $output
            throw "FAILED $test (exit=$exit). Log: build/car-art-04e/$stem.log"
        }
        Write-Host "PASS $test" -ForegroundColor Green
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\verify_game024.ps1" -Godot $Godot -ExpectedBranch $ExpectedBranch -Timeout 120
    if ($LASTEXITCODE -ne 0) { throw "Full GAME-024 verification command failed" }
    $gatePath = Join-Path $root "build\game-024-verification.json"
    if (-not (Test-Path $gatePath)) { throw "Full acceptance report was not created" }
    $gate = Get-Content $gatePath -Raw | ConvertFrom-Json
    if ($gate.status -ne "passed" -or $gate.commit -ne $sha -or
        -not $gate.full_regression_passed -or -not $gate.readiness_evidence_passed) {
        throw "GAME-024 evidence gate blocked or belongs to another SHA: $($gate.reason)"
    }
    Write-Host "CAR-ART-04E local regression gate PASSED at $sha" -ForegroundColor Green
    if ($BuildApk) {
        $apkDir = Join-Path $root "build\android"
        New-Item -ItemType Directory -Path $apkDir -Force | Out-Null
        Invoke-GodotCheck "android-export" @(
            "--headless","--path",".","--export-debug","Android Debug",
            "build/android/civic-chaos-debug.apk"
        )
        $apk = Join-Path $apkDir "civic-chaos-debug.apk"
        if (-not (Test-Path $apk)) { throw "APK was not produced despite export exit code 0" }
        Get-Item $apk | Select-Object FullName, Length, LastWriteTime
        Write-Host "APK built for manual Android QA; device acceptance NOT yet complete." -ForegroundColor Yellow
    }
} finally {
    Pop-Location
}
