import 'package:flutter/material.dart';

import 'settings.dart';
import 'update/updates.dart';
import 'version.dart';

/// Como as configuracoes fecharam.
enum SettingsResult {
  /// Esc, Cancelar ou o X: nada mudou (fora o tema, que vale na hora).
  cancelled,

  /// Salvar: a chave foi gravada.
  saved,

  /// O usuario pediu para atualizar o app.
  update,
}

/// Abre as configuracoes. O foco ja cai no campo da chave; Enter salva e Esc
/// fecha sem salvar. O tema muda na hora, sem precisar salvar.
Future<SettingsResult> showSettingsDialog(
  BuildContext context,
  Settings settings, {
  Updates? updates,
}) async {
  final result = await showDialog<SettingsResult>(
    context: context,
    builder: (_) => _SettingsDialog(settings: settings, updates: updates),
  );
  return result ?? SettingsResult.cancelled;
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.settings, this.updates});

  final Settings settings;
  final Updates? updates;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final _key = TextEditingController(text: widget.settings.key)
    ..selection = TextSelection.collapsed(offset: widget.settings.key.length);
  late bool _obscure = widget.settings.obscureKey;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _save() {
    widget.settings
      ..key = _key.text
      ..obscureKey = _obscure;
    Navigator.of(context).pop(SettingsResult.saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurfaceVariant,
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Configurações',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar (Esc)',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Text('Chave', style: label),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _key,
                      autofocus: true,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        hintText: 'Digite a chave :X',
                        suffixIcon: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: IconButton(
                            tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                            icon: Icon(
                              _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Misturada a cada texto. Vazia, o ReSo usa só o texto.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    Text('Tema', style: label),
                    const SizedBox(height: 8),
                    _ThemePicker(settings: widget.settings),
                    if (widget.updates != null) ...[
                      const SizedBox(height: 24),
                      Text('Versão', style: label),
                      const SizedBox(height: 4),
                      _UpdateRow(updates: widget.updates!),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: _save, child: const Text('Salvar')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Em telas estreitas os icones saem para os nomes caberem.
        final icons = constraints.maxWidth >= 340;
        ButtonSegment<ThemeMode> segment(
          ThemeMode mode,
          String text,
          IconData icon, [
          String? tooltip,
        ]) => ButtonSegment(
          value: mode,
          label: Text(text, maxLines: 1, softWrap: false),
          icon: icons ? Icon(icon, size: 18) : null,
          tooltip: tooltip,
        );

        return ValueListenableBuilder<ThemeMode>(
          valueListenable: settings.themeMode,
          builder: (context, mode, _) => SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              segment(
                ThemeMode.system,
                'Auto',
                Icons.brightness_auto_rounded,
                'Segue o tema do sistema',
              ),
              segment(ThemeMode.light, 'Claro', Icons.light_mode_rounded),
              segment(ThemeMode.dark, 'Escuro', Icons.dark_mode_rounded),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => settings.setThemeMode(selection.first),
          ),
        );
      },
    );
  }
}

/// A versao em uso e o botao de procurar outra.
class _UpdateRow extends StatelessWidget {
  const _UpdateRow({required this.updates});

  final Updates updates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final checking = updates.stage == UpdateStage.checking;
        final status = switch (updates.stage) {
          UpdateStage.checking => 'Procurando…',
          UpdateStage.failed => 'Não foi possível verificar: ${updates.error}',
          _ when updates.hasUpdate => 'Versão ${updates.newVersion} disponível.',
          _ when updates.newVersion.isNotEmpty => 'Esta é a versão mais recente.',
          _ => '',
        };
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ReSo $appVersion', style: theme.textTheme.bodyMedium),
                  if (status.isNotEmpty)
                    Text(
                      status,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: updates.stage == UpdateStage.failed
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (updates.hasUpdate)
              TextButton(
                onPressed: () => Navigator.of(context).pop(SettingsResult.update),
                child: const Text('Atualizar'),
              )
            else
              TextButton(
                onPressed: checking ? null : () => updates.check(silent: false),
                child: const Text('Procurar atualização'),
              ),
          ],
        );
      },
    );
  }
}
