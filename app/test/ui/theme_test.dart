import 'dart:math' as math;

import 'package:fikajiana/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rapport de contraste WCAG 2.2 :
/// https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio
double _contraste(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (nom, theme) in [
    ('clair', AppTheme.clair),
    ('sombre', AppTheme.sombre),
  ]) {
    final c = theme.colorScheme;

    group('thème $nom', () {
      test('Material 3', () => expect(theme.useMaterial3, isTrue));

      for (final (paire, avant, fond) in [
        ('onSurface / surface', c.onSurface, c.surface),
        ('onSurfaceVariant / surface', c.onSurfaceVariant, c.surface),
        ('primary / surface', c.primary, c.surface),
        ('tertiary / surface', c.tertiary, c.surface),
        ('onPrimary / primary', c.onPrimary, c.primary),
        (
          'onSecondaryContainer / secondaryContainer',
          c.onSecondaryContainer,
          c.secondaryContainer,
        ),
        ('onError / error', c.onError, c.error),
        ('secondary / surface', c.secondary, c.surface),
        ('onTertiary / tertiary', c.onTertiary, c.tertiary),
        (
          'onPrimaryContainer / primaryContainer',
          c.onPrimaryContainer,
          c.primaryContainer,
        ),
        (
          'onTertiaryContainer / tertiaryContainer',
          c.onTertiaryContainer,
          c.tertiaryContainer,
        ),
      ]) {
        test('texte ≥ 4,5:1 : $paire', () {
          final r = _contraste(avant, fond);
          // ignore: avoid_print, relevé noté dans docs/design.md
          print('$nom | $paire | ${r.toStringAsFixed(2)}');
          expect(r, greaterThanOrEqualTo(4.5));
        });
      }

      test('contour ≥ 3:1 : outline / surface', () {
        final r = _contraste(c.outline, c.surface);
        // ignore: avoid_print, relevé noté dans docs/design.md
        print('$nom | outline / surface | ${r.toStringAsFixed(2)}');
        expect(r, greaterThanOrEqualTo(3));
      });
    });
  }
}
