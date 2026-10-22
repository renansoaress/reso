#!/usr/bin/env bash
# Gera o ReSo para Linux e empacota o instalador na mesma passada.
#
#   ./tool/build_installer.sh              # build + pacotes
#   ./tool/build_installer.sh --skip-build # so reempacota o que ja existe
#
# Gera dois pacotes em build/installer:
#   reso_<versao>_amd64.deb              Debian/Ubuntu (sudo apt install ./...)
#   reso-<versao>-linux-x64.tar.gz       demais distros, com install.sh
#
# Precisa, na maquina Linux: flutter, clang, cmake, ninja-build, pkg-config e
# libgtk-3-dev. O .deb so e gerado se o dpkg-deb existir.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

version="$(bash tool/sync_version.sh)"
echo "ReSo $version (Linux)"

if [ "${1:-}" != "--skip-build" ]; then
  # Sempre do zero: o build incremental nao regenera a fonte de icones
  # enxugada nem o AssetManifest, e um icone novo sairia invisivel no pacote.
  echo "Limpando o build anterior (flutter clean)..."
  flutter clean >/dev/null
  echo "Compilando (flutter build linux --release)..."
  flutter build linux --release
fi

bundle="build/linux/x64/release/bundle"
[ -x "$bundle/reso" ] || {
  echo "nao achei $bundle/reso - rode sem --skip-build" >&2
  exit 1
}

out="build/installer"
mkdir -p "$out"

# --------------------------------------------------------------------- .deb
if command -v dpkg-deb >/dev/null 2>&1; then
  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' EXIT

  install -d "$stage/opt/reso" "$stage/usr/bin" \
             "$stage/usr/share/applications" "$stage/DEBIAN"
  cp -r "$bundle/." "$stage/opt/reso/"
  chmod +x "$stage/opt/reso/reso"
  ln -s /opt/reso/reso "$stage/usr/bin/reso"
  install -m644 installer/linux/reso.desktop "$stage/usr/share/applications/reso.desktop"

  for size in 256 128 64 48 32; do
    install -Dm644 "installer/linux/reso-$size.png" \
      "$stage/usr/share/icons/hicolor/${size}x${size}/apps/reso.png"
  done

  size_kb="$(du -sk "$stage" | cut -f1)"
  cat > "$stage/DEBIAN/control" <<EOF
Package: reso
Version: $version
Section: utils
Priority: optional
Architecture: amd64
Maintainer: ${RESO_MAINTAINER:-ReSo <noreply@localhost>}
Depends: libgtk-3-0 (>= 3.24.0)
Installed-Size: $size_kb
Description: Digite o texto, copie o ReSo
 Gera uma senha a partir de um texto (e de uma chave opcional), sempre a
 mesma para a mesma entrada.
EOF

  # Depois da instalacao, o postinst atualiza o menu e o cache de icones.
  cat > "$stage/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database -q /usr/share/applications || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi
exit 0
EOF
  chmod 755 "$stage/DEBIAN/postinst"

  deb="$out/reso_${version}_amd64.deb"
  dpkg-deb --build --root-owner-group "$stage" "$deb" >/dev/null
  echo "Pronto: $deb ($(du -h "$deb" | cut -f1))"
else
  echo "dpkg-deb nao encontrado: pulando o .deb"
fi

# ------------------------------------------------------------------ tar.gz
pack="$(mktemp -d)/reso-$version"
mkdir -p "$pack/bundle" "$pack/icons"
cp -r "$bundle/." "$pack/bundle/"
chmod +x "$pack/bundle/reso"
cp installer/linux/reso.desktop "$pack/"
cp installer/linux/install.sh installer/linux/uninstall.sh "$pack/"
chmod +x "$pack/install.sh" "$pack/uninstall.sh"
cp installer/linux/reso-*.png "$pack/icons/"

tarball="$out/reso-$version-linux-x64.tar.gz"
tar -czf "$tarball" -C "$(dirname "$pack")" "reso-$version"
rm -rf "$(dirname "$pack")"
echo "Pronto: $tarball ($(du -h "$tarball" | cut -f1))"
