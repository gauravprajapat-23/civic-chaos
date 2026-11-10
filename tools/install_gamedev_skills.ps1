# Local, read-only reference installer for the uploaded gamedev skill pack.
# Does not execute third-party scripts, modify Godot scenes or dispatch CI.
param(
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) ".agent-skills")
)
$ErrorActionPreference = "Stop"

$archive = (Resolve-Path -LiteralPath $ZipPath -ErrorAction Stop).Path
$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("civic-skills-" + [guid]::NewGuid().ToString("N"))
$skillFolders = @(
    "router",
    "skills/godot/godot-gdscript",
    "skills/godot/godot-nodes-scenes",
    "skills/godot/godot-3d-essentials",
    "skills/godot/godot-gdscript-headless-testing",
    "skills/godot/godot-physics",
    "skills/godot/godot-resources",
    "skills/godot/godot-ui-control",
    "skills/disciplines/physics-tuning",
    "skills/disciplines/ai-behavior-trees-utility-ai",
    "skills/disciplines/game-ai",
    "skills/disciplines/save-systems",
    "skills/disciplines/game-ui-ux",
    "skills/disciplines/input-systems",
    "skills/disciplines/performance-optimization",
    "skills/disciplines/game-feel",
    "skills/disciplines/audio-design",
    "skills/disciplines/camera-systems"
)

try {
    Expand-Archive -LiteralPath $archive -DestinationPath $temporary -Force
    $source = Join-Path $temporary "awesome-gamedev-agent-skills-main"
    if (-not (Test-Path -LiteralPath (Join-Path $source "router/SKILL.md") -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $source "LICENSE") -PathType Leaf)) {
        throw "This ZIP is not the expected awesome-gamedev-agent-skills catalog."
    }
    foreach ($folder in $skillFolders) {
        $skill = Join-Path $source $folder
        if (-not (Test-Path -LiteralPath (Join-Path $skill "SKILL.md") -PathType Leaf)) {
            throw "Missing required skill: $folder/SKILL.md"
        }
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($folder in $skillFolders) {
        $skill = Join-Path $source $folder
        Get-ChildItem -LiteralPath $skill -File -Recurse | Where-Object {
            $_.Extension -in @(".md", ".yaml")
        } | ForEach-Object {
            $relativeFile = $_.FullName.Substring($source.Length).TrimStart([char]'\', [char]'/')
            $target = Join-Path $Destination $relativeFile
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        }
    }
    foreach ($name in @("LICENSE", "NOTICE")) {
        Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path $Destination $name) -Force
    }
    Write-Host "Selected Godot and game-design skill references installed at $Destination"
    Write-Host "No game or GitHub workflow files were changed."
}
finally {
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Recurse -Force
    }
}
