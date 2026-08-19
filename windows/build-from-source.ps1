[CmdletBinding()]
param(
    [string]$SourceDirectory = (Join-Path $PSScriptRoot 'upstream-discord-drover'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'build-output'),
    [string]$MSBuildPath,
    [switch]$FetchUpstream
)

$ErrorActionPreference = 'Stop'

if ($FetchUpstream) {
    if (Test-Path $SourceDirectory) {
        throw "Source directory already exists: $SourceDirectory"
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required when using -FetchUpstream.'
    }
    & git clone https://github.com/hdrover/discord-drover.git $SourceDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Could not clone the upstream repository.' }
}

$project = Join-Path $SourceDirectory 'drover.dproj'
if (-not (Test-Path $project)) {
    throw "Upstream source was not found at $SourceDirectory. Use -FetchUpstream or set -SourceDirectory."
}

if (-not $MSBuildPath) {
    $msbuild = Get-Command msbuild.exe -ErrorAction SilentlyContinue
    if (-not $msbuild) {
        throw 'MSBuild was not found. Install Embarcadero RAD Studio and run this script from its Developer Command Prompt, or pass -MSBuildPath.'
    }
    $MSBuildPath = $msbuild.Source
}
if (-not (Test-Path $MSBuildPath)) { throw "MSBuild was not found: $MSBuildPath" }

& $MSBuildPath $project /t:Build /p:Config=Release /p:Platform=Win64
if ($LASTEXITCODE -ne 0) { throw 'The upstream Drover build failed.' }

$builtDll = Join-Path $SourceDirectory 'Win64\Release\drover.dll'
if (-not (Test-Path $builtDll)) { throw "Build completed but output DLL was not found: $builtDll" }

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Copy-Item -LiteralPath $builtDll -Destination (Join-Path $OutputDirectory 'version.dll') -Force
$packetFile = Join-Path $SourceDirectory 'dist\drover-packet.bin'
if (Test-Path $packetFile) {
    Copy-Item -LiteralPath $packetFile -Destination (Join-Path $OutputDirectory 'drover-packet.bin') -Force
}

Write-Host "Built files are ready in: $OutputDirectory"
Write-Host 'Install them with: .\setup-windows.ps1 -LocalDroverDirectory .\build-output'
