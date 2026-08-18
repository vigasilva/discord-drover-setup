#!/usr/bin/env bash
# One-command setup for Arch Linux + Hyprland. Run as your normal user.
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run this script as your normal desktop user, not as root." >&2
  exit 1
fi
if [[ ! -f /etc/arch-release ]]; then
  echo "This setup script supports Arch Linux only." >&2
  exit 1
fi
if ! command -v sudo >/dev/null; then
  echo "sudo is required to install Arch packages and enable Tor." >&2
  exit 1
fi

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/discord-drover"
config_file="${config_dir}/drover.ini"

echo "Installing Discord, Tor, and Drover build/runtime dependencies…"
sudo pacman -S --needed --noconfirm \
  base-devel cmake discord tor pipewire wireplumber \
  xdg-desktop-portal xdg-desktop-portal-hyprland

echo "Enabling the local Tor SOCKS5 service…"
sudo systemctl enable --now tor.service

mkdir -p "$config_dir"
if [[ -f "$config_file" ]]; then
  backup_file="${config_file}.backup.$(date +%Y%m%d%H%M%S)"
  cp -p "$config_file" "$backup_file"
  echo "Backed up existing configuration to: $backup_file"
fi
install -m 600 "${project_dir}/config/drover.tor.ini" "$config_file"

"${project_dir}/install.sh"

cat <<'EOF'

Setup complete. Fully close Discord if it is currently running, then launch it
normally from the application menu. The normal Discord launcher now starts it
through Drover and the local Tor SOCKS5 service.
EOF
