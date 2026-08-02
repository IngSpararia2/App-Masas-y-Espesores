param(
    [ValidateSet("All", "Android", "Windows")]
    [string]$Platform = "All"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BrandingRoot = Join-Path $ProjectRoot "assets\branding"
$GeneratedRoot = Join-Path $BrandingRoot "generated"
$SourceIcon = Join-Path $BrandingRoot "app_icon_source.png"
$ExpectedSourceSha256 = "99DAEDF5385C07F2D7A0867613D2FF8CC14CEDA886DC1844E51FA206DD5894A6"

if (-not (Test-Path -LiteralPath $SourceIcon -PathType Leaf)) {
    throw "Branding source icon was not found: $SourceIcon"
}

$ActualSourceSha256 = (Get-FileHash -LiteralPath $SourceIcon -Algorithm SHA256).Hash
if ($ActualSourceSha256 -ne $ExpectedSourceSha256) {
    throw "Branding source icon does not match the supplied PNG. Expected SHA-256 $ExpectedSourceSha256, got $ActualSourceSha256."
}

function Copy-BrandingTree {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw "Generated branding directory was not found: $SourceRoot"
    }

    $ResolvedSourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd("\")
    $CopiedFiles = 0

    foreach ($SourceFile in Get-ChildItem -LiteralPath $ResolvedSourceRoot -File -Recurse) {
        $RelativePath = $SourceFile.FullName.Substring($ResolvedSourceRoot.Length).TrimStart("\")
        $Destination = Join-Path $DestinationRoot $RelativePath
        $DestinationDirectory = Split-Path -Parent $Destination
        New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
        Copy-Item -LiteralPath $SourceFile.FullName -Destination $Destination -Force
        $CopiedFiles++
    }

    return $CopiedFiles
}

$AppliedFiles = 0

if ($Platform -eq "All" -or $Platform -eq "Android") {
    $AndroidTarget = Join-Path $ProjectRoot "android\app\src\main\res"
    if (Test-Path -LiteralPath $AndroidTarget -PathType Container) {
        $AndroidSource = Join-Path $GeneratedRoot "android\res"
        $AppliedFiles += Copy-BrandingTree -SourceRoot $AndroidSource -DestinationRoot $AndroidTarget
    }
    elseif ($Platform -eq "Android") {
        throw "Android runner was not found: $AndroidTarget"
    }
}

if ($Platform -eq "All" -or $Platform -eq "Windows") {
    $WindowsTargetDirectory = Join-Path $ProjectRoot "windows\runner\resources"
    $WindowsSourceIcon = Join-Path $GeneratedRoot "windows\app_icon.ico"
    if (Test-Path -LiteralPath $WindowsTargetDirectory -PathType Container) {
        if (-not (Test-Path -LiteralPath $WindowsSourceIcon -PathType Leaf)) {
            throw "Generated Windows icon was not found: $WindowsSourceIcon"
        }
        Copy-Item -LiteralPath $WindowsSourceIcon -Destination (Join-Path $WindowsTargetDirectory "app_icon.ico") -Force
        $AppliedFiles++
    }
    elseif ($Platform -eq "Windows") {
        throw "Windows runner was not found: $WindowsTargetDirectory"
    }
}

if ($AppliedFiles -eq 0) {
    throw "No native runner was found. Create Android or Windows first, then apply branding again."
}

Write-Host "Branding applied successfully ($AppliedFiles files)." -ForegroundColor Green
