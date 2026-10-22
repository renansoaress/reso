# Gera o ReSo para Windows e empacota o instalador na mesma passada.
#
#   pwsh tool/build_installer.ps1              # build + instalador
#   pwsh tool/build_installer.ps1 -SkipBuild   # so reempacota o que ja existe
#
# A versao vem do pubspec.yaml: e ela que aparece no instalador, no "Adicionar
# ou remover programas" e no nome do arquivo gerado.
[CmdletBinding()]
param(
  [switch]$SkipBuild,
  [string]$IsccPath = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# ---------------------------------------------------------------- versao
$version = & (Join-Path $PSScriptRoot 'sync_version.ps1')
Write-Host "ReSo $version (Windows)" -ForegroundColor Cyan

# ---------------------------------------------------------------- build
if (-not $SkipBuild) {
  # Sempre do zero: o build incremental do Windows nao regenera a fonte de
  # icones enxugada nem o AssetManifest, e um icone novo sairia invisivel no
  # instalador.
  Write-Host 'Limpando o build anterior (flutter clean)...' -ForegroundColor Cyan
  & flutter clean | Out-Null
  Write-Host 'Compilando (flutter build windows --release)...' -ForegroundColor Cyan
  & flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw "flutter build falhou ($LASTEXITCODE)" }
}

$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'reso.exe'))) {
  throw "nao achei o reso.exe em $release - rode sem -SkipBuild"
}

# ---------------------------------------------------------------- ISCC
if (-not $IsccPath -and $env:ISCC) { $IsccPath = $env:ISCC }
if (-not $IsccPath) {
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
  )
  $IsccPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $IsccPath) {
  throw @'
Inno Setup 6 nao encontrado. Instale com:
    winget install --id JRSoftware.InnoSetup
ou passe o caminho: -IsccPath "C:\...\ISCC.exe"
'@
}

$outDir = Join-Path $root 'build\installer'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host 'Empacotando o instalador...' -ForegroundColor Cyan
& $IsccPath /Q `
  "/DAppVersion=$version" `
  "/DSourceDir=$release" `
  "/DOutputDir=$outDir" `
  (Join-Path $root 'installer\windows\reso.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC falhou ($LASTEXITCODE)" }

$setup = Join-Path $outDir "reso-setup-$version.exe"
$size = [math]::Round((Get-Item $setup).Length / 1MB, 1)
Write-Host "Pronto: $setup ($size MB)" -ForegroundColor Green
