param(
    [string]$UnityPath = '',
    [string]$PythonPath = 'C:/Python314/python.exe',
    [switch]$PrepareOnly,
    [switch]$SkipTests
)
$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$project = Join-Path $repository 'unity/GoldenHour'
$reports = Join-Path $repository 'playtest-reports/unity'
New-Item -ItemType Directory -Force $reports | Out-Null
& $PythonPath (Join-Path $PSScriptRoot 'prepare_assets.py')
if ($LASTEXITCODE -ne 0) { throw 'Asset preparation failed.' }
if (-not $SkipTests) {
    & (Join-Path $PSScriptRoot 'test_core.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Core acceptance checks failed.' }
}
if ($PrepareOnly) { Write-Output 'Source assets are prepared. Unity compilation has NOT run.'; exit 0 }
if (-not $UnityPath) {
    $candidates = @(
        'C:/Users/bryce/.cache/donutsgame/unity/6000.3.28f1/Editor/Unity.exe',
        'C:/Program Files/Unity/Hub/Editor/6000.3.28f1/Editor/Unity.exe'
    )
    $UnityPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $UnityPath -or -not (Test-Path -LiteralPath $UnityPath)) {
    throw 'Unity 6000.3.28f1 is not installed. Complete the Windows installer approval, activate a valid Unity license if requested, then rerun with -UnityPath pointing to Editor/Unity.exe. No installer or account changes are attempted by this script.'
}
$log = Join-Path $reports 'build.log'
$arguments = @('-batchmode','-quit','-projectPath',('"' + $project + '"'),'-executeMethod','GoldenHour.Editor.GoldenHourBuild.Build','-logFile',('"' + $log + '"'))
$process = Start-Process -FilePath $UnityPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
Write-Output "Unity build started: PID $($process.Id). Log: $log"
$process.WaitForExit()
if ($process.ExitCode -ne 0) { throw "Unity exited $($process.ExitCode). Inspect $log for compiler, package, import, or license errors." }
$exe = Join-Path $repository 'builds/unity/windows/GoldenHour.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Unity exited but no Windows player was produced.' }
$buildLog = Get-Content -LiteralPath $log -Raw
if (-not $buildLog.Contains('GH_BUILD Succeeded')) { throw 'Build success marker missing. Do not treat an older EXE as a new build.' }
Write-Output "Windows player built: $exe"
Write-Output 'Before distributing: launch it, inspect every station, run an entire shift, verify tray physics and animation, and review native screenshots. Compilation alone is not release validation.'
