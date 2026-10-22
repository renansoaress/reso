# Publica uma versao nova do ReSo a partir do Windows: um comando, do numero
# da versao aos instaladores, a atualizacao automatica, ao site, ao commit, a
# tag e ao push.
#
#   pwsh tool/release.ps1 -Version 2.1.0 -Notes "Visual novo.\nTema claro e escuro."
#   pwsh tool/release.ps1                          # repete a versao do pubspec
#   pwsh tool/release.ps1 -SkipUpload -SkipGit     # so gera os arquivos
#   pwsh tool/release.ps1 -SkipLinux               # sem o WSL
#   pwsh tool/release.ps1 -SkipWindows -SkipLinux  # so a web
#   pwsh tool/release.ps1 -SkipBuild -SkipTests    # so reenvia o que ja existe
#
# O que ele faz, em ordem:
#   1. grava a versao no pubspec.yaml e em lib/version.dart;
#   2. roda flutter analyze e flutter test;
#   3. compila e empacota o instalador do Windows (tool/build_installer.ps1);
#   4. compila e empacota o .deb e o .tar.gz do Linux no WSL
#      (tool/build_linux_wsl.sh), na distribuicao -WslDistro ou na padrao;
#   5. compila a web: PWA com WebAssembly (tool/build_web.ps1);
#   6. gera o latest.json com o SHA-256 de cada pacote (tool/publish_update.dart),
#      preservando os pacotes que ja estiverem publicados na mesma versao;
#   7. envia tudo ao servidor numa conexao so: os pacotes do desktop e o
#      latest.json para a pasta publica da atualizacao, e a web para a pasta
#      do reso_web.service. O latest.json entra por ultimo: se chegasse antes dos pacotes, um ReSo
#      poderia ver a versao nova e nao achar o arquivo. A web e trocada de uma
#      vez (mv), e quem esta usando nunca ve meio site;
#   8. commita a versao, cria a tag vX.Y.Z com as notas e empurra.
#
# O servidor fica fora do repositorio, em tool/release.local.json (ignorado
# pelo git). Copie o tool/release.example.json e preencha:
#
#   server      usuario@host do SSH
#   port        porta do SSH
#   updatePath  pasta publicada no endereco do lib/update/update_service.dart
#               (a que o ReSo instalado consulta)
#   webPath     pasta servida pelo reso_web.service
#
# Os caminhos sao relativos a home do usuario remoto. Os parametros -Server,
# -Port, -UpdatePath e -WebPath passam por cima do arquivo.
#
# O acesso ao servidor e conferido no comeco: sem chave instalada, o script
# oferece instalar a sua (a senha e pedida uma vez, com voce na frente, e nao
# depois de minutos de build).
[CmdletBinding()]
param(
  [string]$Version = '',
  [string]$Notes = '',
  [switch]$SkipTests,
  [switch]$SkipBuild,
  [switch]$SkipWindows,
  [switch]$SkipLinux,
  [switch]$SkipWeb,
  [switch]$SkipUpload,
  [switch]$SkipGit,
  [switch]$Yes,

  # A distribuicao do WSL que compila o Linux; vazio usa a padrao.
  [string]$WslDistro = '',

  # O servidor; vazio vem do tool/release.local.json (ver acima).
  [string]$Server = '',
  [int]$Port = 0,
  [string]$UpdatePath = '',
  [string]$WebPath = '',
  [string]$BaseHref = '/'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# ------------------------------------------------------------------ servidor
$configLocal = Join-Path $PSScriptRoot 'release.local.json'
if (Test-Path $configLocal) {
  $config = Get-Content $configLocal -Raw | ConvertFrom-Json
  if (-not $Server) { $Server = "$($config.server)" }
  if (-not $Port) { $Port = [int]$config.port }
  if (-not $UpdatePath) { $UpdatePath = "$($config.updatePath)" }
  if (-not $WebPath) { $WebPath = "$($config.webPath)" }
}
if (-not $Port) { $Port = 22 }

# O endereco publico da atualizacao e o que o app consulta: fica num lugar so.
$servico = Get-Content (Join-Path $root 'lib/update/update_service.dart') -Raw
if ($servico -notmatch "updateManifestUrl\s*=\s*'([^']+)/latest\.json'") {
  throw 'nao achei o updateManifestUrl em lib/update/update_service.dart'
}
$UpdateUrl = $Matches[1]

function Etapa([string]$texto) {
  Write-Host ''
  Write-Host "==> $texto" -ForegroundColor Cyan
}
function Marca([bool]$pulado) { if ($pulado) { '[ ]' } else { '[x]' } }

# Se o servidor aceita a chave SSH sem perguntar nada. BatchMode faz o ssh
# desistir em vez de pedir a senha.
function Test-AcessoPorChave {
  & ssh -p "$Port" -o BatchMode=yes -o ConnectTimeout=10 $Server exit 2>$null
  return $LASTEXITCODE -eq 0
}

# Poe a sua chave publica no authorized_keys do servidor, criando uma chave
# ed25519 sem frase se voce ainda nao tem nenhuma. Pede a senha uma vez.
function Install-Chave {
  $pasta = Join-Path $HOME '.ssh'
  $publica = @('id_ed25519.pub', 'id_ecdsa.pub', 'id_rsa.pub') |
    ForEach-Object { Join-Path $pasta $_ } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
  if (-not $publica) {
    New-Item -ItemType Directory -Force $pasta | Out-Null
    $privada = Join-Path $pasta 'id_ed25519'
    & ssh-keygen -q -t ed25519 -f $privada -N '' -C "reso-release@$env:COMPUTERNAME"
    if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen falhou' }
    $publica = "$privada.pub"
  }
  Write-Host "Instalando $(Split-Path $publica -Leaf) em $Server; a senha e pedida agora:" -ForegroundColor Yellow
  # A chave chega pela entrada padrao (o CR do PowerShell sai la) e so e
  # acrescentada se ainda nao esta; umask 077 porque o sshd recusa
  # authorized_keys aberto demais.
  $remoto = 'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; k=$(tr -d ''\r''); grep -qxF "$k" ~/.ssh/authorized_keys || echo "$k" >> ~/.ssh/authorized_keys'
  Get-Content $publica -Raw | & ssh -p "$Port" $Server $remoto
  if ($LASTEXITCODE -ne 0) { throw 'nao consegui instalar a chave no servidor' }
}

# -------------------------------------------------------------------- plano
$pubspec = Get-Content 'pubspec.yaml' -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw 'nao encontrei a versao no pubspec.yaml'
}
$versao = if ($Version) { $Version } else { $Matches[1] }
# Com -SkipBuild, reenvia o que ja estiver em build\installer.
$pacotesNoPlano = $SkipBuild -or -not ($SkipWindows -and $SkipLinux)
$webNoPlano = $SkipBuild -or -not $SkipWeb
if ($SkipBuild) { $SkipWindows = $true; $SkipLinux = $true; $SkipWeb = $true }

