// Gera o build/web/sw.js a partir do tool/sw_template.js.
//
//   dart run tool/make_sw.dart [build/web]
//
// Chamado pelo tool/build_web.* depois do `flutter build web`: cada arquivo
// do build entra com o seu SHA-256, e o hash do conjunto vira a versao do
// cache. Mudou um byte, o navegador ve um sw.js novo e atualiza o app.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

// Fica de fora do cache: o proprio service worker e restos do build.
const _skip = {'sw.js', 'flutter_service_worker.js', '.last_build_id', 'assets/NOTICES'};

// Baixado ja na instalacao. O motor (wasm ou js) fica para o primeiro uso:
// so o navegador sabe qual dos dois vai usar.
bool _isCore(String key) =>
    key == 'index.html' ||
    key == 'flutter_bootstrap.js' ||
    key == 'flutter.js' ||
    key == 'manifest.json' ||
    key == 'favicon.png' ||
    key.startsWith('icons/') ||
    key.startsWith('assets/');

void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'build/web' : args.first);
  if (!File('${dir.path}/index.html').existsSync()) {
    stderr.writeln('nao achei ${dir.path}/index.html: rode o flutter build web antes');
    exit(1);
  }

  final resources = <String, String>{};
  final files = dir.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final key = file.path.substring(dir.path.length + 1).replaceAll('\\', '/');
    if (_skip.contains(key)) continue;
    resources[key] = sha256.convert(file.readAsBytesSync()).toString().substring(0, 16);
  }

  final all = resources.entries.map((e) => '${e.key}:${e.value}').join('\n');
  final build = sha256.convert(utf8.encode(all)).toString().substring(0, 16);
  final core = resources.keys.where(_isCore).toList();

  final template = File('tool/sw_template.js').readAsStringSync();
  final sw = template
      .replaceFirst("'__BUILD__'", jsonEncode(build))
      .replaceFirst('__RESOURCES__', const JsonEncoder.withIndent('  ').convert(resources))
      .replaceFirst('__CORE__', jsonEncode(core));
  File('${dir.path}/sw.js').writeAsStringSync(sw);

  stdout.writeln(
    'sw.js: build $build, ${resources.length} arquivos (${core.length} na instalacao)',
  );
}
