#Requires -Version 7.0
<#
.SYNOPSIS
Imports, verifies, exports, and packages Golden Hour.
.DESCRIPTION
Uses Godot 4.7.2 and matching installed export templates. Existing archives and
saves are preserved. Engine helpers are hidden; no interactive game is launched.
#>
[CmdletBinding()]
param(
    [string]$GodotPath = (Join-Path $env:USERPROFILE '.cache\donutsgame\godot\Godot_v4.7.2-stable_win64_console.exe')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$WorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
$WorkspacePrefix = $WorkspaceRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$BuildId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
$EngineVersion = '4.7.2.stable'

function Get-WorkspacePath {
    param([Parameter(Mandatory)][string]$RelativePath)
    $absolute = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $RelativePath))
    if (-not $absolute.StartsWith($WorkspacePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Output escaped the workspace: $absolute"
    }
    # A lexical prefix alone does not protect a directory redirected by a link.
    $ancestor = $absolute
    while ($ancestor -and $ancestor -ne $WorkspaceRoot) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Refusing a redirected workspace output path: $ancestor"
            }
        }
        $ancestor = Split-Path -Parent $ancestor
    }
    return $absolute
}

$ProjectPath = Get-WorkspacePath 'project.godot'
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Leaf)) {
    throw "Not a Godot project: $WorkspaceRoot"
}
$versionMatch = [regex]::Match([IO.File]::ReadAllText($ProjectPath), '(?m)^config/version="([^"]+)"')
if (-not $versionMatch.Success) { throw 'project.godot is missing config/version.' }
$GameVersion = $versionMatch.Groups[1].Value -replace '[^A-Za-z0-9._-]', '-'
if ($GameVersion -notmatch '^1\.0\.\d+$') {
    throw "This Golden Hour package expects a version 1.0 release; project has $GameVersion."
}
if ([IO.File]::ReadAllText($ProjectPath) -notmatch '(?m)^run/main_scene="res://scenes/stand_main.tscn"') {
    throw 'Golden Hour requires scenes/stand_main.tscn as the project main scene.'
}
$BuildsDir = Get-WorkspacePath 'builds'
$WindowsDir = Get-WorkspacePath "builds/windows/$GameVersion"
$WebDir = Get-WorkspacePath "builds/web/$GameVersion"
$ReleaseDir = Get-WorkspacePath 'builds/releases'
$LogDir = Get-WorkspacePath "builds/logs/$BuildId"
$StageDir = Get-WorkspacePath "builds/release-staging/$BuildId"
if (Test-Path -LiteralPath $StageDir) { throw "Build staging already exists: $StageDir" }
foreach ($directory in @($BuildsDir, $WindowsDir, $WebDir, $ReleaseDir, $LogDir, $StageDir)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
$IgnorePath = Get-WorkspacePath 'builds/.gdignore'
if (-not (Test-Path -LiteralPath $IgnorePath)) {
    [IO.File]::WriteAllText($IgnorePath, '', [Text.UTF8Encoding]::new($false))
}

function Invoke-NativeLogged {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Step,
        [switch]$AllowFailure
    )
    Write-Host "[$Step]"
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.WorkingDirectory = $WorkspaceRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "Could not start $Executable" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
    }
    finally { $process.Dispose() }
    $output = $stdout + $stderr
    $logPath = Get-WorkspacePath "builds/logs/$BuildId/$Step.log"
    [IO.File]::WriteAllText($logPath, $output, [Text.UTF8Encoding]::new($false))
    foreach ($line in ($output -split '\r?\n')) {
        if ($line -match 'STAND MODEL:|STAND CONTROLLER:|STAND PRESENTATION:|STAND AUDIO:|WORLD QA:|HAND MOTION QA:|FOOD PHYSICS QA:|FOOD INTEGRATION QA:|CHUTE DISTRIBUTION QA:|TITLE MENU QA:|ACTION PACING QA:|COUNTER QA:|CUSTOMER ART QA:|STAND ART QA:|PROFILE:|AUDIO_SMOKE|EXPORT_SCOPE_OK|BALANCE:|^(SCRIPT ERROR|ERROR|WARNING):') {
            Write-Host $line
        }
    }
    if (-not $AllowFailure -and ($exitCode -ne 0 -or $output -match '(?m)^(SCRIPT ERROR|ERROR):')) {
        throw "Step '$Step' failed (exit $exitCode). See $logPath"
    }
    return [pscustomobject]@{ Output = $output; ExitCode = $exitCode; LogPath = $logPath }
}

