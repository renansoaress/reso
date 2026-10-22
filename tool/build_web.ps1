# Gera o ReSo para a web: PWA instalavel (Android e iPhone) com WebAssembly.
#
#   pwsh tool/build_web.ps1                  # build em build\web
#   pwsh tool/build_web.ps1 -BaseHref /reso/ # servido numa subpasta
#   pwsh tool/build_web.ps1 -Serve           # e abre em http://localhost:5500
#
# O `--wasm` gera as duas versoes: o navegador com WasmGC (Chrome, Edge,
# Firefox, Safari 18.2+) roda a de WebAssembly; os outros caem na de
# JavaScript sozinhos. O `--no-web-resources-cdn` serve o motor daqui mesmo,
# e nao do gstatic: o app abre offline e nao depende de terceiros.
#
# Depois do build, o tool/make_sw.dart gera o sw.js com o hash de cada
# arquivo, e o build\web\reso-web-<versao>.tar.gz sai pronto para publicar.
[CmdletBinding()]
param(
  [string]$BaseHref = '/',
  [switch]$Serve,
  [int]$Port = 5500
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$version = & (Join-Path $PSScriptRoot 'sync_version.ps1')
Write-Host "ReSo $version (web)" -ForegroundColor Cyan

Write-Host 'Compilando (flutter build web --wasm)...' -ForegroundColor Cyan
& flutter build web --release --wasm --no-web-resources-cdn "--base-href=$BaseHref"
if ($LASTEXITCODE -ne 0) { throw "flutter build web falhou ($LASTEXITCODE)" }

& dart run tool/make_sw.dart build/web
if ($LASTEXITCODE -ne 0) { throw 'make_sw falhou' }

$outDir = Join-Path $root 'build\installer'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$tarball = Join-Path $outDir "reso-web-$version.tar.gz"
# O tar do Windows: num terminal do Git Bash, o `tar` do PATH e o GNU, que le
# o "D:" do caminho como um servidor remoto.
& (Join-Path $env:SystemRoot 'System32\tar.exe') -czf $tarball -C (Join-Path $root 'build\web') .
if ($LASTEXITCODE -ne 0) { throw "tar falhou ($LASTEXITCODE)" }
$size = [math]::Round((Get-Item $tarball).Length / 1MB, 1)
Write-Host "Pronto: build\web e $tarball ($size MB)" -ForegroundColor Green

if ($Serve) {
  Write-Host "Servindo em http://localhost:$Port (Ctrl+C para parar)" -ForegroundColor Cyan
  & python (Join-Path $PSScriptRoot 'serve_web.py') (Join-Path $root 'build\web') --port $Port
}
