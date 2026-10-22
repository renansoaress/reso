import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reso/reso.dart';
import 'package:reso/version.dart';

void main() {
  // Saidas da versao 2.0.2: o ReSo de um texto nunca pode mudar.
  const golden = [
    ['github', '', 'b+2z+ABdb514'],
    ['github', 'chave', '\$t7!WZc82816'],
    ['a', '', '0%Y175!Cddf1'],
    ['Olá, mundo!', 'x', '4+X*wecD6c51'],
    ['email@exemplo.com', 'segredo 123', '30--6XCxe2b0'],
    ['ç€😀', 'ñ', '1aY!A#xd8261'],
  ];

  test('gera o mesmo ReSo de sempre', () {
    for (final [text, key, expected] in golden) {
      expect(reso(text, key: key), expected, reason: '"$text" com chave "$key"');
    }
  });

  test('texto vazio nao gera nada', () {
    expect(reso(''), '');
    expect(reso('', key: 'chave'), '');
  });

  test('lib/version.dart acompanha o pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version, reason: 'rode tool/sync_version.ps1');
  });
}