$Candidates = [Collections.Generic.List[string]]::new()
if (-not $PSBoundParameters.ContainsKey('GodotPath')) {
    foreach ($commandName in @('godot', 'godot4')) {
        $command = Get-Command $commandName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $Candidates.Add($command.Source) }
    }
}
$Candidates.Add($GodotPath)
$ResolvedGodot = $null
$candidateNumber = 0
foreach ($candidate in ($Candidates | Select-Object -Unique)) {
    $candidateNumber += 1
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
    $resolvedCandidate = (Resolve-Path -LiteralPath $candidate).ProviderPath
    $versionResult = Invoke-NativeLogged -Executable $resolvedCandidate -Arguments @('--version') -Step "engine-version-$candidateNumber" -AllowFailure
    if ($versionResult.ExitCode -eq 0 -and $versionResult.Output.Trim().StartsWith($EngineVersion)) {
        $ResolvedGodot = $resolvedCandidate
        break
    }
}
if (-not $ResolvedGodot) {
    throw "Godot $EngineVersion was not found. Pass -GodotPath with its Windows console executable."
}
Write-Host "Workspace: $WorkspaceRoot"
Write-Host "Godot: $ResolvedGodot"

function Invoke-GodotStep {
    param([string]$Step, [string[]]$Arguments)
    return Invoke-NativeLogged -Executable $ResolvedGodot -Arguments (@('--headless', '--path', $WorkspaceRoot) + $Arguments) -Step $Step
}

$requiredSources = @(
    'tests/test_stand_model.gd', 'tests/test_stand_controller.gd', 'tools/check_audio.gd',
    'tests/test_stand_food_physics.gd', 'tests/test_stand_food_integration.gd',
    'tools/check_chute_distribution.gd',
    'tools/capture_title_1_0_2.gd',
    'tools/check_action_pacing.gd', 'tests/test_stand_hand_motion.gd',
    'tests/test_stand_counter.gd', 'tests/test_stand_customers.gd', 'tests/test_stand_art.gd',
    'tests/test_player_profile.gd', 'tests/test_stand_presentation.gd', 'tests/test_stand_audio.gd', 'tests/test_stand_world.gd', 'docs/IDEA2_PLAYTEST.md',
    'docs/ASSET_LICENSES.md', 'docs/ART_PROMPTS.json', 'docs/licenses/Godot-LICENSE.txt',
    'docs/licenses/Godot-COPYRIGHT.txt', 'docs/licenses/SOURCES.json', 'assets/fonts/OFL.txt'
)
foreach ($relative in $requiredSources) {
    $sourcePath = Get-WorkspacePath $relative
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Required source missing: $sourcePath" }
}

