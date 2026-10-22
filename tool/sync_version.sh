#!/usr/bin/env bash
# Mantem a versao num lugar so: o `pubspec.yaml`.
#
#   ./tool/sync_version.sh          # copia a versao do pubspec para o codigo
#   ./tool/sync_version.sh 2.1.0    # muda a versao
#
# Mesmo papel do tool/sync_version.ps1. Imprime a versao final.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

atual="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' pubspec.yaml | head -1)"
[ -n "$atual" ] || { echo "nao encontrei a versao no pubspec.yaml" >&2; exit 1; }

alvo="${1:-}"
if [ -n "$alvo" ] && [ "$alvo" != "$atual" ]; then
  [[ "$alvo" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "versao invalida: '$alvo' (use X.Y.Z)" >&2; exit 1; }
  sed -i -E "s/^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+/version: $alvo/" pubspec.yaml
  echo "pubspec.yaml: $atual -> $alvo" >&2
  atual="$alvo"
fi

dart="// Gerado por tool/sync_version: a versao mora no pubspec.yaml.
const appVersion = '$atual';"
if [ ! -f lib/version.dart ] || [ "$(cat lib/version.dart)" != "$dart" ]; then
  printf '%s\n' "$dart" > lib/version.dart
  echo "lib/version.dart: $atual" >&2
fi

echo "$atual"
