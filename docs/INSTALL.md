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

## Linux

### Arch Linux

For Arch Linux with Hyprland, run the automated setup as your normal desktop user:

```sh
cd linux
./setup-arch.sh
```

It installs build dependencies, Discord, Tor, PipeWire, and the Hyprland portal; enables `tor.service`; writes a Tor configuration; and updates the user-level Discord desktop launcher.

### Debian and Ubuntu

Install the native Discord package from Discord, then install prerequisites:

```sh
sudo apt update
sudo apt install build-essential cmake tor pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-gtk
sudo systemctl enable --now tor.service
```

For GNOME, install `xdg-desktop-portal-gnome` instead of the GTK portal when it is available. For KDE Plasma, use `xdg-desktop-portal-kde`.

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
sudo dnf install gcc gcc-c++ make cmake tor pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-gtk
sudo systemctl enable --now tor.service
```

For GNOME, install `xdg-desktop-portal-gnome`; for KDE Plasma, install `xdg-desktop-portal-kde`. Then use the same configure-and-install commands shown for Debian and Ubuntu.

### openSUSE

Install Discord from its native package or a trusted package source, then run:

```sh
sudo zypper install gcc gcc-c++ make cmake tor pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-gtk
sudo systemctl enable --now tor.service
```

Use the matching GNOME or KDE portal package if applicable, then use the same configure-and-install commands shown for Debian and Ubuntu.

### Other distributions

Install a C compiler, `make`, CMake, native Discord, Tor, PipeWire, WirePlumber, `xdg-desktop-portal`, and the portal backend matching your desktop environment. Start Tor's system service, copy `linux/config/drover.tor.ini` to `~/.config/discord-drover/drover.ini`, and run `linux/install.sh`.

### Wayland screen sharing

Wayland screen capture requires PipeWire, WirePlumber, `xdg-desktop-portal`, and a backend for your desktop environment. Hyprland requires `xdg-desktop-portal-hyprland`; GNOME and KDE need their respective portal backends. These components solve capture permissions only—Tor/proxy networking can still prevent a Discord stream from connecting.

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
