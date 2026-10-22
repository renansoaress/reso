# Mantem a versao num lugar so: o `pubspec.yaml`.
#
#   pwsh tool/sync_version.ps1                 # copia a versao do pubspec para o codigo
#   pwsh tool/sync_version.ps1 -Version 2.1.0  # muda a versao
#
# O Dart nao le o pubspec.yaml em tempo de execucao, entao o numero tambem
# precisa estar em `lib/version.dart`; este script copia de um para o outro.
# O test/reso_test.dart reprova quando os dois divergem.
#
# Retorna a versao final, para quem chamou.
[CmdletBinding()]
param(
  [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $root 'pubspec.yaml'
$dartPath = Join-Path $root 'lib\version.dart'
$utf8 = [Text.UTF8Encoding]::new($false)

$pubspec = [IO.File]::ReadAllText($pubspecPath)
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?') {
  throw 'nao encontrei a versao no pubspec.yaml'
}
$atual = $Matches[1]
$build = $Matches[2]

if ($Version -and $Version -ne $atual) {
  if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
    throw "versao invalida: '$Version' (use X.Y.Z)"
  }
  $pubspec = $pubspec -replace '(?m)^version:.*$', "version: $Version$build"
  [IO.File]::WriteAllText($pubspecPath, $pubspec, $utf8)
  Write-Host "pubspec.yaml: $atual -> $Version" -ForegroundColor Cyan
  $atual = $Version
}

$dart = "// Gerado por tool/sync_version: a versao mora no pubspec.yaml.`nconst appVersion = '$atual';`n"
if (-not (Test-Path $dartPath) -or [IO.File]::ReadAllText($dartPath) -ne $dart) {
  [IO.File]::WriteAllText($dartPath, $dart, $utf8)
  Write-Host "lib/version.dart: $atual" -ForegroundColor Cyan
}

return $atual
