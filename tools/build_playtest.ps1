#Requires -Version 7.0
<#
.SYNOPSIS
Imports, verifies, exports, and packages the Golden Hour Windows/Web playtest.
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
$BuildsDir = Get-WorkspacePath 'builds'
$WindowsDir = Get-WorkspacePath "builds/windows/$GameVersion"
$WebDir = Get-WorkspacePath 'builds/web'
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
        if ($line -match 'RUN MODEL:|CONTROLLER|FEEDBACK|AUDIO_SMOKE|BALANCE:|^(SCRIPT ERROR|ERROR|WARNING):') {
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
    'tests/test_run_model.gd', 'tools/check_audio.gd', 'docs/Quick Start.txt',
    'docs/ASSET_LICENSES.md', 'docs/licenses/Godot-LICENSE.txt',
    'docs/licenses/Godot-COPYRIGHT.txt', 'docs/licenses/SOURCES.json', 'assets/fonts/OFL.txt'
)
foreach ($relative in $requiredSources) {
    $sourcePath = Get-WorkspacePath $relative
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Required source missing: $sourcePath" }
}

Invoke-GodotStep -Step '01-import' -Arguments @('--editor', '--import', '--quit') | Out-Null
$core = Invoke-GodotStep -Step '02-core-tests' -Arguments @('--script', 'res://tests/test_run_model.gd')
if ($core.Output -notmatch 'RUN MODEL: (\d+) checks, 0 failures' -or [int]$Matches[1] -lt 134) {
    throw "Core suite did not report at least 134 passing checks. See $($core.LogPath)"
}
$controllerTests = @(Get-ChildItem -LiteralPath (Get-WorkspacePath 'tests') -Filter '*controller*.gd' -File | Sort-Object Name)
foreach ($controllerTest in $controllerTests) {
    $result = Invoke-GodotStep -Step ("03-" + $controllerTest.BaseName) -Arguments @('--script', ('res://tests/' + $controllerTest.Name))
    if ($result.Output -notmatch '(?im)CONTROLLER[^\r\n]*0 failures') {
        throw "Controller suite did not report a passing summary. See $($result.LogPath)"
    }
}
if ($controllerTests.Count -eq 0) { Write-Warning 'No controller test file exists; only core and audio checks will run.' }
$audio = Invoke-GodotStep -Step '04-audio-tests' -Arguments @('--script', 'res://tools/check_audio.gd')
if ($audio.Output -notmatch 'AUDIO_SMOKE_OK') { throw "Audio smoke result missing. See $($audio.LogPath)" }

$feedbackTest = Get-WorkspacePath 'tests/test_feedback.gd'
if (Test-Path -LiteralPath $feedbackTest) {
    $feedback = Invoke-GodotStep -Step '04-feedback-tests' -Arguments @('--script', 'res://tests/test_feedback.gd')
    if ($feedback.Output -notmatch '(?im)FEEDBACK[^\r\n]*0 failures') {
        throw "Feedback suite did not report a passing summary. See $($feedback.LogPath)"
    }
}

$WindowsExe = Get-WorkspacePath "builds/windows/$GameVersion/GoldenHour.exe"
$WebIndex = Get-WorkspacePath 'builds/web/index.html'
Invoke-GodotStep -Step '05-export-windows' -Arguments @('--export-release', 'Windows Desktop', $WindowsExe) | Out-Null
Invoke-GodotStep -Step '06-export-web' -Arguments @('--export-release', 'Web', $WebIndex) | Out-Null

function Copy-PackageNotices {
    param([Parameter(Mandatory)][string]$Destination)
    $licenseDir = Join-Path $Destination 'LICENSES'
    New-Item -ItemType Directory -Path $licenseDir -Force | Out-Null
    Copy-Item -LiteralPath (Get-WorkspacePath 'docs/Quick Start.txt') -Destination (Join-Path $Destination 'Quick Start.txt')
    foreach ($name in @('Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'SOURCES.json')) {
        Copy-Item -LiteralPath (Get-WorkspacePath "docs/licenses/$name") -Destination (Join-Path $licenseDir $name)
    }
    Copy-Item -LiteralPath (Get-WorkspacePath 'assets/fonts/OFL.txt') -Destination (Join-Path $licenseDir 'Fredoka-OFL.txt')
    Copy-Item -LiteralPath (Get-WorkspacePath 'docs/ASSET_LICENSES.md') -Destination (Join-Path $licenseDir 'ASSET_PROVENANCE.md')
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
    $sourcePath = Get-WorkspacePath "builds/web/$name"
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
        foreach ($entry in @($requiredEntry, 'Quick Start.txt', 'LICENSES/Godot-LICENSE.txt', 'LICENSES/Godot-COPYRIGHT.txt', 'LICENSES/Fredoka-OFL.txt')) {
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
