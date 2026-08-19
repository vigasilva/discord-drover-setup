# Configuration

## Linux

The Linux launcher reads:

```text
~/.config/discord-drover/drover.ini
```

Example:

```ini
[drover]
proxy = socks5://127.0.0.1:9050
udp_bypass = true
packet_file = drover-packet.bin
```

`proxy` accepts an unauthenticated `http://host:port` or `socks5://host:port` URL. An empty value enables direct mode. Proxy credentials are intentionally unsupported because command-line proxy credentials could be exposed to other local processes.

`udp_bypass` enables the UDP prelude behavior. `packet_file` is optional; relative paths are resolved from the configuration file directory and are reread for each new matching UDP socket.

To use a non-standard Discord executable, set `DISCORD_DROVER_DISCORD_BIN` before launching Drover:

```sh
DISCORD_DROVER_DISCORD_BIN=/path/to/Discord ~/.local/bin/discord-drover
```

## Windows

The Windows script writes this configuration into each detected Discord `app-*` directory:

```ini
[drover]
proxy = socks5://127.0.0.1:9050
```

To change it, edit the relevant `drover.ini` while Discord is closed. The headless Tor configuration and logs are in `%LOCALAPPDATA%\DiscordDrover\tor`.
