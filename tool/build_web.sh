#!/usr/bin/env bash
# Gera o ReSo para a web: PWA instalavel (Android e iPhone) com WebAssembly.
#
#   ./tool/build_web.sh                    # build em build/web
#   ./tool/build_web.sh --base-href /reso/ # servido numa subpasta
#   ./tool/build_web.sh --serve            # e abre em http://localhost:5500
#
# Mesmo processo do tool/build_web.ps1 (ver la os porques).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

base_href='/'
serve=0
port=5500
while [ $# -gt 0 ]; do
  case "$1" in
    --base-href) base_href="$2"; shift 2 ;;
    --serve) serve=1; shift ;;
    --port) port="$2"; shift 2 ;;
    *) echo "opcao desconhecida: $1" >&2; exit 1 ;;
  esac
done

version="$(bash tool/sync_version.sh)"
echo "ReSo $version (web)"

echo "Compilando (flutter build web --wasm)..."
flutter build web --release --wasm --no-web-resources-cdn --base-href="$base_href"
dart run tool/make_sw.dart build/web

mkdir -p build/installer
tarball="build/installer/reso-web-$version.tar.gz"
tar -czf "$tarball" -C build/web .
echo "Pronto: build/web e $tarball ($(du -h "$tarball" | cut -f1))"

if [ "$serve" -eq 1 ]; then
  echo "Servindo em http://localhost:$port (Ctrl+C para parar)"
  python3 tool/serve_web.py build/web --port "$port"
fi
