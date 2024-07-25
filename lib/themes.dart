// lib/themes.dart

import 'package:flutter/material.dart';

ThemeData lightTheme = ThemeData(
  useMaterial3: true, // Ativa o Material 3
  colorScheme: const ColorScheme.light(
    primary: Colors.blue, // Cor principal para o tema claro
    onPrimary: Colors.white, // Cor do texto e ícones sobre o fundo principal
    secondary: Colors.amber, // Cor secundária
    onSecondary: Colors.black, // Cor do texto sobre o fundo geral
    surface: Colors.white, // Cor de fundo dos componentes, como cartões
    onSurface: Colors.black, // Cor do texto sobre os componentes
  ),
  appBarTheme: const AppBarTheme(
    color: Colors.blue, // Cor da AppBar no tema claro
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.blue, // Cor do texto e ícones no ElevatedButton
    ),
  ),
);

ThemeData darkTheme = ThemeData(
  useMaterial3: true, // Ativa o Material 3
  colorScheme: ColorScheme.dark(
    primary: Colors.blueGrey, // Cor principal para o tema escuro
    onPrimary: Colors.white, // Cor do texto e ícones sobre o fundo principal
    secondary: Colors.teal, // Cor secundária
    onSecondary: Colors.white, // Cor do texto sobre o fundo geral
    // surface: Colors.grey[850], // Cor de fundo dos componentes, como cartões
    surface: Colors.grey.shade800, // Cor de fundo dos componentes, como cartões
    onSurface: Colors.white, // Cor do texto sobre os componentes
  ),
  appBarTheme: const AppBarTheme(
    color: Colors.blueGrey, // Cor da AppBar no tema escuro
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.teal, // Cor do texto e ícones no ElevatedButton
    ),
  ),
);
