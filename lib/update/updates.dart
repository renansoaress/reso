import 'package:flutter/foundation.dart';

import 'updates_stub.dart' if (dart.library.io) 'updates_io.dart' as impl;

/// A etapa em que esta a atualizacao.
enum UpdateStage {
  /// Nada a fazer (ou nunca verificado).
  idle,

  /// Consultando o servidor.
  checking,

  /// Existe versao nova esperando o usuario decidir.
  available,

  /// Baixando o instalador.
  downloading,

  /// Instalador baixado e conferido.
  ready,

  /// A ultima tentativa falhou.
  failed,
}

/// Atualizacao das versoes de desktop (Windows e Linux).
///
/// A verificacao na abertura e discreta: falha em silencio e nunca atrapalha
/// o uso. Quem decide atualizar e o usuario. A web se atualiza pelo service
/// worker e o celular pela loja: la, [Updates.create] retorna nulo.
abstract class Updates extends ChangeNotifier {
  static Updates? create() => impl.createUpdates();

  UpdateStage get stage;

  /// A versao anunciada pelo servidor, ou vazio.
  String get newVersion;

  /// O que mudou, como publicado no manifesto.
  String get notes;

  /// De 0 a 1, durante o download.
  double get progress;

  /// O motivo da ultima falha, ou vazio.
  String get error;

  /// Se o instalador esta rodando (no Linux, o `apt` com a janela de senha).
  bool get installing;

  bool get hasUpdate =>
      stage == UpdateStage.available ||
      stage == UpdateStage.downloading ||
      stage == UpdateStage.ready;

  /// Consulta o servidor. Com [silent], os erros sao engolidos.
  Future<void> check({bool silent = true});

  /// Baixa e confere o instalador da versao anunciada.
  Future<void> download();

  /// Entrega o instalador ao sistema; `true` quando o ReSo vai fechar.
  Future<bool> install();
}
