Set-StrictMode -Version 3.0

function Initialize-MasaLabFlutterEnvironment {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    $ResolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

    # Keep the large, regenerable caches on the same data drive, but outside the
    # repository so Flutter's analyzer never treats downloaded packages as app
    # source code.
    $CacheRoot = if ($env:MASALAB_CACHE_ROOT) {
        [System.IO.Path]::GetFullPath($env:MASALAB_CACHE_ROOT)
    } else {
        Join-Path (Split-Path -Parent $ResolvedProjectRoot) ".masalab-cache"
    }
    $env:MASALAB_CACHE_ROOT = $CacheRoot
    $env:PUB_CACHE = Join-Path $CacheRoot "pub"
    $env:GRADLE_USER_HOME = Join-Path $CacheRoot "gradle"
    foreach ($CacheDirectory in @($CacheRoot, $env:PUB_CACHE, $env:GRADLE_USER_HOME)) {
        if (-not (Test-Path -LiteralPath $CacheDirectory)) {
            New-Item -ItemType Directory -Path $CacheDirectory -Force | Out-Null
        }
    }

    $Candidates = New-Object System.Collections.Generic.List[string]

    $FlutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if (-not $FlutterCommand) {
        $FlutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    }
    if ($FlutterCommand) {
        $CommandPath = $FlutterCommand.Source
        if (-not $CommandPath) {
            $CommandPath = $FlutterCommand.Path
        }
        if ($CommandPath) {
            $Candidates.Add($CommandPath)
        }
    }

    if ($env:FLUTTER_ROOT) {
        $Candidates.Add((Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"))
    }

    if ($env:USERPROFILE) {
        $UserFlutterRoot = Join-Path $env:USERPROFILE "flutter"
        $Candidates.Add((Join-Path $UserFlutterRoot "bin\flutter.bat"))

        if (Test-Path -LiteralPath $UserFlutterRoot) {
            $VersionedInstalls = Get-ChildItem -LiteralPath $UserFlutterRoot -Directory -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending
            foreach ($Install in $VersionedInstalls) {
                $Candidates.Add((Join-Path $Install.FullName "bin\flutter.bat"))
            }
        }
    }

    foreach ($CommonPath in @(
        "C:\src\flutter\bin\flutter.bat",
        "D:\flutter\bin\flutter.bat",
        "D:\src\flutter\bin\flutter.bat"
    )) {
        $Candidates.Add($CommonPath)
    }

    $DataFlutterRoot = "D:\flutter"
    if (Test-Path -LiteralPath $DataFlutterRoot) {
        $VersionedDataInstalls = Get-ChildItem -LiteralPath $DataFlutterRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
        foreach ($Install in $VersionedDataInstalls) {
            $Candidates.Add((Join-Path $Install.FullName "bin\flutter.bat"))
        }
    }

    $Seen = @{}
    foreach ($Candidate in $Candidates) {
        if (-not $Candidate) { continue }

        $FullPath = [System.IO.Path]::GetFullPath($Candidate)
        $Key = $FullPath.ToLowerInvariant()
        if ($Seen.ContainsKey($Key)) { continue }
        $Seen[$Key] = $true

        if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
            return $FullPath
        }
    }

    throw @"
No se encontró Flutter.

Instale Flutter y déjelo en PATH, defina FLUTTER_ROOT o ubíquelo en una carpeta
como %USERPROFILE%\flutter\<version>\bin\flutter.bat.
"@
}

function Assert-MasaLabWindowsToolchain {
    [CmdletBinding()]
    param()

    $VsWhereCandidates = New-Object System.Collections.Generic.List[string]
    $VsWhereCommand = Get-Command vswhere.exe -ErrorAction SilentlyContinue
    if ($VsWhereCommand) {
        $VsWhereCandidates.Add($VsWhereCommand.Source)
    }
    if (${env:ProgramFiles(x86)}) {
        $VsWhereCandidates.Add((Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"))
    }
    $VsWhereCandidates.Add("D:\Microsoft Visual Studio\Installer\vswhere.exe")

    $VsWhere = $VsWhereCandidates |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1

    if (-not $VsWhere) {
        throw @"
Faltan las herramientas para compilar la aplicación de Windows.

Instale Visual Studio con la carga "Desarrollo para el escritorio con C++"
(Desktop development with C++). Debe incluir MSVC, Windows SDK y CMake para
Windows. Después ejecute de nuevo INICIAR_EN_WINDOWS.bat.
"@
    }

    $VisualStudioPath = & $VsWhere `
        -latest `
        -products * `
        -requires Microsoft.VisualStudio.Workload.NativeDesktop `
        -property installationPath

    if ($LASTEXITCODE -ne 0 -or -not $VisualStudioPath) {
        throw @"
Visual Studio está instalado, pero falta la carga "Desarrollo para el escritorio
con C++". Abra Visual Studio Installer, pulse Modificar y agréguela completa.
"@
    }
}
