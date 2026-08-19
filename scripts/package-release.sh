#!/usr/bin/env bash
set -euo pipefail

version=${1:?Usage: scripts/package-release.sh VERSION}
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${project_dir}/dist"
stage_dir="$(mktemp -d)"
trap 'rm -rf "$stage_dir"' EXIT

for command in bsdtar tar install; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done

mkdir -p "$output_dir"

windows_name="discord-drover-setup-windows-${version}"
windows_stage="${stage_dir}/${windows_name}"
mkdir -p "$windows_stage"
install -m 644 "${project_dir}/windows/setup-windows.cmd" "$windows_stage/"
install -m 644 "${project_dir}/windows/setup-windows.ps1" "$windows_stage/"
install -m 644 "${project_dir}/windows/build-from-source.ps1" "$windows_stage/"
install -m 644 "${project_dir}/release-assets/windows/README.md" "$windows_stage/README.md"
bsdtar -a -cf "${output_dir}/${windows_name}.zip" -C "$stage_dir" "$windows_name"

linux_name="discord-drover-setup-linux-${version}"
linux_stage="${stage_dir}/${linux_name}"
mkdir -p "$linux_stage"
tar -C "${project_dir}/linux" --exclude=build -cf - . | tar -C "$linux_stage" -xf -
install -m 644 "${project_dir}/release-assets/linux/README.md" "$linux_stage/README.md"
tar -C "$stage_dir" -czf "${output_dir}/${linux_name}.tar.gz" "$linux_name"

printf '%s\n' "Created: ${output_dir}/${windows_name}.zip"
printf '%s\n' "Created: ${output_dir}/${linux_name}.tar.gz"