# A arvore precisa estar limpa: publicar o que nao esta commitado da uma tag
# que ninguem consegue reproduzir.
if (-not $SkipGit) {
  $sujos = @(& git status --porcelain) |
    Where-Object { $_ -notmatch '(pubspec\.yaml|lib/version\.dart)$' }
  if ($sujos) {
    Write-Host 'Ha mudancas nao commitadas:' -ForegroundColor Red
    $sujos | ForEach-Object { Write-Host "  $_" }
    throw 'commite (ou guarde) antes de publicar, ou use -SkipGit'
  }
}

# `\n` escrito nas notas vira quebra de linha (a mesma regra do
# UpdateManifest.notesFromCommandLine), no latest.json e na tag.
$notasTexto = $Notes.Replace("`r`n", "`n").Replace('\n', "`n").Trim()

Write-Host "ReSo $versao" -ForegroundColor Green
Write-Host "  $(Marca $SkipTests) testes    flutter analyze + flutter test"
Write-Host "  $(Marca $SkipWindows) windows   instalador reso-setup-$versao.exe"
Write-Host "  $(Marca $SkipLinux) linux     .deb e .tar.gz no WSL $(if ($WslDistro) { "($WslDistro)" } else { '(distribuicao padrao)' })"
Write-Host "  $(Marca $SkipWeb) web       PWA com WebAssembly (base $BaseHref)"
$destino = if ($Server) { "${Server}:${Port}" } else { '(servidor nao configurado: tool/release.local.json)' }
Write-Host "  $(Marca $SkipUpload) envio     $destino"
Write-Host "                desktop -> ~/$UpdatePath ($UpdateUrl)"
Write-Host "                web     -> ~/$WebPath"
Write-Host "  $(Marca $SkipGit) git       commit `"$versao`", tag v$versao e push"
if ($notasTexto) {
  Write-Host '  notas:' -ForegroundColor DarkGray
  $notasTexto -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
} else {
  Write-Host '  sem -Notes: a atualizacao aparece sem a lista do que mudou' -ForegroundColor Yellow
}

$porChave = $true
if (-not $SkipUpload) {
  $faltando = @(
    if (-not $Server) { 'server' }
    if (-not $UpdatePath -and $pacotesNoPlano) { 'updatePath' }
    if (-not $WebPath -and $webNoPlano) { 'webPath' }
  )
  if ($faltando) {
    throw @"
Falta configurar o servidor: $($faltando -join ', ').
Copie tool\release.example.json para tool\release.local.json (fica so na sua
maquina, o git ignora) e preencha. Ou use -SkipUpload para so gerar os arquivos.
"@
  }
  foreach ($ferramenta in @('ssh', 'scp')) {
    if (-not (Get-Command $ferramenta -ErrorAction SilentlyContinue)) {
      throw "$ferramenta nao encontrado: Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
    }
  }
  $porChave = Test-AcessoPorChave
  if ($porChave) {
    Write-Host '            acesso por chave: o envio nao vai pedir senha' -ForegroundColor DarkGray
  } else {
    Write-Host '            o servidor pede senha (sua chave nao esta instalada nele)' -ForegroundColor Yellow
  }
}

if (-not $Yes) {
  $resposta = Read-Host 'Continuar? [s/N]'
  if ($resposta -notmatch '^[sSyY]') { Write-Host 'cancelado'; return }
}

if (-not $SkipUpload -and -not $porChave -and -not $Yes) {
  $instalar = Read-Host 'Instalar sua chave no servidor agora? A senha e pedida uma vez, agora, e nas proximas publicacoes nao mais. [S/n]'
  if ($instalar -notmatch '^[nN]') {
    Install-Chave
    $porChave = Test-AcessoPorChave
    if ($porChave) { Write-Host 'Chave instalada: o envio nao vai pedir senha.' -ForegroundColor Green }
  }
}

# ------------------------------------------------------------------- versao
Etapa 'Versao'
$versao = & (Join-Path $PSScriptRoot 'sync_version.ps1') -Version $Version
Write-Host "ReSo $versao" -ForegroundColor Green

# ------------------------------------------------------------------- testes
if (-not $SkipTests) {
  Etapa 'Testes'
  & flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze reprovou' }
  & flutter test
  if ($LASTEXITCODE -ne 0) { throw 'flutter test reprovou' }
}

$outDir = Join-Path $root 'build\installer'

# ------------------------------------------------------------------ pacotes
# O Windows vem primeiro: o build_installer.ps1 faz `flutter clean`, que
# apagaria o que as outras etapas deixaram em build\.
if (-not $SkipWindows) {
  Etapa 'Instalador do Windows'
  & (Join-Path $PSScriptRoot 'build_installer.ps1')
}

if (-not $SkipLinux) {
  Etapa 'Pacotes do Linux (WSL)'
  if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'WSL nao encontrado: instale (wsl --install) ou use -SkipLinux'
  }
  $distro = if ($WslDistro) { @('-d', $WslDistro) } else { @() }
  # O caminho do projeto visto de dentro do WSL (D:\x vira /mnt/d/x).
  $origem = (& wsl.exe @distro -- wslpath -a ($root -replace '\\', '/')).Trim()
  if ($LASTEXITCODE -ne 0 -or -not $origem) { throw 'wslpath falhou' }
  & wsl.exe @distro -- bash "$origem/tool/build_linux_wsl.sh" $origem
  if ($LASTEXITCODE -ne 0) {
    throw 'os pacotes do Linux nao sairam (veja acima); use -SkipLinux para seguir sem eles'
  }
}

if (-not $SkipWeb) {
  Etapa 'Web (PWA + WebAssembly)'
  & (Join-Path $PSScriptRoot 'build_web.ps1') -BaseHref $BaseHref
}

$pacotes = @(
  "reso-setup-$versao.exe",
  "reso_${versao}_amd64.deb",
  "reso-$versao-linux-x64.tar.gz"
) | ForEach-Object { Join-Path $outDir $_ } | Where-Object { $pacotesNoPlano -and (Test-Path $_) }
$web = Join-Path $outDir "reso-web-$versao.tar.gz"
if (-not $webNoPlano -or -not (Test-Path $web)) { $web = $null }
if (-not $pacotes -and -not $web) { throw "nenhum pacote da versao $versao em $outDir" }

# ---------------------------------------------------------------- manifesto
$manifesto = $null
if ($pacotes) {
  Etapa 'Manifesto de atualizacao'
  # As notas vao por arquivo: o `dart` do Windows e um .bat, e o cmd corta o
  # argumento na primeira quebra de linha e engole as aspas duplas.
  $arquivoNotas = Join-Path ([IO.Path]::GetTempPath()) "reso-notas-$PID.txt"
  [IO.File]::WriteAllText($arquivoNotas, $Notes, [Text.UTF8Encoding]::new($false))
  try {
    & dart run tool/publish_update.dart "--base-url=$UpdateUrl" "--notes-file=$arquivoNotas"
  } finally {
    Remove-Item $arquivoNotas -ErrorAction SilentlyContinue
  }
  if ($LASTEXITCODE -ne 0) { throw 'nao consegui gerar o latest.json' }
  $manifesto = Join-Path $outDir 'latest.json'
}

# -------------------------------------------------------------------- envio
if ($SkipUpload) {
  Etapa 'Envio (pulado)'
  Write-Host "Arquivos prontos em $outDir" -ForegroundColor Green
} else {
  Etapa "Envio para ${Server}"
  foreach ($p in @($pacotes) + @($web) | Where-Object { $_ }) {
    Write-Host ("  {0,-34} {1,8:N1} MB" -f (Split-Path $p -Leaf), ((Get-Item $p).Length / 1MB))
  }

  # Tudo sobe para uma pasta de chegada e o script remoto distribui: um scp e
  # um ssh, nao importa quantos arquivos. O latest.json so e movido para o
  # lugar depois dos pacotes.
  $chegada = "reso-release-$versao"
  $arquivos = @($pacotes) + @($web, $manifesto, (Join-Path $PSScriptRoot 'serve_web.py')) |
    Where-Object { $_ }
  $nomeWeb = if ($web) { Split-Path $web -Leaf } else { '' }

  $remoto = @"
set -e
cd ~
c='$chegada'
if ls "`$c"/reso-setup-* "`$c"/reso_*.deb "`$c"/reso-*-linux-x64.tar.gz >/dev/null 2>&1; then
  mkdir -p '$UpdatePath'
  for f in "`$c"/reso-setup-* "`$c"/reso_*.deb "`$c"/reso-*-linux-x64.tar.gz; do
    [ -f "`$f" ] && mv -f "`$f" '$UpdatePath/'
  done
  [ -f "`$c/latest.json" ] && mv -f "`$c/latest.json" '$UpdatePath/latest.json'
  echo "desktop: $UpdateUrl/latest.json"
