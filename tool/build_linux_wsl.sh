#!/usr/bin/env bash
# Gera os pacotes do Linux dentro do WSL, para o tool/release.ps1 fazer as
# tres plataformas de uma vez a partir do Windows.
#
#   wsl -- bash tool/build_linux_wsl.sh /mnt/d/Projects/reso
#
# Copia o codigo para o disco do proprio Linux (compilar em /mnt/d e lento, e
# o `flutter clean` do build_installer.sh apagaria o build do Windows),
# roda o tool/build_installer.sh la e traz o .deb e o .tar.gz para o
# build/installer da pasta de origem.
#
# Precisa, no WSL: um Flutter **do Linux** (o do Windows aparece no PATH pelo
# /mnt/c e nao serve), clang, cmake, ninja-build, pkg-config, libgtk-3-dev e
# dpkg-deb. O Flutter e procurado em $RESO_FLUTTER, em ~/flutter, em
# /opt/flutter e no PATH, nessa ordem.
set -euo pipefail

src="${1:?uso: build_linux_wsl.sh <pasta do projeto, vista do WSL>}"
[ -f "$src/pubspec.yaml" ] || { echo "nao achei $src/pubspec.yaml" >&2; exit 1; }

flutter_bin=''
for candidate in "${RESO_FLUTTER:-}" "$HOME/flutter/bin/flutter" \
                 /opt/flutter/bin/flutter "$(command -v flutter || true)"; do
  [ -n "$candidate" ] || continue
  case "$candidate" in /mnt/*) continue ;; esac
  if [ -x "$candidate" ]; then flutter_bin="$candidate"; break; fi
done
[ -n "$flutter_bin" ] || {
  echo "nenhum Flutter do Linux no WSL (instale em ~/flutter ou use RESO_FLUTTER)" >&2
  exit 1
}
export PATH="$(dirname "$flutter_bin"):$PATH"
command -v dpkg-deb >/dev/null || { echo "falta o dpkg-deb no WSL" >&2; exit 1; }

work="$HOME/reso-release"
mkdir -p "$work"
# A copia e por cima, sem o build e o cache: a pasta de trabalho guarda o
# .dart_tool entre uma publicacao e outra, e o build_installer.sh limpa o
# build antes de compilar.
(cd "$src" && tar --exclude=./build --exclude=./.dart_tool --exclude=./.git \
    --exclude=./windows/flutter/ephemeral --exclude=./linux/flutter/ephemeral \
    -cf - .) | (cd "$work" && tar -xf -)
cd "$work"
# O autocrlf do Windows pode ter posto CRLF num script; o bash nao roda assim.
find tool installer -name '*.sh' -exec sed -i 's/\r$//' {} +

echo "Flutter: $(flutter --version 2>/dev/null | head -1)"
bash tool/build_installer.sh

version="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' pubspec.yaml | head -1)"
mkdir -p "$src/build/installer"
for name in "reso_${version}_amd64.deb" "reso-${version}-linux-x64.tar.gz"; do
  [ -f "build/installer/$name" ] || { echo "nao saiu build/installer/$name" >&2; exit 1; }
  cp "build/installer/$name" "$src/build/installer/$name"
  echo "Copiado: build/installer/$name"
done
