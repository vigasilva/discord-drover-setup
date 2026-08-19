[CmdletBinding()]
param(
    [string]$Proxy,
    [switch]$SkipPackageInstall
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Install-WinGetPackage {
    param([Parameter(Mandatory = $true)][string]$Id)
    & winget install --exact --id $Id --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    # WinGet returns this code when the package is installed and has no newer
    # version. That is a successful state for a bootstrap installer.
    $noUpgradeAvailable = -1978335189
    if ($LASTEXITCODE -eq 0) { return }
    if ($LASTEXITCODE -eq $noUpgradeAvailable) {
        Write-Host "$Id is already installed and current."
        return
    }
    throw "WinGet could not install $Id (exit code $LASTEXITCODE)."
}

function Get-DiscordDirectories {
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Discord'),
        (Join-Path $env:LOCALAPPDATA 'DiscordCanary'),
        (Join-Path $env:LOCALAPPDATA 'DiscordPTB')
    )
    foreach ($root in $roots) {
        if (Test-Path $root) {
            Get-ChildItem -Path $root -Directory -Filter 'app-*' | Where-Object {
                (Test-Path (Join-Path $_.FullName 'Discord.exe')) -or
                (Test-Path (Join-Path $_.FullName 'DiscordCanary.exe')) -or
                (Test-Path (Join-Path $_.FullName 'DiscordPTB.exe'))
            }
        }
    }
}

function Start-TorBrowserIfFound {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Tor Browser\Browser\firefox.exe'),
        (Join-Path $env:USERPROFILE 'Desktop\Tor Browser\Browser\firefox.exe')
    )
    $browser = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($browser) {
        Start-Process -FilePath $browser -ArgumentList '-osint', '-url', 'about:blank'
        Write-Host 'Started Tor Browser. If it asks to connect or configure a bridge, complete that step first.'
    } else {
        Write-Warning 'Tor Browser was installed but its executable could not be located automatically.'
    }
}

function Get-DetectedTorProxy {
    if (Test-NetConnection -ComputerName '127.0.0.1' -Port 9150 -InformationLevel Quiet) {
        return 'socks5://127.0.0.1:9150'
    }
    if (Test-NetConnection -ComputerName '127.0.0.1' -Port 9050 -InformationLevel Quiet) {
        return 'socks5://127.0.0.1:9050'
    }
    return 'socks5://127.0.0.1:9150'
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw 'PowerShell 5 or newer is required.'
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required. Install App Installer from Microsoft, then run this setup again.'
}
if (-not $Proxy) {
    $Proxy = Get-DetectedTorProxy
    Write-Host "Selected Tor proxy: $Proxy"
}
if ($Proxy -notmatch '^socks5://[^/@\s:]+:\d{1,5}$') {
    throw 'Proxy must use the form socks5://127.0.0.1:9150.'
}

if (-not $SkipPackageInstall) {
    Write-Host 'Installing Discord and Tor Browser with WinGet…'
    Install-WinGetPackage -Id 'Discord.Discord'
    Install-WinGetPackage -Id 'TorProject.TorBrowser'
}

Get-Process -Name Discord, DiscordCanary, DiscordPTB -ErrorAction SilentlyContinue | Stop-Process -Force

$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/hdrover/discord-drover/releases/latest' -Headers @{ 'User-Agent' = 'Discord-Drover-Setup' }
$asset = $release.assets | Where-Object { $_.name -match '^drover-v.+\.zip$' } | Select-Object -First 1
if (-not $asset) { throw 'The upstream Drover release does not contain the expected ZIP asset.' }

$tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("discord-drover-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDirectory | Out-Null
try {
    $archive = Join-Path $tempDirectory $asset.name
    $expanded = Join-Path $tempDirectory 'expanded'
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archive
    Expand-Archive -Path $archive -DestinationPath $expanded -Force

    $versionDll = Get-ChildItem -Path $expanded -Recurse -File -Filter 'version.dll' | Select-Object -First 1
    if (-not $versionDll) { throw 'The downloaded Drover release does not contain version.dll.' }
    $packetFile = Get-ChildItem -Path $expanded -Recurse -File -Filter 'drover-packet.bin' | Select-Object -First 1

    $discordDirectories = @(Get-DiscordDirectories)
    if ($discordDirectories.Count -eq 0) {
        throw 'Discord was not found after installation. Start Discord once, close it, and run this setup again.'
    }

    $ini = "[drover]`r`nproxy = $Proxy`r`n"
    foreach ($directory in $discordDirectories) {
        Copy-Item -LiteralPath $versionDll.FullName -Destination (Join-Path $directory.FullName 'version.dll') -Force
        Set-Content -LiteralPath (Join-Path $directory.FullName 'drover.ini') -Value $ini -Encoding ASCII
        if ($packetFile) {
            Copy-Item -LiteralPath $packetFile.FullName -Destination (Join-Path $directory.FullName 'drover-packet.bin') -Force
        }
        Write-Host "Installed Drover in $($directory.FullName)"
    }
} finally {
    if (Test-Path $tempDirectory) { Remove-Item -LiteralPath $tempDirectory -Recurse -Force }
}

Start-TorBrowserIfFound
$proxyPort = [int]($Proxy.Split(':')[-1])
if (Test-NetConnection -ComputerName '127.0.0.1' -Port $proxyPort -InformationLevel Quiet) {
    Write-Host "Tor SOCKS5 is listening on 127.0.0.1:$proxyPort."
} else {
    Write-Warning "Tor is not listening on port $proxyPort yet. Finish connecting Tor Browser before launching Discord."
}
Write-Host 'Setup complete. Relaunch Discord once Tor is connected.'
