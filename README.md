# Discord Drover Setup

Discord Drover Setup simplifies installing and configuring Discord Drover on Windows and provides a native Linux implementation for the Discord desktop client. It is an integration/setup project, not a fork of the upstream Windows Drover project.

- **Linux:** a launcher adds Discord proxy settings and loads a small `LD_PRELOAD` library for the original project's UDP prelude behavior.
- **Windows:** setup downloads the upstream Drover release, installs its `version.dll` beside Discord, and can run a local headless Tor SOCKS5 service.

It does not install a system-wide VPN or edit global proxy settings.

## Quick start

| Platform | Recommended setup |
| --- | --- |
| Windows 10/11 | Run [`windows/setup-windows.cmd`](windows/setup-windows.cmd). |
| Arch Linux / Hyprland | Run [`linux/setup-arch.sh`](linux/setup-arch.sh). |
| Debian, Ubuntu, Fedora, openSUSE, or another Linux distribution | Follow the [Linux setup guide](docs/INSTALL.md#linux). |

The Linux implementation requires a native Discord installation. Flatpak Discord is not supported because its sandbox prevents loading the host preload library.

## Documentation

- [Installation guide for Windows and major Linux distributions](docs/INSTALL.md)
- [Configuration reference](docs/CONFIGURATION.md)
- [Security, privacy, and networking limitations](docs/SECURITY.md)
- [Release history](CHANGELOG.md)

## Important limitations

Tor and ordinary SOCKS proxies are not suitable for Discord screen sharing, streaming, or reliable voice media. This project does **not** tunnel Discord UDP through Tor; its UDP behavior only sends small prelude datagrams before a matching voice packet. Use a low-latency VPN such as WireGuard when reliable UDP media is required.

The Windows setup downloads the published upstream Windows Drover binary; this repository does not bundle it. See [NOTICE](NOTICE) for attribution.

## License

The Linux implementation and setup scripts in this repository are released under the [MIT License](LICENSE). The separately downloaded upstream Windows Drover release remains subject to its upstream terms.
