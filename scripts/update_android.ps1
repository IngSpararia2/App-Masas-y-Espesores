$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Limpiando archivos generados..." -ForegroundColor Cyan
flutter clean
if ($LASTEXITCODE -ne 0) { throw "flutter clean falló." }

Write-Host "Resolviendo dependencias..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get falló." }

Write-Host "Compilando APK release..." -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "La compilación del APK falló." }

$apk = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apk)) { throw "No se encontró el APK esperado en $apk" }

Write-Host ""
Write-Host "APK generado correctamente:" -ForegroundColor Green
Write-Host $apk -ForegroundColor Green
