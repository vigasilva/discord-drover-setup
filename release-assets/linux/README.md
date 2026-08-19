# Discord Drover Setup for Linux

This bundle contains the Linux source and builds locally on your machine.

## Arch Linux

```sh
./setup-arch.sh
```

## Other distributions

Install a C compiler, `make`, CMake, native Discord, and Tor. Enable the Tor service, then run:

```sh
mkdir -p ~/.config/discord-drover
install -m 600 config/drover.tor.ini ~/.config/discord-drover/drover.ini
./install.sh
```

See the full project documentation for package commands for Debian/Ubuntu, Fedora, and openSUSE.
