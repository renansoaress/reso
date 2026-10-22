import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reso/update/update_service.dart';

void main() {
  test('compara versoes numero a numero', () {
    expect(UpdateService.compareVersions('2.0.10', '2.0.9'), greaterThan(0));
    expect(UpdateService.compareVersions('2.1.0', '2.1.0'), 0);
    expect(UpdateService.compareVersions('2.0', '2.0.1'), lessThan(0));
  });

  test('le o manifesto e completa com o da mesma versao no ar', () {
    final local = UpdateManifest.parse(
      '\u{feff}{"version":"2.1.0","notes":"","windows":{"url":"https://x/a.exe","sha256":"AB","size":3}}',
    )!;
    expect(local.windows!.sha256, 'ab');
    expect(local.windows!.fileName, 'a.exe');

    final remote = UpdateManifest.parse(
      '{"version":"2.1.0","notes":"Novidades","linux_deb":{"url":"https://x/b.deb"}}',
    );
    final merged = local.mergedWith(remote);
    expect(merged.notes, 'Novidades');
    expect(merged.linuxDeb!.url, 'https://x/b.deb');
    expect(merged.windows!.url, 'https://x/a.exe');

    final old = UpdateManifest.parse('{"version":"2.0.2","linux_deb":{"url":"https://x/c.deb"}}');
    expect(local.mergedWith(old).linuxDeb, isNull);

    expect(UpdateManifest.parse('{"notes":"sem versao"}'), isNull);
    expect(UpdateManifest.parse('nao e json'), isNull);
    expect(UpdateManifest.notesFromCommandLine(r'Linha 1\nLinha 2'), 'Linha 1\nLinha 2');
  });

  test('o AppId e o mesmo do instalador', () {
    final iss = File('installer/windows/reso.iss').readAsStringSync();
    expect(iss, contains('AppId={${UpdateService.appId}'));
    expect(
      UpdateService.installerArguments(installDir: r'C:\ReSo', scope: '/CURRENTUSER'),
      containsAll(['/SILENT', '/reabrir=1', r'/DIR=C:\ReSo']),
    );
  });

  test('reconhece como o ReSo foi instalado no Linux', () {
    final temp = Directory.systemTemp.createTempSync('reso-dpkg');
    addTearDown(() => temp.deleteSync(recursive: true));
    File('${temp.path}/reso.list').writeAsStringSync('/opt/reso\n/opt/reso/reso\n');
    expect(UpdateService.linuxInstallFor('/opt/reso/reso', dpkgInfo: temp.path), LinuxInstall.deb);
    expect(
      UpdateService.linuxInstallFor('${temp.path}/reso', dpkgInfo: temp.path),
      LinuxInstall.folder,
    );

    final manifest = UpdateManifest(
      version: '2.1.0',
      linuxDeb: const UpdateAsset(url: 'https://x/a.deb'),
      linuxTarGz: const UpdateAsset(url: 'https://x/a.tar.gz'),
    );
    expect(manifest.assetForLinux(LinuxInstall.deb)!.url, endsWith('.deb'));
    expect(manifest.assetForLinux(LinuxInstall.folder)!.url, endsWith('.tar.gz'));
    expect(UpdateService.debInstallCommand('a.deb', root: false, hasApt: true).first, 'pkexec');
    expect(UpdateService.debFailure(126, root: false), isNotNull);
    expect(UpdateService.debFailure(0, root: false), isNull);
  });

  test('acha o programa dentro do .tar.gz extraido', () {
    final temp = Directory.systemTemp.createTempSync('reso-tar');
    addTearDown(() => temp.deleteSync(recursive: true));
    expect(UpdateService.findBundle(temp), isNull);
    File('${temp.path}/reso-2.1.0/bundle/reso').createSync(recursive: true);
    expect(UpdateService.findBundle(temp)!.path, endsWith('bundle'));
  });

  group('download', () {
    late HttpServer server;
    final payload = List<int>.generate(50000, (i) => i % 251);

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        request.response
          ..contentLength = payload.length
          ..add(payload)
          ..close();
      });
    });
    tearDown(() => server.close(force: true));

    String url(String name) => 'http://127.0.0.1:${server.port}/$name';

    test('baixa e confere o SHA-256', () async {
      final asset = UpdateAsset(
        url: url('reso-teste-ok.bin'),
        sha256: sha256.convert(payload).toString(),
        size: payload.length,
      );
      var last = 0.0;
      final file = await const UpdateService().download(asset, onProgress: (p) => last = p);
      addTearDown(() => file.deleteSync());
      expect(file.readAsBytesSync(), payload);
      expect(last, 1.0);
    });

    test('recusa e apaga um arquivo que nao confere', () async {
      final asset = UpdateAsset(url: url('reso-teste-ruim.bin'), sha256: '00' * 32);
      await expectLater(const UpdateService().download(asset), throwsA(isA<UpdateFailure>()));
      final leftover = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}reso-teste-ruim.bin',
      );
      expect(leftover.existsSync(), isFalse);
    });
  });
}
