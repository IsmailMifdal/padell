import 'package:flutter/material.dart';

/// Jetons de couleur et dégradés de l'identité Padel.
class AppColors {
  AppColors._();

  // Marque — vert émeraude profond, plus « premium » que le vert vif
  static const primary = Color(0xFF0DA271);
  static const primaryDark = Color(0xFF076B4B);
  static const primaryDeep = Color(0xFF04432F);
  static const lime = Color(0xFFC6F68D); // accent énergie (CTA secondaires)

  // Neutres (light) — fond légèrement chaud, encre plus profonde
  static const ink = Color(0xFF0B1712);
  static const slate = Color(0xFF64716A);
  static const bg = Color(0xFFF3F6F4);
  static const surface = Colors.white;
  static const line = Color(0xFFE3E9E5);

  // États
  static const amber = Color(0xFFF59E0B);
  static const danger = Color(0xFFE5484D);
  static const info = Color(0xFF2E7DF6);

  // Dégradé principal (hero, boutons, en-têtes) — émeraude → forêt
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF11B67E), Color(0xFF056243)],
  );

  static const heroGradientDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B7A50), Color(0xFF03392A)],
  );

  /// Palette de couvertures pour les cartes de clubs (choisie par empreinte).
  static const covers = <List<Color>>[
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFF2C7A51), Color(0xFF88D498)],
    [Color(0xFF136A8A), Color(0xFF267871)],
    [Color(0xFF0F766E), Color(0xFF5EEAD4)],
    [Color(0xFF166534), Color(0xFF4ADE80)],
    [Color(0xFF115E59), Color(0xFF2DD4BF)],
  ];

  static LinearGradient coverFor(String seed) {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final pair = covers[h % covers.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: pair,
    );
  }
}
