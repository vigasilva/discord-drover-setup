# Installation guide

## Before you begin

- Quit Discord completely before installing or changing its configuration.
- Use a native Discord desktop installation. The Linux preload implementation cannot operate inside Flatpak Discord.
- A proxy handles Discord's TCP/web traffic. It does not make Discord voice or screen sharing anonymous, and Tor is unsuitable for real-time media.

## Windows 10/11

1. Download or clone this repository.
2. Open the `windows` folder.
3. Double-click `setup-windows.cmd`.
4. Wait for the setup to complete, then relaunch Discord.

The script uses WinGet to install Discord if needed, downloads Tor's Windows Expert Bundle, starts a local headless Tor process at `127.0.0.1:9050`, downloads the current pinned upstream Drover release, and places its files in detected Discord installation folders.

Run the PowerShell script directly only when you need a different proxy:

```powershell
.\setup-windows.ps1 -Proxy socks5://proxy.example:1080
```

Headless Tor files and logs are kept in `%LOCALAPPDATA%\DiscordDrover\tor`. If it cannot connect, inspect `tor.log`; bridge configuration is a manual network-specific decision.

### Windows: build the upstream source locally

If you do not want the setup to download an upstream release binary, build it locally with Embarcadero RAD Studio's MSBuild support. This script clones the upstream repository only into your local working directory; it does not add upstream source or binaries to this repository.

```powershell
.\build-from-source.ps1 -FetchUpstream
.\setup-windows.ps1 -LocalDroverDirectory .\build-output
```

Run the first command from a RAD Studio Developer Command Prompt, or pass the full `MSBuild.exe` path with `-MSBuildPath`. The script builds the upstream Win64 Release DLL and writes a locally created `version.dll` into `build-output` for the installer to use.

## Linux

### Arch Linux

For Arch Linux, run the automated setup as your normal desktop user:

```sh
cd linux
./setup-arch.sh
```

It installs build dependencies, Discord, and Tor; enables `tor.service`; writes a Tor configuration; builds the Linux helper locally; and updates the user-level Discord desktop launcher.

### Debian and Ubuntu

Install the native Discord package from Discord, then install prerequisites:

```sh
sudo apt update
sudo apt install build-essential cmake tor
sudo systemctl enable --now tor.service
```

Configure and install Drover:

```sh
cd linux
mkdir -p ~/.config/discord-drover
install -m 600 config/drover.tor.ini ~/.config/discord-drover/drover.ini
./install.sh
```

### Fedora

Install Discord from its native RPM or your chosen trusted package source, then run:

```sh
sudo dnf install gcc gcc-c++ make cmake tor
sudo systemctl enable --now tor.service
```

Then use the same configure-and-install commands shown for Debian and Ubuntu. The helper is built locally when `linux/install.sh` runs.

### openSUSE

Install Discord from its native package or a trusted package source, then run:

```sh
sudo zypper install gcc gcc-c++ make cmake tor
sudo systemctl enable --now tor.service
```

Then use the same configure-and-install commands shown for Debian and Ubuntu. The helper is built locally when `linux/install.sh` runs.

### Other distributions

Install a C compiler, `make`, CMake, native Discord, and Tor. Start Tor's system service, copy `linux/config/drover.tor.ini` to `~/.config/discord-drover/drover.ini`, and run `linux/install.sh`. This compiles the Linux helper from the checked-out source on the local machine; it does not download a prebuilt Linux executable.

## Uninstall

### Linux

Remove the user-level launcher override, binary, library, and configuration:

```sh
rm -f ~/.local/share/applications/discord.desktop
rm -f ~/.local/bin/discord-drover
rm -rf ~/.local/lib/discord-drover
rm -rf ~/.config/discord-drover
```

If installed with another prefix, remove the equivalent paths there. You may disable Tor independently with `sudo systemctl disable --now tor.service`.

### Windows

Close Discord, then remove `version.dll`, `drover.ini`, and optionally `drover-packet.bin` from each Discord `app-*` directory under `%LOCALAPPDATA%\Discord`. Remove `%LOCALAPPDATA%\DiscordDrover\tor` to remove the headless Tor files.
