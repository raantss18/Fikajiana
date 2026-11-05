import 'package:fikajiana/ui/theme/couleurs.dart';
import 'package:flutter/material.dart';

abstract class AppTheme {
  static final ThemeData clair = ThemeData(
    colorScheme: AppCouleurs.schemaClair,
    fontFamily: 'Nunito',
  );
  static final ThemeData sombre = ThemeData(
    colorScheme: AppCouleurs.schemaSombre,
    fontFamily: 'Nunito',
  );
}
