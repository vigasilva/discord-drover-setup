#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [--prefix PATH]

Build and install Discord Drover to PATH (default: ~/.local), preserve an
existing configuration, and add a “Discord (Drover)” desktop launcher.
EOF
}

prefix="${HOME}/.local"
while (($#)); do
  case "$1" in
    --prefix)
      (($# >= 2)) || { echo "--prefix requires a path" >&2; exit 2; }
      prefix="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for command in cmake install sed; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${project_dir}/build"
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/discord-drover"
config_file="${config_dir}/drover.ini"
applications_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"

cmake -S "$project_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_dir"
cmake --install "$build_dir" --prefix "$prefix"

mkdir -p "$config_dir" "$applications_dir"
if [[ ! -e "$config_file" ]]; then
  install -m 600 "${project_dir}/config/drover.ini.default" "$config_file"
  echo "Created configuration: $config_file"
else
  echo "Kept existing configuration: $config_file"
fi

system_desktop_file=""
for candidate in /usr/share/applications/discord.desktop /usr/share/applications/Discord.desktop; do
  if [[ -r "$candidate" ]]; then
    system_desktop_file="$candidate"
    break
  fi
done

if [[ -n "$system_desktop_file" ]]; then
  desktop_file="${applications_dir}/$(basename "$system_desktop_file")"
  awk -v launcher="${prefix}/bin/discord-drover" '
    /^Exec=/ { print "Exec=" launcher " %U"; next }
    /^TryExec=/ { next }
    { print }
  ' "$system_desktop_file" > "$desktop_file"
  echo "Overrode Discord launcher: $desktop_file"
else
  desktop_file="${applications_dir}/discord-drover.desktop"
  sed "s|@INSTALL_PREFIX@|${prefix}|g" "${project_dir}/share/discord-drover.desktop.in" > "$desktop_file"
  echo "Discord desktop file was not found; added a separate Drover launcher instead."
fi
chmod 644 "$desktop_file"
if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$applications_dir" || true
fi

cat <<EOF

Installed Discord Drover to: ${prefix}
Configuration: ${config_file}

Edit the configuration before launching if you need a proxy. For system Tor:
  proxy = socks5://127.0.0.1:9050

Launch Discord normally from your application menu, or run:
  ${prefix}/bin/discord-drover
EOF
