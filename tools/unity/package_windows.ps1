#requires -Version 7.0
<#
Packages an already-built, natively validated player. Does not build or run Unity.
Example:
pwsh -NoProfile -File tools/unity/package_windows.ps1 `
  -SceneAcceptanceResult 'C:/path/to/Acceptance/run/result.json' `
  -MenuAcceptanceResult 'C:/path/to/UIAcceptance/run/result.json'

All writes go to one NEW timestamped release under builds/unity/releases.
Existing releases are never deleted or overwritten. Partial staging is retained
if verification fails. Only a successful run emits VERIFIED.json and a checksum.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SceneAcceptanceResult,
    [Parameter(Mandatory)][string]$MenuAcceptanceResult
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$version = '1.1.0'
$repository = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$runtime = Join-Path $repository 'builds/unity/windows'
$releaseParent = Join-Path $repository 'builds/unity/releases'
$packageName = "GoldenHour-$version-windows-x64"
$packageCache = Join-Path $repository 'unity/GoldenHour/Library/PackageCache'

function Get-LocalFile([string]$Path) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.PSProvider.Name -ne 'FileSystem' -or $item.PSIsContainer -or $item.Length -eq 0) {
        throw "Required nonempty local file is missing: $Path"
    }
    if ($item.FullName.StartsWith('\\') -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Use a regular local file, not a network path or link: $Path"
    }
    return $item
}

function Assert-Within([string]$Path, [string]$Parent) {
    $absolute = [IO.Path]::GetFullPath($Path)
    $prefix = [IO.Path]::GetFullPath($Parent).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes its required local directory: $absolute"
    }
    return $absolute
}

function Read-PassingResult([string]$Path, [string]$Kind) {
    $file = Get-LocalFile $Path
    $result = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
    if ($result -isnot [System.Collections.IDictionary] -or -not $result.Contains('passed') -or
        $result['passed'] -isnot [bool] -or $result['passed'] -ne $true) {
        throw "$Kind must contain the JSON boolean passed: true: $($file.FullName)"
    }
    return $file
}

function Write-NewText([string]$Path, [string]$Text) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose() }
}

function Copy-ReleaseFile([string]$Source, [string]$RelativePath) {
    $destination = Assert-Within (Join-Path $stage $RelativePath) $stage
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
    [IO.File]::Copy($Source, $destination, $false)
}

function Get-StagedFiles {
    return @(Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = [IO.Path]::GetRelativePath($stage, $_.FullName).Replace('\', '/')
            bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
}

# Validate every source before creating a release. Native report paths are read
# only, including reports under the user's LocalLow directory.
$sceneResult = Read-PassingResult $SceneAcceptanceResult 'SceneAcceptance'
$menuResult = Read-PassingResult $MenuAcceptanceResult 'MenuAcceptance'
if ($sceneResult.FullName -eq $menuResult.FullName) { throw 'Scene and menu acceptance must be separate native result files.' }
Get-LocalFile (Join-Path $runtime 'GoldenHour.exe') | Out-Null
Get-LocalFile (Join-Path $runtime 'UnityPlayer.dll') | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $runtime 'GoldenHour_Data') -PathType Container)) {
    throw 'GoldenHour_Data is missing. Build the complete Windows player first.'
}

$extras = [Collections.Generic.List[object]]::new()
foreach ($pair in @(
    @('unity/QUICK_START.txt', 'QUICK_START.txt'),
    @('assets/fonts/OFL.txt', 'LICENSES/Fredoka-OFL.txt'),
    @('docs/ASSET_LICENSES.md', 'LICENSES/ASSET_LICENSES.md'),
    @('docs/ART_PROMPTS.json', 'LICENSES/ART_PROMPTS.json'),
    @('unity/GoldenHour/Assets/Art/Textures/oil_flame.provenance.json', 'LICENSES/oil_flame.provenance.json')
)) {
    $source = Get-LocalFile (Join-Path $repository $pair[0])
    $extras.Add([pscustomobject]@{ Source = $source.FullName; Destination = $pair[1] })
}

