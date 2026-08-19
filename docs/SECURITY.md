# Security and privacy

## What this project changes

- Linux launches Discord with a process-local proxy setting and an `LD_PRELOAD` library.
- Windows places the upstream Drover `version.dll` next to Discord, where Discord loads it through normal Windows DLL search behavior.
- The Windows setup forcibly closes running Discord processes before copying files.

Review the source and use releases you trust before running either setup script.

For Windows, a source-build option is available through `windows/build-from-source.ps1`. It builds the upstream source locally with RAD Studio and passes the resulting `version.dll` to the setup script, avoiding a prebuilt upstream release download.

## Network limitations

- TCP/web traffic can use the configured proxy.
- The Linux UDP helper sends an optional payload, then one-byte `0` and `1` datagrams, before the first matching 74-byte UDP datagram. It sends all of them directly to Discord's original destination.
- UDP is not routed through Tor by this project. Discord voice, video, and screen sharing can reveal the normal network path and may fail when a SOCKS/Tor proxy is configured.
- Tor is high-latency and not appropriate for dependable real-time Discord media. Use WireGuard or another UDP-capable VPN for that use case.

## Proxy and Tor safety

- Do not expose a Tor SOCKS listener such as port 9050 to the Internet.
- Do not run an unauthenticated public proxy; it can be abused and attributed to your server.
- Keep Tor's SOCKS listener bound to `127.0.0.1` unless you have designed and secured an authenticated gateway.
- A bridge may be required on networks that block Tor. Bridge choice and configuration are outside the scope of automated setup.
