; Instalador do ReSo para Windows (Inno Setup 6).
;
; Compilado pelo `tool/build_installer.ps1`, que faz o build do Flutter, le a
; versao do pubspec.yaml e chama o ISCC com as definicoes abaixo.
;
;   pwsh tool/build_installer.ps1
;
; Instala por usuario (sem UAC), cria atalho no menu Iniciar e, se o usuario
; quiser, na area de trabalho.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif

#define AppName "ReSo"
#define AppExe "reso.exe"

[Setup]
; O AppId identifica o programa entre versoes: mantendo-o fixo, instalar uma
; versao nova substitui a anterior em vez de deixar duas lado a lado.
AppId={{AFB0A203-E110-4725-91EA-0AAE05533ABF}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppName}
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=yes
; Sem UAC: instala em %LOCALAPPDATA%\Programs\ReSo. Quem quiser o programa
; para todos os usuarios da maquina roda o instalador como administrador.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=reso-setup-{#AppVersion}
SetupIconFile={#SourcePath}\..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName} {#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Fecha o ReSo aberto antes de substituir os arquivos. Quem o reabre e a
; entrada [Run] com `Check: DeveReabrir`, e nao o Restart Manager (que so
; reabre quem chamou RegisterApplicationRestart).
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; O runner, as DLLs do Flutter e a pasta `data` (assets e icudtl.dat).
Source: "{#SourceDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; `runasoriginaluser`: um Setup elevado (instalacao para todos os usuarios)
; nao abre o ReSo como administrador.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent runasoriginaluser
; Reabertura pedida pelo proprio ReSo ao se atualizar (`/reabrir=1`, ver
; lib/update/update_service.dart). Roda tambem em modo silencioso; sem
; `postinstall`, nao vira uma caixa de selecao do assistente.
Filename: "{app}\{#AppExe}"; Flags: nowait runasoriginaluser; Check: DeveReabrir

[UninstallDelete]
; As preferencias (chave e tema) ficam em %APPDATA%\com.example\reso e nao
; sao apagadas: quem reinstala reencontra a propria configuracao.
Type: dirifempty; Name: "{app}"

[Code]
{ O ReSo pediu para ser reaberto depois de se atualizar? Quem instala na mao
  nao passa nada e cai na caixa de selecao normal do assistente. }
function DeveReabrir(): Boolean;
begin
  Result := ExpandConstant('{param:reabrir|0}') = '1';
end;
