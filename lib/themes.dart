import 'package:flutter/material.dart';

import 'brand.dart';

final ThemeData lightTheme = _build(Brightness.light);
final ThemeData darkTheme = _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final brand = dark ? BrandColors.dark : BrandColors.light;

  // Superficies neutras levemente azuladas, puxadas para o azul do "R".
  final scheme = ColorScheme.fromSeed(seedColor: brand.blue, brightness: brightness).copyWith(
    primary: brand.blue,
    onPrimary: dark ? const Color(0xFF041026) : Colors.white,
    secondary: brand.purple,
    tertiary: brand.green,
    error: brand.red,
    surface: dark ? const Color(0xFF0E1016) : const Color(0xFFF4F5F9),
    onSurface: dark ? const Color(0xFFE8EAF2) : const Color(0xFF141824),
    onSurfaceVariant: dark ? const Color(0xFF9AA1B5) : const Color(0xFF5B6275),
    surfaceContainerLowest: dark ? const Color(0xFF13161E) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF171A23) : const Color(0xFFF9FAFC),
    surfaceContainer: dark ? const Color(0xFF1B1F29) : const Color(0xFFEEF0F5),
    surfaceContainerHigh: dark ? const Color(0xFF20242F) : const Color(0xFFE8EBF1),
    surfaceContainerHighest: dark ? const Color(0xFF272C38) : const Color(0xFFE1E5EC),
    outline: dark ? const Color(0xFF3B4253) : const Color(0xFFC3C8D4),
    outlineVariant: dark ? const Color(0xFF292E3B) : const Color(0xFFDCE0E8),
  );

  final radius = BorderRadius.circular(16);
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: color, width: width),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: scheme.surface,
    extensions: [brand],
    visualDensity: VisualDensity.standard,
    splashFactory: InkRipple.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 2),
      suffixIconColor: scheme.onSurfaceVariant,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      textStyle: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: scheme.surface),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
