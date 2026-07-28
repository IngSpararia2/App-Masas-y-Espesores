$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if (-not (Test-Path "windows\CMakeLists.txt")) {
    & "$PSScriptRoot\bootstrap_flutter.ps1"
}

flutter pub get
flutter run -d windows
