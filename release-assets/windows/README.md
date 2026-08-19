# Discord Drover Setup for Windows

1. Extract this ZIP.
2. Double-click `setup-windows.cmd`.
3. When setup finishes, launch Discord normally.

The default setup installs Discord when needed, starts a local headless Tor service at `127.0.0.1:9050`, and installs the upstream Drover release into Discord.

## Build upstream Drover locally instead

If you prefer not to download the upstream prebuilt release, install Embarcadero RAD Studio and run this from a RAD Studio Developer Command Prompt:

```powershell
.\build-from-source.ps1 -FetchUpstream
.\setup-windows.ps1 -LocalDroverDirectory .\build-output
```

See the project documentation for security and configuration details.
