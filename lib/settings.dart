import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias do app. As chaves sao as da primeira versao: quem atualiza
/// continua com a chave e as escolhas que ja tinha.
class Settings {
  Settings(this._prefs) : themeMode = ValueNotifier(_parseTheme(_prefs.getString(_kThemeMode)));

  static const _kObscureText = 'obscureText';
  static const _kObscureKey = 'modalObscureText';
  static const _kKey = 'modalText';
  static const _kThemeMode = 'themeMode';

  final SharedPreferences _prefs;

  /// Automatico, claro ou escuro; o app redesenha ao mudar.
  final ValueNotifier<ThemeMode> themeMode;

  bool get obscureText => _prefs.getBool(_kObscureText) ?? true;
  set obscureText(bool value) => _prefs.setBool(_kObscureText, value);

  bool get obscureKey => _prefs.getBool(_kObscureKey) ?? true;
  set obscureKey(bool value) => _prefs.setBool(_kObscureKey, value);

  String get key => _prefs.getString(_kKey) ?? '';
  set key(String value) => _prefs.setString(_kKey, value);

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    _prefs.setString(_kThemeMode, mode.name);
  }

  static ThemeMode _parseTheme(String? name) =>
      ThemeMode.values.firstWhere((mode) => mode.name == name, orElse: () => ThemeMode.system);
}
