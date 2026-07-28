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

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter no está disponible en PATH."
}

$BackupRoot = Join-Path $env:TEMP ("masalab_windows_repair_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $BackupRoot | Out-Null

$FoldersToKeep = @("lib", "test", "docs", "scripts")
$FilesToKeep = @(
    "pubspec.yaml",
    "analysis_options.yaml",
    "README.md",
    "GUIA_RAPIDA.md",
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

    Write-Host "Regenerando la plataforma Windows..." -ForegroundColor Cyan

    if (Test-Path "windows") {
        Remove-Item "windows" -Recurse -Force
    }
    if (Test-Path "build") {
        Remove-Item "build" -Recurse -Force
    }

    flutter config --enable-windows-desktop | Out-Null
    flutter create --platforms=windows --org com.samuelpararia --project-name masalab_historico .
    if ($LASTEXITCODE -ne 0) {
        throw "No fue posible regenerar la carpeta windows."
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

    flutter clean
    if ($LASTEXITCODE -ne 0) {
        throw "flutter clean terminó con errores."
    }

    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get terminó con errores."
    }
}
finally {
    if (Test-Path $BackupRoot) {
        Remove-Item $BackupRoot -Recurse -Force
    }
}

Write-Host ""
Write-Host "Plataforma Windows reparada." -ForegroundColor Green
Write-Host "Ahora ejecute INICIAR_EN_WINDOWS.bat"
Write-Host ""
