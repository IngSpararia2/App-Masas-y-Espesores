$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
. "$PSScriptRoot\flutter_environment.ps1"
$Flutter = Initialize-MasaLabFlutterEnvironment -ProjectRoot $ProjectRoot

if (-not (Test-Path "windows\CMakeLists.txt")) {
    throw "Falta la plataforma Windows. Ejecute PREPARAR_PROYECTO.bat y vuelva a intentarlo."
}

Write-Host "Flutter: $Flutter" -ForegroundColor DarkGray
Write-Host "Proyecto: $ProjectRoot" -ForegroundColor DarkGray

Assert-MasaLabWindowsToolchain

& $Flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get terminó con errores."
}

& $Flutter run -d windows
if ($LASTEXITCODE -ne 0) {
    throw "flutter run -d windows terminó con errores."
}