Invoke-GodotStep -Step '01-import' -Arguments @('--editor', '--import', '--quit') | Out-Null
$core = Invoke-GodotStep -Step '02-stand-model-tests' -Arguments @('--script', 'res://tests/test_stand_model.gd')
if ($core.Output -notmatch '(?im)STAND[ _]MODEL:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 1) {
    throw "Stand model suite did not report passing checks. See $($core.LogPath)"
}
$controller = Invoke-GodotStep -Step '03-stand-controller-tests' -Arguments @('--script', 'res://tests/test_stand_controller.gd')
if ($controller.Output -notmatch '(?im)STAND[ _]CONTROLLER:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 1) {
    throw "Stand controller suite did not report passing checks. See $($controller.LogPath)"
}
$audio = Invoke-GodotStep -Step '04-audio-tests' -Arguments @('--script', 'res://tools/check_audio.gd')
if ($audio.Output -notmatch 'AUDIO_SMOKE_OK') { throw "Audio smoke result missing. See $($audio.LogPath)" }
$profile = Invoke-GodotStep -Step '05-profile-tests' -Arguments @('--script', 'res://tests/test_player_profile.gd')
if ($profile.Output -notmatch '(?im)(?:PLAYER )?PROFILE:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 28) {
    throw "Career profile suite did not report at least 28 passing checks. See $($profile.LogPath)"
}
$presentation = Invoke-GodotStep -Step '06-presentation-tests' -Arguments @('--script', 'res://tests/test_stand_presentation.gd')
if ($presentation.Output -notmatch '(?im)STAND PRESENTATION:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 1) {
    throw "Presentation suite did not report passing checks. See $($presentation.LogPath)"
}
$standAudio = Invoke-GodotStep -Step '07-stand-audio-tests' -Arguments @('--script', 'res://tests/test_stand_audio.gd')
if ($standAudio.Output -notmatch '(?im)STAND AUDIO:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 1) {
    throw "Stand audio suite did not report passing checks. See $($standAudio.LogPath)"
}
$world = Invoke-GodotStep -Step '08-stand-world-tests' -Arguments @('--script', 'res://tests/test_stand_world.gd')
if ($world.Output -notmatch '(?im)WORLD QA:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 28) {
    throw "Stand world suite did not report at least 28 passing checks. See $($world.LogPath)"
}
$food = Invoke-GodotStep -Step '08a-food-physics-tests' -Arguments @('--script', 'res://tests/test_stand_food_physics.gd')
if ($food.Output -notmatch '(?im)FOOD PHYSICS QA:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 30) {
    throw "Physical food suite did not pass. See $($food.LogPath)"
}
$foodIntegration = Invoke-GodotStep -Step '08b-food-integration-tests' -Arguments @('--script', 'res://tests/test_stand_food_integration.gd')
if ($foodIntegration.Output -notmatch '(?im)FOOD INTEGRATION QA:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 1) {
    throw "Physical inventory integration suite did not pass. See $($foodIntegration.LogPath)"
}

$chute = Invoke-GodotStep -Step '08c-chute-distribution-tests' -Arguments @('--script', 'res://tools/check_chute_distribution.gd', '--fixed-fps', '60')
if ($chute.Output -notmatch '(?im)CHUTE DISTRIBUTION QA:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 1) {
    throw "Discharge distribution suite did not pass. See $($chute.LogPath)"
}

$WindowsExe = Get-WorkspacePath "builds/windows/$GameVersion/GoldenHour.exe"
$title = Invoke-GodotStep -Step '08d-title-menu-tests' -Arguments @('--script', 'res://tools/capture_title_1_0_2.gd')
if ($title.Output -notmatch '(?im)TITLE MENU QA:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 1) {
    throw "Title menu suite did not pass. See $($title.LogPath)"
}

$WebIndex = Get-WorkspacePath "builds/web/$GameVersion/index.html"
$hands = Invoke-GodotStep -Step '08e-hand-motion-tests' -Arguments @('--script', 'res://tests/test_stand_hand_motion.gd')
if ($hands.Output -notmatch '(?im)HAND MOTION QA:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 1) {
    throw "Hand motion suite did not pass. See $($hands.LogPath)"
}
$pacing = Invoke-GodotStep -Step '08f-action-pacing-tests' -Arguments @('--script', 'res://tools/check_action_pacing.gd')
if ($pacing.Output -notmatch '(?im)ACTION PACING QA:\s+(\d+) checks,\s+0 failures' -or [int]$Matches[1] -lt 1) {
    throw "Animation pacing suite did not pass. See $($pacing.LogPath)"
}

foreach ($artGate in @(
    @{Step='08g-counter-tests'; Script='res://tests/test_stand_counter.gd'; Marker='COUNTER QA'},
    @{Step='08h-customer-tests'; Script='res://tests/test_stand_customers.gd'; Marker='CUSTOMER ART QA'},
    @{Step='08i-art-tests'; Script='res://tests/test_stand_art.gd'; Marker='STAND ART QA'}
)) {
    $result = Invoke-GodotStep -Step $artGate.Step -Arguments @('--script', $artGate.Script)
    if ($result.Output -notmatch ('(?im)' + $artGate.Marker + ':\s+(\d+) checks,\s+0 failures') -or [int]$Matches[1] -lt 1) {
        throw "Art integration gate did not pass: $($artGate.Marker). See $($result.LogPath)"
    }
}

