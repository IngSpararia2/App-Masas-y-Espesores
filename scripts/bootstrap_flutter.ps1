$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

function Write-AsciiTextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $AbsolutePath = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $Path))
    [System.IO.File]::WriteAllText($AbsolutePath, $Content, [System.Text.Encoding]::ASCII)
}

function Apply-SafeNativeBranding {
    $AndroidManifest = "android\app\src\main\AndroidManifest.xml"
    if (Test-Path $AndroidManifest) {
        $Content = Get-Content $AndroidManifest -Raw
        $Content = $Content.Replace(
            'android:label="masalab_historico"',
            'android:label="MasaLab Hist&#243;rico"'
        )
        Write-AsciiTextFile -Path $AndroidManifest -Content $Content
    }

    $WindowsMain = "windows\runner\main.cpp"
    if (Test-Path $WindowsMain) {
        $Content = Get-Content $WindowsMain -Raw
        $Content = $Content.Replace(
            'L"masalab_historico"',
            'L"MasaLab Hist\u00F3rico"'
        )
        Write-AsciiTextFile -Path $WindowsMain -Content $Content
    }

    # Runner.rc se deja exactamente como lo genera Flutter. Modificarlo con
    # Set-Content en Windows PowerShell 5.1 puede introducir una codificación
    # que rc.exe de Visual Studio 2019 interpreta incorrectamente.
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter no está disponible en PATH. Instale Flutter estable y vuelva a ejecutar este script."
}

$BackupRoot = Join-Path $env:TEMP ("masalab_source_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $BackupRoot | Out-Null

$FoldersToKeep = @("lib", "test", "docs", "scripts", "assets")
foreach ($Folder in $FoldersToKeep) {
    if (Test-Path $Folder) {
        Copy-Item $Folder -Destination $BackupRoot -Recurse -Force
    }
}

$FilesToKeep = @(
    "pubspec.yaml",
    "analysis_options.yaml",
    "README.md",
    "GUIA_RAPIDA.md",
    "LICENSE.txt",
    ".gitignore"
)
foreach ($File in $FilesToKeep) {
    if (Test-Path $File) {
        Copy-Item $File -Destination $BackupRoot -Force
    }
}

if (Test-Path "android") { Remove-Item "android" -Recurse -Force }
if (Test-Path "windows") { Remove-Item "windows" -Recurse -Force }
if (Test-Path "build") { Remove-Item "build" -Recurse -Force }

$VersionJson = flutter --version --machine | ConvertFrom-Json
$VersionParts = $VersionJson.frameworkVersion.Split('.')
$Major = [int]$VersionParts[0]
$Minor = [int]$VersionParts[1]
if ($Major -lt 3 -or ($Major -eq 3 -and $Minor -lt 38)) {
    throw "Este proyecto requiere Flutter 3.38 o superior. Versión encontrada: $($VersionJson.frameworkVersion)"
}

flutter config --enable-windows-desktop | Out-Null
flutter create --platforms=android,windows --org com.samuelpararia --project-name masalab_historico .
if ($LASTEXITCODE -ne 0) {
    throw "flutter create no pudo generar las plataformas nativas."
}

foreach ($Folder in $FoldersToKeep) {
    $Source = Join-Path $BackupRoot $Folder
    if (Test-Path $Source) {
        if (Test-Path $Folder) { Remove-Item $Folder -Recurse -Force }
        Copy-Item $Source -Destination $ProjectRoot -Recurse -Force
    }
}
foreach ($File in $FilesToKeep) {
    $Source = Join-Path $BackupRoot $File
    if (Test-Path $Source) {
        Copy-Item $Source -Destination $ProjectRoot -Force
    }
}

Remove-Item $BackupRoot -Recurse -Force
Apply-SafeNativeBranding
& "$PSScriptRoot\apply_branding.ps1" -Platform All

flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get terminó con errores."
}

Write-Host ""
Write-Host "Proyecto preparado correctamente." -ForegroundColor Green
Write-Host "Ejecute: .\scripts\run_windows.ps1"
Write-Host "APK:     .\scripts\build_apk.ps1"
Write-Host ""
flutter doctor