# These installed runtime packages and their notice files were verified locally.
# Resolve package hashes rather than baking transient PackageCache suffixes in.
$unityPackages = @(
    @{ Name = 'com.unity.burst'; Label = 'Unity.Burst'; Notice = 'Third Party Notices.md' },
    @{ Name = 'com.unity.render-pipelines.core'; Label = 'Unity.RenderPipelines.Core'; Notice = 'THIRD PARTY NOTICES.md' },
    @{ Name = 'com.unity.render-pipelines.universal'; Label = 'Unity.RenderPipelines.Universal'; Notice = 'Third Party Notices.md' },
    @{ Name = 'com.unity.ugui'; Label = 'Unity.UGUI' },
    @{ Name = 'com.unity.collections'; Label = 'Unity.Collections' },
    @{ Name = 'com.unity.mathematics'; Label = 'Unity.Mathematics'; Extra = 'Unity.Mathematics/Noise/LICENSE' },
    @{ Name = 'com.unity.render-pipelines.universal-config'; Label = 'Unity.RenderPipelines.UniversalConfig' },
    @{ Name = 'com.unity.shadergraph'; Label = 'Unity.ShaderGraph' }
)
$noticeSources = [Collections.Generic.List[object]]::new()
foreach ($package in $unityPackages) {
    $matches = @(Get-ChildItem -LiteralPath $packageCache -Directory | Where-Object { $_.Name -like ($package.Name + '@*') })
    if ($matches.Count -ne 1) { throw "Expected exactly one installed $($package.Name) package; found $($matches.Count)." }
    $files = @(@{ Source = 'LICENSE.md'; Destination = "$($package.Label)-LICENSE.md" })
    if ($package.ContainsKey('Notice')) { $files += @{ Source = $package.Notice; Destination = "$($package.Label)-ThirdPartyNotices.md" } }
    if ($package.ContainsKey('Extra')) { $files += @{ Source = $package.Extra; Destination = "$($package.Label)-Noise-LICENSE.txt" } }
    foreach ($entry in $files) {
        $source = Get-LocalFile (Join-Path $matches[0].FullName $entry.Source)
        $destination = 'LICENSES/' + $entry.Destination
        $extras.Add([pscustomobject]@{ Source = $source.FullName; Destination = $destination })
        $noticeSources.Add([ordered]@{
            package = $package.Name
            source = [IO.Path]::GetRelativePath($repository, $source.FullName).Replace('\', '/')
            includedAs = $destination
            sha256 = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        })
    }
}

$runtimeEntries = @(Get-ChildItem -LiteralPath $runtime -Recurse -Force | Where-Object {
    $relative = [IO.Path]::GetRelativePath($runtime, $_.FullName)
    -not (($relative -split '[\\/]') | Where-Object { $_ -like '*_BurstDebugInformation_DoNotShip' })
})
if ($runtimeEntries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
    throw 'Runtime contains a link/reparse point. Resolve it before packaging.'
}
$runtimeFiles = @($runtimeEntries | Where-Object { -not $_.PSIsContainer })
if ($runtimeFiles.Count -eq 0) { throw 'No runtime files found.' }

$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
$release = Assert-Within (Join-Path $releaseParent ($stamp + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '-' + $packageName)) $repository
$stage = Assert-Within (Join-Path $release $packageName) $release
[IO.Directory]::CreateDirectory($releaseParent) | Out-Null
New-Item -ItemType Directory -Path $release -ErrorAction Stop | Out-Null
New-Item -ItemType Directory -Path $stage -ErrorAction Stop | Out-Null
foreach ($file in $runtimeFiles) {
    $source = Assert-Within $file.FullName $runtime
    Copy-ReleaseFile $source ([IO.Path]::GetRelativePath($runtime, $source))
}
foreach ($extra in $extras) { Copy-ReleaseFile $extra.Source $extra.Destination }
Copy-ReleaseFile $sceneResult.FullName 'VALIDATION/SceneAcceptance.result.json'
Copy-ReleaseFile $menuResult.FullName 'VALIDATION/MenuAcceptance.result.json'
Write-NewText (Join-Path $stage 'LICENSES/Unity-Package-Sources.json') (($noticeSources.ToArray() | ConvertTo-Json -Depth 6) + "`n")

$payloadFiles = Get-StagedFiles
$manifest = [ordered]@{
    product = 'Golden Hour'
    version = $version
    platform = 'Windows x64'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    runtimeSource = 'builds/unity/windows'
    nativeSceneAcceptance = 'VALIDATION/SceneAcceptance.result.json'
    nativeMenuAcceptance = 'VALIDATION/MenuAcceptance.result.json'
    hashAlgorithm = 'SHA256'
    manifestExcludesItself = $true
    files = $payloadFiles
}
Write-NewText (Join-Path $stage 'MANIFEST.json') (($manifest | ConvertTo-Json -Depth 8) + "`n")
$stagedFiles = Get-StagedFiles # includes MANIFEST.json for ZIP verification
$expected = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
foreach ($file in $stagedFiles) { $expected.Add($packageName + '/' + $file.path, $file) }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.ZipFile
$zipPath = Join-Path $release ($packageName + '.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $true)
$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
try {
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName.EndsWith('/')) {
            if (-not $entry.FullName.StartsWith($packageName + '/', [StringComparison]::Ordinal)) { throw "Unexpected ZIP directory: $($entry.FullName)" }
            $directory = Assert-Within (Join-Path $stage $entry.FullName.Substring($packageName.Length + 1)) $stage
            if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw "ZIP directory absent from stage: $($entry.FullName)" }
            continue
        }
        if (-not $expected.ContainsKey($entry.FullName) -or -not $seen.Add($entry.FullName)) { throw "Unexpected or duplicate ZIP file: $($entry.FullName)" }
        $file = $expected[$entry.FullName]
        if ($entry.Length -ne $file.bytes) { throw "ZIP length mismatch: $($entry.FullName)" }
        $stream = $entry.Open()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
        finally { $stream.Dispose(); $hasher.Dispose() }
        if ($hash -ne $file.sha256) { throw "ZIP hash mismatch: $($entry.FullName)" }
    }
    if ($seen.Count -ne $expected.Count) { throw 'ZIP is missing staged files.' }
} finally { $archive.Dispose() }

$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumPath = $zipPath + '.sha256'
Write-NewText $checksumPath ($zipHash + ' *' + [IO.Path]::GetFileName($zipPath) + "`n")
$verified = [ordered]@{
    verified = $true
    version = $version
    fileCount = $seen.Count
    zipSha256 = $zipHash
    archive = [IO.Path]::GetFileName($zipPath)
    manifest = $packageName + '/MANIFEST.json'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
}
Write-NewText (Join-Path $release 'VERIFIED.json') (($verified | ConvertTo-Json) + "`n")
[pscustomobject]@{ Version = $version; ReleaseDirectory = $release; Archive = $zipPath; Checksum = $checksumPath; Manifest = (Join-Path $stage 'MANIFEST.json'); Verified = $true; Files = $seen.Count } | ConvertTo-Json
