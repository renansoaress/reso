#!/usr/bin/env bash
# Remove o ReSo instalado pelo install.sh (nao mexe no .deb). Respeita o
# mesmo RESO_PREFIX.
set -euo pipefail

prefix="${RESO_PREFIX:-$HOME/.local}"
target="$prefix/opt/reso"
apps="$prefix/share/applications"
icons="$prefix/share/icons/hicolor"

rm -rf "$target"
rm -f "$prefix/bin/reso" "$apps/reso.desktop"
for size in 256 128 64 48 32; do
  rm -f "$icons/${size}x${size}/apps/reso.png"
done

desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
rm -f "$desktop_dir/reso.desktop"

command -v update-desktop-database >/dev/null 2>&1 && \
  update-desktop-database "$apps" 2>/dev/null || true

echo "ReSo removido."
echo "As preferencias continuam em ~/.local/share/com.example.reso (apague a mao se quiser)."
