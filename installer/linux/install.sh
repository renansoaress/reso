#!/usr/bin/env bash
# Instala o ReSo para o usuario atual, sem sudo.
#
#   ./install.sh              # instala em ~/.local/opt/reso
#   ./install.sh --no-desktop # sem o atalho na area de trabalho
#
# A variavel RESO_PREFIX troca o prefixo ~/.local. O .deb e o caminho
# recomendado em Debian/Ubuntu; este script serve as demais distribuicoes e
# a quem nao quer instalar como root.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prefix="${RESO_PREFIX:-$HOME/.local}"
target="$prefix/opt/reso"
apps="$prefix/share/applications"
icons="$prefix/share/icons/hicolor"
want_desktop=1
[ "${1:-}" = "--no-desktop" ] && want_desktop=0

echo "Instalando o ReSo em $target"
rm -rf "$target"
mkdir -p "$target" "$apps" "$prefix/bin"
cp -r "$here/bundle/." "$target/"
chmod +x "$target/reso"

ln -sf "$target/reso" "$prefix/bin/reso"

for size in 256 128 64 48 32; do
  src="$here/icons/reso-$size.png"
  [ -f "$src" ] || continue
  mkdir -p "$icons/${size}x${size}/apps"
  cp "$src" "$icons/${size}x${size}/apps/reso.png"
done

# O atalho aponta para o binario instalado, e nao para o `reso` do PATH:
# ~/.local/bin nem sempre esta no PATH das sessoes graficas.
entry="$apps/reso.desktop"
sed "s|^Exec=.*|Exec=$target/reso|" "$here/reso.desktop" > "$entry"
chmod +x "$entry"

if [ "$want_desktop" = "1" ]; then
  desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
  if [ -d "$desktop_dir" ]; then
    cp "$entry" "$desktop_dir/reso.desktop"
    chmod +x "$desktop_dir/reso.desktop"
    # O GNOME so abre atalhos marcados como confiaveis.
    gio set "$desktop_dir/reso.desktop" metadata::trusted true 2>/dev/null || true
    echo "Atalho criado em $desktop_dir"
  fi
fi

command -v update-desktop-database >/dev/null 2>&1 && \
  update-desktop-database "$apps" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
  gtk-update-icon-cache -f -t "$icons" 2>/dev/null || true

echo
echo "Pronto. Abra pelo menu de aplicativos ou rode: $target/reso"
