import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'reso.dart';
import 'settings.dart';
import 'settings_dialog.dart';
import 'update/update_dialog.dart';
import 'update/updates.dart';
import 'version.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings, this.updates});

  final Settings settings;
  final Updates? updates;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late bool _obscure = widget.settings.obscureText;
  String _hash = '';
  bool _copied = false;
  Timer? _copiedTimer;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _text.addListener(_update);
    // Procura versao nova depois da abertura, sem disputar com ela.
    final updates = widget.updates;
    if (updates != null) {
      _checkTimer = Timer(const Duration(seconds: 2), updates.check);
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _checkTimer?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _update() {
    final hash = reso(_text.text, key: widget.settings.key);
    if (hash == _hash) return;
    setState(() {
      _hash = hash;
      _copied = false;
    });
  }

  void _toggleObscure() {
    setState(() => _obscure = !_obscure);
    widget.settings.obscureText = _obscure;
  }

  Future<void> _copy() async {
    if (_hash.isEmpty) return;
    _focus.requestFocus();
    try {
      await Clipboard.setData(ClipboardData(text: _hash));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível copiar. Selecione e copie à mão.')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _clear() {
    _text.clear();
    _focus.requestFocus();
  }

  Future<void> _openSettings() async {
    final result = await showSettingsDialog(context, widget.settings, updates: widget.updates);
    if (!mounted) return;
    // Salvou: o texto digitado sai, como sempre foi (o ReSo de antes era da
    // chave antiga). O setState redesenha o indicador da engrenagem.
    if (result == SettingsResult.saved) _text.clear();
    setState(() {});
    if (result == SettingsResult.update) return _openUpdate();
    _focus.requestFocus();
  }

  Future<void> _openUpdate() async {
    final updates = widget.updates;
    if (updates == null) return;
    await showUpdateDialog(context, updates);
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.settings.key.isNotEmpty;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _clear,
        const SingleActivator(LogicalKeyboardKey.comma, control: true): _openSettings,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): _openSettings,
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: _Backdrop()),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.updates != null)
                          UpdatePill(updates: widget.updates!, onTap: _openUpdate),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: hasKey ? 'Configurações · chave ativa' : 'Configurações',
                          onPressed: _openSettings,
                          icon: Badge(
                            isLabelVisible: hasKey,
                            smallSize: 9,
                            backgroundColor: context.brand.red,
                            child: const Icon(Icons.tune_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: ResoWordmark(size: 64)),
                              const SizedBox(height: 28),
                              _input(),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: _hash.isEmpty
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 14),
                                        child: _ResultCard(
                                          hash: _hash,
                                          copied: _copied,
                                          onCopy: _copy,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const _Footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input() {
    return TextField(
      controller: _text,
      focusNode: _focus,
      autofocus: true,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      onSubmitted: (_) => _copy(),
      // Sem isto o Enter tira o foco do campo.
      onEditingComplete: () {},
      decoration: InputDecoration(
        hintText: 'Digite o texto :)',
        suffixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: IconButton(
            tooltip: _obscure ? 'Mostrar' : 'Ocultar',
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: _toggleObscure,
          ),
        ),
      ),
    );
  }
}

/// O ReSo gerado. Um toque (ou Enter no campo) copia.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.hash, required this.copied, required this.onCopy});

  final String hash;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.brand;

    // Cada tipo de caractere numa cor do logo: facil de conferir de olho.
    Color colorOf(int unit) {
      if (unit >= 0x41 && unit <= 0x5A) return brand.blue; // A-Z
      if (unit >= 0x30 && unit <= 0x39) return brand.purple; // 0-9
      if (unit >= 0x61 && unit <= 0x7A) return scheme.onSurface; // a-z
      return brand.red; // simbolos
    }

    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: copied ? brand.green : scheme.outlineVariant,
          width: copied ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onCopy,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        for (final unit in hash.codeUnits)
                          TextSpan(
                            text: String.fromCharCode(unit),
                            style: TextStyle(color: colorOf(unit)),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.w500,
                      fontSize: 24,
                      letterSpacing: 1.5,
                    ),
                    semanticsLabel: hash,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CopyPill(copied: copied),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyPill extends StatelessWidget {
  const _CopyPill({required this.copied});

  final bool copied;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.brand;
    final color = copied ? brand.green : scheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: Row(
          key: ValueKey(copied),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(copied ? Icons.check_rounded : Icons.content_copy_rounded, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              copied ? 'Copiado' : 'Copiar',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
    );
    final touch =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final wide = MediaQuery.sizeOf(context).width >= 560;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          Text('v$appVersion', style: muted),
          const Spacer(),
          if (!touch && wide)
            Text('Enter copia  ·  Esc limpa  ·  Ctrl+, configurações', style: muted),
        ],
      ),
    );
  }
}

/// Fundo com um brilho bem leve de cada cor do logo, um em cada canto.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final alpha = Theme.of(context).brightness == Brightness.dark ? 0.13 : 0.09;

    Widget glow(Alignment center, Color color) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 0.9,
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          glow(const Alignment(-1.0, -1.0), brand.blue),
          glow(const Alignment(1.0, -0.8), brand.green),
          glow(const Alignment(-1.0, 1.0), brand.red),
          glow(const Alignment(1.0, 1.0), brand.purple),
        ],
      ),
    );
  }
}
