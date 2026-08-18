# Discord Drover for Linux

This is a Linux-native rewrite of the Windows Discord Drover approach. It is deliberately separate from the original Windows project.

It launches Discord with an HTTP or SOCKS5 proxy scoped to that process and uses an `LD_PRELOAD` library to send optional UDP prelude packets before Discord's first 74-byte UDP voice packet. It neither installs a driver nor edits Discord files.

## Build

```sh
cmake -S . -B build
cmake --build build
```

## Install

For a user-local installation with an application-menu launcher, run:

```sh
./install.sh
```

It installs under `~/.local`, creates `~/.config/discord-drover/drover.ini` only if it does not already exist, and never changes Discord's files. It creates or updates a user-level override at `~/.local/share/applications/discord.desktop`; from then on, launching Discord normally from the application menu runs it through Drover. Existing Discord launch arguments, including Wayland flags, are retained. This override survives Discord package updates.

### One-command Arch Linux setup

On Arch Linux with Hyprland, run this executable as your normal user:

```sh
./setup-arch.sh
```

It uses `sudo` to install Discord, Tor, and the needed PipeWire/portal packages; enables `tor.service`; configures Drover to use `socks5://127.0.0.1:9050`; and updates the normal Discord launcher. If a Drover configuration already exists, it is saved as a timestamped backup before the Tor configuration replaces it. Once the script completes, close any running Discord process and launch Discord normally.

### One-command Windows setup

On Windows, run [`windows/setup-windows.cmd`](windows/setup-windows.cmd). It uses WinGet to install Discord and Tor Browser, downloads the latest upstream Windows Drover release, closes Discord, and copies `version.dll` plus a Tor SOCKS5 configuration into every detected Discord installation. It automatically chooses an active Tor Browser listener on port `9150`, or a system Tor listener on port `9050`.

To force system Tor port `9050`, run the PowerShell script directly:

```powershell
.\setup-windows.ps1 -Proxy socks5://127.0.0.1:9050
```

If Tor Browser asks you to connect or configure a bridge, complete that prompt before relaunching Discord. This cannot be safely automated because it depends on the network and any censorship-circumvention settings you choose.

Create a configuration directory, then copy and edit the example:

```sh
mkdir -p ~/.config/discord-drover
cp config/drover.ini.example ~/.config/discord-drover/drover.ini
```

Then run:

```sh
./build/discord-drover
```

Pass any normal Discord arguments after the launcher, for example `./build/discord-drover --start-minimized`.

For a nonstandard Discord executable, set `DISCORD_DROVER_DISCORD_BIN=/path/to/Discord`. Flatpak Discord is intentionally not supported: its sandbox prevents reliable use of the host `LD_PRELOAD` library.

## Configuration

`proxy` accepts only unauthenticated `http://host:port` and `socks5://host:port` URLs. Proxy credentials are not supported because adding them to a Chromium command-line argument would expose them to local process inspection. An empty proxy enables direct mode while retaining the optional UDP behavior.

`packet_file` is optional. It is read again for each new voice socket, so it can be changed without restarting Discord.

## Technical constraints

The UDP rule deliberately follows the original: the first 74-byte datagram on each UDP file descriptor is treated as the voice setup packet. This is a heuristic and should be tested against the current Discord Linux build. The preload library is enabled only for processes started by this launcher.

This project has not been tested against Discord's live voice service. Use it only where you are authorized to do so and in accordance with Discord's terms and your local network rules.
