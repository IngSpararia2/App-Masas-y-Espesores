$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
. "$PSScriptRoot\flutter_environment.ps1"
$Flutter = Initialize-MasaLabFlutterEnvironment -ProjectRoot $ProjectRoot

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

$VersionOutput = & $Flutter --version --machine
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo consultar la versión de Flutter."
}
$VersionJson = $VersionOutput | ConvertFrom-Json
$VersionParts = $VersionJson.frameworkVersion.Split('.')
$Major = [int]$VersionParts[0]
$Minor = [int]$VersionParts[1]
if ($Major -lt 3 -or ($Major -eq 3 -and $Minor -lt 38)) {
    throw "Este proyecto requiere Flutter 3.38 o superior. Versión encontrada: $($VersionJson.frameworkVersion)"
}

$MissingPlatforms = @()
if (-not (Test-Path "android\app")) {
    $MissingPlatforms += "android"
}
if (-not (Test-Path "windows\CMakeLists.txt")) {
    $MissingPlatforms += "windows"
}

if ($MissingPlatforms.Count -gt 0) {
    $BackupBase = Join-Path $env:MASALAB_CACHE_ROOT "backups"
    New-Item -ItemType Directory -Path $BackupBase -Force | Out-Null
    $BackupRoot = Join-Path $BackupBase ("masalab_source_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $BackupRoot | Out-Null

    $FoldersToKeep = @("lib", "test", "docs", "scripts", "assets")
    $FilesToKeep = @(
        "pubspec.yaml",
        "analysis_options.yaml",
        "README.md",
        "GUIA_RAPIDA.md",
        "CHANGELOG.md",
        "LICENSE.txt",
        ".gitignore"
    )

    try {
        foreach ($Folder in $FoldersToKeep) {
            if (Test-Path $Folder) {
                Copy-Item $Folder -Destination $BackupRoot -Recurse -Force
            }
        }
        foreach ($File in $FilesToKeep) {
            if (Test-Path $File) {
                Copy-Item $File -Destination $BackupRoot -Force
            }
        }

        & $Flutter config --enable-windows-desktop | Out-Null
        $PlatformsArgument = $MissingPlatforms -join ","
        & $Flutter create "--platforms=$PlatformsArgument" --org com.samuelpararia --project-name masalab_historico .
        if ($LASTEXITCODE -ne 0) {
            throw "flutter create no pudo generar las plataformas nativas faltantes."
        }

    }
    finally {
        # Restore the app sources whether flutter create succeeds or fails. The
        # command is only allowed to add the missing native runner.
        foreach ($Folder in $FoldersToKeep) {
            $Source = Join-Path $BackupRoot $Folder
            if (Test-Path $Source) {
                Copy-Item $Source -Destination $ProjectRoot -Recurse -Force
            }
        }
        foreach ($File in $FilesToKeep) {
            $Source = Join-Path $BackupRoot $File
            if (Test-Path $Source) {
                Copy-Item $Source -Destination $ProjectRoot -Force
            }
        }
        if (Test-Path $BackupRoot) {
            Remove-Item $BackupRoot -Recurse -Force
        }
    }
} else {
    Write-Host "Las plataformas Android y Windows ya están preparadas." -ForegroundColor DarkGray
}

Apply-SafeNativeBranding
& "$PSScriptRoot\apply_branding.ps1" -Platform All

& $Flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get terminó con errores."
}

Write-Host ""
Write-Host "Proyecto preparado correctamente." -ForegroundColor Green
Write-Host "Ejecute: .\scripts\run_windows.ps1"
Write-Host "APK:     .\scripts\build_apk.ps1"
Write-Host ""
& $Flutter doctor
