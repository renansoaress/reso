import 'dart:io';

import '../version.dart';
import 'update_service.dart';
import 'updates.dart';

Updates? createUpdates() => Platform.isWindows || Platform.isLinux ? DesktopUpdates() : null;

class DesktopUpdates extends Updates {
  DesktopUpdates({
    UpdateService service = const UpdateService(),
    String current = appVersion,
    this.url = updateManifestUrl,
  }) : _service = service,
       _current = current;

  final UpdateService _service;
  final String _current;
  final String url;

  UpdateManifest? _manifest;
  File? _installer;

  @override
  UpdateStage stage = UpdateStage.idle;
  @override
  double progress = 0;
  @override
  String error = '';
  @override
  bool installing = false;

  @override
  String get newVersion => _manifest?.version ?? '';

  @override
  String get notes => _manifest?.notes ?? '';

  @override
  Future<void> check({bool silent = true}) async {
    if (stage == UpdateStage.checking || stage == UpdateStage.downloading) return;
    stage = UpdateStage.checking;
    error = '';
    notifyListeners();

    try {
      final found = await _service.fetch(url);
      _manifest = found;
      final newer = UpdateService.compareVersions(found.version, _current) > 0;
      stage = newer && found.assetForPlatform != null ? UpdateStage.available : UpdateStage.idle;
    } on UpdateFailure catch (failure) {
      _manifest = null;
      error = failure.message;
      stage = silent ? UpdateStage.idle : UpdateStage.failed;
    }
    notifyListeners();
  }

  @override
  Future<void> download() async {
    final asset = _manifest?.assetForPlatform;
    if (asset == null || stage == UpdateStage.downloading) return;

    stage = UpdateStage.downloading;
    progress = 0;
    error = '';
    notifyListeners();

    try {
      _installer = await _service.download(
        asset,
        onProgress: (value) {
          // Um aviso por ponto percentual: a barra anda sem redesenhar a cada
          // pacote de rede.
          final rounded = (value * 100).floor() / 100;
          if (rounded == progress) return;
          progress = rounded;
          notifyListeners();
        },
      );
      progress = 1;
      stage = UpdateStage.ready;
    } on UpdateFailure catch (failure) {
      error = failure.message;
      stage = UpdateStage.failed;
    } on Object catch (failure) {
      // Preso em "Baixando", o dialogo nao deixaria nem tentar de novo.
      error = failure.toString();
      stage = UpdateStage.failed;
    }
    notifyListeners();
  }

  @override
  Future<bool> install() async {
    final file = _installer;
    if (file == null || installing) return false;
    installing = true;
    error = '';
    notifyListeners();
    try {
      final tookOver = await _service.launch(file);
      // No Windows quem fecha o ReSo e o instalador; no Linux, o ajudante
      // espera este processo sair para reabrir. As preferencias ja foram
      // gravadas quando mudaram.
      if (tookOver && Platform.isLinux) exit(0);
      return tookOver;
    } on UpdateFailure catch (failure) {
      error = failure.message;
      return false;
    } finally {
      installing = false;
      notifyListeners();
    }
  }
}
