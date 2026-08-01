param(
    [switch]$SplitPerAbi
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
. "$PSScriptRoot\flutter_environment.ps1"
$Flutter = Initialize-MasaLabFlutterEnvironment -ProjectRoot $ProjectRoot

if (-not (Test-Path "android\app")) {
    & "$PSScriptRoot\bootstrap_flutter.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo preparar la plataforma Android."
    }
}

& $Flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get finalizó con errores."
}

if ($SplitPerAbi) {
    & $Flutter build apk --release --split-per-abi
} else {
    & $Flutter build apk --release
}

if ($LASTEXITCODE -ne 0) {
    throw "La compilación del APK falló. Revisa el error mostrado arriba."
}

$outputDirectory = Join-Path $ProjectRoot "build\app\outputs\flutter-apk"
$apks = Get-ChildItem -Path $outputDirectory -Filter "*.apk" -File -ErrorAction SilentlyContinue
if (-not $apks) {
    throw "Flutter terminó sin error, pero no se encontró ningún APK en $outputDirectory."
}

Write-Host ""
Write-Host "APK generado correctamente:" -ForegroundColor Green
foreach ($apk in $apks) {
    Write-Host "  $($apk.FullName)" -ForegroundColor Green
}
