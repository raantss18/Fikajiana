import 'package:flutter/material.dart';

/// Couleurs de la marque (`docs/design.md`, ADR 0010).
abstract class AppCouleurs {
  static const Color orange = Color(0xFFF4A23C);
  static const ciel = Color(0xFF1E9FD8);
  static const saumon = Color(0xFFEC8A80);

  static const encre = Color(0xFF2A1E18);
  static const papier = Color(0xFFFFFBF4);
  static const ardoise = Color(0xFF1B1613);
  static const craie = Color(0xFFF2E9E1);

  /// Graine des rôles neutres : des gris chauds, comme le papier.
  static const Color graine = orange;

  static final ColorScheme schemaClair = ColorScheme.fromSeed(seedColor: graine)
      .copyWith(
        primary: const Color(0xFF006A9A),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFCDE9F8),
        onPrimaryContainer: const Color(0xFF00344D),
        secondary: const Color(0xFFA33F36),
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: const Color(0xFFFFDAD5),
        onSecondaryContainer: const Color(0xFF410906),
        tertiary: const Color(0xFF8A5000),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: const Color(0xFFFFDDB3),
        onTertiaryContainer: const Color(0xFF2C1600),
        surface: papier,
        onSurface: encre,
      );

  static final ColorScheme schemaSombre =
      ColorScheme.fromSeed(
        seedColor: graine,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF8BD0F5),
        onPrimary: const Color(0xFF00344D),
        primaryContainer: const Color(0xFF004C70),
        onPrimaryContainer: const Color(0xFFCDE9F8),
        secondary: const Color(0xFFFFB4AA),
        onSecondary: const Color(0xFF5A1510),
        secondaryContainer: const Color(0xFF7F2A22),
        onSecondaryContainer: const Color(0xFFFFDAD5),
        tertiary: const Color(0xFFFFB866),
        onTertiary: const Color(0xFF4A2800),
        tertiaryContainer: const Color(0xFF6A3C00),
        onTertiaryContainer: const Color(0xFFFFDDB3),
        surface: ardoise,
        onSurface: craie,
      );
}
