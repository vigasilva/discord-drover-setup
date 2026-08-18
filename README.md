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
