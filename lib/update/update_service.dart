import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Onde o ReSo instalado procura versao nova. O tool/release.ps1 publica ali
/// os pacotes e o manifesto.
const updateManifestUrl = 'https://renans.dev/static/reso/latest.json';

/// Um arquivo publicado para uma plataforma.
class UpdateAsset {
  const UpdateAsset({required this.url, this.sha256 = '', this.size = 0});

  final String url;

  /// SHA-256 do arquivo, em hexadecimal. Vazio dispensa a verificacao.
  final String sha256;

  /// Tamanho em bytes, para a barra de progresso.
  final int size;

  String get fileName {
    final path = Uri.tryParse(url)?.pathSegments;
    if (path == null || path.isEmpty) return 'reso-update';
    return path.last;
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    if (sha256.isNotEmpty) 'sha256': sha256,
    if (size > 0) 'size': size,
  };

  static UpdateAsset? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final url = json['url']?.toString() ?? '';
    if (url.isEmpty) return null;
    return UpdateAsset(
      url: url,
      sha256: (json['sha256']?.toString() ?? '').trim().toLowerCase(),
      size: json['size'] is num ? (json['size'] as num).toInt() : 0,
    );
  }
}

/// O que o servidor anuncia como versao mais recente: um JSON estatico, sem
/// nada rodando do outro lado.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    this.notes = '',
    this.windows,
    this.linuxDeb,
    this.linuxTarGz,
  });

  final String version;
  final String notes;
  final UpdateAsset? windows;
  final UpdateAsset? linuxDeb;
  final UpdateAsset? linuxTarGz;

  /// O arquivo que serve para a plataforma onde o ReSo esta rodando.
  UpdateAsset? get assetForPlatform {
    if (Platform.isWindows) return windows;
    if (Platform.isLinux) return assetForLinux(UpdateService.linuxInstall);
    return null;
  }

  /// O `.deb` para quem veio do `.deb`, o `.tar.gz` para a pasta do usuario.
  /// Faltando o preferido, vai o outro, que o [UpdateService.launch] ao menos
  /// mostra na pasta.
  UpdateAsset? assetForLinux(LinuxInstall install) =>
      install == LinuxInstall.folder ? linuxTarGz ?? linuxDeb : linuxDeb ?? linuxTarGz;

  Map<String, dynamic> toJson() => {
    'version': version,
    'notes': notes,
    if (windows != null) 'windows': windows!.toJson(),
    if (linuxDeb != null) 'linux_deb': linuxDeb!.toJson(),
    if (linuxTarGz != null) 'linux_targz': linuxTarGz!.toJson(),
  };

  /// Completa o que falta com o que [other] ja anunciava, se for **da mesma
  /// versao**: publicar so o Windows nao derruba o pacote do Linux, e
  /// vice-versa. De outra versao, apontaria a nova para o pacote velho.
  UpdateManifest mergedWith(UpdateManifest? other) {
    if (other == null || other.version != version) return this;
    return UpdateManifest(
      version: version,
      notes: notes.isNotEmpty ? notes : other.notes,
      windows: windows ?? other.windows,
      linuxDeb: linuxDeb ?? other.linuxDeb,
      linuxTarGz: linuxTarGz ?? other.linuxTarGz,
    );
  }

  /// As notas como chegam da linha de comando: `\n` escrito vira quebra de
  /// linha, CRLF vira `\n` e o BOM sai.
  static String notesFromCommandLine(String raw) {
    final text = raw.startsWith('\u{feff}') ? raw.substring(1) : raw;
    return text.replaceAll('\r\n', '\n').replaceAll(r'\n', '\n').trim();
  }

  /// Le o manifesto em [body]; nulo se o JSON e invalido ou nao tem versao.
  static UpdateManifest? parse(String body) {
    try {
      final text = body.trim();
      final data = jsonDecode(text.startsWith('\u{feff}') ? text.substring(1) : text);
      if (data is! Map<String, dynamic>) return null;
      final version = data['version']?.toString().trim() ?? '';
      if (version.isEmpty) return null;
      return UpdateManifest(
        version: version,
        notes: data['notes']?.toString() ?? '',
        windows: UpdateAsset.fromJson(data['windows']),
        linuxDeb: UpdateAsset.fromJson(data['linux_deb']),
        linuxTarGz: UpdateAsset.fromJson(data['linux_targz']),
      );
    } on FormatException {
      return null;
    }
  }
}

/// Como o ReSo em uso foi instalado no Linux: decide o pacote e quem instala.
enum LinuxInstall {
  /// Pelo `.deb`, em `/opt/reso`: o `apt` instala, com a senha pedida pelo
  /// `pkexec`.
  deb,

  /// Numa pasta em que o usuario escreve (o `install.sh`): o proprio ReSo
  /// troca os arquivos.
  folder,