Invoke-GodotStep -Step '09-export-windows' -Arguments @('--export-release', 'Windows Desktop', $WindowsExe) | Out-Null
Invoke-GodotStep -Step '10-export-web' -Arguments @('--export-release', 'Web', $WebIndex) | Out-Null

# Mount each exported pack in a separate empty project. Checking from the source
# project would accidentally satisfy missing resources with workspace files.
$ScopeDir = Get-WorkspacePath "builds/release-staging/$BuildId/scope-check"
New-Item -ItemType Directory -Path $ScopeDir | Out-Null
[IO.File]::WriteAllText((Join-Path $ScopeDir 'project.godot'), "config_version=5`n[application]`nconfig/name=`"GoldenHour Export Verification`"`n", [Text.UTF8Encoding]::new($false))
$scopeSource = @'
extends SceneTree

func _initialize() -> void:
    var arguments = OS.get_cmdline_user_args()
    if arguments.size() != 1 or not ProjectSettings.load_resource_pack(arguments[0], true):
        push_error("Could not mount the exported resource pack")
        quit(1)
        return
    var required = ["res://scenes/stand_main.tscn", "res://scripts/stand_main.gd", "res://scripts/stand_model.gd", "res://scripts/stand_content.gd", "res://scripts/stand_world.gd", "res://scripts/stand_food_physics.gd", "res://scripts/stand_hud.gd", "res://scripts/stand_feedback.gd", "res://scripts/player_profile.gd", "res://scripts/stand_audio.gd", "res://scripts/game_audio.gd", "res://assets/fonts/Fredoka-Medium.ttf", "res://assets/art/title_keyart.png", "res://assets/art/brand_seal.png", "res://assets/art/counter_sign.png", "res://assets/shaders/oil.gdshader", "res://assets/shaders/donut_crust.gdshader", "res://assets/shaders/powder_sugar.gdshader", "res://assets/shaders/fairground_sky.gdshader", "res://assets/audio/stand/evening_theme.wav", "res://assets/audio/stand/fryer_loop.wav", "res://assets/audio/sale_jackpot.wav"]
    required.append_array(["res://assets/art/shaker_cinnamon.svg", "res://assets/art/shaker_powdered.svg", "res://assets/models/fairgoer_geometry.res", "res://scripts/customer_geometry.gd"])
    for material in ["counter_wood", "kraft_paper"]:
        for channel in ["color", "normal", "roughness"]:
            required.append("res://assets/materials/" + material + "_" + channel + ".png")
    var forbidden = ["res://scenes/main.tscn", "res://scripts/main.gd", "res://scripts/run_model.gd", "res://scripts/world.gd", "res://scripts/upgrades.gd", "res://scripts/score_feedback.gd", "res://tests/test_stand_model.gd", "res://tests/test_controller.gd", "res://assets/fonts/Fredoka.ttf"]
    var failures = 0
    for path in required:
        if not ResourceLoader.exists(path):
            push_error("Export is missing required resource: " + path)
            failures += 1
    for path in forbidden:
        if ResourceLoader.exists(path):
            push_error("Export contains historical or development resource: " + path)
            failures += 1
    if failures == 0: print("EXPORT_SCOPE_OK: required runtime assets present; prototype and test resources absent")
    quit(1 if failures > 0 else 0)
'@
$ScopeScript = Join-Path $ScopeDir 'verify_export.gd'
[IO.File]::WriteAllText($ScopeScript, $scopeSource, [Text.UTF8Encoding]::new($false))
foreach ($platform in @('windows', 'web')) {
    $packPath = if ($platform -eq 'windows') { $WindowsExe } else { Get-WorkspacePath "builds/web/$GameVersion/index.pck" }
    $scopeResult = Invoke-NativeLogged -Executable $ResolvedGodot -Arguments @('--headless', '--path', $ScopeDir, '--script', $ScopeScript, '--', $packPath) -Step "11-scope-$platform"
    if ($scopeResult.Output -notmatch 'EXPORT_SCOPE_OK') { throw "Export scope verification failed. See $($scopeResult.LogPath)" }
}

function Copy-PackageNotices {
    param([Parameter(Mandatory)][string]$Destination)
    $licenseDir = Join-Path $Destination 'LICENSES'
    New-Item -ItemType Directory -Path $licenseDir -Force | Out-Null
    Copy-Item -LiteralPath (Get-WorkspacePath 'docs/IDEA2_PLAYTEST.md') -Destination (Join-Path $Destination 'Quick Start.txt')
    foreach ($name in @('Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'SOURCES.json')) {
        Copy-Item -LiteralPath (Get-WorkspacePath "docs/licenses/$name") -Destination (Join-Path $licenseDir $name)
    }
    Copy-Item -LiteralPath (Get-WorkspacePath 'assets/fonts/OFL.txt') -Destination (Join-Path $licenseDir 'Fredoka-OFL.txt')
    Copy-Item -LiteralPath (Get-WorkspacePath 'docs/ASSET_LICENSES.md') -Destination (Join-Path $licenseDir 'ASSET_PROVENANCE.md')
    Copy-Item -LiteralPath (Get-WorkspacePath 'docs/ART_PROMPTS.json') -Destination (Join-Path $licenseDir 'ART_PROMPTS.json')
}

$WindowsStage = Get-WorkspacePath "builds/release-staging/$BuildId/windows"
$WebStage = Get-WorkspacePath "builds/release-staging/$BuildId/web"
foreach ($directory in @($WindowsStage, $WebStage)) {
    New-Item -ItemType Directory -Path $directory | Out-Null
}
if (-not (Test-Path -LiteralPath $WindowsExe -PathType Leaf) -or (Get-Item -LiteralPath $WindowsExe).Length -lt 1000000) {
    throw 'Windows export did not produce a valid-sized executable.'
}
Copy-Item -LiteralPath $WindowsExe -Destination (Join-Path $WindowsStage 'GoldenHour.exe')
$webFiles = @(
    'index.html', 'index.js', 'index.wasm', 'index.pck',
    'index.audio.worklet.js', 'index.audio.position.worklet.js',
    'index.png', 'index.icon.png', 'index.apple-touch-icon.png'
)
foreach ($name in $webFiles) {
    $sourcePath = Get-WorkspacePath "builds/web/$GameVersion/$name"
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or (Get-Item -LiteralPath $sourcePath).Length -eq 0) {
        throw "Web export file missing or empty: $sourcePath"
    }
    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $WebStage $name)
}
foreach ($directory in @($WindowsDir, $WebDir, $WindowsStage, $WebStage)) {
    Copy-PackageNotices -Destination $directory
}

