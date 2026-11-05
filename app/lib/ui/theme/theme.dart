import 'package:fikajiana/ui/theme/couleurs.dart';
import 'package:flutter/material.dart';

abstract class AppTheme {
  static final ThemeData clair = _theme(Brightness.light);
  static final ThemeData sombre = _theme(Brightness.dark);

  static ThemeData _theme(Brightness luminosite) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppCouleurs.encre,
        brightness: luminosite,
      ),
    );
  }
}
