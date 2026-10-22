// Gera o `latest.json`, o manifesto que o ReSo instalado consulta.
//
//   dart run tool/publish_update.dart
//   dart run tool/publish_update.dart --notes="O que mudou."
//
// Em Dart, e nao em PowerShell/bash, para haver uma implementacao so do
// formato, a mesma que o app le (lib/update/update_service.dart).
//
// Antes de gravar, busca o manifesto que ja esta no ar: se for da mesma
// versao, os pacotes que faltam aqui sao preservados. Assim publicar so o
// Windows nao derruba o pacote do Linux, e vice-versa.
//
// Opcoes:
//   --base-url=<url>   endereco publico da pasta (padrao: a pasta do
//                      updateManifestUrl, a que o app consulta)
//   --notes=<texto>    o que aparece na janela de atualizacao; `\n` quebra
//   --notes-file=<arq> o mesmo, lido de um arquivo UTF-8 (o release.ps1 passa
//                      assim: o `dart` do Windows e um .bat, e o cmd corta o
//                      argumento na primeira quebra de linha)
//   --dir=<pasta>      onde estao os pacotes (padrao: build/installer)
//   --no-merge         ignora o manifesto que esta no ar
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:reso/update/update_service.dart';

Future<void> main(List<String> args) async {
  final options = _parse(args);
  final baseUrl =
      (options['base-url'] ?? updateManifestUrl.substring(0, updateManifestUrl.lastIndexOf('/')))
          .replaceAll(RegExp(r'/+$'), '');

  final version = _versionFromPubspec();
  final directory = Directory(options['dir'] ?? 'build/installer');
  if (!directory.existsSync()) _fail('nao achei ${directory.path}');

  UpdateAsset? asset(String fileName) {
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    stdout.writeln('  $fileName (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB)');
    return UpdateAsset(
      url: '$baseUrl/$fileName',
      sha256: sha256.convert(bytes).toString(),
      size: bytes.length,
    );
  }

  stdout.writeln('Pacotes da versao $version em ${directory.path}:');
  var manifest = UpdateManifest(
    version: version,
    notes: UpdateManifest.notesFromCommandLine(_notes(options)),
    windows: asset('reso-setup-$version.exe'),
    linuxDeb: asset('reso_${version}_amd64.deb'),
    linuxTarGz: asset('reso-$version-linux-x64.tar.gz'),
  );
  if (manifest.windows == null && manifest.linuxDeb == null && manifest.linuxTarGz == null) {
    _fail('nenhum pacote da versao $version em ${directory.path}');
  }

  if (!options.containsKey('no-merge')) {
    UpdateManifest? remote;
    try {
      remote = await const UpdateService().fetch('$baseUrl/latest.json');
    } on UpdateFailure catch (error) {
      stdout.writeln('Manifesto no ar: nenhum ($error), publicando do zero.');
    }
    if (remote != null && remote.version == version) {
      stdout.writeln('Aproveitando o manifesto no ar (mesma versao).');
    }
    manifest = manifest.mergedWith(remote);
  }

  final output = File('${directory.path}${Platform.pathSeparator}latest.json');
  // Sem BOM: tres bytes invisiveis no comeco fariam o app recusar o JSON.
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n',
    encoding: utf8,
  );
  stdout.writeln('\nManifesto de $version em ${output.path}');
  stdout.writeln(output.readAsStringSync());
}

String _versionFromPubspec() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) _fail('rode a partir da raiz do projeto');
  final match = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  if (match == null) _fail('nao encontrei a versao no pubspec.yaml');
  return match.group(1)!;
}

String _notes(Map<String, String> options) {
  final path = options['notes-file'] ?? '';
  if (path.isEmpty) return options['notes'] ?? '';
  final file = File(path);
  if (!file.existsSync()) _fail('nao achei $path');
  return file.readAsStringSync(encoding: utf8);
}

Map<String, String> _parse(List<String> args) {
  final options = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) _fail('argumento desconhecido: $arg');
    final parts = arg.substring(2).split('=');
    options[parts.first] = parts.length > 1 ? parts.sublist(1).join('=') : '';
  }
  return options;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
