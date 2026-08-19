[CmdletBinding()]
param(
    [string]$Proxy = 'socks5://127.0.0.1:9050',
    [switch]$SkipPackageInstall,
    [string]$TorExpertUrl = 'https://archive.torproject.org/tor-package-archive/torbrowser/15.0.20/tor-expert-bundle-windows-x86_64-15.0.20.tar.gz'
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

function Start-HeadlessTor {
    param([Parameter(Mandatory = $true)][string]$BundleUrl)

    $torRoot = Join-Path $env:LOCALAPPDATA 'DiscordDrover\tor'
    $torExe = Join-Path $torRoot 'tor\tor.exe'
    $torData = Join-Path $torRoot 'data-directory'
    $torrc = Join-Path $torRoot 'torrc'
    $torLog = Join-Path $torRoot 'tor.log'
    $torPid = Join-Path $torRoot 'tor.pid'
    New-Item -ItemType Directory -Path $torRoot, $torData -Force | Out-Null

    if (-not (Test-Path $torExe)) {
        if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) {
            throw 'Windows tar.exe is required to unpack the Tor Expert Bundle.'
        }
        $archive = Join-Path $torRoot 'tor-expert-bundle.tar.gz'
        Write-Host 'Downloading the headless Tor Expert Bundle…'
        Invoke-WebRequest -Uri $BundleUrl -OutFile $archive
        & tar.exe -xzf $archive -C $torRoot
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $torExe)) {
            throw 'The Tor Expert Bundle could not be unpacked.'
        }
        Remove-Item -LiteralPath $archive -Force
    }

    $torrcContents = @"
DataDirectory `"$torData`"
SocksPort 127.0.0.1:9050
PidFile `"$torPid`"
CookieAuthentication 1
Log notice file `"$torLog`"
"@
    Set-Content -LiteralPath $torrc -Value $torrcContents -Encoding ASCII

    if (-not (Test-NetConnection -ComputerName '127.0.0.1' -Port 9050 -InformationLevel Quiet)) {
        Write-Host 'Starting headless Tor on 127.0.0.1:9050…'
        Start-Process -FilePath $torExe -ArgumentList '-f', "`"$torrc`"" -WindowStyle Hidden
        $deadline = (Get-Date).AddSeconds(60)
        do {
            Start-Sleep -Seconds 2
            if (Test-NetConnection -ComputerName '127.0.0.1' -Port 9050 -InformationLevel Quiet) { break }
        } while ((Get-Date) -lt $deadline)
    }

    if (-not (Test-NetConnection -ComputerName '127.0.0.1' -Port 9050 -InformationLevel Quiet)) {
        throw "Headless Tor did not open port 9050. Check $torLog."
    }
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw 'PowerShell 5 or newer is required.'
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required. Install App Installer from Microsoft, then run this setup again.'
}
if ($Proxy -notmatch '^socks5://[^/@\s:]+:\d{1,5}$') {
    throw 'Proxy must use the form socks5://127.0.0.1:9150.'
}

if (-not $SkipPackageInstall) {
    Write-Host 'Installing Discord with WinGet…'
    Install-WinGetPackage -Id 'Discord.Discord'
}

Start-HeadlessTor -BundleUrl $TorExpertUrl

Get-Process -Name Discord, DiscordCanary, DiscordPTB -ErrorAction SilentlyContinue | Stop-Process -Force

# Do not use the GitHub REST API here: shared IP addresses can exhaust its
# unauthenticated rate limit. This redirect is the upstream release asset.
$droverReleaseUrl = 'https://github.com/hdrover/discord-drover/releases/latest/download/drover-v0.9.zip'

$tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("discord-drover-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDirectory | Out-Null
try {
    $archive = Join-Path $tempDirectory 'drover-v0.9.zip'
    $expanded = Join-Path $tempDirectory 'expanded'
    Invoke-WebRequest -Uri $droverReleaseUrl -OutFile $archive
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

$proxyPort = [int]($Proxy.Split(':')[-1])
if (Test-NetConnection -ComputerName '127.0.0.1' -Port $proxyPort -InformationLevel Quiet) {
    Write-Host "Tor SOCKS5 is listening on 127.0.0.1:$proxyPort."
} else {
    Write-Warning "Tor is not listening on port $proxyPort."
}
Write-Host 'Setup complete. Relaunch Discord.'
