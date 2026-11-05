<#
.SYNOPSIS
Verifies an explicitly selected Golden Hour Windows release ZIP and runs its native smoke test.
.DESCRIPTION
Uses a fresh extraction beneath builds/package-validation, checks the release checksum,
exported executable and version metadata, and verifies that all ten player-save paths
remain unchanged. Never replaces an extraction or existing verification evidence.
.EXAMPLE
./tools/verify_windows_package.ps1 -ZipPath ./builds/releases/GoldenHour-1.0.6-windows-20261104-120000-000.zip
#>
param([Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ZipPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-NoReparsePath([string]$Path) {
    # Check existing ancestors as well as the leaf: a junction higher up the path
    # would otherwise redirect a lexically safe workspace destination elsewhere.
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $lookupErrors = @()
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue -ErrorVariable lookupErrors
        if ($null -ne $item) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse-point paths are not accepted: $cursor"
            }
        } elseif ($lookupErrors.Count -gt 0 -and $lookupErrors[0].CategoryInfo.Category -ne [Management.Automation.ErrorCategory]::ObjectNotFound) {
            throw "Cannot inspect path safety: $cursor : $($lookupErrors[0])"
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Get-WorkspacePath([string]$Relative) {
    $full = [IO.Path]::GetFullPath((Join-Path $repoDir $Relative))
    if (-not $full.StartsWith($repoDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes the game workspace: $Relative"
    }
    Assert-NoReparsePath $full
    return $full
}

function Get-Sha256([string]$Path) {
    Assert-NoReparsePath $Path
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-PlayerFingerprints {
    $result = [ordered]@{}
    Assert-NoReparsePath $playerDir
    foreach ($name in $protectedNames) {
        foreach ($suffix in @('', '.backup')) {
            $relative = $name + $suffix
            $path = Join-Path $playerDir $relative
            Assert-NoReparsePath $path
            if ((Test-Path -LiteralPath $path) -and -not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Expected a save file or absent path: $path"
            }
            $result[$relative] = if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Sha256 $path } else { 'ABSENT' }
        }
    }
    return $result
}

if ($env:OS -ne 'Windows_NT') { throw 'This verifier requires Windows and its native executable runtime.' }
$repoDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd([IO.Path]::DirectorySeparatorChar)
Assert-NoReparsePath $repoDir
Assert-NoReparsePath $ZipPath
$zipFile = Get-Item -LiteralPath $ZipPath
if ($zipFile.PSIsContainer -or $zipFile.Name -notmatch '^GoldenHour-(?<version>1\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))-windows-(?<id>[0-9]{8}-[0-9]{6}-[0-9]{3})\.zip$') {
    throw 'Select a GoldenHour-1.x.x-windows-yyyyMMdd-HHmmss-fff.zip release explicitly.'
}
$gameVersion = $Matches.version
$buildId = $Matches.id
$buildTime = [DateTime]::MinValue
if (-not [DateTime]::TryParseExact($buildId, 'yyyyMMdd-HHmmss-fff', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$buildTime)) {
    throw 'The release filename has an invalid build timestamp.'
}
$logDir = Get-WorkspacePath "builds/logs/$buildId"
if (-not (Test-Path -LiteralPath $logDir -PathType Container)) { throw 'The selected release has no matching build-log folder.' }
$extractDir = Get-WorkspacePath "builds/package-validation/$buildId/windows"
if (Test-Path -LiteralPath $extractDir) { throw "Fresh extraction already exists; nothing was replaced: $extractDir" }
$stdoutPath = Get-WorkspacePath "builds/logs/$buildId/12-packaged-native.stdout.log"
$stderrPath = Get-WorkspacePath "builds/logs/$buildId/12-packaged-native.stderr.log"
$resultPath = Get-WorkspacePath "builds/logs/$buildId/12-packaged-native-result.json"
foreach ($path in @($stdoutPath, $stderrPath, $resultPath)) {
    if (Test-Path -LiteralPath $path) { throw "Verification evidence already exists; nothing was replaced: $path" }
}
$exportedExe = Get-WorkspacePath "builds/windows/$gameVersion/GoldenHour.exe"
if (-not (Test-Path -LiteralPath $exportedExe -PathType Leaf)) { throw 'The matching versioned Windows export is missing.' }
$zipHash = Get-Sha256 $zipFile.FullName
$hashManifest = Get-WorkspacePath "builds/releases/GoldenHour-$gameVersion-$buildId-SHA256.txt"
$expectedHashLine = "$zipHash  $($zipFile.Name)"
if (@(Get-Content -LiteralPath $hashManifest | Where-Object { $_ -ceq $expectedHashLine }).Count -ne 1) {
    throw 'Windows ZIP does not match exactly one entry in the completed build checksum manifest.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zipFile.FullName)
try {
    # Validate the complete central directory before creating the extraction.
    # Windows path aliases, duplicate entries and link types are rejected too.
    $entries = [Collections.Generic.List[object]]::new()
    $destinations = [Collections.Generic.Dictionary[string, bool]]::new([StringComparer]::OrdinalIgnoreCase)
    $totalBytes = [int64]0
    foreach ($entry in $archive.Entries) {
        $name = $entry.FullName.Replace('\', '/')
        if ([string]::IsNullOrEmpty($name) -or $name.StartsWith('/') -or [IO.Path]::IsPathRooted($name)) {
            throw "ZIP has an empty or absolute entry: $name"
        }
        $isDirectory = $name.EndsWith('/')
        $segments = $name.TrimEnd('/').Split('/')
        foreach ($segment in $segments) {
            if ([string]::IsNullOrEmpty($segment) -or $segment -in @('.', '..') -or $segment -match '[<>:"|?*\x00-\x1f]' -or $segment -match '[. ]$' -or $segment -match '^(?i:CON|PRN|AUX|NUL|CLOCK\$|COM[1-9]|LPT[1-9])(?:\.|$)') {
                throw "ZIP entry has an unsafe Windows path component: $name"
            }
        }
        $unixType = ([int64]$entry.ExternalAttributes -shr 16) -band 0xF000
        if ($unixType -notin @(0, 0x4000, 0x8000) -or ($entry.ExternalAttributes -band [int][IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "ZIP links, reparse points and special files are not allowed: $name"
        }
        if ($unixType -eq 0x4000 -and -not $isDirectory) { throw "ZIP directory metadata disagrees with its path: $name" }
        $destination = [IO.Path]::GetFullPath((Join-Path $extractDir ($name.Replace('/', [IO.Path]::DirectorySeparatorChar))))
        if (-not $destination.StartsWith($extractDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "ZIP entry escapes the fresh extraction: $name"
        }
        $destination = $destination.TrimEnd([IO.Path]::DirectorySeparatorChar)
        if ($destinations.ContainsKey($destination)) { throw "ZIP has duplicate or colliding paths: $name" }
        $destinations.Add($destination, $isDirectory)
        $totalBytes += $entry.Length
        if ($totalBytes -gt 2GB -or $entries.Count -ge 2048) { throw 'ZIP exceeds the Windows package verification size or entry budget.' }
        $entries.Add([pscustomobject]@{ Entry = $entry; Destination = $destination; IsDirectory = $isDirectory })
    }
    foreach ($entry in $entries) {
        $ancestor = [IO.Path]::GetDirectoryName($entry.Destination)
        while ($ancestor.Length -gt $extractDir.Length) {
            if ($destinations.ContainsKey($ancestor) -and -not $destinations[$ancestor]) { throw "ZIP file blocks an entry directory: $ancestor" }
            $ancestor = [IO.Path]::GetDirectoryName($ancestor)
        }
    }
    Assert-NoReparsePath $extractDir
    # Unlike CreateDirectory, New-Item without Force refuses a destination that
    # appeared after the initial freshness check.
    New-Item -ItemType Directory -Path $extractDir -ErrorAction Stop | Out-Null
    foreach ($entry in $entries) {
        Assert-NoReparsePath $entry.Destination
        if ($entry.IsDirectory) {
            [IO.Directory]::CreateDirectory($entry.Destination) | Out-Null
            continue
        }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($entry.Destination)) | Out-Null
        Assert-NoReparsePath $entry.Destination
        $inputStream = $entry.Entry.Open()
        try {
            $outputStream = [IO.File]::Open($entry.Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
        } finally { $inputStream.Dispose() }
        if ((Get-Item -LiteralPath $entry.Destination).Length -ne $entry.Entry.Length) { throw "Extracted entry length differs: $($entry.Entry.FullName)" }
    }
} finally { $archive.Dispose() }
if ((Get-Sha256 $zipFile.FullName) -cne $zipHash) { throw 'The ZIP changed during verification.' }

$extractedExe = Join-Path $extractDir 'GoldenHour.exe'
$exportedHash = Get-Sha256 $exportedExe
$extractedHash = Get-Sha256 $extractedExe
if ($exportedHash -cne $extractedHash) { throw 'Extracted EXE differs from the matching Windows export.' }
$metadata = (Get-Item -LiteralPath $extractedExe).VersionInfo
$expectedPeVersion = "$gameVersion.0"
if ($metadata.FileVersion -cne $expectedPeVersion -or $metadata.ProductVersion -cne $expectedPeVersion) {
    throw "Extracted EXE version is not $expectedPeVersion."
}
foreach ($relative in @('Quick Start.txt', 'LICENSES/Godot-LICENSE.txt', 'LICENSES/Godot-COPYRIGHT.txt', 'LICENSES/Fredoka-OFL.txt', 'LICENSES/ASSET_PROVENANCE.md', 'LICENSES/ART_PROMPTS.json', 'LICENSES/SOURCES.json')) {
    $notice = Join-Path $extractDir $relative
    Assert-NoReparsePath $notice
    if (-not (Test-Path -LiteralPath $notice -PathType Leaf)) { throw "Package notice missing: $relative" }
}

# Construct the em dash explicitly so Windows PowerShell 5.1 and PowerShell 7
# protect the same real save folder regardless of the script's UTF-8 encoding.
$playerFolder = 'Golden Hour ' + [char]0x2014 + ' Mini Donut Club'
$playerDir = Join-Path (Join-Path $env:APPDATA 'Godot/app_userdata') $playerFolder
$protectedNames = @('golden_hour_run.json', 'golden_hour_settings.json', 'stand_run.json', 'stand_settings.json', 'career.json')
$before = Get-PlayerFingerprints
$smoke = $null
$nativeExit = $null
$timedOut = $false
$failureMessage = $null
$watch = [Diagnostics.Stopwatch]::StartNew()
try {
    $smoke = Start-Process -FilePath $extractedExe -ArgumentList @('--', '--smoke') -WorkingDirectory $extractDir -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    if (-not $smoke.WaitForExit(45000)) {
        $timedOut = $true
        throw 'Extracted-package native smoke exceeded its 45-second timeout.'
    }
    $smoke.Refresh()
    $nativeExit = $smoke.ExitCode
} catch {
    $failureMessage = $_.Exception.Message
} finally {
    try {
        if ($null -ne $smoke) {
            $smoke.Refresh()
            if (-not $smoke.HasExited) {
                # Only this verifier's own smoke process is stopped on failure.
                $smoke.Kill()
                if (-not $smoke.WaitForExit(5000)) { throw 'The verifier smoke process did not stop after its timeout.' }
            }
            $smoke.Dispose()
        }
    } catch {
        $failureMessage = (@($failureMessage, $_.Exception.Message) | Where-Object { $_ }) -join '; '
    } finally {
        $watch.Stop()
        try { $after = Get-PlayerFingerprints } catch {
            $after = [ordered]@{ verification_error = $_.Exception.Message }
            $failureMessage = (@($failureMessage, $_.Exception.Message) | Where-Object { $_ }) -join '; '
        }
    }
}
$unchanged = ($before | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress)
$stdout = if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) { [IO.File]::ReadAllText($stdoutPath) } else { '' }
$stderr = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) { [IO.File]::ReadAllText($stderrPath) } else { '' }
$runtimeVersion = $stdout -cmatch ('(?m)^STAND_READY version=' + [regex]::Escape($gameVersion) + '\s*$')
$smokeMarker = $stdout -cmatch '(?m)^STAND_SMOKE_PASS(?:[ \t]+[^\r\n]*)?\r?$'
$passed = $null -eq $failureMessage -and $nativeExit -eq 0 -and $smokeMarker -and $runtimeVersion -and [string]::IsNullOrWhiteSpace($stderr) -and $unchanged
$result = [ordered]@{
    build_id = $buildId
    version = $gameVersion
    zip = $zipFile.FullName
    zip_sha256 = $zipHash
    checksum_manifest = $hashManifest
    archive_entries_verified = $entries.Count
    archive_uncompressed_bytes = $totalBytes
    executable = $extractedExe
    exported_sha256 = $exportedHash
    extracted_sha256 = $extractedHash
    file_version = $metadata.FileVersion
    product_version = $metadata.ProductVersion
    runtime_version_confirmed = $runtimeVersion
    native_smoke_exit = $nativeExit
    native_smoke_marker = $smokeMarker
    native_smoke_seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 3)
    native_smoke_timeout = $timedOut
    failure_message = $failureMessage
    stderr_empty = [string]::IsNullOrWhiteSpace($stderr)
    saved_files_verified = $before.Count
    player_data_directory = $playerDir
    player_data_before = $before
    player_data_after = $after
    player_data_unchanged = $unchanged
    args = @('--', '--smoke')
    hidden_window = $true
    passed = $passed
}
[IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$result | ConvertTo-Json -Depth 8
if (-not $passed) { throw "Packaged native validation failed; inspect $resultPath" }
