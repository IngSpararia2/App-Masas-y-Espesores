$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
. "$PSScriptRoot\flutter_environment.ps1"
$Flutter = Initialize-MasaLabFlutterEnvironment -ProjectRoot $ProjectRoot

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

function Write-AsciiTextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $AbsolutePath = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $Path))
    [System.IO.File]::WriteAllText($AbsolutePath, $Content, [System.Text.Encoding]::ASCII)
}

$BackupBase = Join-Path $env:MASALAB_CACHE_ROOT "backups"
New-Item -ItemType Directory -Path $BackupBase -Force | Out-Null
$BackupRoot = Join-Path $BackupBase ("masalab_windows_repair_" + [guid]::NewGuid().ToString("N"))
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
$HadWindowsPlatform = Test-Path "windows"
$WindowsBackup = Join-Path $BackupRoot "windows"
$WindowsBackupReady = $false
$WindowsRebuildStarted = $false

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
    if ($HadWindowsPlatform) {
        Copy-Item "windows" -Destination $BackupRoot -Recurse -Force
        $WindowsBackupReady = $true
    }

    Write-Host "Regenerando la plataforma Windows..." -ForegroundColor Cyan

    $WindowsRebuildStarted = $true
    if (Test-Path "windows") {
        Remove-Item "windows" -Recurse -Force
    }
    if (Test-Path "build") {
        Remove-Item "build" -Recurse -Force
    }

    & $Flutter config --enable-windows-desktop | Out-Null
    & $Flutter create --platforms=windows --org com.samuelpararia --project-name masalab_historico .
    if ($LASTEXITCODE -ne 0) {
        throw "No fue posible regenerar la carpeta windows."
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

    # Runner.rc se conserva sin modificaciones para evitar problemas de
    # codificación con rc.exe/Visual Studio 2019.

    & "$PSScriptRoot\apply_branding.ps1" -Platform Windows

    & $Flutter clean
    if ($LASTEXITCODE -ne 0) {
        throw "flutter clean terminó con errores."
    }

    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get terminó con errores."
    }
}
catch {
    $RepairError = $_
    if ($WindowsRebuildStarted) {
        Write-Warning "La reparación falló; se restaurará la plataforma Windows anterior."
        if (Test-Path "windows") {
            Remove-Item "windows" -Recurse -Force
        }
        if ($HadWindowsPlatform -and $WindowsBackupReady -and (Test-Path $WindowsBackup)) {
            Copy-Item $WindowsBackup -Destination $ProjectRoot -Recurse -Force
        }
    }
    throw $RepairError
}
finally {
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

Write-Host ""
Write-Host "Plataforma Windows reparada." -ForegroundColor Green
Write-Host "Ahora ejecute INICIAR_EN_WINDOWS.bat"
Write-Host ""