$releaseFiles = [Collections.Generic.List[string]]::new()
foreach ($platform in @('windows', 'web')) {
    $stage = if ($platform -eq 'windows') { $WindowsStage } else { $WebStage }
    $zipPath = Get-WorkspacePath "builds/releases/GoldenHour-$GameVersion-$platform-$BuildId.zip"
    if (Test-Path -LiteralPath $zipPath) { throw "Release already exists: $zipPath" }
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entryNames = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        $requiredEntry = if ($platform -eq 'windows') { 'GoldenHour.exe' } else { 'index.html' }
        foreach ($entry in @($requiredEntry, 'Quick Start.txt', 'LICENSES/Godot-LICENSE.txt', 'LICENSES/Godot-COPYRIGHT.txt', 'LICENSES/Fredoka-OFL.txt', 'LICENSES/ASSET_PROVENANCE.md', 'LICENSES/ART_PROMPTS.json')) {
            if ($entry -notin $entryNames) { throw "Package is missing $entry : $zipPath" }
        }
    }
    finally { $zip.Dispose() }
    $releaseFiles.Add($zipPath)
}
$hashLines = foreach ($releaseFile in $releaseFiles) {
    $hash = Get-FileHash -LiteralPath $releaseFile -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($releaseFile))"
}
$hashPath = Get-WorkspacePath "builds/releases/GoldenHour-$GameVersion-$BuildId-SHA256.txt"
[IO.File]::WriteAllLines($hashPath, $hashLines, [Text.UTF8Encoding]::new($false))
Write-Host 'Build, verification, and packaging completed.'
foreach ($releaseFile in $releaseFiles) { Write-Host $releaseFile }
Write-Host "Checksums: $hashPath"
Write-Host "Logs: $LogDir"
