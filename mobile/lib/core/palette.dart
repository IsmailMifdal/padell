import 'package:flutter/material.dart';

/// Jetons de couleur et dégradés de l'identité Padel.
class AppColors {
  AppColors._();

  // Marque
  static const primary = Color(0xFF0FA968); // vert padel
  static const primaryDark = Color(0xFF07724A);
  static const primaryDeep = Color(0xFF054F36);
  static const lime = Color(0xFFB6F09C); // accent énergie

  // Neutres (light)
  static const ink = Color(0xFF0C1B14);
  static const slate = Color(0xFF5B6B63);
  static const bg = Color(0xFFF4F7F5);
  static const surface = Colors.white;
  static const line = Color(0xFFE4EAE6);

  // États
  static const amber = Color(0xFFF59E0B);
  static const danger = Color(0xFFE5484D);
  static const info = Color(0xFF2E7DF6);

  // Dégradé principal (hero, boutons, en-têtes)
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF047857)],
  );

  static const heroGradientDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B7A50), Color(0xFF043D2A)],
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
