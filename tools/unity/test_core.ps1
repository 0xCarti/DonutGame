$ErrorActionPreference = 'Stop'
$testProject = Join-Path $PSScriptRoot 'test_core.csproj'
$testOutput = Join-Path ([IO.Path]::GetTempPath()) 'GoldenHour-CoreTests'
$testIntermediate = Join-Path $testOutput 'obj'
$testBinary = Join-Path $testOutput 'bin'
& dotnet build $testProject --configuration Release --nologo --verbosity quiet "-p:BaseIntermediateOutputPath=$testIntermediate/" "-p:OutputPath=$testBinary/"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& dotnet (Join-Path $testBinary 'test_core.dll')
exit $LASTEXITCODE