  /// Em outro lugar: o pacote so e mostrado na pasta.
  readOnly,
}

/// Falha ao verificar, baixar ou instalar uma atualizacao.
class UpdateFailure implements Exception {
  const UpdateFailure(this.message);

  /// O motivo, ja no texto que o usuario le.
  final String message;

  @override
  String toString() => message;
}

/// Consulta o servidor, baixa o instalador e o executa.
class UpdateService {
  const UpdateService({
    this.attempts = 6,
    this.retryDelay = const Duration(seconds: 2),
    this.stallTimeout = const Duration(seconds: 30),
  });

  /// Quantas vezes o download tenta, contando a primeira. Cada tentativa
  /// continua de onde a anterior parou.
  final int attempts;

  /// Espera antes de tentar de novo, multiplicada pelo numero da tentativa.
  final Duration retryDelay;

  /// Tempo sem chegar nenhum byte depois do qual a conexao e dada como morta.
  final Duration stallTimeout;

  /// Positivo quando [a] e mais nova que [b]. Como texto, "2.0.9" passaria
  /// de "2.0.10".
  static int compareVersions(String a, String b) {
    final left = _parts(a);
    final right = _parts(b);
    for (var i = 0; i < 3; i++) {
      final diff = left[i] - right[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  static List<int> _parts(String version) {
    final numbers = version
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers;
  }

  /// Le o manifesto publicado em [url]; lanca [UpdateFailure] se falhar.
  Future<UpdateManifest> fetch(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw UpdateFailure('O servidor respondeu HTTP ${response.statusCode}.');
      }
      final body = await response.transform(utf8.decoder).join();
      final manifest = UpdateManifest.parse(body);
      if (manifest == null) throw const UpdateFailure('O manifesto de atualização é inválido.');
      return manifest;
    } on SocketException catch (error) {
      throw UpdateFailure(error.osError?.message ?? error.message);
    } on HttpException catch (error) {
      throw UpdateFailure(error.message);
    } on TimeoutException {
      throw const UpdateFailure('O servidor não respondeu.');
    } finally {
      client.close(force: true);
    }
  }

  /// Baixa [asset] para a pasta temporaria e confere o SHA-256.
  ///
  /// O arquivo sera **executado**: conferir o hash anunciado no manifesto
  /// (que veio por HTTPS) impede que um download truncado ou trocado rode na
  /// maquina. Uma conexao que cai no meio nao perde o que ja veio: a
  /// tentativa seguinte pede so o resto (`Range`).
  Future<File> download(UpdateAsset asset, {void Function(double progress)? onProgress}) async {
    final target = File('${Directory.systemTemp.path}${Platform.pathSeparator}${asset.fileName}');
    var received = 0;
    var total = asset.size;
    var sink = target.openWrite();
    var done = false;
    try {
      for (var attempt = 1; ; attempt++) {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        try {
          final request = await client.getUrl(Uri.parse(asset.url));
          if (received > 0) {
            request.headers.set(HttpHeaders.rangeHeader, 'bytes=$received-');
          }
          final response = await request.close().timeout(stallTimeout);
          if (received > 0 && response.statusCode == HttpStatus.ok) {
            // O servidor ignorou o `Range` e mandou tudo de novo: recomeca.
            await sink.close();
            sink = target.openWrite();
            received = 0;
          } else if (response.statusCode != HttpStatus.ok &&
              response.statusCode != HttpStatus.partialContent) {
            throw UpdateFailure('O servidor respondeu HTTP ${response.statusCode}.');
          }
          if (response.contentLength > 0) total = received + response.contentLength;
          await for (final chunk in response.timeout(stallTimeout)) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0) onProgress?.call(received / total);
          }
          if (total > 0 && received < total) {
            throw const HttpException('conexão fechada antes do fim');
          }
          break;
        } on UpdateFailure {
          rethrow;
        } on Exception catch (error) {
          if (attempt >= attempts) throw UpdateFailure(_reason(error));
          await sink.flush();
          await Future<void>.delayed(retryDelay * attempt);
        } finally {
          client.close(force: true);
        }
      }
      await sink.flush();
      await sink.close();

      if (asset.sha256.isNotEmpty) {
        final digest = sha256.convert(await target.readAsBytes()).toString();
        if (digest != asset.sha256) {
          throw const UpdateFailure('O arquivo baixado não confere. Tente de novo.');
        }
      }
      done = true;
      return target;
    } on FileSystemException catch (error) {
      throw UpdateFailure(error.message);
    } finally {
      if (!done) {
        // Pela metade ou adulterado, o arquivo nao fica.
        try {
          await sink.close();
        } on Exception {
          // Ja fechado.
        }
        try {
          if (target.existsSync()) await target.delete();
        } on FileSystemException {
          // Preso pelo antivirus, por exemplo: a pasta temporaria limpa.
        }
      }
    }
  }

  static String _reason(Exception error) => switch (error) {
    SocketException(:final osError, :final message) => osError?.message ?? message,
    HttpException(:final message) => message,
    TimeoutException() => 'O servidor parou de responder.',
    _ => error.toString(),
  };

  /// Linha de comando do instalador do Windows.
  ///
  /// O `/DIR` e obrigatorio: sem ele o Inno Setup instala onde o ReSo foi
  /// instalado da primeira vez, e um programa movido de pasta atualizaria uma
  /// copia que nao esta em uso. O `/reabrir=1` e do installer/windows/reso.iss:
  /// abre o ReSo novo no fim.
  static List<String> installerArguments({required String installDir, required String scope}) => [
    '/SILENT',
    '/CLOSEAPPLICATIONS',
    '/NORESTARTAPPLICATIONS',
    '/reabrir=1',
    scope,
    '/DIR=$installDir',
  ];

  /// O mesmo AppId do installer/windows/reso.iss (um teste confere).
  static const appId = '{AFB0A203-E110-4725-91EA-0AAE05533ABF}';

  /// O escopo do registro existente, ou o que a pasta permite. Repetir o
  /// escopo registrado evita uma segunda entrada em "Adicionar ou remover
  /// programas"; `/CURRENTUSER` dispensa o UAC no meio da atualizacao.
  static Future<String> scopeFor(String installDir) async =>
      await registeredScope() ?? (canWriteTo(installDir) ? '/CURRENTUSER' : '/ALLUSERS');

  static Future<String?> registeredScope() async {
    const suffix =
        r'Software\Microsoft\Windows\CurrentVersion\Uninstall'
        '\\${appId}_is1';
    Future<bool> registered(String hive) async {
      try {
        final result = await Process.run('reg', [
          'query',
          '$hive\\$suffix',
          '/v',
          'UninstallString',
        ]);
        return result.exitCode == 0;
      } on ProcessException {
        return false;
      }
    }

    if (await registered('HKCU')) return '/CURRENTUSER';
    if (await registered('HKLM')) return '/ALLUSERS';
    return null;
  }

  /// Se o usuario escreve em [directory]. Testa escrevendo de fato: as
  /// permissoes do Windows tem camadas demais para um palpite.
  static bool canWriteTo(String directory) {
    final probe = File('$directory${Platform.pathSeparator}.reso-teste-de-escrita');
    try {
      probe.writeAsStringSync('.', flush: true);
      return true;
    } on FileSystemException {
      return false;
    } finally {
      try {
        if (probe.existsSync()) probe.deleteSync();
      } on FileSystemException {
        // Nao conseguir apagar o teste nao muda a resposta.
      }
    }
  }

  /// Como o ReSo em uso foi instalado no Linux, decidido uma vez.
  static final LinuxInstall linuxInstall = linuxInstallFor(Platform.resolvedExecutable);

  /// Pelo `.deb` se o `dpkg` registra [exe] no pacote `reso`, numa pasta do
  /// usuario se ele escreve ali, senao em lugar nenhum atualizavel.
  static LinuxInstall linuxInstallFor(String exe, {String dpkgInfo = '/var/lib/dpkg/info'}) {
    try {
      final list = File('$dpkgInfo/reso.list');
      if (list.existsSync() && list.readAsLinesSync().any((line) => line.trim() == exe)) {
        return LinuxInstall.deb;
      }
    } on FileSystemException {
      // Sem como ler o registro do dpkg: decide a pasta.
    }
    return canWriteTo(File(exe).parent.path) ? LinuxInstall.folder : LinuxInstall.readOnly;
  }

  /// Instala o [deb] baixado. Fora do root, o `pkexec` pede a senha numa
  /// janela do sistema (o ReSo nao tem terminal).
  static List<String> debInstallCommand(String deb, {required bool root, required bool hasApt}) => [
    if (!root) 'pkexec',
    if (hasApt) ...[
      '/usr/bin/apt-get',
      'install',
      '-y',
      '--allow-downgrades',
      deb,
    ] else ...[
      '/usr/bin/dpkg',
      '-i',
      deb,
    ],
  ];

  /// A falha do comando do [debInstallCommand], ou nula se deu certo. Fora do
  /// root, 126 e 127 sao do `pkexec`: senha recusada ou janela fechada.
  static UpdateFailure? debFailure(int exitCode, {required bool root}) {
    if (exitCode == 0) return null;
    if (!root && (exitCode == 126 || exitCode == 127)) {
      return const UpdateFailure(
        'Instalação cancelada: a senha de administrador não foi informada.',
      );
    }
    return UpdateFailure('O pacote não foi instalado (código $exitCode).');
  }

  /// O ajudante que reabre o ReSo depois que ele fecha, rodado pelo `/bin/sh`
  /// com: o pid que fecha, o executavel, e numa atualizacao de pasta, a pasta
  /// do programa novo, a do programa em uso e a temporaria a apagar no fim.
  /// Os arquivos so sao trocados com o ReSo fechado.
  static const relaunchScript = r'''
pid="$1"; exe="$2"; novo="$3"; pasta="$4"; temp="$5"
i=0
while kill -0 "$pid" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 600 ]; then
    [ -n "$temp" ] && rm -rf "$temp"
    exit 1
  fi
  sleep 0.1
done
if [ -n "$novo" ]; then
  if cp --help 2>&1 | grep -q -- --remove-destination; then
    cp -R -f --remove-destination "$novo/." "$pasta/"
  else
    cp -R -f "$novo/." "$pasta/"
  fi
  chmod +x "$exe"
fi
[ -n "$temp" ] && rm -rf "$temp"
exec "$exe"
''';

  /// A pasta do programa dentro do `.tar.gz` extraido em [unpacked]
  /// (`reso-<versao>/bundle`, ver tool/build_installer.sh), ou nula.
  static Directory? findBundle(Directory unpacked) => unpacked
      .listSync()
      .whereType<Directory>()
      .map((d) => Directory('${d.path}/bundle'))
      .where((b) => File('${b.path}/reso').existsSync())
      .firstOrNull;

  Future<bool> _launchLinux(File file) async {
    final exe = Platform.resolvedExecutable;
    final name = file.path;
    if (name.endsWith('.deb') && linuxInstall == LinuxInstall.deb) {
      final root = await _isRoot();
      if (root || File('/usr/bin/pkexec').existsSync()) {
        final command = debInstallCommand(
          name,
          root: root,
          hasApt: File('/usr/bin/apt-get').existsSync(),
        );
        final result = await Process.run(command.first, command.sublist(1));
        final failure = debFailure(result.exitCode, root: root);
        if (failure != null) throw failure;
        await _relaunchAfterExit(exe);
        return true;
      }
    }
    if (name.endsWith('.tar.gz') && linuxInstall == LinuxInstall.folder) {
      final temp = await Directory.systemTemp.createTemp('reso-atualizacao');
      var handedOver = false;
      try {
        final unpacked = await Process.run('tar', ['-xzf', name, '-C', temp.path]);
        final bundle = unpacked.exitCode == 0 ? findBundle(temp) : null;
        if (bundle == null) throw const UpdateFailure('O pacote baixado não é do ReSo.');
        await _relaunchAfterExit(
          exe,
          bundle: bundle.path,
          installDir: File(exe).parent.path,
          cleanup: temp.path,
        );
        handedOver = true;
        return true;
      } finally {
        // Entregue ao ajudante, e ele quem apaga a temporaria.
        if (!handedOver) await temp.delete(recursive: true);
      }
    }
    await Process.start('xdg-open', [file.parent.path], mode: ProcessStartMode.detached);
    return false;
  }

  static Future<bool> _isRoot() async {
    try {
      final result = await Process.run('id', ['-u']);
      return (result.stdout as String).trim() == '0';
    } on ProcessException {
      return false;
    }
  }

  static Future<void> _relaunchAfterExit(
    String exe, {
    String bundle = '',
    String installDir = '',
    String cleanup = '',
  }) async {
    await Process.start('/bin/sh', [
      '-c',
      relaunchScript,
      'reso-atualizacao',
      '$pid',
      exe,
      bundle,
      installDir,
      cleanup,
    ], mode: ProcessStartMode.detached);
  }

  /// Entrega o arquivo baixado ao sistema. Retorna `true` quando o ReSo deve
  /// fechar para a atualizacao terminar.
  ///
  /// No Windows o instalador roda desacoplado e ele mesmo fecha o ReSo
  /// (`CloseApplications=yes` no reso.iss) e o reabre. No Linux quem fecha e
  /// o proprio ReSo, e o [relaunchScript] o reabre. Sem como instalar, o
  /// pacote e mostrado na pasta e retorna `false`.
  Future<bool> launch(File file) async {
    try {
      if (Platform.isWindows) {
        final folder = File(Platform.resolvedExecutable).parent.path;
        await Process.start(
          file.path,
          installerArguments(installDir: folder, scope: await scopeFor(folder)),
          mode: ProcessStartMode.detached,
        );
        return true;
      }
      if (Platform.isLinux) return await _launchLinux(file);
    } on FileSystemException catch (error) {
      throw UpdateFailure(error.message);
    } on ProcessException {
      throw const UpdateFailure('Não foi possível iniciar o instalador.');
    }
    return false;
  }
}
