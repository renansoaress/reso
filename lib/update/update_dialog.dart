import 'package:flutter/material.dart';

import '../brand.dart';
import 'updates.dart';

/// O aviso de versao nova, ao lado da engrenagem. So aparece quando ha uma.
class UpdatePill extends StatelessWidget {
  const UpdatePill({super.key, required this.updates, required this.onTap});

  final Updates updates;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        if (!updates.hasUpdate) return const SizedBox.shrink();
        final downloading = updates.stage == UpdateStage.downloading;
        final green = context.brand.green;
        return Tooltip(
          message: 'ReSo ${updates.newVersion} disponível',
          child: TextButton.icon(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: green,
              backgroundColor: green.withValues(alpha: 0.12),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
            ),
            icon: downloading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: green,
                      value: updates.progress > 0 ? updates.progress : null,
                    ),
                  )
                : const Icon(Icons.system_update_alt_rounded, size: 18),
            label: Text(downloading ? '${(updates.progress * 100).round()}%' : 'Atualizar'),
          ),
        );
      },
    );
  }
}

/// Mostra o que ha de novo e, num clique, baixa, confere e instala.
Future<void> showUpdateDialog(BuildContext context, Updates updates) {
  return showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final brand = context.brand;
        final downloading = updates.stage == UpdateStage.downloading;
        final ready = updates.stage == UpdateStage.ready;
        final busy = downloading || updates.installing;
        final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

        Future<void> go() async {
          if (!ready) await updates.download();
          if (updates.stage != UpdateStage.ready) return;
          final tookOver = await updates.install();
          // Na falha o dialogo fica, com o motivo e o botao de tentar de novo.
          if (!tookOver && updates.error.isEmpty && context.mounted) {
            Navigator.of(context).pop();
          }
        }

        return AlertDialog(
          icon: Icon(Icons.system_update_alt_rounded, color: brand.green),
          title: Text(
            'ReSo ${updates.newVersion}',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  updates.notes.isNotEmpty ? updates.notes : 'Uma versão nova está disponível.',
                  style: muted,
                ),
                if (downloading) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      color: brand.green,
                      value: updates.progress > 0 ? updates.progress : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Baixando… ${(updates.progress * 100).round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (updates.installing) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Instalando: o ReSo fecha e abre de novo.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (updates.error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    updates.error,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Depois'),
            ),
            FilledButton(
              onPressed: busy ? null : go,
              child: Text(updates.error.isNotEmpty ? 'Tentar de novo' : 'Atualizar agora'),
            ),
          ],
        );
      },
    ),
  );
}
