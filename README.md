<p align="center">
  <img src="assets/icon/app_icon.png" width="128" alt="ReSo">
</p>

<h1 align="center">ReSo :)</h1>

<p align="center">
  <b>Você lembra de uma palavra. O ReSo lembra da senha.</b><br>
  <a href="https://github.com/renansoaress/reso/actions/workflows/ci.yml"><img src="https://github.com/renansoaress/reso/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/renansoaress/reso/releases/latest"><img src="https://img.shields.io/github/v/release/renansoaress/reso?label=vers%C3%A3o" alt="Versão"></a>
</p>

---

Digite `github` e o ReSo devolve algo como `b+2z+ABdb514`. Digite `github` de
novo amanhã, no celular, no notebook do trabalho ou na casa da sua avó: sai
**o mesmo** `b+2z+ABdb514`. Sem nuvem, sem cadastro, sem banco de dados para
vazar. Não tem o que vazar: a senha não fica guardada em lugar nenhum, ela é
recalculada toda vez.

Quer que só você chegue nas suas senhas? Coloque uma **chave** nas
configurações. Com ela, o mesmo `github` vira outra coisa, e quem não tem a
chave pode digitar `github` o dia inteiro que não acerta.

## Como usa

1. Abre (o cursor já está no campo, não precisa nem clicar).
2. Digita.
3. **Enter**. Copiado.

Pronto, era isso. `Esc` limpa, `Ctrl+,` abre as configurações.

## Onde roda

| | |
|---|---|
| **Windows** | instalador na [última versão](https://github.com/renansoaress/reso/releases/latest); se atualiza sozinho |
| **Linux** | `.deb` ou `.tar.gz` na mesma página; também se atualiza sozinho |
| **iPhone / Android** | abra a versão web e *Adicionar à Tela de Início*. Vira app, com ícone e tudo, e funciona offline |
| **Navegador** | a mesma versão web, em WebAssembly |

Tema claro, escuro ou automático, como você preferir.

## Para quem vai mexer no código

Flutter 3.47+. O essencial:

```sh
flutter run                 # roda
flutter test                # testa (inclusive se o ReSo de sempre continua o mesmo)
```

Os scripts de `tool/`:

| Script | O que faz |
|---|---|
| `tool/release.ps1 -Version X.Y.Z -Notes "..."` | publica tudo: testes, instalador do Windows, pacotes do Linux (no WSL), web, atualização automática, site, tag e push |
| `tool/build_installer.ps1` / `.sh` | só o instalador do Windows / os pacotes do Linux |
| `tool/build_web.ps1 -Serve` | só a web (PWA + WebAssembly), e já serve em `localhost:5500` |
| `tool/make_icon.py` | redesenha o ícone em todos os tamanhos e plataformas |

O servidor para onde o `release.ps1` envia não fica no repositório: copie o
`tool/release.example.json` para `tool/release.local.json` e preencha (o git
ignora esse arquivo).

Ao subir uma tag `vX.Y.Z`, o GitHub Actions compila as três versões e monta
a Release com os links de cada uma.

> ⚠️ O algoritmo em `lib/reso.dart` é sagrado: mudou um caractere, mudou a
> senha de todo mundo. O `test/reso_test.dart` está lá de guarda.
