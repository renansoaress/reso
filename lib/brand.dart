import 'package:flutter/material.dart';

/// As quatro cores do logo, em tons para cada tema. As do tema escuro sao as
/// mesmas do icone (tool/make_icon.py).
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.blue,
    required this.green,
    required this.red,
    required this.purple,
  });

  final Color blue;
  final Color green;
  final Color red;
  final Color purple;

  static const light = BrandColors(
    blue: Color(0xFF1F6FEB),
    green: Color(0xFF13A05A),
    red: Color(0xFFE23A4B),
    purple: Color(0xFF8A3FE0),
  );

  static const dark = BrandColors(
    blue: Color(0xFF4D94FF),
    green: Color(0xFF34D37F),
    red: Color(0xFFFF5C67),
    purple: Color(0xFFB474FF),
  );

  @override
  BrandColors copyWith({Color? blue, Color? green, Color? red, Color? purple}) {
    return BrandColors(
      blue: blue ?? this.blue,
      green: green ?? this.green,
      red: red ?? this.red,
      purple: purple ?? this.purple,
    );
  }

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    return BrandColors(
      blue: Color.lerp(blue, other.blue, t)!,
      green: Color.lerp(green, other.green, t)!,
      red: Color.lerp(red, other.red, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
    );
  }
}

extension BrandContext on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
}

/// O "ReSo" do logo: cada letra com a sua fonte e a sua cor.
class ResoWordmark extends StatelessWidget {
  const ResoWordmark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    TextSpan letter(
      String text,
      String family,
      Color color, {
      FontWeight weight = FontWeight.w800,
      FontStyle? style,
    }) => TextSpan(
      text: text,
      style: TextStyle(fontFamily: family, fontWeight: weight, fontStyle: style, color: color),
    );

    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: size, height: 1.1),
        children: [
          letter('R', 'LogoR', brand.blue, style: FontStyle.italic),
          letter('e', 'LogoE', brand.green),
          letter('S', 'LogoS', brand.red),
          letter('o', 'LogoO', brand.purple, weight: FontWeight.w900),
        ],
      ),
      semanticsLabel: 'ReSo',
    );
  }
}
