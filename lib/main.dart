import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'settings.dart';
import 'themes.dart';
import 'update/updates.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // As preferencias sao lidas antes do primeiro quadro: o app ja abre no tema
  // escolhido, sem piscar o outro.
  final settings = Settings(await SharedPreferences.getInstance());
  runApp(ResoApp(settings: settings, updates: Updates.create()));
}

class ResoApp extends StatelessWidget {
  const ResoApp({super.key, required this.settings, this.updates});

  final Settings settings;

  /// Nulo onde o app nao se atualiza sozinho (web, celular, testes).
  final Updates? updates;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: settings.themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'ReSo',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: mode,
        home: HomePage(settings: settings, updates: updates),
      ),
    );
  }
}
