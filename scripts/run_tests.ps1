$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
. "$PSScriptRoot\flutter_environment.ps1"
$Flutter = Initialize-MasaLabFlutterEnvironment -ProjectRoot $ProjectRoot

& $Flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get terminó con errores." }

& $Flutter analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze encontró errores." }

& $Flutter test
if ($LASTEXITCODE -ne 0) { throw "flutter test encontró pruebas fallidas." }