fi
if [ -n '$nomeWeb' ]; then
  w='$WebPath'
  rm -rf "`$w.new" "`$w.old"
  mkdir -p "`$w.new"
  tar -xzf "`$c/$nomeWeb" -C "`$w.new"
  mv -f "`$c/serve_web.py" "`$(dirname "`$w")/reso_serve_web.py"
  [ -d "`$w" ] && mv "`$w" "`$w.old"
  mv "`$w.new" "`$w"
  rm -rf "`$w.old"
  # O reso_web.service antigo servia a pasta pelo WorkingDirectory, que
  # ficaria apontando para a pasta velha: reiniciar resolve.
  if systemctl cat reso_web.service >/dev/null 2>&1; then
    systemctl restart reso_web.service
    echo 'web: reso_web.service reiniciado'
  else
    echo "web: ~/`$w atualizada (reso_web.service nao encontrado)"
  fi
fi
rm -rf "`$c"
"@ -replace "`r", ''

  while ($true) {
    if (-not $porChave) {
      [Console]::Beep(880, 300)
      Write-Host 'A senha do servidor sera pedida agora (envio e instalacao).' -ForegroundColor Yellow
    }
    & ssh -p "$Port" $Server "mkdir -p ~/$chegada"
    $codigo = $LASTEXITCODE
    if ($codigo -eq 0) {
      & scp -P "$Port" @arquivos "${Server}:$chegada/"
      $codigo = $LASTEXITCODE
    }
    if ($codigo -eq 0) {
      $remoto | & ssh -p "$Port" $Server 'bash -s'
      $codigo = $LASTEXITCODE
    }
    if ($codigo -eq 0) { break }
    Write-Host "envio falhou ($codigo)." -ForegroundColor Red
    $repetir = if ($Yes) { 'n' } else { Read-Host 'Tentar o envio de novo? Os arquivos ja estao prontos. [S/n]' }
    if ($repetir -match '^[nN]') {
      throw "envio falhou ($codigo); para so reenviar: -SkipTests -SkipBuild e as mesmas -Notes"
    }
  }
}

# ---------------------------------------------------------------------- git
if (-not $SkipGit) {
  Etapa "Commit, tag v$versao e push"
  & git diff --quiet -- pubspec.yaml lib/version.dart
  if ($LASTEXITCODE -ne 0) {
    & git add pubspec.yaml lib/version.dart
    & git commit -m "$versao"
    if ($LASTEXITCODE -ne 0) { throw 'git commit falhou' }
  } else {
    Write-Host 'a versao ja estava commitada' -ForegroundColor DarkGray
  }

  & git rev-parse -q --verify "refs/tags/v$versao" > $null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "a tag v$versao ja existe: mantida como esta" -ForegroundColor Yellow
  } else {
    $mensagem = if ($notasTexto) { "ReSo $versao`n`n$notasTexto`n" } else { "ReSo $versao`n" }
    $arquivoTag = Join-Path ([IO.Path]::GetTempPath()) "reso-tag-$PID.txt"
    [IO.File]::WriteAllText($arquivoTag, $mensagem, [Text.UTF8Encoding]::new($false))
    try {
      & git tag -a "v$versao" -F $arquivoTag --cleanup=whitespace
    } finally {
      Remove-Item $arquivoTag -ErrorAction SilentlyContinue
    }
    if ($LASTEXITCODE -ne 0) { throw 'git tag falhou' }
  }

  $ramo = (& git rev-parse --abbrev-ref HEAD).Trim()
  & git push origin $ramo --follow-tags
  if ($LASTEXITCODE -ne 0) { throw 'git push falhou' }
}

Write-Host ''
if ($SkipUpload) {
  Write-Host "ReSo $versao pronto em $outDir (nada foi enviado)." -ForegroundColor Green
} else {
  Write-Host "ReSo $versao publicado." -ForegroundColor Green
}
